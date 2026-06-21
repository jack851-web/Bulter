import 'package:flutter/material.dart';

import '../bulter_module.dart';
import '../../ai/tools/thought_tools.dart';
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

  /// 思想模块当前是单页布局（对齐 phone-07 原型），子 tab 由 [ThoughtHomePage] 内部
  /// 处理；模块的 [tabs] 留空让 AppShell 走 buildHomePage。
  @override
  List<ModuleTab> get tabs => const [];

  @override
  bool get hasSubAgent => true;

  @override
  SpecialistAgent? get subAgent => null;

  @override
  List<ToolDefinition> get tools => const [
    ThoughtTools.queryThoughtsDef,
    ThoughtTools.queryLettersDef,
    ThoughtTools.saveThoughtDef,
    ThoughtTools.saveLetterDef,
    ThoughtTools.deleteThoughtDef,
    ThoughtTools.deleteLetterDef,
  ];

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
