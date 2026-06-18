import 'dart:convert';

/// 单条消息在短记忆中的角色。
enum ChatRole { system, user, assistant, tool }

/// 会话级短记忆的一条消息。
class ChatMessage {
  final ChatRole role;
  final String content;
  final DateTime createdAt;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.createdAt,
  });

  /// OpenAI 风格 wire 字段
  String get wireRole {
    switch (role) {
      case ChatRole.system:
        return 'system';
      case ChatRole.user:
        return 'user';
      case ChatRole.assistant:
        return 'assistant';
      case ChatRole.tool:
        return 'tool';
    }
  }
}

/// 会话级短记忆（滑动窗口）。
///
/// 设计目标：
/// - 单次对话（一次 [start] ~ 一次 [reset]）内维持上下文。
/// - 超过 [maxRounds]（默认 20 轮 = 40 条消息）时按 FIFO 丢弃最旧。
/// - 不做摘要，不做 RAG；这一步只把"上下文窗口可控"这件事做对。
/// - Step 7 接入长期记忆后，长期记忆由 RAG 注入到 system prompt，**不**写回
///   短记忆，避免污染滚动窗口。
class ShortTermMemory {
  final List<ChatMessage> _messages = [];
  final int maxRounds;

  ShortTermMemory({this.maxRounds = 20});

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  int get length => _messages.length;

  bool get isEmpty => _messages.isEmpty;

  /// 追加 system 提示（不计入 rounds；多个 system 合并显示在开头）。
  void addSystem(String content) {
    _messages.removeWhere((m) => m.role == ChatRole.system);
    _messages.insert(
      0,
      ChatMessage(
        role: ChatRole.system,
        content: content,
        createdAt: DateTime.now(),
      ),
    );
  }

  void append(ChatMessage msg) {
    _messages.add(msg);
    _truncate();
  }

  /// 清空所有消息（保留可选 system）。
  void reset({bool keepSystem = true}) {
    if (keepSystem) {
      _messages.removeWhere((m) => m.role != ChatRole.system);
    } else {
      _messages.clear();
    }
  }

  /// 转为 LLM 需要的 messages 字段（OpenAI Chat Completions 格式）。
  ///
  /// - system / user: `{role, content}`
  /// - assistant (含 tool_calls 编码): `{role, content, [tool_calls]}`
  /// - tool: `{role: tool, tool_call_id, content}`
  List<Map<String, dynamic>> toLlmMessages() {
    final out = <Map<String, dynamic>>[];
    for (final m in _messages) {
      if (m.role == ChatRole.system || m.role == ChatRole.user) {
        out.add({'role': m.wireRole, 'content': m.content});
      } else if (m.role == ChatRole.assistant) {
        // 检查是否含 [tool_calls] 编码
        final idx = m.content.indexOf('[tool_calls]');
        if (idx >= 0) {
          final contentPart = m.content.substring(0, idx).trimRight();
          final jsonPart = m.content.substring(idx + '[tool_calls]'.length);
          out.add({
            'role': 'assistant',
            if (contentPart.isNotEmpty) 'content': contentPart,
            'tool_calls': (jsonDecode(jsonPart) as List).cast<dynamic>(),
          });
        } else {
          out.add({'role': 'assistant', 'content': m.content});
        }
      } else if (m.role == ChatRole.tool) {
        // 编码格式: <toolCallId>|<json>
        final pipeIdx = m.content.indexOf('|');
        if (pipeIdx > 0) {
          final id = m.content.substring(0, pipeIdx);
          final body = m.content.substring(pipeIdx + 1);
          out.add({'role': 'tool', 'tool_call_id': id, 'content': body});
        } else {
          out.add({'role': 'tool', 'content': m.content});
        }
      }
    }
    return out;
  }

  /// 估算当前 token 数（粗略：每 4 个字符 ≈ 1 token；仅做 UI 提示用）。
  int estimateTokens() {
    final totalChars = _messages.fold<int>(
      0,
      (sum, m) => sum + m.content.length,
    );
    return (totalChars / 4).ceil();
  }

  void _truncate() {
    // 保留 system；其余按 (user, assistant) 配对删除最早的。
    final systemMsgs = _messages
        .where((m) => m.role == ChatRole.system)
        .toList();
    final others = _messages.where((m) => m.role != ChatRole.system).toList();
    final maxMessages = maxRounds * 2;
    if (others.length <= maxMessages) return;

    final dropped = others.length - maxMessages;
    final kept = others.sublist(dropped);

    // 防御：丢弃后如果首条不是 user（说明配对被切断），再丢一条
    if (kept.isNotEmpty && kept.first.role != ChatRole.user) {
      kept.removeAt(0);
    }

    _messages
      ..clear()
      ..addAll(systemMsgs)
      ..addAll(kept);
  }

  /// 当前可见的"轮"数（user/assistant 配对 = 1 轮）。
  int get rounds {
    return _messages
            .where(
              (m) => m.role == ChatRole.user || m.role == ChatRole.assistant,
            )
            .length ~/
        2;
  }

  /// 取最近 [n] 条用于 UI 显示。
  List<ChatMessage> tail(int n) {
    if (n <= 0) return const [];
    return _messages.length <= n
        ? List.unmodifiable(_messages)
        : List.unmodifiable(_messages.sublist(_messages.length - n));
  }

  /// 找到最后一条 assistant 消息的索引（流式追加时用）。不存在返回 -1。
  int lastAssistantIndex() {
    return _messages.lastIndexWhere((m) => m.role == ChatRole.assistant);
  }

  /// 更新最后一条 assistant 的 content（流式打字机效果用）。
  void updateLastAssistantContent(String delta) {
    final i = lastAssistantIndex();
    if (i < 0) return;
    final old = _messages[i];
    _messages[i] = ChatMessage(
      role: ChatRole.assistant,
      content: old.content + delta,
      createdAt: old.createdAt,
    );
  }
}
