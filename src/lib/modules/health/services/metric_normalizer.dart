import '../../../db/app_database.dart';
import '../db/health_tables.dart';

/// 健康指标归一化器（Step 13）。
///
/// **职责**：
/// - 把同类指标（如"体重 80kg"）归一化到 **0-100 健康分**
/// - 提供**正常范围**（低/高），用于异常高亮
/// - 支持多种指标类型（weight / sleep / heart_rate / ...）
///
/// **设计**：
/// - 每个 metric_name 都映射到 [MetricProfile]（单位 / 正常范围 / 越界规则）
/// - 分数越接近 100 = 越健康
/// - 超出 normal_range → 分数 < 60 并标记 `severity`
class MetricNormalizer {
  MetricNormalizer._();
  static final MetricNormalizer instance = MetricNormalizer._();

  /// 已知指标的 profile（可在 Settings 里扩展）。
  static final Map<String, MetricProfile> _profiles = {
    'weight': MetricProfile(
      metricName: 'weight',
      label: '体重',
      unit: 'kg',
      normalLow: 45,
      normalHigh: 80,
      // 偏离 1kg → 减 5 分（封顶 60 分）
      penaltyPerUnit: 5,
      direction: MetricDirection.symmetric,
    ),
    'bmi': MetricProfile(
      metricName: 'bmi',
      label: 'BMI',
      unit: '',
      normalLow: 18.5,
      normalHigh: 24.9,
      penaltyPerUnit: 8,
      direction: MetricDirection.symmetric,
    ),
    'sleep_hours': MetricProfile(
      metricName: 'sleep_hours',
      label: '睡眠时长',
      unit: 'h',
      normalLow: 7,
      normalHigh: 9,
      penaltyPerUnit: 15,
      direction: MetricDirection.bothBounds,
    ),
    'steps': MetricProfile(
      metricName: 'steps',
      label: '步数',
      unit: '步',
      normalLow: 6000,
      normalHigh: 15000,
      penaltyPerUnit: 0.001, // 步数差距大，权重小
      direction: MetricDirection.lowerBoundOnly,
    ),
    'resting_heart_rate': MetricProfile(
      metricName: 'resting_heart_rate',
      label: '静息心率',
      unit: 'bpm',
      normalLow: 50,
      normalHigh: 80,
      penaltyPerUnit: 2,
      direction: MetricDirection.symmetric,
    ),
  };

  /// 标准化 + 算健康分。
  MetricAssessment assess(HealthRecord r) {
    final profile = _profiles[r.type];
    if (profile == null) {
      return MetricAssessment(
        record: r,
        profile: null,
        score: 80, // 未知指标默认 80
        severity: MetricSeverity.normal,
        message: '未配置健康范围',
      );
    }
    final value = r.valueNum ?? double.tryParse(r.valueText ?? '') ?? 0;
    return _assessWithProfile(value, profile, r);
  }

  MetricAssessment _assessWithProfile(
    double value,
    MetricProfile p,
    HealthRecord r,
  ) {
    if (value >= p.normalLow && value <= p.normalHigh) {
      return MetricAssessment(
        record: r,
        profile: p,
        score: 100,
        severity: MetricSeverity.normal,
        message: '正常',
      );
    }
    // 计算偏离量
    final distance = value < p.normalLow
        ? p.normalLow - value
        : value - p.normalHigh;
    final penalty = (distance * p.penaltyPerUnit).round();
    final score = (100 - penalty).clamp(0, 99);
    MetricSeverity severity;
    if (score >= 80) {
      severity = MetricSeverity.normal;
    } else if (score >= 60) {
      severity = MetricSeverity.warning;
    } else {
      severity = MetricSeverity.critical;
    }
    final dir = value < p.normalLow ? '过低' : '过高';
    return MetricAssessment(
      record: r,
      profile: p,
      score: score,
      severity: severity,
      message: '$dir（正常 ${p.normalLow}-${p.normalHigh}${p.unit}）',
    );
  }

  /// 批量评估 + 加权汇总到综合分。
  Future<HealthAggregate> aggregateBatch(Iterable<HealthRecord> records) async {
    final assessments = records.map(assess).toList();
    if (assessments.isEmpty) {
      return const HealthAggregate(
        overallScore: 100,
        assessments: [],
        dimensionScores: {},
      );
    }
    // 维度聚合：按 profile.metricName 分组
    final byDim = <String, List<MetricAssessment>>{};
    for (final a in assessments) {
      final key = a.profile?.metricName ?? a.record.type;
      byDim.putIfAbsent(key, () => []).add(a);
    }
    final dimScores = <String, double>{};
    byDim.forEach((dim, list) {
      final avg =
          list.map((a) => a.score).reduce((a, b) => a + b) / list.length;
      dimScores[dim] = avg;
    });
    final overall = dimScores.values.reduce((a, b) => a + b) / dimScores.length;
    return HealthAggregate(
      overallScore: overall.round().clamp(0, 100),
      assessments: assessments,
      dimensionScores: dimScores,
    );
  }
}

/// 指标 profile。
class MetricProfile {
  final String metricName;
  final String label;
  final String unit;
  final double normalLow;
  final double normalHigh;
  final double penaltyPerUnit; // 每偏离 1 单位的扣分
  final MetricDirection direction;

  const MetricProfile({
    required this.metricName,
    required this.label,
    required this.unit,
    required this.normalLow,
    required this.normalHigh,
    required this.penaltyPerUnit,
    required this.direction,
  });
}

enum MetricDirection {
  symmetric, // 上下界同等惩罚（如 BMI）
  lowerBoundOnly, // 只关注下界（如步数越少越不健康）
  bothBounds, // 上下界都重要（如睡眠）
}

enum MetricSeverity { normal, warning, critical }

/// 单条评估结果。
class MetricAssessment {
  final HealthRecord record;
  final MetricProfile? profile;
  final int score; // 0-100
  final MetricSeverity severity;
  final String message;

  const MetricAssessment({
    required this.record,
    required this.profile,
    required this.score,
    required this.severity,
    required this.message,
  });

  bool get isAbnormal => severity != MetricSeverity.normal;
}

/// 综合评分（含各维度）。
class HealthAggregate {
  final int overallScore; // 0-100
  final List<MetricAssessment> assessments;
  final Map<String, double> dimensionScores;

  const HealthAggregate({
    required this.overallScore,
    required this.assessments,
    required this.dimensionScores,
  });

  /// 异常指标数量。
  int get abnormalCount => assessments.where((a) => a.isAbnormal).length;

  /// 严重异常指标数量（critical）。
  int get criticalCount =>
      assessments.where((a) => a.severity == MetricSeverity.critical).length;
}
