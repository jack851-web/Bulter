import 'dart:typed_data';

import '../../db/vector_store.dart';
import 'embedder.dart';

/// 单条召回结果。
class RetrievalHit {
  /// 原始命中（来自 [VectorStore]）
  final VectorHit raw;
  /// 余弦相似度（0-1；越高越相似）。本地 L2 距离 → 转相似度。
  final double similarity;
  /// 来源（人类可读）："memory" / "thought" / "transaction" / ...
  final String source;
  /// 命中所属的"高一级对象"id（与 raw.sourceId 相同时简化显示）
  final int sourceId;

  const RetrievalHit({
    required this.raw,
    required this.similarity,
    required this.source,
    required this.sourceId,
  });
}

/// 检索选项。
class RetrievalOptions {
  /// 召回 Top-K。
  final int k;

  /// 相似度阈值（0-1），低于此值丢弃。默认 0.45。
  final double minSimilarity;

  /// 是否按 sourceType 去重（同 source 只保留最高分）。
  final bool dedupeBySource;

  /// 最多保留每个 sourceType 的条数（仅在 [dedupeBySource] = true 时生效）。
  final int maxPerSource;

  const RetrievalOptions({
    this.k = 5,
    this.minSimilarity = 0.45,
    this.dedupeBySource = true,
    this.maxPerSource = 2,
  });
}

/// 检索器：调用 [Embedder] 把 query 转成向量，再用 [VectorStore] 取 Top-K。
///
/// - **失败优雅降级**：embedder / vector store 任一不可用时，返回空列表（不抛错给主流程）。
/// - **Rerank**：Step 6 阶段仅按相似度 + 去重排序；Step 9 可在此处插 Cross-Encoder。
class Retriever {
  final Embedder embedder;
  final VectorStore store;

  Retriever({required this.embedder, required this.store});

  /// 单 query 检索。
  Future<List<RetrievalHit>> retrieve(
    String query, {
    RetrievalOptions options = const RetrievalOptions(),
  }) async {
    if (query.trim().isEmpty) return const [];
    try {
      final emb = await embedder.embedBatch([query]);
      if (emb.isEmpty) return const [];
      final hits = await store.topK(emb.first, k: options.k * 2);
      // sqlite-vec 距离（L2）转余弦相似度（所有向量已 L2 归一化）
      //   cos = 1 - 0.5 * L2^2
      //   similarity = clamp(cos, 0, 1)
      final scored = hits.map((h) {
        final sim = (1.0 - 0.5 * h.distance * h.distance).clamp(0.0, 1.0);
        return RetrievalHit(
          raw: h,
          similarity: sim,
          source: h.sourceType,
          sourceId: h.sourceId,
        );
      }).where((h) => h.similarity >= options.minSimilarity).toList();

      // 按相似度降序
      scored.sort((a, b) => b.similarity.compareTo(a.similarity));

      // 按 sourceType 去重（每类保留 maxPerSource）
      if (options.dedupeBySource) {
        final seen = <String, int>{};
        return scored
            .where((h) {
              final c = seen[h.source] ?? 0;
              if (c >= options.maxPerSource) return false;
              seen[h.source] = c + 1;
              return true;
            })
            .take(options.k)
            .toList(growable: false);
      }
      return scored.take(options.k).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// 把一批 hits 渲染成可注入 LLM 的字符串。
  static String renderContext(List<RetrievalHit> hits, {int maxChars = 1500}) {
    if (hits.isEmpty) return '';
    final buf = StringBuffer('以下是可能相关的历史记忆：\n');
    for (final h in hits) {
      final sim = h.similarity.toStringAsFixed(2);
      buf.writeln(
        '- [${h.source} #${h.sourceId}, 相似度=$sim] ${h.raw.chunkText}',
      );
      if (buf.length > maxChars) break;
    }
    return buf.toString();
  }
}
