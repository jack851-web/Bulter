import 'package:drift/drift.dart' show OrderingMode, OrderingTerm;

import '../../../db/app_database.dart';
import '../db/wealth_tables.dart';
import 'monthly_report_service.dart';

/// 财富图表服务（Step 13b）。
///
/// **职责**：
/// - **分类柱图**：本月支出按 category 汇总（top N）
/// - **趋势折线**：过去 N 个月支出 / 收入
/// - **预算 vs 实际**：每个 category 的预算占用
///
/// **数据模型**（前端好消费）：
/// - [CategoryBar] = `{category, amountCents, ratio, color}`
/// - [TrendPoint] = `{year, month, incomeCents, expenseCents}`
/// - [BudgetUsage] = `{category, spentCents, limitCents, ratio}`
class ChartService {
  ChartService._();
  static final ChartService instance = ChartService._();

  /// 本月分类柱图数据（按金额降序）。
  Future<List<CategoryBar>> categoryBarsForMonth(
    AppDatabase db, {
    required int year,
    required int month,
    int topN = 8,
  }) async {
    final report =
        await MonthlyReportService.instance.generate(db, year: year, month: month);
    final total = report.expenseCents;
    if (total == 0) return const [];

    final entries = report.categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final bars = <CategoryBar>[];
    for (var i = 0; i < entries.length && i < topN; i++) {
      final e = entries[i];
      bars.add(CategoryBar(
        category: e.key,
        label: _categoryLabel(e.key),
        amountCents: e.value,
        ratio: e.value / total,
        colorIndex: i, // 用 index 配色（详见 CategoryBar.colorName）
      ));
    }
    return bars;
  }

  /// 趋势折线（最近 N 个月）。
  Future<List<TrendPoint>> trend(
    AppDatabase db, {
    int months = 6,
  }) async {
    final reports =
        await MonthlyReportService.instance.recentMonths(db, months: months);
    return [
      for (final r in reports)
        TrendPoint(
          year: r.year,
          month: r.month,
          incomeCents: r.incomeCents,
          expenseCents: r.expenseCents,
          label: '${r.month}月',
        ),
    ];
  }

  /// 预算 vs 实际（所有月度预算）。
  Future<List<BudgetUsage>> budgetUsage(AppDatabase db) async {
    final budgets = await (db.select(db.budgets)
          ..where((b) => b.period.equals('monthly')))
        .get();
    if (budgets.isEmpty) return const [];

    // 当月已支出（按 category）
    final now = DateTime.now();
    final report = await MonthlyReportService.instance
        .generate(db, year: now.year, month: now.month);

    final usage = <BudgetUsage>[];
    for (final b in budgets) {
      final spent = report.categoryBreakdown[b.category] ?? 0;
      usage.add(BudgetUsage(
        category: b.category,
        label: _categoryLabel(b.category),
        spentCents: spent,
        limitCents: b.limitCents,
        ratio: b.limitCents == 0 ? 0 : spent / b.limitCents,
      ));
    }
    return usage;
  }

  // category → 中文 label
  static String _categoryLabel(String cat) {
    const map = {
      'food': '餐饮',
      'transport': '交通',
      'shopping': '购物',
      'housing': '住房',
      'medical': '医疗',
      'edu': '学习',
      'entertain': '娱乐',
      'salary': '工资',
      'bonus': '奖金',
      'investment': '投资',
      'gift': '礼金',
      'other': '其他',
    };
    return map[cat] ?? cat;
  }
}

/// 单条分类柱。
class CategoryBar {
  final String category;
  final String label;
  final int amountCents;
  final double ratio; // 0-1，占总支出比
  final int colorIndex;

  const CategoryBar({
    required this.category,
    required this.label,
    required this.amountCents,
    required this.ratio,
    required this.colorIndex,
  });

  /// 调色板：8 种 Cal.com 风格色（红/橙/黄/绿/青/蓝/紫/灰）。
  String get colorName {
    const palette = [
      'red', 'orange', 'yellow', 'green',
      'cyan', 'blue', 'purple', 'gray',
    ];
    return palette[colorIndex % palette.length];
  }
}

/// 单个时间点的趋势数据。
class TrendPoint {
  final int year;
  final int month;
  final int incomeCents;
  final int expenseCents;
  final String label;

  const TrendPoint({
    required this.year,
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
    required this.label,
  });

  int get netCents => incomeCents - expenseCents;
}

/// 单条预算使用情况。
class BudgetUsage {
  final String category;
  final String label;
  final int spentCents;
  final int limitCents;
  final double ratio; // 0-1（>1 表示超支）

  const BudgetUsage({
    required this.category,
    required this.label,
    required this.spentCents,
    required this.limitCents,
    required this.ratio,
  });

  bool get isOverBudget => ratio > 1.0;
}
