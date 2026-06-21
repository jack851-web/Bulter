import 'package:flutter/foundation.dart';

import '../../modules/bulter_module.dart';
import '../../modules/registry.dart';
import '../ai_service.dart';
import '../tools/tool_registry.dart';

/// 子模型（Specialist Agent）注册表。
///
/// Step 8 改造：
/// - 每个 SpecialistAgent 持有 `AiService` + 隔离 `ToolRegistry` 的真实可调用实例。
/// - 注册时通过 `module.hasSubAgent` 判断是否注册（中枢 / 演示模块返回 `false`）。
/// - 物理隔离：[ToolRegistry] 在构造时走 `includeWrite: false`，写工具根本进不来。
class SubAgentRegistry {
  SubAgentRegistry._();
  static final SubAgentRegistry instance = SubAgentRegistry._();

  final Map<String, SpecialistAgent> _agents = {};
  final Map<String, ToolRegistry> _isolatedToolRegistries = {};

  /// 注册一个模块的子 Agent。
  ///
  /// 仅当模块 `hasSubAgent == true` 时才注册。中枢 / 演示模块默认 `hasSubAgent=false`，
  /// 不会被注册。
  void register(BulterModule module) {
    if (!module.hasSubAgent) return;

    // 构造隔离的 ToolRegistry（只读 + briefing + RAG，写工具物理不进入）。
    final isolated = ToolRegistry.fresh();
    isolated.registerFromModules([module], includeWrite: false);
    _isolatedToolRegistries[module.id] = isolated;

    final agent = SpecialistAgent(
      moduleId: module.id,
      name: module.displayName,
      systemPrompt: _composeSystemPrompt(module.id, module.displayName),
      toolRegistry: isolated,
      aiService: AiService.instance,
    );
    _agents[module.id] = agent;
  }

  void registerAllFromModules(List<BulterModule> modules) {
    for (final m in modules) {
      register(m);
    }
  }

  SpecialistAgent? get(String moduleId) => _agents[moduleId];
  ToolRegistry? toolsOf(String moduleId) => _isolatedToolRegistries[moduleId];
  List<SpecialistAgent> get all => _agents.values.toList(growable: false);

  /// 全部子 Agent 的隔离 ToolRegistry（app_bootstrap 给它们注入 executor）。
  Map<String, ToolRegistry> get allToolRegistries =>
      Map.unmodifiable(_isolatedToolRegistries);

  /// 便利方法：从 ModuleRegistry 一次性同步。
  void syncFromModuleRegistry() {
    registerAllFromModules(ModuleRegistry.instance.all);
  }

  void clear() {
    _agents.clear();
    _isolatedToolRegistries.clear();
  }

  /// 子 Agent 的 system prompt：声明身份 + 严格的能力边界 + 回复格式。
  static String _composeSystemPrompt(String moduleId, String displayName) {
    return '你是 Bulter 的 "$displayName"（模块 $moduleId）子助手。\n'
        '\n'
        '能力边界（**严格执行**）：\n'
        '1. 只能读本模块（$moduleId）的数据，**绝对不能**读写其他模块\n'
        '2. 只能调用只读工具；写工具 / 删除工具都没有注册，物理上不可用\n'
        '3. 不要猜测其他模块的数据，需要时告诉用户"这个信息需要问 $moduleId 之外的其他模块"\n'
        '\n'
        '回复格式：\n'
        '- 直接回答问题，像真人聊天一样\n'
        '- 数字要带单位（¥、天、kg 等）\n'
        '- 最多 200 字；超过就只给最重要的几条\n'
        '- 不要 markdown 围栏或项目符号列表（除非用户要）';
  }
}
