import 'ai/sub_agents/sub_agent_registry.dart';
import 'ai/tools/tool_registry.dart';
import 'modules/butler/butler_module.dart';
import 'modules/demo/demo_module.dart';
import 'modules/growth/growth_module.dart';
import 'modules/health/health_module.dart';
import 'modules/registry.dart';
import 'modules/relationship/relationship_module.dart';
import 'modules/thought/thought_module.dart';
import 'modules/wealth/wealth_module.dart';

/// App 启动时调用一次：注册所有模块 + 同步子 Agent / 工具注册表。
///
/// **核心原则**：任何"加新模块"的动作只需要在下方 [registerAll] 加一行。
/// **不**修改 router / orchestrator / EventBus 等主框架文件。
Future<void> bootstrapApp() async {
  final registry = ModuleRegistry.instance;
  await registry.registerAll(const [
    // 中枢
    ButlerModule(),
    // 业务模块
    RelationshipModule(),
    GrowthModule(),
    WealthModule(),
    ThoughtModule(),
    HealthModule(),
    // 模块化验证假模块（plan.md 第 1 步完成标准第 8 条）
    DemoModule(),
  ]);

  // 主模型注册全量工具（含写工具）
  ToolRegistry.instance
    ..clear()
    ..registerFromModules(registry.all, includeWrite: true);

  // 子 Agent 注册表：每个子模型独立 ToolRegistry，物理隔离写工具
  SubAgentRegistry.instance
    ..clear()
    ..syncFromModuleRegistry();
}
