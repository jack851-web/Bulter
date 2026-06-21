import 'package:flutter/foundation.dart';

import '../ai_service.dart';
import '../rag/context_injector.dart';
import '../rag/embedder.dart';
import '../rag/retriever.dart';
import 'short_term.dart';
import 'user_profile.dart';
import 'working.dart';
import '../../db/app_database.dart';
import 'long_term.dart';

/// 4 层记忆的统一管理器。
///
/// 层级（自下而上）：
/// 1. **UserProfile**（用户画像）— 始终注入
/// 2. **LongTerm**（长期记忆 RAG）— 按 query 召回 Top-K
/// 3. **Working**（工作记忆）— 多步任务中间状态
/// 4. **ShortTerm**（短记忆）— 当前会话的滚动窗口
///
/// 职责：
/// - 在每次 LLM 调用前组装完整的 system prompt（画像 + RAG + 工作记忆 + 短记忆）
/// - 在长记忆抽取阈值达到时触发 [LongTermMemory.maybeExtract]
/// - 在用户画像抽取阈值达到时触发 [UserProfileMemory.maybeExtract]
/// - 暴露"本次注入了什么"给 UI 显示（折叠记忆注入区）
class MemoryManager {
  final AppDatabase db;
  final Embedder embedder;
  final Retriever retriever;
  final ContextInjector injector;
  final LongTermMemory longTerm;
  final UserProfileMemory userProfile;
  final AiService aiService;

  /// 长记忆抽取阈值（每多少条新 user 消息触发一次）。
  final int longTermEveryN;
  final int userProfileEveryN;

  int _sinceLongTerm = 0;
  int _sinceUserProfile = 0;

  /// 当前活跃的工作记忆（每个会话一个）。
  final WorkingMemory working = WorkingMemory();

  /// 本次调用注入的信息（给 UI 显示用）。
  MemoryInjectionReport? lastReport;

  MemoryManager({
    required this.db,
    required this.embedder,
    required this.retriever,
    required this.injector,
    required this.longTerm,
    required this.userProfile,
    required this.aiService,
    this.longTermEveryN = 6,
    this.userProfileEveryN = 12,
  });

  /// 构造 LLM 调用的 system prompt（合并 4 层）。
  ///
  /// 顺序：基础提示 → 用户画像 → RAG 召回 → 工作记忆 → 短记忆（短记忆自带）
  Future<String> buildSystemPrompt(ShortTermMemory memory) async {
    final base = AiService.systemPromptTemplate;
    final parts = <String>[base];

    // 1) 用户画像
    try {
      final profile = await userProfile.current();
      final rendered = UserProfileMemory.render(profile);
      if (rendered.isNotEmpty) parts.add(rendered);
    } catch (e) {
      debugPrint('MemoryManager: 读取用户画像失败: $e');
    }

    // 2) RAG 注入（ContextInjector 内部已处理 lastInjectedCount）
    try {
      final ragPrompt = await injector.build(
        baseSystemPrompt: base,
        memory: memory,
      );
      // 如果 injector 注入了，就把它的内容整段加到 parts（不重复 base）
      if (injector.lastInjectedCount > 0) {
        // ragPrompt 已经包含 base + 注入段
        // 把"原 base 之后追加的内容"再追加一次：直接用 ragPrompt 即可
        // 但 parts 已经有 base，所以换成：parts.clear + 用 ragPrompt
        parts
          ..clear()
          ..add(ragPrompt);
      }
    } catch (e) {
      debugPrint('MemoryManager: RAG 注入失败: $e');
    }

    // 3) 工作记忆
    final w = working.render();
    if (w.isNotEmpty) parts.add(w);

    // 4) 短记忆的消息流由 AiService 在 buildEnhancedSystemPrompt 外处理
    return parts.join('\n\n');
  }

  /// 在每轮对话后调用，更新"距下次抽取"的计数，并按需触发抽取。
  ///
  /// - [memory] 当前短记忆（用于抽取时拿到上下文）
  Future<MemoryUpdateResult> onUserMessage(ShortTermMemory memory) async {
    _sinceLongTerm++;
    _sinceUserProfile++;

    var longTermAdded = 0;
    var longTermDeduped = 0;
    var profileUpdated = 0;

    if (_sinceLongTerm >= longTermEveryN) {
      _sinceLongTerm = 0;
      try {
        final r = await longTerm.maybeExtract(memory: memory);
        longTermAdded = r.added;
        longTermDeduped = r.deduped;
      } catch (e) {
        debugPrint('MemoryManager: 长记忆抽取失败: $e');
      }
    }

    if (_sinceUserProfile >= userProfileEveryN) {
      _sinceUserProfile = 0;
      try {
        final tail = memory.messages
            .where(
              (m) => m.role == ChatRole.user || m.role == ChatRole.assistant,
            )
            .toList();
        if (tail.isNotEmpty) {
          final lastN = tail.length > 10 ? tail.sublist(tail.length - 10) : tail;
          final transcript = lastN
              .map((m) => '[${m.role.name}] ${m.content}')
              .join('\n');
          final r = await userProfile.maybeExtract(
            recentTranscript: transcript,
          );
          profileUpdated = r.updated;
        }
      } catch (e) {
        debugPrint('MemoryManager: 用户画像抽取失败: $e');
      }
    }

    return MemoryUpdateResult(
      longTermAdded: longTermAdded,
      longTermDeduped: longTermDeduped,
      profileUpdated: profileUpdated,
    );
  }

  /// 强制清空工作记忆（用户切换话题 / 任务结束时由调用方决定）。
  void finishTask() => working.finishTask();
}

/// 一次 LLM 调用注入到 system prompt 的记忆概要（给 UI 显示）。
class MemoryInjectionReport {
  final int profileFields;     // 用户画像中已填字段数
  final int ragHits;           // RAG 召回条数
  final bool hasWorkingTask;   // 是否含工作记忆
  final int shortTermRounds;   // 短记忆轮数

  const MemoryInjectionReport({
    required this.profileFields,
    required this.ragHits,
    required this.hasWorkingTask,
    required this.shortTermRounds,
  });
}

/// 长记忆 / 画像抽取的合并结果。
class MemoryUpdateResult {
  final int longTermAdded;
  final int longTermDeduped;
  final int profileUpdated;
  const MemoryUpdateResult({
    required this.longTermAdded,
    required this.longTermDeduped,
    required this.profileUpdated,
  });
  bool get hasChanges =>
      longTermAdded > 0 || longTermDeduped > 0 || profileUpdated > 0;
}
