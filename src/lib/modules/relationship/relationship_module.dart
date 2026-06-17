import 'package:flutter/material.dart';

import '../bulter_module.dart';
import '../../features/relationship/relationship_home_page.dart';
import '../../theme/tokens.dart';
import 'db/relationship_daos.dart';
import 'db/relationship_tables.dart';

/// 关系模块
class RelationshipModule implements BulterModule {
  const RelationshipModule();

  @override
  String get id => ModuleId.relationship;

  @override
  String get displayName => '关系';

  @override
  Color get brandColor => BulterColors.relationship;

  @override
  String get iconName => 'heart';

  @override
  String get entryRoute => '/relationship';

  @override
  Widget buildHomePage(BuildContext context) => const RelationshipHomePage();

  @override
  List<ModuleTab> get tabs => const [
    ModuleTab(
      id: 'list',
      label: '联系人',
      icon: Icons.people_alt_outlined,
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'timeline',
      label: '互动',
      icon: Icons.timeline_rounded,
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'favors',
      label: '人情',
      icon: Icons.redeem_rounded,
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'appts',
      label: '约定',
      icon: Icons.event_note_rounded,
      builder: _placeholder,
    ),
  ];

  @override
  SpecialistAgent? get subAgent => const SpecialistAgent(
    moduleId: ModuleId.relationship,
    name: 'Relation Specialist',
  );

  @override
  List<ToolDefinition> get tools => const [];

  @override
  BriefingGenerator? get briefingGenerator => null;

  @override
  List<Type> get tableClasses => const [Contacts, Interactions, Favors];

  @override
  List<Type> get daoClasses => const [RelationshipDao];

  @override
  Future<void> onRegister() async {}

  @override
  Future<void> onDispose() async {}
}

Widget _placeholder(BuildContext context) => const SizedBox.shrink();
