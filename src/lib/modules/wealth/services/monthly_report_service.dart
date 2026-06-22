import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../db/wealth_tables.dart';

/// 月度账单服务（Step 13）。
///
/// **职责**：
/// - 按月份聚合 transactions（收入 / 支出 / 净额 / 分类分布）
/// - 与上月对比（百分比变化）
/// - **预算超支**检测
/// - 支持任意月份查询
class MonthlyReportService {
  MonthlyReportService._();
  static final MonthlyReportService instance = MonthlyReportService._();

  /// 生成月度账单报告。
  Future<MonthlyReport> generate(
    AppDatabase db, {
    required int year,
    required int month, // 1-12
  }) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    final txns =
        await (db.select(db.transactions)..where(
              (t) =>
                  t.occurredAt.isBiggerOrEqualValue(start) &
                  t.occurredAt.isSmallerThanValue(end),
            ))
            .get();

    final income = txns
        .where((t) => t.type == 'income')
        .fold<int>(0, (a, b) => a + b.amountCents);
    final expense = txns
        .where((t) => t.type == 'expense')
        .fold<int>(0, (a, b) => a + b.amountCents.abs());

    // 按 category 分组（支出）
    final byCategory = <String, int>{};
    for (final t in txns.where((t) => t.type == 'expense')) {
      byCategory[t.category] =
          (byCategory[t.category] ?? 0) + t.amountCents.abs();
    }

    // 与上月对比
    final prevStart = DateTime(year, month - 1, 1);
    final prevEnd = start;
    final prevTxns =
        await (db.select(db.transactions)..where(
              (t) =>
                  t.occurredAt.isBiggerOrEqualValue(prevStart) &
                  t.occurredAt.isSmallerThanValue(prevEnd),
            ))
            .get();
    final prevExpense = prevTxns
        .where((t) => t.type == 'expense')
        .fold<int>(0, (a, b) => a + b.amountCents.abs());

    // 预算超支检测（本月所有月度预算）
    final budgets = await (db.select(
      db.budgets,
    )..where((b) => b.period.equals('monthly'))).get();
    final overBudget = <BudgetAlert>[];
    for (final b in budgets) {
      final spent = byCategory[b.category] ?? 0;
      if (spent > b.limitCents) {
        overBudget.add(
          BudgetAlert(
            category: b.category,
            spentCents: spent,
            limitCents: b.limitCents,
            overRatio: (spent - b.limitCents) / b.limitCents,
          ),
        );
      }
    }

    return MonthlyReport(
      year: year,
      month: month,
      incomeCents: income,
      expenseCents: expense,
      netCents: income - expense,
      prevExpenseCents: prevExpense,
      categoryBreakdown: byCategory,
      overBudget: overBudget,
      txCount: txns.length,
    );
  }

  /// 生成过去 N 个月的趋势（用于图表）。
  Future<List<MonthlyReport>> recentMonths(
    AppDatabase db, {
    int months = 6,
  }) async {
    final now = DateTime.now();
    final out = <MonthlyReport>[];
    for (var i = months - 1; i >= 0; i--) {
      var m = now.month - i;
      var y = now.year;
      while (m <= 0) {
        m += 12;
        y--;
      }
      out.add(await generate(db, year: y, month: m));
    }
    return out;
  }
}

/// 单月账单报告。
class MonthlyReport {
  final int year;
  final int month;
  final int incomeCents;
  final int expenseCents;
  final int netCents;
  final int prevExpenseCents;
  final Map<String, int> categoryBreakdown;
  final List<BudgetAlert> overBudget;
  final int txCount;

  const MonthlyReport({
    required this.year,
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
    required this.netCents,
    required this.prevExpenseCents,
    required this.categoryBreakdown,
    required this.overBudget,
    required this.txCount,
  });

  /// 与上月支出对比（百分比，负数=减少）。
  double get expenseChangePct {
    if (prevExpenseCents == 0) return 0;
    return ((expenseCents - prevExpenseCents) / prevExpenseCents) * 100;
  }

  String get label => '$year 年 $month 月';
}

/// 预算超支告警。
class BudgetAlert {
  final String category;
  final int spentCents;
  final int limitCents;
  final double overRatio;

  const BudgetAlert({
    required this.category,
    required this.spentCents,
    required this.limitCents,
    required this.overRatio,
  });
}
