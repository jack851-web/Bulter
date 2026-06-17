import 'package:flutter/material.dart';

import '../bulter_module.dart';
import '../module_placeholder_page.dart';
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
  String get iconName => 'wallet';

  @override
  String get entryRoute => '/wealth';

  @override
  Widget buildHomePage(BuildContext context) => const ModulePlaceholderPage(
    moduleName: '财富',
    brandColor: BulterColors.wealth,
    icon: Icons.account_balance_wallet_rounded,
    features: [
      '余额总览（多账户：现金 / 银行卡 / 支付宝 / 微信）',
      '收支记录 CRUD（金额 · 类别 · 时间 · 备注）',
      '月度收支统计（收入 / 支出 / 结余）',
      '类别分析（食 / 行 / 购 / 娱占比）',
      'CSV 批量导入（支付宝 / 微信账单）',
      '月度账单页（分类汇总 + 趋势）',
      '预算管理（类别预算 + 超支提醒）',
      '自然语言查询（"上个月吃饭花了多少"）',
    ],
  );

  @override
  List<ModuleTab> get tabs => const [
    ModuleTab(
      id: 'overview',
      label: '总览',
      icon: Icons.dashboard_outlined,
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'records',
      label: '账单',
      icon: Icons.receipt_long_rounded,
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'budgets',
      label: '预算',
      icon: Icons.savings_rounded,
      builder: _placeholder,
    ),
    ModuleTab(
      id: 'analysis',
      label: '分析',
      icon: Icons.pie_chart_outline_rounded,
      builder: _placeholder,
    ),
  ];

  @override
  SpecialistAgent? get subAgent => const SpecialistAgent(
    moduleId: ModuleId.wealth,
    name: 'Wealth Specialist',
  );

  @override
  List<ToolDefinition> get tools => const [];

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
