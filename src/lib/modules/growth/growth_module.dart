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

  @override
  List<ModuleTab> get tabs => const [
    ModuleTab(
      id: 'goals',
      label: '目标',
      iconName: 'modules/growth.svg',
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'projects',
      label: '项目',
      iconName: 'modules/briefcase.svg',
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'learning',
      label: '学习',
      iconName: 'modules/report.svg',
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'resume',
      label: '简历',
      iconName: 'common/info.svg',
      builder: _placeholder,
    ),
  ];

  @override
  SpecialistAgent? get subAgent => const SpecialistAgent(
    moduleId: ModuleId.growth,
    name: 'Growth Specialist',
  );

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

Widget _placeholder(BuildContext context) => const SizedBox.shrink();
