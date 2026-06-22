import 'package:bulter/db/app_database.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../form/amount_input.dart';
import '../form/stream_list_view.dart';
import 'account_form.dart';
import 'transaction_form.dart';

/// 财富模块主页（原型：phone-06-finance.png）。
///
/// 布局（自上而下）：
///   1) 顶部大字总额 + 总负债 / 今日变化 + 2 个账户
///   2) 双按钮：纯黑"存入" + 白底"分一份"
///   3) 账户 / 预算区（2 张账户卡）
///   4) 最近流水 2 行
///   5) 底部 FAB：记一笔
class WealthHomePage extends StatelessWidget {
  const WealthHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Account>>(
      stream: AppDatabase.I.wealthDao.watchAccounts(),
      builder: (context, accSnap) {
        final accounts = accSnap.data ?? const <Account>[];
        // 注：AppShell 已提供 Scaffold + FAB（AI 入口 + 模块 quickAdd），
        // 这里只放列表内容；记一笔功能由 AppShell 顶栏 + 按钮调用 openAddTransaction。
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            BulterSpacing.l,
            BulterSpacing.l,
            BulterSpacing.l,
            BulterSpacing.huge,
          ),
          children: [
            _BalanceHero(accounts: accounts),
            const SizedBox(height: BulterSpacing.l),
            _ActionRow(accounts: accounts),
            const SizedBox(height: BulterSpacing.l),
            _SectionTitle('账户 / 预算'),
            const SizedBox(height: BulterSpacing.s),
            _AccountsList(accounts: accounts),
            const SizedBox(height: BulterSpacing.l),
            _SectionTitle('最近流水'),
            const SizedBox(height: BulterSpacing.s),
            _RecentTransactions(accounts: accounts),
          ],
        );
      },
    );
  }

  static void openAddTransaction(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionForm(
          title: '记一笔',
          onSubmit: (data) async {
            await AppDatabase.I.wealthDao.insertTransaction(data);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  static void openAddAccount(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountForm(
          title: '新增账户',
          onSubmit: (data) async {
            await AppDatabase.I.wealthDao.insertAccount(data);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  final List<Account> accounts;
  const _BalanceHero({required this.accounts});

  @override
  Widget build(BuildContext context) {
    final totalCents = accounts.fold<int>(0, (a, b) => a + b.balanceCents);
    final debtCents = accounts
        .where((a) => a.type == 'credit')
        .fold<int>(0, (a, b) => a + b.balanceCents);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '总余额 · 总负债',
          style: TextStyle(
            fontSize: BulterFontSize.footnote,
            color: BulterColors.textSecondary,
            fontWeight: BulterFontWeight.semibold,
          ),
        ),
        const SizedBox(height: BulterSpacing.xs),
        Text(
          formatCents(totalCents),
          style: const TextStyle(
            fontSize: BulterFontSize.displayL,
            fontWeight: BulterFontWeight.heavy,
            color: BulterColors.textPrimary,
            height: 1.0,
          ),
        ),
        if (debtCents > 0) ...[
          const SizedBox(height: BulterSpacing.s),
          Text(
            '其中负债 ${formatCents(debtCents.abs())}',
            style: const TextStyle(
              fontSize: BulterFontSize.footnote,
              color: BulterColors.textTertiary,
            ),
          ),
        ],
        const SizedBox(height: BulterSpacing.s),
        Text(
          '${accounts.length} 个账户合计 · 今日 +24.0',
          style: const TextStyle(
            fontSize: BulterFontSize.caption,
            color: BulterColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final List<Account> accounts;
  const _ActionRow({required this.accounts});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: '存入',
            icon: Icons.arrow_downward_rounded,
            filled: true,
            onTap: () => _openTransfer(context, accounts),
          ),
        ),
        const SizedBox(width: BulterSpacing.m),
        Expanded(
          child: _ActionButton(
            label: '分一份',
            icon: Icons.arrow_outward_rounded,
            filled: false,
            onTap: () => _openTransaction(context),
          ),
        ),
      ],
    );
  }

  void _openTransfer(BuildContext context, List<Account> accounts) {
    // 简化：跳到新增账户（后续 Step 4/5 接入"转账"工具）
    if (accounts.length < 2) {
      WealthHomePage.openAddAccount(context);
      return;
    }
    WealthHomePage.openAddTransaction(context);
  }

  void _openTransaction(BuildContext context) {
    WealthHomePage.openAddTransaction(context);
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? BulterColors.cta : BulterColors.surface;
    final fg = filled ? BulterColors.ctaText : BulterColors.textPrimary;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(BulterRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(BulterRadius.pill),
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BulterRadius.pill),
            border: filled
                ? null
                : Border.all(color: BulterColors.divider, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: BulterSpacing.s),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: BulterFontSize.bodyLg,
                  fontWeight: BulterFontWeight.semibold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: BulterFontSize.bodyLg,
        fontWeight: BulterFontWeight.semibold,
        color: BulterColors.textPrimary,
      ),
    );
  }
}

class _AccountsList extends StatelessWidget {
  final List<Account> accounts;
  const _AccountsList({required this.accounts});

  static const _typeIcons = {
    'cash': Icons.account_balance_wallet_rounded,
    'bank': Icons.account_balance_rounded,
    'credit': Icons.credit_card_rounded,
    'investment': Icons.trending_up_rounded,
    'other': Icons.help_outline_rounded,
  };

  static const _typeLabels = {
    'cash': '现金',
    'bank': '银行卡',
    'credit': '信用卡',
    'investment': '投资',
    'other': '其他',
  };

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(BulterSpacing.l),
        decoration: BoxDecoration(
          color: BulterColors.surface,
          borderRadius: BorderRadius.circular(BulterRadius.l),
          border: Border.all(color: BulterColors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: BulterColors.wealth.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(BulterRadius.m),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: BulterColors.wealth,
                size: 20,
              ),
            ),
            const SizedBox(width: BulterSpacing.m),
            const Expanded(
              child: Text(
                '还没有账户 · 点击新增',
                style: TextStyle(
                  fontSize: BulterFontSize.body,
                  color: BulterColors.textSecondary,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.chevron_right_rounded,
                color: BulterColors.textTertiary,
              ),
              onPressed: () => WealthHomePage.openAddAccount(context),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final a in accounts)
          Padding(
            padding: const EdgeInsets.only(bottom: BulterSpacing.s),
            child: _AccountCard(account: a),
          ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Account account;
  const _AccountCard({required this.account});

  static const _typeIcons = _AccountsList._typeIcons;
  static const _typeLabels = _AccountsList._typeLabels;

  @override
  Widget build(BuildContext context) {
    final icon = _typeIcons[account.type] ?? _typeIcons['other']!;
    return ListCard(
      brandColor: BulterColors.wealth,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AccountForm(
            title: '编辑账户',
            initial: account,
            onSubmit: (data) async {
              await AppDatabase.I.wealthDao.updateAccount(data);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: BulterColors.wealth.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(BulterRadius.m),
            ),
            child: Icon(icon, color: BulterColors.wealth, size: 20),
          ),
          const SizedBox(width: BulterSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: const TextStyle(
                    fontSize: BulterFontSize.bodyLg,
                    fontWeight: BulterFontWeight.semibold,
                    color: BulterColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _typeLabels[account.type] ?? '其他',
                  style: const TextStyle(
                    fontSize: BulterFontSize.footnote,
                    color: BulterColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatCents(account.balanceCents, currency: account.currency),
            style: TextStyle(
              fontSize: BulterFontSize.titleS,
              fontWeight: BulterFontWeight.semibold,
              color: account.balanceCents < 0
                  ? BulterColors.error
                  : BulterColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  final List<Account> accounts;
  const _RecentTransactions({required this.accounts});

  static const _catLabels = {
    'food': '餐饮',
    'transport': '交通',
    'shopping': '购物',
    'housing': '住房',
    'medical': '医疗',
    'edu': '学习',
    'entertain': '娱乐',
    'other': '其他',
    'salary': '工资',
    'bonus': '奖金',
    'investment': '投资',
    'gift': '礼金',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Transaction>>(
      stream: AppDatabase.I.wealthDao.watchRecentTransactions(limit: 2),
      builder: (context, snap) {
        final items = snap.data ?? const <Transaction>[];
        if (items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(BulterSpacing.l),
            decoration: BoxDecoration(
              color: BulterColors.surface,
              borderRadius: BorderRadius.circular(BulterRadius.l),
              border: Border.all(color: BulterColors.divider, width: 0.5),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: BulterColors.textTertiary,
                  size: 20,
                ),
                SizedBox(width: BulterSpacing.m),
                Text(
                  '还没有流水 · 点击右下角记一笔',
                  style: TextStyle(
                    fontSize: BulterFontSize.body,
                    color: BulterColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final t in items)
              Padding(
                padding: const EdgeInsets.only(bottom: BulterSpacing.s),
                child: _TransactionRow(
                  transaction: t,
                  accountName: _findAccountName(accounts, t.accountId),
                ),
              ),
          ],
        );
      },
    );
  }

  String _findAccountName(List<Account> accounts, int id) {
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return '?';
  }
}

class _TransactionRow extends StatelessWidget {
  final Transaction transaction;
  final String accountName;
  const _TransactionRow({required this.transaction, required this.accountName});

  static const _catLabels = _RecentTransactions._catLabels;

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == 'expense';
    final color = isExpense ? BulterColors.error : BulterColors.success;
    final amountCents = transaction.amountCents.abs();
    return ListCard(
      brandColor: color,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BulterSpacing.s,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(BulterRadius.s),
                      ),
                      child: Text(
                        _catLabels[transaction.category] ??
                            transaction.category,
                        style: TextStyle(
                          fontSize: BulterFontSize.caption,
                          color: color,
                          fontWeight: BulterFontWeight.semibold,
                        ),
                      ),
                    ),
                    const SizedBox(width: BulterSpacing.s),
                    Text(
                      accountName,
                      style: const TextStyle(
                        fontSize: BulterFontSize.caption,
                        color: BulterColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                if ((transaction.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: BulterSpacing.xs),
                  Text(
                    transaction.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: BulterFontSize.body,
                      color: BulterColors.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: BulterSpacing.s),
          Text(
            '${isExpense ? '-' : '+'}${formatCents(amountCents)}',
            style: TextStyle(
              fontSize: BulterFontSize.titleS,
              fontWeight: BulterFontWeight.semibold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
