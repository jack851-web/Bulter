import 'package:flutter/material.dart';

import '../bulter_module.dart';
import '../../features/thought/thought_home_page.dart';
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
  String get iconName => 'thought';

  @override
  String get entryRoute => '/thought';

  @override
  Widget buildHomePage(BuildContext context) => const ThoughtHomePage();

  @override
  List<ModuleTab> get tabs => const [
    ModuleTab(
      id: 'thoughts',
      label: '读后感',
      iconName: 'modules/thought.svg',
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'letters',
      label: '信件',
      iconName: 'modules/mail.svg',
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'review',
      label: '回顾',
      iconName: 'modules/trending-up.svg',
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'tags',
      label: '标签',
      iconName: 'common/plus.svg',
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
