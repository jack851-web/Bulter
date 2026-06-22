import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../db/health_tables.dart';
import 'metric_normalizer.dart';

/// 综合健康分服务（Step 13）。
///
/// **职责**：
/// - 取最近 N 天的所有健康记录
/// - 调 [MetricNormalizer] 评估 + 加权汇总
/// - 持久化到 [HealthScores] 表
class HealthScoreService {
  HealthScoreService._();
  static final HealthScoreService instance = HealthScoreService._();

  /// 计算 + 保存最新综合分（默认最近 30 天）。
  Future<HealthScore> computeAndSave(
    AppDatabase db, {
    Duration window = const Duration(days: 30),
  }) async {
    final since = DateTime.now().subtract(window);
    final records =
        await (db.select(db.healthRecords)
              ..where((r) => r.occurredAt.isBiggerOrEqualValue(since))
              ..orderBy([
                (r) => OrderingTerm(
                  expression: r.occurredAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    final aggregate = await MetricNormalizer.instance.aggregateBatch(records);

    // 准备 dimensionsJson：map<dimension, score>
    final dimsJson =
        '{'
        '${aggregate.dimensionScores.entries.map((e) => '"${e.key}":${e.value.toStringAsFixed(1)}').join(',')}'
        '}';

    // 保存到 HealthScores 表
    final id = await db.healthDao.insertScore(
      HealthScoresCompanion.insert(
        period: DateTime.now(),
        overallScore: aggregate.overallScore,
        dimensionsJson: Value(dimsJson),
      ),
    );

    return HealthScore(
      id: id,
      period: DateTime.now(),
      overallScore: aggregate.overallScore,
      aggregate: aggregate,
    );
  }
}

/// 一次综合分结果（含聚合详情）。
class HealthScore {
  final int id;
  final DateTime period;
  final int overallScore;
  final HealthAggregate aggregate;

  const HealthScore({
    required this.id,
    required this.period,
    required this.overallScore,
    required this.aggregate,
  });

  /// 健康等级（0-100 → A/B/C/D/E）。
  String get grade {
    if (overallScore >= 90) return 'A（优秀）';
    if (overallScore >= 80) return 'B（良好）';
    if (overallScore >= 70) return 'C（一般）';
    if (overallScore >= 60) return 'D（注意）';
    return 'E（异常）';
  }
}
