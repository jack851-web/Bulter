import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../db/health_tables.dart';

/// 健康趋势服务（Step 13b）。
///
/// **职责**：
/// - 按 `type`（weight / sleep / heart_rate ...）拉最近 N 天的时间序列
/// - 输出 [TrendSeries]（点列表 + 范围）
class HealthTrendService {
  HealthTrendService._();
  static final HealthTrendService instance = HealthTrendService._();

  /// 拉某个指标的时间序列。
  ///
  /// - [metricType]：'weight' / 'sleep_hours' / 'steps' / 'resting_heart_rate' ...
  /// - [window]：时间范围（默认 30 天）
  /// - 自动过滤 valueNum == null
  Future<TrendSeries> series(
    AppDatabase db, {
    required String metricType,
    Duration window = const Duration(days: 30),
  }) async {
    final since = DateTime.now().subtract(window);
    final records =
        await (db.select(db.healthRecords)
              ..where(
                (r) =>
                    r.type.equals(metricType) &
                    r.occurredAt.isBiggerOrEqualValue(since) &
                    r.valueNum.isNotNull(),
              )
              ..orderBy([
                (r) => OrderingTerm(
                  expression: r.occurredAt,
                  mode: OrderingMode.asc,
                ),
              ]))
            .get();

    final points = [
      for (final r in records)
        TrendPoint(timestamp: r.occurredAt, value: r.valueNum!, unit: r.unit),
    ];

    return TrendSeries(
      metricType: metricType,
      label: _metricLabel(metricType),
      unit: points.isEmpty ? '' : (points.first.unit ?? ''),
      points: points,
    );
  }

  /// 同时拉多个指标（一个图上叠多条线）。
  Future<List<TrendSeries>> multiSeries(
    AppDatabase db, {
    required List<String> metricTypes,
    Duration window = const Duration(days: 30),
  }) async {
    final out = <TrendSeries>[];
    for (final t in metricTypes) {
      out.add(await series(db, metricType: t, window: window));
    }
    return out;
  }

  static String _metricLabel(String type) {
    const map = {
      'weight': '体重',
      'bmi': 'BMI',
      'sleep_hours': '睡眠时长',
      'steps': '步数',
      'resting_heart_rate': '静息心率',
      'mood': '心情',
      'exercise': '运动量',
    };
    return map[type] ?? type;
  }
}

/// 时间序列。
class TrendSeries {
  final String metricType;
  final String label;
  final String unit;
  final List<TrendPoint> points;

  const TrendSeries({
    required this.metricType,
    required this.label,
    required this.unit,
    required this.points,
  });

  bool get isEmpty => points.isEmpty;
  int get count => points.length;

  /// 最大值。
  double get max {
    if (points.isEmpty) return 0;
    return points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
  }

  /// 最小值。
  double get min {
    if (points.isEmpty) return 0;
    return points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
  }

  /// 平均值。
  double get avg {
    if (points.isEmpty) return 0;
    return points.map((p) => p.value).reduce((a, b) => a + b) / points.length;
  }

  /// 最新值。
  double? get latest => points.isEmpty ? null : points.last.value;

  /// 跨度（max - min）。
  double get span => max - min;
}

/// 时间序列上的一个点。
class TrendPoint {
  final DateTime timestamp;
  final double value;
  final String? unit;

  const TrendPoint({
    required this.timestamp,
    required this.value,
    required this.unit,
  });
}
