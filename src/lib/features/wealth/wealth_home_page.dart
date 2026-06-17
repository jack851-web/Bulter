import 'package:bulter/db/app_database.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../form/amount_input.dart';
import '../form/stream_list_view.dart';
import 'account_form.dart';
import 'transaction_form.dart';

/// 财富模块主页：顶部余额总览，下方 Tab 切换「账户 / 流水」。
class WealthHomePage extends StatelessWidget {
  const WealthHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const _BalanceHero(),
          Container(
            color: BulterColors.canvas,
            child: TabBar(
              labelColor: BulterColors.cta,
              unselectedLabelColor: BulterColors.textSecondary,
              indicatorColor: BulterColors.wealth,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontSize: BulterFontSize.bodyLg,
                fontWeight: BulterFontWeight.semibold,
              ),
              tabs: const [
                Tab(text: '账户'),
                Tab(text: '流水'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _AccountsTab(),
                _TransactionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Account>>(
      stream: AppDatabase.I.wealthDao.watchAccounts(),
      builder: (context, snap) {
        final accounts = snap.data ?? const <Account>[];
        final totalCents = accounts.fold<int>(0, (a, b) => a + b.balanceCents);
        return Container(
          margin: const EdgeInsets.fromLTRB(
            BulterSpacing.l,
            BulterSpacing.s,
            BulterSpacing.l,
            BulterSpacing.l,
          ),
          padding: const EdgeInsets.all(BulterSpacing.xl),
          decoration: BoxDecoration(
            color: BulterColors.wealth.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(BulterRadius.xxl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '总余额',
                style: TextStyle(
                  fontSize: BulterFontSize.footnote,
                  color: BulterColors.textSecondary,
                  fontWeight: BulterFontWeight.semibold,
                ),
              ),
              const SizedBox(height: BulterSpacing.s),
              Text(
                formatCents(totalCents),
                style: const TextStyle(
                  fontSize: BulterFontSize.displayS,
                  fontWeight: BulterFontWeight.heavy,
                  color: BulterColors.textPrimary,
                ),
              ),
              const SizedBox(height: BulterSpacing.s),
              Text(
                '${accounts.length} 个账户',
                style: const TextStyle(
                  fontSize: BulterFontSize.footnote,
                  color: BulterColors.textTertiary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccountsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BulterColors.canvas,
      body: StreamListView<Account>(
        stream: AppDatabase.I.wealthDao.watchAccounts(),
        brandColor: BulterColors.wealth,
        emptyTitle: '还没有账户',
        emptyHint: '把现金、银行卡、信用卡、投资账户都收进来',
        emptyIcon: Icons.account_balance_wallet_outlined,
        itemBuilder: (context, a, idx) => _AccountRow(account: a),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddAccount(context),
        backgroundColor: BulterColors.cta,
        foregroundColor: BulterColors.ctaText,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新账户'),
      ),
    );
  }

  static void _openAddAccount(BuildContext context) {
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

class _AccountRow extends StatelessWidget {
  final Account account;
  const _AccountRow({required this.account});

  static const _typeIcons = {
    'cash': Icons.account_balance_wallet_rounded,
    'bank': Icons.account_balance_rounded,
    'credit': Icons.credit_card_rounded,
    'investment': Icons.trending_up_rounded,
    'other': Icons.help_outline_rounded,
  };

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
      trailing: IconButton(
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: BulterColors.error,
        ),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('删除账户'),
              content: Text('确认删除"${account.name}"？其下流水将一并删除。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text(
                    '删除',
                    style: TextStyle(color: BulterColors.error),
                  ),
                ),
              ],
            ),
          );
          if (ok == true) {
            await AppDatabase.I.wealthDao.deleteAccount(account.id);
          }
        },
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: BulterColors.wealth.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(BulterRadius.m),
            ),
            child: Icon(icon, color: BulterColors.wealth, size: 22),
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
                  _typeLabel(account.type),
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

  static String _typeLabel(String t) => switch (t) {
        'cash' => '现金',
        'bank' => '银行卡',
        'credit' => '信用卡',
        'investment' => '投资',
        _ => '其他',
      };
}

class _TransactionsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BulterColors.canvas,
      body: StreamBuilder<List<Account>>(
        stream: AppDatabase.I.wealthDao.watchAccounts(),
        builder: (context, accSnap) {
          final accounts = accSnap.data ?? const <Account>[];
          return StreamListView<Transaction>(
            stream: AppDatabase.I.wealthDao.watchRecentTransactions(),
            brandColor: BulterColors.wealth,
            emptyTitle: '还没有流水',
            emptyHint: '记一笔开始追踪你的钱花在哪里',
            emptyIcon: Icons.receipt_long_outlined,
            itemBuilder: (context, t, idx) {
              final acc = accounts.firstWhere(
                (a) => a.id == t.accountId,
                orElse: () => Account(
                  id: 0,
                  name: '?',
                  type: 'other',
                  balanceCents: 0,
                  currency: 'CNY',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
              return _TransactionRow(transaction: t, accountName: acc.name);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddTransaction(context),
        backgroundColor: BulterColors.cta,
        foregroundColor: BulterColors.ctaText,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text('记一笔'),
      ),
    );
  }

  static void _openAddTransaction(BuildContext context) {
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
}

class _TransactionRow extends StatelessWidget {
  final Transaction transaction;
  final String accountName;
  const _TransactionRow({required this.transaction, required this.accountName});

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
    final isExpense = transaction.type == 'expense';
    final color = isExpense ? BulterColors.error : BulterColors.success;
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
                const SizedBox(height: BulterSpacing.xs),
                if ((transaction.description ?? '').isNotEmpty)
                  Text(
                    transaction.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: BulterFontSize.body,
                      color: BulterColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  '${transaction.occurredAt.year}-${transaction.occurredAt.month.toString().padLeft(2, '0')}-${transaction.occurredAt.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: BulterFontSize.caption,
                    color: BulterColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: BulterSpacing.s),
          Text(
            '${isExpense ? '-' : '+'}${formatCents(transaction.amountCents.abs())}',
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
