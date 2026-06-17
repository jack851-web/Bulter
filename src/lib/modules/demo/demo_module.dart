import 'package:flutter/material.dart';

import '../bulter_module.dart';
import '../module_placeholder_page.dart';
import '../../theme/tokens.dart';
import '../../components/svg_icon.dart';
import 'db/demo_daos.dart';
import 'db/demo_tables.dart';

/// 假模块 Demo：用于验证模块化架构（plan.md 第 1 步完成标准第 8 条）。
///
/// 验证方式：在 `lib/modules/demo/` 目录下新建文件 + 在 `app_bootstrap.dart`
/// 注册一行 `register(DemoModule())`，胶囊切换器自动出现"Demo"入口。
/// **不需要**修改 router / orchestrator / EventBus 等任何主框架文件。
class DemoModule implements BulterModule {
  const DemoModule();

  @override
  String get id => ModuleId.demo;

  @override
  String get displayName => 'Demo';

  @override
  Color get brandColor => BulterColors.info;

  @override
  String get iconName => 'puzzle';

  @override
  String get entryRoute => '/demo';

  @override
  Widget buildHomePage(BuildContext context) => ModulePlaceholderPage(
    moduleName: 'Demo',
    brandColor: BulterColors.info,
    icon: const SvgIcon('common/circle.svg', size: 32),
    features: const [
      '这是一个假业务模块',
      '仅用于验证"模块化插拔"架构',
      '注册一行即可出现在胶囊切换器',
      '不修改 router / orchestrator / EventBus 任何主框架文件',
    ],
  );

  @override
  List<ModuleTab> get tabs => const [
    ModuleTab(
      id: 'main',
      label: '主页',
      iconName: 'common/circle.svg',
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'settings',
      label: '设置',
      iconName: 'common/tune.svg',
      builder: _placeholder,
    ),
  ];

  @override
  SpecialistAgent? get subAgent => null;

  @override
  List<ToolDefinition> get tools => const [];

  @override
  BriefingGenerator? get briefingGenerator => null;

  @override
  List<Type> get tableClasses => const [DemoItems];

  @override
  List<Type> get daoClasses => const [DemoDao];

  @override
  Future<void> onRegister() async {}

  @override
  Future<void> onDispose() async {}
}

Widget _placeholder(BuildContext context) => const SizedBox.shrink();
