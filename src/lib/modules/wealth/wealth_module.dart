import 'package:flutter/material.dart';

import '../bulter_module.dart';
import '../../ai/tools/wealth_tools.dart';
import '../../features/wealth/wealth_home_page.dart';
import '../../theme/tokens.dart';
import 'db/wealth_daos.dart';
import 'db/wealth_tables.dart';

/// 财富模块
class WealthModule implements BulterModule {
  const WealthModule();

  @override
  String get id => ModuleId.wealth;

  @override
  String get displayName => '财富';

  @override
  Color get brandColor => BulterColors.wealth;

  @override
  String get iconName => 'wealth';

  @override
  String get entryRoute => '/wealth';

  @override
  Widget buildHomePage(BuildContext context) => const WealthHomePage();

  /// 财富模块当前是单页布局（对齐 phone-06 原型），子 tab 由 [WealthHomePage] 内部
  /// 处理；模块的 [tabs] 留空让 AppShell 走 buildHomePage。
  @override
  List<ModuleTab> get tabs => const [];

  @override
  bool get hasSubAgent => true;

  @override
  SpecialistAgent? get subAgent => null;

  @override
  void Function(BuildContext)? get quickAdd =>
      WealthHomePage.openAddTransaction;

  @override
  List<ToolDefinition> get tools => const [
    WealthTools.queryAccountsDef,
    WealthTools.queryTransactionsDef,
    WealthTools.querySpendingDef,
    WealthTools.saveTransactionDef,
    WealthTools.saveAccountDef,
    WealthTools.deleteTransactionDef,
  ];

  @override
  BriefingGenerator? get briefingGenerator => null;

  @override
  List<Type> get tableClasses => const [Accounts, Transactions, Budgets];

  @override
  List<Type> get daoClasses => const [WealthDao];

  @override
  Future<void> onRegister() async {}

  @override
  Future<void> onDispose() async {}
}
