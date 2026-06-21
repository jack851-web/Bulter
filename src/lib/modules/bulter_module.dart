import 'dart:async' show TimeoutException;

import 'package:drift/drift.dart';
import 'package:flutter/material.dart' hide Table;

import '../ai/ai_service.dart';
import '../ai/memory/short_term.dart';
import '../ai/tools/tool_registry.dart';
import '../theme/tokens.dart';

/// 模块 ID。约定全小写，URL / 事件 / Hive Box 命名都用这个。
class ModuleId {
  ModuleId._();
  static const String butler = 'butler';
  static const String relationship = 'relationship';
  static const String growth = 'growth';
  static const String wealth = 'wealth';
  static const String thought = 'thought';
  static const String health = 'health';
  static const String memory = 'memory';
  static const String demo = 'demo';
}

/// 子 Agent（Specialist Agent）— Step 8 起成为可调用实例。
///
/// 注册时由 [SubAgentRegistry] 注入隔离的 [ToolRegistry]（仅含只读工具 + RAG）
/// + 主模型共用的 [AiService]，构造时即**物理隔离写权限**：子 Agent 的
/// ToolRegistry 在 [SubAgentRegistry.register] 里走 `includeWrite: false`，
/// 因此 SpecialistAgent 拿不到任何 write/confirmation 工具，从根上断绝越权。
///
/// 调用语义（[invoke]）：
/// 1. 拼一个简短的 system prompt："你是 Bulter 的 X 模块子助手，只能读 X 模块数据…"
/// 2. 走标准 [AiService.streamCompletion] + 隔离 ToolRegistry → 子 Agent 自由调用本模块只读工具
/// 3. 8s 超时；失败 / 越权 / 超时统一返回降级文案（不让主模型幻觉越权）
class SpecialistAgent {
  final String moduleId;
  final String name;
  final String systemPrompt;
  final ToolRegistry toolRegistry;
  final AiService aiService;
  final Duration defaultTimeout;

  SpecialistAgent({
    required this.moduleId,
    required this.name,
    required this.systemPrompt,
    required this.toolRegistry,
    required this.aiService,
    this.defaultTimeout = const Duration(seconds: 8),
  });

  /// 拉起一次子模型调用（短上下文 + 隔离 ToolRegistry + RAG 自动注入）。
  ///
  /// 返回 [SubAgentResult]，**始终成功**（即使 LLM 失败 / 超时也返回降级文案），
  /// 主模型拿到结果后可继续拼装跨模块叙事。
  Future<SubAgentResult> invoke(
    String query, {
    Duration? timeout,
    void Function(String toolName)? onToolCall,
  }) async {
    final limit = timeout ?? defaultTimeout;
    final stopwatch = Stopwatch()..start();
    final toolsUsed = <String>[];
    final memory = ShortTermMemory(maxRounds: 12)
      ..addSystem(systemPrompt)
      ..append(
        ChatMessage(
          role: ChatRole.user,
          content: query,
          createdAt: DateTime.now(),
        ),
      );

    final captured = StringBuffer();
    final errors = <String>[];

    final chatOptions = ChatOptions(
      reactLoop: true,
      maxReactRounds: 4,
      toolRegistry: toolRegistry,
    );

    try {
      await aiService
          .streamCompletion(
            memory: memory,
            callback: (event) {
              if (event.error != null) {
                final msg = event.error is AiError
                    ? (event.error as AiError).message
                    : event.error.toString();
                errors.add(msg);
                return;
              }
              if (event.hasToolCalls) {
                for (final c in event.toolCalls) {
                  toolsUsed.add(c.name);
                  onToolCall?.call(c.name);
                }
              }
              if (event.delta.isNotEmpty) {
                captured.write(event.delta);
              }
            },
            options: chatOptions,
          )
          .timeout(limit);

      final text = captured.toString().trim();
      stopwatch.stop();
      if (text.isEmpty) {
        return SubAgentResult(
          moduleId: moduleId,
          moduleName: name,
          ok: false,
          text: '（$name 子模型未返回内容）',
          toolsUsed: toolsUsed,
          elapsed: stopwatch.elapsed,
          error: errors.isEmpty ? null : errors.join('；'),
        );
      }
      return SubAgentResult(
        moduleId: moduleId,
        moduleName: name,
        ok: true,
        text: text,
        toolsUsed: toolsUsed,
        elapsed: stopwatch.elapsed,
      );
    } on TimeoutException {
      stopwatch.stop();
      return SubAgentResult(
        moduleId: moduleId,
        moduleName: name,
        ok: false,
        text: '（$name 子模型调用超时，已降级。该模块暂时不可用）',
        toolsUsed: toolsUsed,
        elapsed: stopwatch.elapsed,
        error: 'timeout ${limit.inMilliseconds}ms',
      );
    } catch (e) {
      stopwatch.stop();
      return SubAgentResult(
        moduleId: moduleId,
        moduleName: name,
        ok: false,
        text: '（$name 子模型调用失败：${e.toString().split('\n').first}）',
        toolsUsed: toolsUsed,
        elapsed: stopwatch.elapsed,
        error: e.toString(),
      );
    }
  }
}

/// 子 Agent 一次调用的结构化结果。
///
/// 主模型在 `invoke_sub_agent` 工具里收到 `text`（自然语言），直接转给 LLM 拼装
/// 跨模块叙事；同时 `toolsUsed` / `elapsed` / `error` 给对话页用于渲染调度链路卡。
class SubAgentResult {
  final String moduleId;
  final String moduleName;
  final bool ok;
  final String text;
  final List<String> toolsUsed;
  final Duration elapsed;
  final String? error;

  const SubAgentResult({
    required this.moduleId,
    required this.moduleName,
    required this.ok,
    required this.text,
    required this.toolsUsed,
    required this.elapsed,
    this.error,
  });

  /// 给 LLM 看的简洁表达（不包含 elapsed / toolsUsed 等元信息）。
  String toLlmContext() => '[$moduleName] $text';

  /// 给 UI 看的调度链路卡文本。
  String toUiCard() {
    if (ok) {
      final tools = toolsUsed.isEmpty ? '' : '（用了 ${toolsUsed.join(' / ')}）';
      return '$moduleName · ${elapsed.inMilliseconds}ms$tools';
    }
    return '$moduleName · 失败 · ${error ?? "未知"}';
  }
}

/// 工具分类。
enum ToolCategory { read, write, confirmation, system }

/// 工具定义（Step 5 完整版：name / description / JSON Schema / category）。
class ToolDefinition {
  /// OpenAI Function Calling 的工具名（同一注册表内唯一，snake_case）
  final String name;

  /// 工具中文 + 英文描述，给 LLM 看
  final String description;

  /// 工具分类
  final ToolCategory category;

  /// JSON Schema 描述参数列表。
  /// 格式与 OpenAI Chat Completions `tools[i].function.parameters` 完全一致：
  /// ```json
  /// {
  ///   "type": "object",
  ///   "properties": {
  ///     "name": {"type": "string", "description": "..."}
  ///   },
  ///   "required": ["name"]
  /// }
  /// ```
  final Map<String, dynamic> parameters;

  const ToolDefinition({
    required this.name,
    required this.description,
    required this.category,
    this.parameters = const {
      'type': 'object',
      'properties': <String, dynamic>{},
    },
  });
}

/// 工具执行器：返回 [ToolResult]（定义在 `ai/tools/tool_registry.dart`）。
///
/// 为了避免模块间循环 import，本 typedef 的返回类型用动态化的 `Map`；
/// 实际注册时的真实签名是 `Future<ToolResult> Function(Map<String, dynamic>)`，
/// 在 `tool_registry.dart` 的 [ToolRegistry.register] 处做协变检查。
typedef ToolExecutor = Future<dynamic> Function(Map<String, dynamic> params);

/// 简报生成器（占位；Step 9 实现）
typedef BriefingGenerator = Future<String> Function();

/// 业务模块统一接口。
///
/// 任何新增模块（关系/成长/财富/思想/健康/记忆/自定义 demo 模块）都必须
/// 实现该接口，并通过 [ModuleRegistry] 注册。新增模块**不需要**修改 router
/// / orchestrator / EventBus 主流程。
abstract class BulterModule {
  /// 唯一 ID（参见 [ModuleId] 常量约定）
  String get id;

  /// 展示名（中文）
  String get displayName;

  /// 品牌色（用于卡片/icon/胶囊切换器高亮）
  Color get brandColor;

  /// lucide 图标名（用于跨模块一致图标；Step 1 阶段可使用 Material Icons fallback）
  String get iconName;

  /// 入口路由 path（go_router）
  String get entryRoute;

  /// 主页 Scaffold（模块内默认视图）。Step 1 用占位，Step 3 起接真实 CRUD。
  Widget buildHomePage(BuildContext context);

  /// 模块内子 Tab 列表（占位；Step 3 后接真实 tabs）。
  /// 返回空列表则不显示底部 Tab。
  List<ModuleTab> get tabs;

  /// 该模块需要注册的子 Agent（默认 null；中枢 / Demo 模块无子 Agent）。
  /// 5 个业务模块 **不直接 override 此 getter** — 改为 override [hasSubAgent]
  /// 让 [SubAgentRegistry] 在启动时构造真实可调用的 [SpecialistAgent] 实例。
  SpecialistAgent? get subAgent;

  /// 是否声明拥有子 Agent（Step 8 引入）。
  ///
  /// 5 个业务模块 override 为 `true`，[SubAgentRegistry] 会在启动时根据
  /// `module.id` + `module.displayName` + 模块 tools 构造真实可调用的
  /// [SpecialistAgent] 实例。中枢 / Demo 模块 override 为 `false`，不会被注册。
  bool get hasSubAgent;

  /// 该模块提供的只读/写工具 id 列表（供 ToolRegistry 注册）
  List<ToolDefinition> get tools;

  /// 该模块提供的简报生成器
  BriefingGenerator? get briefingGenerator;

  /// 该模块归属的 Drift [Table] 类列表（用于 AppDatabase 静态注册 +
  /// 测试时验证模块自包含）。Step 2 接入 Drift 后填充。
  List<Type> get tableClasses => const [];

  /// 该模块提供的 DAO 类（同样是 Type 列表，DAO 实例由 [ModuleRegistry] /
  /// [AppDatabase] 在打开数据库后构造并按需暴露）。
  List<Type> get daoClasses => const [];

  /// 注册时回调（用于挂载 EventBus 监听、打开 Hive Box 等）
  Future<void> onRegister();

  /// 卸载时回调
  Future<void> onDispose();
}

/// DAO 工厂：模块可按需提供 DAO 实例的构造方法（在数据库打开后调用）。
typedef DaoFactory<T> = T Function(QueryExecutor db);

/// 模块内 Tab 描述
class ModuleTab {
  final String id;
  final String label;
  final String iconName;
  final WidgetBuilder builder;

  const ModuleTab({
    required this.id,
    required this.label,
    required this.iconName,
    required this.builder,
  });
}

/// 颜色助手：按 id 返回默认品牌色（仅在模块未实现 brandColor 时兜底）
Color defaultBrandColor(String id) {
  switch (id) {
    case ModuleId.butler:
      return BulterColors.butler;
    case ModuleId.relationship:
      return BulterColors.relationship;
    case ModuleId.growth:
      return BulterColors.growth;
    case ModuleId.wealth:
      return BulterColors.wealth;
    case ModuleId.thought:
      return BulterColors.thought;
    case ModuleId.health:
      return BulterColors.health;
    case ModuleId.memory:
      return BulterColors.memory;
    case ModuleId.demo:
      return BulterColors.info;
    default:
      return BulterColors.butler;
  }
}
