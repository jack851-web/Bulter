import 'package:flutter/foundation.dart';

import '../../modules/bulter_module.dart';

/// AI 工具注册表。
///
/// 通过 [register] 动态注册工具，AI Service 调用 [getJsonSchemas] 取得
/// 当前可用工具列表，调用 [execute] 执行具体工具。
///
/// **权限隔离**在**注册层**完成：子 Agent 构造时只注入 `read / system`
/// 类工具，从根本上隔离写权限，无需运行时字符串匹配。
class ToolRegistry {
  ToolRegistry._();

  /// 工厂构造器：用于子 Agent 创建独立的隔离注册表。
  factory ToolRegistry.fresh() => ToolRegistry._();

  static final ToolRegistry instance = ToolRegistry._();

  final Map<String, ToolDefinition> _definitions = {};
  final Map<String, ToolExecutor> _executors = {};

  /// 注册一个工具（含定义 + 执行器）。
  void register({
    required ToolDefinition tool,
    required ToolExecutor executor,
  }) {
    if (_definitions.containsKey(tool.name)) {
      debugPrint('ToolRegistry: 工具 ${tool.name} 已存在，将被覆盖');
    }
    _definitions[tool.name] = tool;
    _executors[tool.name] = executor;
  }

  /// 收集模块列表中所有工具并注册。
  ///
  /// - 主模型：[includeWrite] = true（默认）
  /// - 子 Agent：[includeWrite] = false（只注入 read / system 类）
  void registerFromModules(
    List<BulterModule> modules, {
    bool includeWrite = true,
  }) {
    for (final m in modules) {
      for (final t in m.tools) {
        if (!includeWrite && t.category == ToolCategory.write) continue;
        if (!includeWrite && t.category == ToolCategory.confirmation) {
          continue;
        }
        _definitions[t.name] = t;
        _executors.putIfAbsent(
          t.name,
          () =>
              (params) async => {
                'status': 'not_implemented',
                'tool': t.name,
                'params': params,
              },
        );
      }
    }
  }

  /// 列出当前注册表中所有工具定义。
  List<ToolDefinition> getTools() =>
      _definitions.values.toList(growable: false);

  /// 按分类筛选。
  List<ToolDefinition> getToolsByCategory(ToolCategory category) {
    return _definitions.values
        .where((t) => t.category == category)
        .toList(growable: false);
  }

  /// 转 OpenAI Function Calling JSON Schema 格式。
  List<Map<String, dynamic>> getJsonSchemas() {
    return _definitions.values
        .map(
          (t) => {
            'type': 'function',
            'function': {
              'name': t.name,
              'description': t.description,
              'parameters': t.parameters,
            },
          },
        )
        .toList(growable: false);
  }

  /// 执行工具。返回 [ToolResult]（结构化结果）。
  Future<ToolResult> execute(String name, Map<String, dynamic> params) async {
    final exec = _executors[name];
    if (exec == null) {
      return ToolResult.error('未注册工具：$name');
    }
    try {
      final raw = await exec(params);
      // 兼容两种返回值：ToolResult / Map<String, dynamic>
      if (raw is ToolResult) return raw;
      if (raw is Map<String, dynamic>) {
        return ToolResult.fromMap(raw);
      }
      return ToolResult.error('工具返回类型异常：${raw.runtimeType}');
    } catch (e, st) {
      debugPrint('ToolRegistry: 执行 $name 出错: $e\n$st');
      return ToolResult.error(e.toString());
    }
  }

  void clear() {
    _definitions.clear();
    _executors.clear();
  }
}

/// 工具执行结果（统一格式）。
///
/// - `status`：`ok` / `pending_confirmation` / `error` / `cancelled`
/// - `summary`：给 LLM 看的一句话总结
/// - `data`：结构化数据（id / 列表等），供 LLM 后续推理使用
class ToolResult {
  final String status;
  final String summary;
  final Map<String, dynamic> data;
  final bool needsConfirmation;
  final String? confirmationPrompt;

  const ToolResult({
    required this.status,
    required this.summary,
    this.data = const {},
    this.needsConfirmation = false,
    this.confirmationPrompt,
  });

  factory ToolResult.fromMap(Map<String, dynamic> map) {
    final status = (map['status'] as String?) ?? 'ok';
    return ToolResult(
      status: status,
      summary: (map['summary'] as String?) ?? '',
      data: (map['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      needsConfirmation: status == 'pending_confirmation',
      confirmationPrompt: map['confirmation_prompt'] as String?,
    );
  }

  factory ToolResult.ok(
    String summary, {
    Map<String, dynamic> data = const {},
  }) => ToolResult(status: 'ok', summary: summary, data: data);

  factory ToolResult.error(String message) =>
      ToolResult(status: 'error', summary: message);

  factory ToolResult.confirm(
    String prompt, {
    Map<String, dynamic> data = const {},
  }) => ToolResult(
    status: 'pending_confirmation',
    summary: prompt,
    data: data,
    needsConfirmation: true,
    confirmationPrompt: prompt,
  );
}
