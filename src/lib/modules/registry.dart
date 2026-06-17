import 'package:flutter/foundation.dart';

import 'bulter_module.dart';

/// 全局模块注册表。
///
/// App 启动时由 [registerAll] 遍历注册所有模块；后续胶囊切换器、底部 Tab、
/// 路由表、子 Agent、工具列表都从本注册表动态生成，**不硬编码模块列表**。
///
/// 验证原则：任何"加新模块"动作只需要：
///   1) 新建 `lib/modules/<id>/` 目录并实现 [BulterModule]
///   2) 在 [registerAll] 里加一行 `register(MyModule())`
/// 即可。**不应**修改 router / orchestrator / EventBus 等主框架文件。
class ModuleRegistry {
  ModuleRegistry._();
  static final ModuleRegistry instance = ModuleRegistry._();

  final Map<String, BulterModule> _modules = {};
  bool _initialized = false;

  /// 注册一个模块。重复注册会覆盖（并打印警告）。
  void register(BulterModule module) {
    if (_modules.containsKey(module.id)) {
      debugPrint('ModuleRegistry: 模块 ${module.id} 已存在，将被覆盖');
    }
    _modules[module.id] = module;
  }

  /// 批量注册；通常在 main() 启动阶段调用一次。
  Future<void> registerAll(List<BulterModule> modules) async {
    for (final m in modules) {
      register(m);
    }
    // 触发 onRegister
    for (final m in _modules.values) {
      await m.onRegister();
    }
    _initialized = true;
  }

  BulterModule? get(String id) => _modules[id];
  List<BulterModule> get all => _modules.values.toList(growable: false);

  /// 顶层胶囊切换器列表：[Bulter 中枢] + 各业务模块。
  /// Bulter 中枢是固定的"主入口"，不属于业务模块。
  List<BulterModule> get capsuleModules {
    final list = <BulterModule>[];
    final butler = _modules[ModuleId.butler];
    if (butler != null) list.add(butler);
    // 业务模块按固定顺序
    for (final id in const [
      ModuleId.relationship,
      ModuleId.growth,
      ModuleId.wealth,
      ModuleId.thought,
      ModuleId.health,
    ]) {
      final m = _modules[id];
      if (m != null) list.add(m);
    }
    // 动态注册的扩展模块（demo 等）追加在末尾
    for (final m in _modules.values) {
      if (m.id == ModuleId.butler) continue;
      if (const [
        ModuleId.relationship,
        ModuleId.growth,
        ModuleId.wealth,
        ModuleId.thought,
        ModuleId.health,
      ].contains(m.id)) {
        continue;
      }
      list.add(m);
    }
    return list;
  }

  bool get isInitialized => _initialized;
}
