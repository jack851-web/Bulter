import 'package:bulter/db/app_database.dart';
import 'package:flutter/material.dart';

import '../../modules/health/services/health_trend_service.dart'
    hide TrendPoint;
import '../../modules/relationship/services/graph_service.dart';
import '../../modules/wealth/services/chart_service.dart';
import '../../theme/tokens.dart';
import 'budget_usage_view.dart';
import 'category_bars_chart.dart';
import 'relationship_graph_view.dart';
import 'trend_line_chart.dart';

/// 数据可视化总览（Step 13b）。
///
/// **包含 3 个图**：
///   1) 关系图谱
///   2) 本月分类柱图 + 月度趋势线
///   3) 健康趋势线（体重 / 睡眠）
///
/// **响应式**：在 Web 端自适应容器宽度（ListView 单列；>900px 时可切双列）
class VisualizationPage extends StatefulWidget {
  const VisualizationPage({super.key});

  @override
  State<VisualizationPage> createState() => _VisualizationPageState();
}

class _VisualizationPageState extends State<VisualizationPage> {
  late Future<RelationshipGraph> _graphFuture;
  late Future<List<CategoryBar>> _barsFuture;
  late Future<List<TrendPoint>> _trendFuture;
  late Future<List<BudgetUsage>> _budgetFuture;
  late Future<List<TrendSeries>> _healthFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final db = AppDatabase.I;
    _graphFuture = GraphService.instance.build(db);
    _barsFuture = ChartService.instance.categoryBarsForMonth(
      db,
      year: DateTime.now().year,
      month: DateTime.now().month,
    );
    _trendFuture = ChartService.instance.trend(db, months: 6);
    _budgetFuture = ChartService.instance.budgetUsage(db);
    _healthFuture = HealthTrendService.instance.multiSeries(
      db,
      metricTypes: const ['weight', 'sleep_hours'],
      window: const Duration(days: 30),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BulterColors.canvas,
      appBar: AppBar(
        title: const Text('数据可视化'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(_reload),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(BulterSpacing.l),
        children: [
          _SectionHeader(title: '关系图谱', subtitle: '节点=人，颜色=距上次联系天数，大小=活跃度'),
          const SizedBox(height: BulterSpacing.s),
          FutureBuilder<RelationshipGraph>(
            future: _graphFuture,
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const _LoadingBox(height: 320);
              }
              return RelationshipGraphView(
                graph: snap.data!,
                onNodeTap: (n) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${n.label} · ${n.sublabel} · ${n.interactionCount} 次互动',
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: BulterSpacing.xl),
          _SectionHeader(title: '本月支出', subtitle: '按分类占比（最多显示 8 个）'),
          const SizedBox(height: BulterSpacing.s),
          FutureBuilder<List<CategoryBar>>(
            future: _barsFuture,
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const _LoadingBox(height: 280);
              }
              return CategoryBarsChart(bars: snap.data!);
            },
          ),
          const SizedBox(height: BulterSpacing.xl),
          _SectionHeader(title: '近 6 月趋势', subtitle: '收入（绿） vs 支出（红）'),
          const SizedBox(height: BulterSpacing.s),
          FutureBuilder<List<TrendPoint>>(
            future: _trendFuture,
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const _LoadingBox(height: 220);
              }
              final points = snap.data!;
              return TrendLineChart(
                series: [
                  points.map((p) => p.incomeCents / 100.0).toList(),
                  points.map((p) => p.expenseCents / 100.0).toList(),
                ],
                xLabels: points.map((p) => p.label).toList(),
                seriesLabels: const ['收入', '支出'],
                seriesColors: const [BulterColors.growth, BulterColors.error],
                yUnit: '¥',
              );
            },
          ),
          const SizedBox(height: BulterSpacing.xl),
          _SectionHeader(title: '预算占用', subtitle: '当月支出 / 月度预算（红=超支）'),
          const SizedBox(height: BulterSpacing.s),
          FutureBuilder<List<BudgetUsage>>(
            future: _budgetFuture,
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const _LoadingBox(height: 200);
              }
              return BudgetUsageView(usages: snap.data!);
            },
          ),
          const SizedBox(height: BulterSpacing.xl),
          _SectionHeader(title: '健康趋势', subtitle: '最近 30 天（体重 + 睡眠）'),
          const SizedBox(height: BulterSpacing.s),
          FutureBuilder<List<TrendSeries>>(
            future: _healthFuture,
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const _LoadingBox(height: 240);
              }
              final series = snap.data!.where((s) => !s.isEmpty).toList();
              if (series.isEmpty) {
                return Container(
                  height: 240,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: BulterColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(BulterRadius.l),
                  ),
                  child: const Text(
                    '近 30 天没有健康记录',
                    style: TextStyle(color: BulterColors.textTertiary),
                  ),
                );
              }
              final allPoints = <DateTime, List<double>>{};
              for (final s in series) {
                for (final p in s.points) {
                  allPoints.putIfAbsent(p.timestamp, () => []).add(p.value);
                }
              }
              final sortedKeys = allPoints.keys.toList()..sort();
              final xLabels = sortedKeys
                  .map((d) => '${d.month}/${d.day}')
                  .toList();
              return TrendLineChart(
                series: [
                  for (final s in series)
                    [
                      for (final k in sortedKeys)
                        s.points
                                .where((p) => p.timestamp == k)
                                .firstOrNull
                                ?.value ??
                            double.nan,
                    ],
                ],
                xLabels: xLabels,
                seriesLabels: series.map((s) => s.label).toList(),
                seriesColors: const [BulterColors.health, BulterColors.wealth],
                yUnit: series.first.unit,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: BulterFontSize.titleM,
            fontWeight: BulterFontWeight.semibold,
            color: BulterColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: BulterFontSize.footnote,
            color: BulterColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _LoadingBox extends StatelessWidget {
  final double height;
  const _LoadingBox({required this.height});
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: BulterColors.surfaceMuted,
      borderRadius: BorderRadius.circular(BulterRadius.l),
    ),
    child: const CircularProgressIndicator(strokeWidth: 2),
  );
}

extension on Iterable<TrendPoint> {
  // 辅助函数（避免与 chart_service.dart 的 TrendPoint 冲突）
}

/// 取 series 在 [k] 时间点的值；无记录返回 NaN（让线图断点）。
double _valueAt(TrendSeries s, DateTime k) {
  for (final p in s.points) {
    if (p.timestamp == k) return p.value;
  }
  return double.nan;
}
