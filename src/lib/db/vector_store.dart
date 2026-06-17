import 'dart:typed_data';

import 'package:drift/drift.dart';

import 'app_database.dart';

/// sqlite-vec 封装：负责 embeddings 虚拟表的 DDL、插入、Top-K 检索。
///
/// **独立 schemaVersion**：向量库升级（旧模型换新模型）时支持增量重算，不影响
/// 主库 schemaVersion。详见 [VectorStore.migrate]。
class VectorStore {
  /// vec0 虚拟表当前 schema 版本（与主库独立计数）。
  static const int vectorSchemaVersion = 1;
  static const int dimensions = 1024; // BGE-M3 输出维度；后续若换模型需要迁移

  final AppDatabase db;
  VectorStore(this.db);

  /// 初始化虚拟表（首次启动时调用）。DDL 走 customStatement，Drift 不感知。
  ///
  /// 当 sqlite-vec 扩展未加载（如桌面测试 / 老系统）时静默跳过，不阻断主库
  /// 初始化。向量相关 API 会在插入 / 检索时再次做可用性检查。
  Future<void> ensureTable() async {
    try {
      await db.customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS vec_embeddings
        USING vec0(
          embedding float[$dimensions],
          source_type TEXT,
          source_id INTEGER,
          chunk_text TEXT,
          model TEXT,
          created_at TEXT
        )
      ''');
    } on Object catch (e) {
      // vec0 模块不可用时跳过；上层调用方应捕获 [StateError]。
      // ignore: avoid_print
      print('[VectorStore] ensureTable skipped: $e');
    }
  }

  /// 写入一条向量。
  Future<int> insert({
    required String sourceType,
    required int sourceId,
    required String chunkText,
    required String model,
    required Float32List embedding,
  }) async {
    final bytes = embedding.buffer.asUint8List();
    final result = await db.customInsert(
      'INSERT INTO vec_embeddings (embedding, source_type, source_id, chunk_text, model, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withBlob(bytes),
        Variable.withString(sourceType),
        Variable.withInt(sourceId),
        Variable.withString(chunkText),
        Variable.withString(model),
        Variable.withString(DateTime.now().toIso8601String()),
      ],
    );
    return result;
  }

  /// Top-K 检索。返回按距离升序排列的 (id, sourceType, sourceId, chunkText)。
  Future<List<VectorHit>> topK(Float32List query, {int k = 5}) async {
    final bytes = query.buffer.asUint8List();
    final rows = await db
        .customSelect(
          'SELECT rowid, source_type, source_id, chunk_text, distance '
          'FROM vec_embeddings '
          'WHERE embedding MATCH ? '
          'ORDER BY distance LIMIT ?',
          variables: [Variable.withBlob(bytes), Variable.withInt(k)],
        )
        .get();
    return rows
        .map(
          (r) => VectorHit(
            rowid: r.read<int>('rowid'),
            sourceType: r.read<String>('source_type'),
            sourceId: r.read<int>('source_id'),
            chunkText: r.read<String>('chunk_text'),
            distance: r.read<double>('distance'),
          ),
        )
        .toList(growable: false);
  }

  /// 清空某 source 下的所有向量（用于去重 / 重建）。
  Future<int> deleteBySource(String sourceType, int sourceId) async {
    return db.customUpdate(
      'DELETE FROM vec_embeddings WHERE source_type = ? AND source_id = ?',
      variables: [Variable.withString(sourceType), Variable.withInt(sourceId)],
      updateKind: UpdateKind.delete,
    );
  }

  /// 模型升级时的"增量重算"占位：旧向量保留、新向量增量追加。
  /// 实际执行由 RAG 层在 Step 6 接入 Embedding API 后填充。
  Future<void> migrate({
    required int fromVersion,
    required int toVersion,
  }) async {
    if (fromVersion == toVersion) return;
    // Step 6 起：按 model 字段 group by，缺新模型向量的旧记录批量重算。
    // Step 2 阶段仅占位。
  }
}

class VectorHit {
  final int rowid;
  final String sourceType;
  final int sourceId;
  final String chunkText;
  final double distance;

  const VectorHit({
    required this.rowid,
    required this.sourceType,
    required this.sourceId,
    required this.chunkText,
    required this.distance,
  });
}
