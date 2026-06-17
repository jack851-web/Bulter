import '../../modules/bulter_module.dart';
import '../../modules/registry.dart';
import '../tools/tool_registry.dart';

/// 子模型（Specialist Agent）注册表。
///
/// 子模型注册时通过 [ToolRegistry] 注入**只读 + RAG + briefing_publish**
/// 工具，物理上无法执行写操作。
class SubAgentRegistry {
  SubAgentRegistry._();
  static final SubAgentRegistry instance = SubAgentRegistry._();

  final Map<String, SpecialistAgent> _agents = {};
  final Map<String, ToolRegistry> _isolatedToolRegistries = {};

  void register(BulterModule module) {
    final agent = module.subAgent;
    if (agent == null) return;
    _agents[module.id] = agent;

    // 为该子模型构造独立的 ToolRegistry：只注入只读 + briefing + RAG
    final isolated = ToolRegistry.fresh();
    isolated.registerFromModules([module], includeWrite: false);
    _isolatedToolRegistries[module.id] = isolated;
  }

  void registerAllFromModules(List<BulterModule> modules) {
    for (final m in modules) {
      register(m);
    }
  }

  SpecialistAgent? get(String moduleId) => _agents[moduleId];
  ToolRegistry? toolsOf(String moduleId) => _isolatedToolRegistries[moduleId];
  List<SpecialistAgent> get all => _agents.values.toList(growable: false);

  /// 便利方法：从 ModuleRegistry 一次性同步
  void syncFromModuleRegistry() {
    registerAllFromModules(ModuleRegistry.instance.all);
  }

  void clear() {
    _agents.clear();
    _isolatedToolRegistries.clear();
  }
}
