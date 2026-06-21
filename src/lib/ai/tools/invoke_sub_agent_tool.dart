import '../../modules/bulter_module.dart';
import '../../modules/registry.dart';
import '../sub_agents/orchestrator.dart';
import '../sub_agents/sub_agent_registry.dart';
import 'tool_registry.dart';

/// `invoke_sub_agent` 工具定义 + executor。
///
/// 暴露给**主模型**，让主模型在跨模块 / 跨领域问题时主动调子模型：
///   - 参数：`module_id` (5 选 1) + `query` (string)
///   - 返回：子模型自然语言结果（含 `toolsUsed` / `elapsed` 等元数据，便于主模型
///     在最终回复里附加"调度链路"叙事）
///
/// **物理约束**（来自 [Orchestrator]）：
/// - 子模型的 ToolRegistry 在注册时已 `includeWrite: false`，本工具拿不到写权限
/// - 单次调用默认 8s 超时，失败返回降级文案（不让主模型产生幻觉越权）
class InvokeSubAgentTool {
  InvokeSubAgentTool._();

  static const String toolName = 'invoke_sub_agent';

  static const ToolDefinition def = ToolDefinition(
    name: toolName,
    description:
        '调用某个模块的子模型，让它基于该模块的最新数据回答问题。'
        '子模型只能读本模块数据，无写权限；返回自然语言结果。'
        '跨模块问题应分多次调用本工具（每次一个 module_id）。',
    category: ToolCategory.system,
    parameters: {
      'type': 'object',
      'properties': {
        'module_id': {
          'type': 'string',
          'enum': ['relationship', 'growth', 'wealth', 'thought', 'health'],
          'description': '要调用的子模型所属模块',
        },
        'query': {
          'type': 'string',
          'description': '发给子模型的问题（自然语言）',
        },
      },
      'required': ['module_id', 'query'],
    },
  );

  /// 注册到主模型的 [ToolRegistry]。
  ///
  /// 必须在 [AppDatabase.I] 已就绪后才调用（executor 内部需要它）。
  static void registerAll(ToolRegistry registry) {
    registry.register(
      tool: def,
      executor: (params) async {
        final moduleId = params['module_id'] as String?;
        final query = params['query'] as String?;
        if (moduleId == null || query == null || query.trim().isEmpty) {
          return ToolResult.error('缺少 module_id 或 query 参数');
        }

        final orchestrator = Orchestrator(registry: SubAgentRegistry.instance);
        final result = await orchestrator.invokeSubAgent(moduleId, query);

        if (!result.ok) {
          // 降级路径：返回 status=ok 但 summary 含降级文案，让主模型看到
          // "该模块暂不可用"而不是工具调用失败。
          return ToolResult.ok(
            result.text,
            data: {
              'module_id': result.moduleId,
              'ok': false,
              'error': result.error ?? 'unknown',
              'elapsed_ms': result.elapsed.inMilliseconds,
            },
          );
        }

        return ToolResult.ok(
          result.text,
          data: {
            'module_id': result.moduleId,
            'module_name': result.moduleName,
            'ok': true,
            'tools_used': result.toolsUsed,
            'elapsed_ms': result.elapsed.inMilliseconds,
          },
        );
      },
    );
  }

  /// 暴露给 [ModuleRegistry] 用于主模型 tool schema（不需要 executor）。
  static List<ToolDefinition> get schema => const [def];
}
