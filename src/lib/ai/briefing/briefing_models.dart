/// 简报数据模型（Step 9）。
///
/// 设计目标：
/// - **可序列化**：JSON ≤2KB，能直接进 `Briefings.jsonData` 字段
/// - **跨模块复用**：业务模块、中枢通用同一套字段
/// - **TTL 内置**：每条简报自带 `ttlSeconds`，UI 渲染时算新鲜度
/// - **降级路径**：子模型失败时仍能渲染（用 fallback 文案）

/// 简报刷新周期。
///
/// - [daily]   每日 23:00 自动刷新
/// - [weekly]  每周日 23:00
/// - [monthly] 每月最后一天 23:00
/// - [yearly]  每年 12/31 23:00
/// - [ondemand] 手动触发（不参与调度）
enum BriefingPeriod {
  daily,
  weekly,
  monthly,
  yearly,
  ondemand;

  String get label {
    switch (this) {
      case BriefingPeriod.daily:
        return '今日';
      case BriefingPeriod.weekly:
        return '本周';
      case BriefingPeriod.monthly:
        return '本月';
      case BriefingPeriod.yearly:
        return '今年';
      case BriefingPeriod.ondemand:
        return '临时';
    }
  }

  String get storageKey {
    return name;
  }

  static BriefingPeriod fromStorageKey(String s) {
    for (final p in BriefingPeriod.values) {
      if (p.storageKey == s) return p;
    }
    return BriefingPeriod.daily;
  }
}

/// 一组 chip 数据（关系模块常用：待联系 2 位 / 人情 1 笔未还）。
class BriefingChip {
  final String label;
  final String value;
  const BriefingChip({required this.label, required this.value});

  Map<String, dynamic> toJson() => {'label': label, 'value': value};
  factory BriefingChip.fromJson(Map<String, dynamic> j) =>
      BriefingChip(label: j['label'] as String, value: j['value'] as String);
}

/// 一条模块简报。
///
/// 中枢主页 Bento 卡片展示：
/// - 标题 + 副标题：`module.displayName` + `period.label`
/// - 标题行：`headline`（如"待回候 5 人 · 重要 8 人"）
/// - 摘要：`summary`（1-2 句中文叙事）
/// - chips：底部小数据方块（如 "2 个待星" / "1 个待人"）
/// - 生成时间 + TTL：UI 算新鲜度
class ModuleBriefing {
  final String moduleId;
  final BriefingPeriod period;
  final String headline;
  final String summary;
  final List<BriefingChip> chips;
  final DateTime generatedAt;
  final int ttlSeconds;

  const ModuleBriefing({
    required this.moduleId,
    required this.period,
    required this.headline,
    required this.summary,
    required this.generatedAt,
    this.chips = const [],
    this.ttlSeconds = 86400,
  });

  /// TTL 过期判断。
  bool isStale([DateTime? now]) {
    final t = now ?? DateTime.now();
    final diff = t.difference(generatedAt).inSeconds;
    return diff > ttlSeconds;
  }

  /// 人类可读新鲜度：刚生成 / 3 分钟前 / 2 小时前 / 1 天前 / 过期。
  String freshnessLabel([DateTime? now]) {
    final t = now ?? DateTime.now();
    final d = t.difference(generatedAt);
    if (d.inSeconds < 0) return '刚刚';
    if (d.inSeconds < 60) return '刚刚';
    if (d.inMinutes < 60) return '${d.inMinutes} 分钟前';
    if (d.inHours < 24) return '${d.inHours} 小时前';
    if (d.inDays < 30) return '${d.inDays} 天前';
    return '很久前';
  }

  ModuleBriefing copyWith({
    String? headline,
    String? summary,
    List<BriefingChip>? chips,
    DateTime? generatedAt,
    int? ttlSeconds,
    BriefingPeriod? period,
  }) =>
      ModuleBriefing(
        moduleId: moduleId,
        period: period ?? this.period,
        headline: headline ?? this.headline,
        summary: summary ?? this.summary,
        chips: chips ?? this.chips,
        generatedAt: generatedAt ?? this.generatedAt,
        ttlSeconds: ttlSeconds ?? this.ttlSeconds,
      );

  Map<String, dynamic> toJson() => {
        'moduleId': moduleId,
        'period': period.storageKey,
        'headline': headline,
        'summary': summary,
        'chips': chips.map((c) => c.toJson()).toList(),
        'generatedAt': generatedAt.toIso8601String(),
        'ttlSeconds': ttlSeconds,
      };

  /// 解析失败 → fallback（仍可渲染，不抛错）。
  static ModuleBriefing fromJson(Map<String, dynamic> j) {
    final chipsJson = (j['chips'] as List?) ?? const [];
    return ModuleBriefing(
      moduleId: j['moduleId'] as String,
      period: BriefingPeriod.fromStorageKey(j['period'] as String? ?? 'daily'),
      headline: j['headline'] as String? ?? '（暂无简报）',
      summary: j['summary'] as String? ?? '',
      chips: chipsJson
          .whereType<Map>()
          .map((m) => BriefingChip.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false),
      generatedAt: DateTime.tryParse(j['generatedAt'] as String? ?? '') ??
          DateTime.now(),
      ttlSeconds: (j['ttlSeconds'] as int?) ?? 86400,
    );
  }

  /// 子模型失败时的 fallback（保证首页永远有内容）。
  static ModuleBriefing fallback(
    String moduleId, {
    String headline = '（暂无简报）',
    String summary = '点击生成今日简报',
    DateTime? now,
  }) =>
      ModuleBriefing(
        moduleId: moduleId,
        period: BriefingPeriod.daily,
        headline: headline,
        summary: summary,
        generatedAt: now ?? DateTime.now(),
      );
}
