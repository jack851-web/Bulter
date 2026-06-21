import 'package:flutter/material.dart';

import '../bulter_module.dart';
import '../../features/growth/growth_home_page.dart';
import '../../theme/tokens.dart';
import 'db/growth_daos.dart';
import 'db/growth_tables.dart';

/// 成长模块
class GrowthModule implements BulterModule {
  const GrowthModule();

  @override
  String get id => ModuleId.growth;

  @override
  String get displayName => '成长';

  @override
  Color get brandColor => BulterColors.growth;

  @override
  String get iconName => 'growth';

  @override
  String get entryRoute => '/growth';

  @override
  Widget buildHomePage(BuildContext context) => const GrowthHomePage();

  /// 成长模块当前是单页布局（对齐 phone-05 原型），子 tab 由 [GrowthHomePage] 内部
  /// 处理；模块的 [tabs] 留空让 AppShell 走 buildHomePage。
  @override
  List<ModuleTab> get tabs => const [];

  @override
  bool get hasSubAgent => true;

  @override
  SpecialistAgent? get subAgent => null;

  @override
  void Function(BuildContext)? get quickAdd => GrowthHomePage.openAddGoal;

  @override
  List<ToolDefinition> get tools => const [];

  @override
  BriefingGenerator? get briefingGenerator => null;

  @override
  List<Type> get tableClasses => const [Goals, Okrs, LearningRecords, Projects];

  @override
  List<Type> get daoClasses => const [GrowthDao];

  @override
  Future<void> onRegister() async {}

  @override
  Future<void> onDispose() async {}
}
