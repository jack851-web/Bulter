import 'package:flutter/material.dart';

import '../bulter_module.dart';
import '../../ai/tools/relationship_tools.dart';
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
  String get iconName => 'relationship';

  @override
  String get entryRoute => '/relationship';

  @override
  Widget buildHomePage(BuildContext context) => const RelationshipHomePage();

  /// 关系模块当前是单页布局（对齐 phone-04 原型），底部 tab 在 [_Body] 内部按
  ///"联系人 / 互动 / 人情" 切分，模块的 [tabs] 留空让 AppShell 走 buildHomePage。
  @override
  List<ModuleTab> get tabs => const [];

  @override
  SpecialistAgent? get subAgent => const SpecialistAgent(
    moduleId: ModuleId.relationship,
    name: 'Relation Specialist',
  );

  @override
  List<ToolDefinition> get tools => const [
    RelationshipTools.queryContactsDef,
    RelationshipTools.queryInteractionsDef,
    RelationshipTools.queryFavorsDef,
    RelationshipTools.saveContactDef,
    RelationshipTools.saveInteractionDef,
    RelationshipTools.saveFavorDef,
    RelationshipTools.deleteContactDef,
    RelationshipTools.deleteInteractionDef,
    RelationshipTools.deleteFavorDef,
  ];

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
