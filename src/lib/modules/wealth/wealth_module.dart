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

  @override
  List<ModuleTab> get tabs => const [
    ModuleTab(
      id: 'overview',
      label: '总览',
      iconName: 'modules/chart.svg',
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'records',
      label: '账单',
      iconName: 'common/receipt.svg',
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'budgets',
      label: '预算',
      iconName: 'modules/wealth.svg',
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'analysis',
      label: '分析',
      iconName: 'modules/chart.svg',
      builder: _placeholder,
    ),
  ];

  @override
  SpecialistAgent? get subAgent => const SpecialistAgent(
    moduleId: ModuleId.wealth,
    name: 'Wealth Specialist',
  );

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

Widget _placeholder(BuildContext context) => const SizedBox.shrink();
