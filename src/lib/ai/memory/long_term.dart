import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../db/app_database.dart';
import '../ai_service.dart';
import '../memory/short_term.dart';
import '../rag/embedder.dart';
import '../rag/retriever.dart';

/// 长期记忆（事实抽取 + 去重）。
///
/// Step 6 流程：
/// 1. **触发**：每次用户消息发送后 / 每 N 轮 / 关闭对话时，调用 [maybeExtract]
/// 2. **提取**：调 LLM（带专门 system prompt），从最近 K 条消息里抽取结构化事实
/// 3. **去重**：对每条候选事实做相似度检索，若已存在极高相似度的旧记录 → 跳过
/// 4. **持久化**：新事实写入 [Memories] 表 + [vec_embeddings] 向量库
///
/// **降级**：
/// - Embedder 不可用 → 仅做"完全相同的字面去重"，不阻塞事实写入
/// - LLM 调用失败 → 跳过本次抽取，下次重试
class LongTermMemory {
  final AppDatabase db;
  final Embedder embedder;
  final Retriever retriever;
  final AiService aiService;

  /// 每多少条新消息触发一次抽取。
  final int extractEveryNMessages;

  /// 已处理消息数（自上次抽取以来）。
  int _sinceLastExtract = 0;

  /// 简报抽取的 system prompt。
  static const String extractSystemPrompt =
      '你是 Bulter 的记忆整理助手。'
      '你的任务是从用户最近的一段对话里，**只**提取值得长期记住的稳定事实。'
      '\n\n'
      '**抽取规则**：\n'
      '1. 只提取稳定、客观、长期有效的事实（生日 / 偏好 / 重要的人 / 长期目标 / 习惯 / 健康状况等）\n'
      '2. 忽略临时性信息（"今天吃了什么"、心情波动、单次对话指令）\n'
      '3. 每条事实用一句话表达（30 字以内）\n'
      '4. 分类只能是：fact / event / preference / relationship\n'
      '\n'
      '**输出格式**（必须是合法 JSON 数组，不要任何解释或 markdown）：\n'
      '[{"content": "...", "type": "fact|event|preference|relationship"}]\n'
      '如果没有值得记住的事实，返回 []。';

  LongTermMemory({
    required this.db,
    required this.embedder,
    required this.retriever,
    required this.aiService,
    this.extractEveryNMessages = 6,
  });

  /// 判断是否该触发抽取（增量计数 + 阈值）。
  bool shouldExtract(int newUserMsgCount) {
    _sinceLastExtract += newUserMsgCount;
    return _sinceLastExtract >= extractEveryNMessages;
  }

  /// 触发一次长期记忆抽取（异步，不阻塞主流程）。
  ///
  /// - [memory] 当前对话的 [ShortTermMemory]
  /// - [sessionId] 可选：把抽取结果与一个 sessionId 关联
  /// - [trigger] 触发原因（用于日志）
  Future<ExtractResult> maybeExtract({
    required ShortTermMemory memory,
    int? sessionId,
    String trigger = 'threshold',
  }) async {
    if (!shouldExtract(1)) {
      return ExtractResult.empty();
    }
    _sinceLastExtract = 0;
    try {
      final facts = await _extractFacts(memory);
      if (facts.isEmpty) {
        return ExtractResult.empty();
      }
      var added = 0;
      var deduped = 0;
      for (final f in facts) {
        if (f.content.trim().isEmpty) continue;
        if (await _isDuplicate(f.content)) {
          deduped++;
          continue;
        }
        await _persistFact(f, sessionId: sessionId);
        added++;
      }
      return ExtractResult(added: added, deduped: deduped);
    } catch (e, st) {
      debugPrint('LongTermMemory.maybeExtract 失败: $e\n$st');
      return ExtractResult.empty();
    }
  }

  /// 调 LLM 抽取事实（不流式）。
  Future<List<_FactCandidate>> _extractFacts(ShortTermMemory memory) async {
    // 取最后 10 条消息（user + assistant）
    final tail = memory.messages
        .where(
          (m) => m.role == ChatRole.user || m.role == ChatRole.assistant,
        )
        .toList();
    if (tail.isEmpty) return const [];
    final lastN = tail.length > 10 ? tail.sublist(tail.length - 10) : tail;
    final transcript = lastN
        .map((m) => '[${m.role.name}] ${m.content}')
        .join('\n');

    final promptMem = ShortTermMemory()..addSystem(extractSystemPrompt);
    promptMem.append(ChatMessage(
      role: ChatRole.user,
      content: '请从下面的对话里提取值得长期记住的事实：\n\n$transcript',
      createdAt: DateTime.now(),
    ));

    final raw = await aiService.completion(memory: promptMem);
    return _parseFacts(raw);
  }

  List<_FactCandidate> _parseFacts(String raw) {
    try {
      // 容错：LLM 可能裹 markdown 围栏或前置废话，取第一个 [...] 块
      final start = raw.indexOf('[');
      final end = raw.lastIndexOf(']');
      if (start < 0 || end <= start) return const [];
      final jsonStr = raw.substring(start, end + 1);
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) {
            final m = e as Map<String, dynamic>;
            return _FactCandidate(
              content: (m['content'] as String?)?.trim() ?? '',
              type: _parseType(m['type'] as String?),
            );
          })
          .where((f) => f.content.isNotEmpty)
          .toList(growable: false);
    } catch (e, st) {
      debugPrint('LongTermMemory._parseFacts 失败: $e\n$st');
      return const [];
    }
  }

  MemoryType _parseType(String? raw) {
    switch (raw) {
      case 'event':
        return MemoryType.event;
      case 'preference':
        return MemoryType.preference;
      case 'relationship':
        return MemoryType.relationship;
      case 'fact':
      default:
        return MemoryType.fact;
    }
  }

  /// 字面 + 向量双维度去重。
  Future<bool> _isDuplicate(String content) async {
    // 1) 字面精确去重
    final all = await db.aiDao.watchMemories().first;
    for (final m in all) {
      if (m.content.trim() == content.trim()) return true;
    }
    // 2) 向量相似度去重（>0.92 视为同一事实）
    try {
      final emb = await embedder.embedBatch([content]);
      if (emb.isEmpty) return false;
      final hits = await retriever.retrieve(
        content,
        options: const RetrievalOptions(k: 3, minSimilarity: 0.92),
      );
      if (hits.isNotEmpty) return true;
    } catch (_) {
      // embedder 失败时只做字面去重（已在上面完成）
    }
    return false;
  }

  /// 写入 [Memories] 表 + [vec_embeddings] 向量库。
  Future<void> _persistFact(_FactCandidate f, {int? sessionId}) async {
    final rowid = await db.aiDao.insertMemory(MemoriesCompanion(
      type: Value(_typeToString(f.type)),
      content: Value(f.content),
      sourceSessionId: Value(sessionId),
      confidence: const Value(1.0),
      createdAt: Value(DateTime.now()),
    ));
    try {
      final emb = await embedder.embedBatch([f.content]);
      if (emb.isNotEmpty) {
        await db.vectorStore.insert(
          sourceType: 'memory',
          sourceId: rowid,
          chunkText: f.content,
          model: embedder.name,
          embedding: emb.first,
        );
      }
    } catch (e) {
      debugPrint('LongTermMemory: 向量化失败（已写入表）: $e');
    }
  }

  String _typeToString(MemoryType t) {
    switch (t) {
      case MemoryType.fact:
        return 'fact';
      case MemoryType.event:
        return 'event';
      case MemoryType.preference:
        return 'preference';
      case MemoryType.relationship:
        return 'relationship';
    }
  }

  /// 手动重置计数器（如关闭会话时强制下一次触发）。
  void resetCounter() => _sinceLastExtract = 0;
}

class _FactCandidate {
  final String content;
  final MemoryType type;
  const _FactCandidate({required this.content, required this.type});
}

enum MemoryType { fact, event, preference, relationship }

/// 抽取结果（用于 UI 状态条 / 调试）。
class ExtractResult {
  final int added;
  final int deduped;
  const ExtractResult({required this.added, required this.deduped});
  const ExtractResult.empty() : added = 0, deduped = 0;
  bool get hasChanges => added > 0 || deduped > 0;
}
