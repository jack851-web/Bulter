import 'package:flutter/material.dart';

import '../bulter_module.dart';
import '../module_placeholder_page.dart';
import '../../theme/tokens.dart';
import 'db/thought_daos.dart';
import 'db/thought_tables.dart';

/// 思想模块
class ThoughtModule implements BulterModule {
  const ThoughtModule();

  @override
  String get id => ModuleId.thought;

  @override
  String get displayName => '思想';

  @override
  Color get brandColor => BulterColors.thought;

  @override
  String get iconName => 'brain';

  @override
  String get entryRoute => '/thought';

  @override
  Widget buildHomePage(BuildContext context) => const ModulePlaceholderPage(
    moduleName: '思想',
    brandColor: BulterColors.thought,
    icon: Icons.psychology_rounded,
    features: [
      '读后感 CRUD（书名 · 作者 · 感悟 · 评分）',
      '思想卡片（灵感速记，标签分类）',
      '思想时间线',
      '标签筛选',
      '给未来的信（定时解锁）',
      '年度回顾（年末自动汇总）',
      '双向链接笔记（[[ ]]）',
    ],
  );

  @override
  List<ModuleTab> get tabs => const [
    ModuleTab(
      id: 'thoughts',
      label: '读后感',
      icon: Icons.menu_book_rounded,
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'letters',
      label: '信件',
      icon: Icons.mail_outline_rounded,
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'review',
      label: '回顾',
      icon: Icons.history_rounded,
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'tags',
      label: '标签',
      icon: Icons.label_outline_rounded,
      builder: _placeholder,
    ),
  ];

  @override
  SpecialistAgent? get subAgent => const SpecialistAgent(
    moduleId: ModuleId.thought,
    name: 'Thought Specialist',
  );

  @override
  List<ToolDefinition> get tools => const [];

  @override
  BriefingGenerator? get briefingGenerator => null;

  @override
  List<Type> get tableClasses => const [Thoughts, Letters, AnnualReviews];

  @override
  List<Type> get daoClasses => const [ThoughtDao];

  @override
  Future<void> onRegister() async {}

  @override
  Future<void> onDispose() async {}
}

Widget _placeholder(BuildContext context) => const SizedBox.shrink();
