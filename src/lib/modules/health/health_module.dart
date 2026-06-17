import 'package:flutter/material.dart';

import '../bulter_module.dart';
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

  @override
  List<ModuleTab> get tabs => const [
    ModuleTab(
      id: 'records',
      label: '记录',
      iconName: 'modules/timeline.svg',
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'reports',
      label: '体检',
      iconName: 'modules/report.svg',
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'trends',
      label: '趋势',
      iconName: 'modules/chart.svg',
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'devices',
      label: '设备',
      iconName: 'modules/chip.svg',
      builder: _placeholder,
    ),
  ];

  @override
  SpecialistAgent? get subAgent => const SpecialistAgent(
    moduleId: ModuleId.health,
    name: 'Health Specialist',
  );

  @override
  List<ToolDefinition> get tools => const [];

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

Widget _placeholder(BuildContext context) => const SizedBox.shrink();
