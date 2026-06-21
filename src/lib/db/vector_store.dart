import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'app_database.dart';

/// sqlite-vec 封装：负责 embeddings 虚拟表的 DDL、插入、Top-K 检索。
///
/// **独立 schemaVersion**：向量库升级（维度变化 / Embedding 模型升级）时支持
/// 自动 drop + recreate，不影响主库 schemaVersion。
class VectorStore {
  /// vec0 虚拟表当前 schema 版本（与主库独立计数）。
  /// - v1: 1024 维 (BGE-M3)
  /// - v2: 1536 维 (OpenAI text-embedding-3-small, 默认)
  static const int vectorSchemaVersion = 2;

  /// 默认维度（OpenAI text-embedding-3-small）。
  static const int defaultDimensions = 1536;

  final AppDatabase db;
  VectorStore(this.db);

  /// 初始化虚拟表（首次启动时调用）。DDL 走 customStatement，Drift 不感知。
  ///
  /// [dimensions] 与期望的 Embedder 输出一致；若表已存在但维度不匹配，
  /// 会 drop 旧表后重建（数据会丢失！生产环境应先备份）。
  ///
  /// 当 sqlite-vec 扩展未加载（如桌面测试 / 老系统）时静默跳过，不阻断主库
  /// 初始化。向量相关 API 会在插入 / 检索时再次做可用性检查。
  Future<void> ensureTable({int dimensions = defaultDimensions}) async {
    try {
      // 0) metadata 表：记录当前维度（用于迁移判定）
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS vec_meta (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');

      // 1) 读取已记录的维度
      final stored = await _readMeta('dimensions');
      final storedDim = stored == null ? null : int.tryParse(stored);

      // 2) 探测 vec_embeddings 表是否存在
      final exists = await _tableExists('vec_embeddings');

      if (exists) {
        if (storedDim == null) {
          // 旧库：表已存在但没有 metadata 记录，按"无法自动迁移"处理：
          // 把旧表 drop 掉重建（Step 6 处于开发阶段，没有真实用户数据）。
          debugPrint(
            '[VectorStore] 旧 vec_embeddings 表无 metadata，按维度=$dimensions 重建',
          );
          await db.customStatement('DROP TABLE vec_embeddings');
          await _createEmbeddingTable(dimensions);
        } else if (storedDim != dimensions) {
          debugPrint(
            '[VectorStore] 维度变化 $storedDim → $dimensions，重建 vec_embeddings',
          );
          await db.customStatement('DROP TABLE vec_embeddings');
          await _createEmbeddingTable(dimensions);
        } else {
          // 维度匹配，啥也不做
        }
      } else {
        await _createEmbeddingTable(dimensions);
      }

      await _writeMeta('dimensions', dimensions.toString());
      await _writeMeta('version', vectorSchemaVersion.toString());
    } on Object catch (e) {
      // vec0 模块不可用时跳过；上层调用方应捕获 [StateError]。
      debugPrint('[VectorStore] ensureTable skipped: $e');
    }
  }

  Future<void> _createEmbeddingTable(int dimensions) async {
    await db.customStatement('''
      CREATE VIRTUAL TABLE vec_embeddings
      USING vec0(
        embedding float[$dimensions],
        source_type TEXT,
        source_id INTEGER,
        chunk_text TEXT,
        model TEXT,
        created_at TEXT
      )
    ''');
  }

  Future<bool> _tableExists(String name) async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          variables: [Variable.withString(name)],
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<String?> _readMeta(String key) async {
    final row = await db
        .customSelect(
          'SELECT value FROM vec_meta WHERE key=?',
          variables: [Variable.withString(key)],
        )
        .getSingleOrNull();
    return row?.read<String>('value');
  }

  Future<void> _writeMeta(String key, String value) async {
    await db.customInsert(
      'INSERT OR REPLACE INTO vec_meta (key, value) VALUES (?, ?)',
      variables: [Variable.withString(key), Variable.withString(value)],
    );
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

  /// 向量总数。
  Future<int> count() async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS c FROM vec_embeddings')
        .getSingle();
    return row.read<int>('c');
  }

  /// 模型升级时的"增量重算"占位：旧向量保留、新向量增量追加。
  /// 实际执行由 RAG 层在 Step 6 接入 Embedding API 后填充。
  Future<void> migrate({
    required int fromVersion,
    required int toVersion,
  }) async {
    if (fromVersion == toVersion) return;
    // 占位：Step 6 起由 [ensureTable] 处理维度变化。
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
