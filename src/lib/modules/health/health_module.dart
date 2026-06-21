import 'package:flutter/material.dart';

import '../bulter_module.dart';
import '../../ai/tools/health_tools.dart';
import '../../features/health/health_home_page.dart';
import '../../theme/tokens.dart';
import 'db/health_daos.dart';
import 'db/health_tables.dart';

/// 健康模块
class HealthModule implements BulterModule {
  const HealthModule();

  @override
  String get id => ModuleId.health;

  @override
  String get displayName => '健康';

  @override
  Color get brandColor => BulterColors.health;

  @override
  String get iconName => 'health';

  @override
  String get entryRoute => '/health';

  @override
  Widget buildHomePage(BuildContext context) => const HealthHomePage();

  /// 健康模块当前是单页布局（对齐 phone-10 原型），子 tab 由 [HealthHomePage] 内部
  /// 处理；模块的 [tabs] 留空让 AppShell 走 buildHomePage。
  @override
  List<ModuleTab> get tabs => const [];

  @override
  SpecialistAgent? get subAgent => const SpecialistAgent(
    moduleId: ModuleId.health,
    name: 'Health Specialist',
  );

  @override
  List<ToolDefinition> get tools => const [
    HealthTools.queryRecordsDef,
    HealthTools.queryReportsDef,
    HealthTools.saveRecordDef,
    HealthTools.deleteRecordDef,
  ];

  @override
  BriefingGenerator? get briefingGenerator => null;

  @override
  List<Type> get tableClasses => const [
    HealthRecords,
    CheckupReports,
    HealthScores,
  ];

  @override
  List<Type> get daoClasses => const [HealthDao];

  @override
  Future<void> onRegister() async {}

  @override
  Future<void> onDispose() async {}
}
