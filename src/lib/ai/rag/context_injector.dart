import 'package:flutter/foundation.dart';

import '../memory/short_term.dart';
import 'retriever.dart';

/// 把 RAG 召回结果注入到 system prompt。
///
/// 设计：
/// - 每次 LLM 调用前，从最后一条 user 消息生成 query
/// - 调 [Retriever] 召回 Top-K
/// - 把结果作为 system prompt 的"附加段落"追加（**不**改写用户原文）
/// - **不**写入 [ShortTermMemory]（避免污染滚动窗口）
class ContextInjector {
  final Retriever retriever;
  final RetrievalOptions options;

  /// 上次注入的命中条数（供 UI 状态条显示用）。每次 [build] 后更新。
  int lastInjectedCount = 0;

  ContextInjector({required this.retriever, this.options = const RetrievalOptions()});

  /// 构造增强后的 system prompt。
  ///
  /// - [baseSystemPrompt]：当前 system 提示模板（含 LLM 行为约束）
  /// - [memory]：短记忆（用于拿到"最后一条 user 消息"作为 query）
  Future<String> build({
    required String baseSystemPrompt,
    required ShortTermMemory memory,
  }) async {
    final query = _extractLastUserQuery(memory);
    if (query == null || query.isEmpty) {
      return baseSystemPrompt;
    }
    try {
      final hits = await retriever.retrieve(query, options: options);
      lastInjectedCount = hits.length;
      if (hits.isEmpty) return baseSystemPrompt;
      final contextBlock = Retriever.renderContext(hits);
      return '$baseSystemPrompt\n\n$contextBlock';
    } catch (e, st) {
      debugPrint('ContextInjector: 注入失败: $e\n$st');
      lastInjectedCount = 0;
      return baseSystemPrompt;
    }
  }

  String? _extractLastUserQuery(ShortTermMemory memory) {
    for (var i = memory.messages.length - 1; i >= 0; i--) {
      final m = memory.messages[i];
      if (m.role == ChatRole.user) {
        return m.content;
      }
    }
    return null;
  }
}
