import 'package:drift/drift.dart' show OrderingMode, OrderingTerm, Value;
import 'package:flutter/foundation.dart';

import '../../db/app_database.dart';
import '../model_registry.dart';

/// 跨会话记忆加载器（Step 11）。
///
/// **职责**：
/// - 新会话开始时，自动加载最近 N 个 session（默认 3）的最后 K 条消息（默认 5 条 / session）
/// - 输出成 system prompt 片段（标注 "[Cross-session context from earlier conversation]"）
/// - **限制总字符数 ≤ 2000**（避免 prompt 爆炸）
/// - **不**喧宾夺主：仅作为补充上下文，主对话仍由 system prompt + RAG 主导
///
/// **不调 LLM**：纯文本拼接。LLM 会基于这些上下文自然理解"用户过去问过什么"。
class CrossSessionMemory {
  CrossSessionMemory._();
  static final CrossSessionMemory instance = CrossSessionMemory._();

  /// 默认加载最近 N 个 session。
  final int defaultRecentSessions = 3;

  /// 每个 session 取最后 K 条消息。
  final int defaultMessagesPerSession = 5;

  /// 总字符上限（避免 prompt 爆炸）。
  final int maxTotalChars = 2000;

  /// 是否启用（设置页可关闭）。
  bool enabled = true;

  /// 加载跨会话上下文，格式化成可直接拼接到 system prompt 的字符串。
  ///
  /// - [excludeSessionId]：当前会话 ID（避免把当前会话也拼进去）。
  /// - [recentSessions]：默认 3
  /// - [messagesPerSession]：默认 5
  /// - 返回 `null` 表示禁用 / 无历史 / 上下文为空
  Future<String?> loadContext({
    int? excludeSessionId,
    int? recentSessions,
    int? messagesPerSession,
  }) async {
    if (!enabled) return null;
    final cfg = ModelRegistry.instance.active;
    if (cfg.apiKey.isEmpty) return null;
    final n = recentSessions ?? defaultRecentSessions;
    final k = messagesPerSession ?? defaultMessagesPerSession;
    try {
      final db = AppDatabase.I;
      // 1) 最近 N 个 session（不含 excludeSessionId）
      var query = db.select(db.sessions)
        ..orderBy([
          (s) => OrderingTerm(expression: s.startedAt, mode: OrderingMode.desc),
        ])
        ..limit(n + (excludeSessionId != null ? 1 : 0));
      if (excludeSessionId != null) {
        query = db.select(db.sessions)
          ..where((s) => s.id.equals(excludeSessionId).equals(false))
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.startedAt, mode: OrderingMode.desc),
          ])
          ..limit(n);
      } else {
        query = query..limit(n);
      }
      final sessions = await query.get();
      if (sessions.isEmpty) return null;

      // 2) 每个 session 取最后 K 条消息
      final buf = StringBuffer();
      buf.writeln('[Cross-session context from earlier conversation]');
      for (final s in sessions) {
        final msgs =
            await (db.select(db.messages)
                  ..where((m) => m.sessionId.equals(s.id))
                  ..orderBy([
                    (m) => OrderingTerm(
                      expression: m.createdAt,
                      mode: OrderingMode.desc,
                    ),
                  ])
                  ..limit(k))
                .get();
        if (msgs.isEmpty) continue;
        // 按时间正序
        final sorted = msgs.reversed.toList();
        buf.writeln();
        buf.writeln(
          '--- ${s.title.isEmpty ? "Session ${s.id}" : s.title} '
          '(${s.startedAt.toLocal().toString().split(".").first}) ---',
        );
        for (final m in sorted) {
          final role = m.role == 'user' ? 'User' : 'Assistant';
          // 截断单条消息（避免超长工具调用挤爆上下文）
          final text = m.content.length > 200
              ? '${m.content.substring(0, 200)}…'
              : m.content;
          buf.writeln('$role: $text');
        }
      }
      final raw = buf.toString();
      // 3) 总字符上限
      if (raw.length <= maxTotalChars) return raw;
      // 截断到 maxTotalChars，但保留段落完整（找最近的 \n）
      final cut = raw.lastIndexOf('\n', maxTotalChars);
      if (cut > 0) {
        return '${raw.substring(0, cut)}\n...(truncated to $maxTotalChars chars)';
      }
      return '${raw.substring(0, maxTotalChars)}...(truncated)';
    } catch (e) {
      debugPrint('CrossSessionMemory: 加载失败 - $e');
      return null;
    }
  }
}
