import 'package:flutter/material.dart';

import '../bulter_module.dart';
import '../module_placeholder_page.dart';
import '../../theme/tokens.dart';

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
  String get iconName => 'target';

  @override
  String get entryRoute => '/growth';

  @override
  Widget buildHomePage(BuildContext context) => const ModulePlaceholderPage(
    moduleName: '成长',
    brandColor: BulterColors.growth,
    icon: Icons.flag_rounded,
    features: [
      '目标 CRUD（年度 / 季度）',
      '目标进度追踪（百分比 + 关键结果）',
      '学习记录（课程 / 书籍 / 技能）',
      '项目看板（待办 / 进行中 / 已完成）',
      'OKR 管理（目标 + KR + 进度）',
      '简历管理（版本化）',
      '人脉分析（结合关系模块）',
    ],
  );

  @override
  List<ModuleTab> get tabs => const [
    ModuleTab(
      id: 'goals',
      label: '目标',
      icon: Icons.flag_outlined,
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'projects',
      label: '项目',
      icon: Icons.view_kanban_rounded,
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'learning',
      label: '学习',
      icon: Icons.school_outlined,
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'resume',
      label: '简历',
      icon: Icons.description_outlined,
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
  Future<void> onRegister() async {}

  @override
  Future<void> onDispose() async {}
}

Widget _placeholder(BuildContext context) => const SizedBox.shrink();
