import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../db/thought_tables.dart';

/// 年度回顾服务（Step 13）。
///
/// **职责**：
/// - 按年汇总 `thoughts` 表的全年记录
/// - 自动提取关键词 / 高频主题
/// - 生成结构化 [AnnualReviewSummary]（用于展示 + 持久化为 [AnnualReview]）
class AnnualReviewService {
  AnnualReviewService._();
  static final AnnualReviewService instance = AnnualReviewService._();

  /// 生成指定年份的回顾汇总。
  Future<AnnualReviewSummary> generate(AppDatabase db, int year) async {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);

    final thoughts =
        await (db.select(db.thoughts)..where(
              (t) =>
                  t.recordedAt.isBiggerOrEqualValue(start) &
                  t.recordedAt.isSmallerThanValue(end),
            ))
            .get();

    // 1) 总数
    final totalCount = thoughts.length;

    // 2) 按 source 分组
    final bySource = <String, int>{};
    for (final t in thoughts) {
      bySource[t.source] = (bySource[t.source] ?? 0) + 1;
    }

    // 3) 按月分布
    final byMonth = List<int>.filled(12, 0);
    for (final t in thoughts) {
      byMonth[t.recordedAt.month - 1]++;
    }

    // 4) 关键词（简单分词：取 content 中长度 >=2 的高频词）
    final wordCount = <String, int>{};
    for (final t in thoughts) {
      _tokenize(t.content).forEach((word) {
        if (word.length < 2) return;
        if (_stopWords.contains(word)) return;
        wordCount[word] = (wordCount[word] ?? 0) + 1;
      });
      // 也提取 sourceRef（如"《书名》"）
      final ref = t.sourceRef;
      if (ref != null && ref.isNotEmpty) {
        wordCount[ref] = (wordCount[ref] ?? 0) + 2;
      }
    }
    final keywords = wordCount.entries
        .where((e) => e.value >= 2)
        .sortedByValueDesc()
        .take(10)
        .map((e) => e.key)
        .toList();

    return AnnualReviewSummary(
      year: year,
      totalCount: totalCount,
      bySource: bySource,
      byMonth: byMonth,
      keywords: keywords,
      thoughts: thoughts,
    );
  }

  /// 持久化年度回顾。
  Future<int> persist(AppDatabase db, AnnualReviewSummary summary) async {
    final review = AnnualReviewsCompanion.insert(
      year: summary.year,
      content: summary.thoughts.map((t) => t.content).join('\n\n---\n\n'),
      highlightsJson: Value(jsonEncode(summary.keywords)),
      challengesJson: const Value('[]'),
      lessons: Value(
        summary.thoughts.isEmpty
            ? '今年还未记录思想。'
            : '本年思想共 ${summary.totalCount} 条，关键词：${summary.keywords.take(5).join('、')}',
      ),
    );
    return db.thoughtDao.upsertAnnualReview(review);
  }

  // 简化分词：连续中英文 token
  List<String> _tokenize(String s) {
    final re = RegExp(r'[\u4e00-\u9fa5]+|[a-zA-Z]+');
    return re.allMatches(s).map((m) => m.group(0)!).toList();
  }

  static const Set<String> _stopWords = {
    '的',
    '了',
    '是',
    '我',
    '你',
    '他',
    '她',
    '它',
    '在',
    '有',
    '和',
    '就',
    '不',
    '人',
    '都',
    '一',
    '上',
    '也',
    '很',
    '到',
    '说',
    '要',
    '去',
    '会',
    '着',
    '没有',
    '看',
    '好',
    '自己',
    '这',
    '那',
    '把',
    '让',
    '但',
    'the',
    'a',
    'an',
    'and',
    'or',
    'but',
    'is',
    'are',
    'was',
    'were',
    'be',
  };
}

/// 单年回顾汇总。
class AnnualReviewSummary {
  final int year;
  final int totalCount;
  final Map<String, int> bySource; // 'book' / 'article' / ...
  final List<int> byMonth; // 长度 12
  final List<String> keywords;
  final List<Thought> thoughts;

  const AnnualReviewSummary({
    required this.year,
    required this.totalCount,
    required this.bySource,
    required this.byMonth,
    required this.keywords,
    required this.thoughts,
  });
}

extension on Iterable<MapEntry<String, int>> {
  Iterable<MapEntry<String, int>> sortedByValueDesc() {
    final list = toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }
}
