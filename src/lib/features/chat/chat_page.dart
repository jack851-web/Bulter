import 'dart:convert' show jsonDecode;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ai/ai_service.dart';
import '../../ai/memory/cross_session.dart';
import '../../ai/memory/memory_manager.dart';
import '../../ai/memory/short_term.dart';
import '../../ai/model_registry.dart';
import '../../components/svg_icon.dart';
import '../../db/app_database.dart';
import '../../theme/tokens.dart';
import 'long_reply_pager.dart';
import 'typewriter_text.dart';

/// AI 对话页（Step 5：流式 + ReAct 工具 + 二次确认）。
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _memory = ShortTermMemory(maxRounds: 20);
  final List<_ChatItem> _items = [];
  bool _sending = false;
  int _ragInjectedCount = 0;
  MemoryInjectionReport? _lastInjection;
  MemoryUpdateResult? _lastMemoryUpdate;
  int _profileFieldCount = 0;
  String _profileName = '';

  @override
  void initState() {
    super.initState();
    _items.add(
      _ChatItem.bubble(
        _Role.assistant,
        '下午好，我是 Buler。\n你已经 3 天没记账了，需要我帮你回忆一下吗？',
      ),
    );
    _loadProfileStatus();
  }

  Future<void> _loadProfileStatus() async {
    final memory = AiService.rag?.memory;
    if (memory == null) return;
    try {
      final p = await memory.userProfile.current();
      if (!mounted) return;
      setState(() {
        _profileName = (p.displayName?.isNotEmpty ?? false)
            ? p.displayName!
            : '';
        _profileFieldCount = _countProfileFields(p);
      });
    } catch (_) {}
  }

  /// 统计画像中已填写的字段数（4 个标量 + 3 个 JSON 列表）。
  int _countProfileFields(UserProfile p) {
    var n = 0;
    if ((p.displayName ?? '').isNotEmpty) n++;
    if ((p.occupation ?? '').isNotEmpty) n++;
    if ((p.location ?? '').isNotEmpty) n++;
    if (p.birthday != null) n++;
    if (_decodeListLen(p.preferencesJson) > 0) n++;
    if (_decodeListLen(p.goalsJson) > 0) n++;
    if (_decodeListLen(p.importantPeopleJson) > 0) n++;
    return n;
  }

  int _decodeListLen(String json) {
    if (json.isEmpty || json == '[]' || json == '{}') return 0;
    try {
      final v = jsonDecode(json);
      if (v is List) return v.length;
      if (v is Map) return v.length;
    } catch (_) {}
    return 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ChatOptions _buildOptions(String? extraSystemPrompt) {
    return ChatOptions(extraSystemPrompt: extraSystemPrompt);
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items.add(_ChatItem.bubble(_Role.user, text));
      _sending = true;
      _controller.clear();
    });
    _scrollToBottom();

    // Step 11：加载跨会话上下文（不阻塞主流程——失败时继续正常 LLM 调用）
    String? crossSessionCtx;
    try {
      crossSessionCtx = await CrossSessionMemory.instance.loadContext();
      if (crossSessionCtx != null && mounted) {
        setState(() {
          _lastInjection = MemoryInjectionReport(
            profileFields: _profileFieldCount,
            ragHits: _lastInjection?.ragHits ?? 0,
            hasWorkingTask:
                AiService.rag?.memory?.working.hasActiveTask ?? false,
            shortTermRounds: _memory.rounds,
            crossSessionChars: crossSessionCtx!.length,
          );
        });
      }
    } catch (_) {
      crossSessionCtx = null;
    }

    _memory.append(
      ChatMessage(
        role: ChatRole.user,
        content: text,
        createdAt: DateTime.now(),
      ),
    );

    // 触发后台抽取（不阻塞主流程）
    _maybeExtractMemories();

    final placeholder = _ChatItem.bubble(_Role.assistant, '');
    placeholder.streaming = true;
    setState(() => _items.add(placeholder));

    String accumulated = '';
    await AiService.instance.streamCompletion(
      memory: _memory,
      callback: (event) {
        if (!mounted) return;
        if (event.error != null) {
          final msg = event.error is AiError
              ? (event.error as AiError).message
              : event.error.toString();
          setState(() {
            placeholder.content = msg;
            placeholder.isError = true;
            placeholder.streaming = false;
            _sending = false;
          });
          return;
        }
        if (event.ragInjectedCount > 0) {
          setState(() {
            _ragInjectedCount = event.ragInjectedCount;
            _lastInjection = MemoryInjectionReport(
              profileFields: _profileFieldCount,
              ragHits: event.ragInjectedCount,
              hasWorkingTask:
                  AiService.rag?.memory?.working.hasActiveTask ?? false,
              shortTermRounds: _memory.rounds,
            );
          });
        }
        if (event.delta.isNotEmpty) {
          accumulated += event.delta;
          setState(() => placeholder.content = accumulated);
          _memory.updateLastAssistantContent(event.delta);
          _scrollToBottom();
        }
        if (event.hasToolCalls) {
          setState(() {
            for (final c in event.toolCalls) {
              _items.add(_ChatItem.toolCall(c));
            }
            _scrollToBottom();
          });
        }
        if (event.hasToolResults) {
          setState(() {
            for (final r in event.toolResults) {
              _items.add(_ChatItem.toolResult(r));
            }
            _scrollToBottom();
          });
        }
        if (event.done) {
          setState(() {
            placeholder.streaming = false;
            _sending = false;
            if (accumulated.isEmpty && !placeholder.isError) {
              placeholder.content = '（无回复）';
            }
          });
          // 处理 pending_confirmation：弹二次确认
          for (final r in event.toolResults) {
            if (r.result.needsConfirmation) {
              _askConfirmation(r, originalArgs: _findCallArgs(r.toolCallId));
            }
          }
        }
      },
      options: _buildOptions(crossSessionCtx),
    );
  }

  Map<String, dynamic> _findCallArgs(String toolCallId) {
    // 倒序找最近一次 tool_call 的 args
    for (var i = _items.length - 1; i >= 0; i--) {
      final it = _items[i];
      if (it.kind == _ItemKind.toolCall && it.toolCall?.id == toolCallId) {
        return it.toolCall!.parsedArgs();
      }
    }
    return const {};
  }

  Future<void> _askConfirmation(
    ToolRunResult r, {
    required Map<String, dynamic> originalArgs,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BulterRadius.l),
        ),
        title: const Text('请确认操作'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Buler 想执行以下操作，是否允许？',
              style: TextStyle(fontSize: BulterFontSize.body),
            ),
            const SizedBox(height: BulterSpacing.m),
            Container(
              padding: const EdgeInsets.all(BulterSpacing.m),
              decoration: BoxDecoration(
                color: BulterColors.canvas,
                borderRadius: BorderRadius.circular(BulterRadius.m),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '工具：${r.toolName}',
                    style: const TextStyle(
                      fontSize: BulterFontSize.footnote,
                      fontWeight: BulterFontWeight.semibold,
                      color: BulterColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: BulterSpacing.s),
                  Text(
                    r.result.confirmationPrompt ?? r.result.summary,
                    style: const TextStyle(
                      fontSize: BulterFontSize.body,
                      color: BulterColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: BulterColors.ctaText,
              backgroundColor: BulterColors.cta,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认执行'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirm == null) return;
    setState(() => _sending = true);
    final placeholder2 = _ChatItem.bubble(_Role.assistant, '');
    placeholder2.streaming = true;
    setState(() => _items.add(placeholder2));
    String acc = '';
    await AiService.instance.resumeAfterConfirmation(
      memory: _memory,
      toolCallId: r.toolCallId,
      toolName: r.toolName,
      originalArgs: originalArgs,
      confirmed: confirm,
      callback: (event) {
        if (!mounted) return;
        if (event.error != null) {
          final msg = event.error is AiError
              ? (event.error as AiError).message
              : event.error.toString();
          setState(() {
            placeholder2.content = msg;
            placeholder2.isError = true;
            placeholder2.streaming = false;
            _sending = false;
          });
          return;
        }
        if (event.delta.isNotEmpty) {
          acc += event.delta;
          setState(() => placeholder2.content = acc);
          _scrollToBottom();
        }
        if (event.hasToolResults) {
          setState(() {
            for (final r in event.toolResults) {
              _items.add(_ChatItem.toolResult(r));
            }
          });
        }
        if (event.done) {
          setState(() {
            placeholder2.streaming = false;
            _sending = false;
            if (acc.isEmpty && !placeholder2.isError) {
              placeholder2.content = '（操作完成）';
            }
          });
        }
      },
      options: _buildOptions(null),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 30), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 后台触发长记忆 / 用户画像抽取。
  void _maybeExtractMemories() {
    final memory = AiService.rag?.memory;
    if (memory == null) return;
    // 异步执行，不 await
    () async {
      try {
        final r = await memory.onUserMessage(_memory);
        if (!mounted) return;
        if (r.hasChanges) {
          setState(() => _lastMemoryUpdate = r);
          // 重新探测画像可用状态
          if (r.profileUpdated > 0) {
            _loadProfileStatus();
          }
        }
      } catch (_) {}
    }();
  }

  void _openModelConfig() {
    Navigator.of(context).pushNamed('/settings/model');
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = ModelRegistry.instance.hasApiKey;
    return Column(
      children: [
        _StatusBar(
          trackedCount: _items.where((i) => i.role == _Role.user).length,
          ragInjectedCount: _ragInjectedCount,
          onConfigure: _openModelConfig,
        ),
        if (_lastInjection != null ||
            _profileFieldCount > 0 ||
            _lastMemoryUpdate != null)
          _MemoryPanel(
            report: _lastInjection,
            updatedCount: _lastMemoryUpdate,
            profileFieldCount: _profileFieldCount,
            profileName: _profileName,
          ),
        Expanded(
          child: _items.isEmpty
              ? const _EmptyChat()
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(
                    BulterSpacing.l,
                    BulterSpacing.l,
                    BulterSpacing.l,
                    BulterSpacing.l,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, i) => _items[i],
                ),
        ),
        if (!hasKey) _NoApiKeyBanner(onTap: _openModelConfig),
        _InputBar(controller: _controller, onSend: _send, enabled: !_sending),
      ],
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BulterSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SvgIcon(
              'chat/chat-bubble-outline.svg',
              size: 56,
              color: BulterColors.textTertiary,
            ),
            SizedBox(height: BulterSpacing.l),
            Text(
              '开始一段对话',
              style: TextStyle(
                fontSize: BulterFontSize.titleS,
                fontWeight: BulterFontWeight.semibold,
                color: BulterColors.textPrimary,
              ),
            ),
            SizedBox(height: BulterSpacing.s),
            Text(
              '可以问"我最近花了多少钱"，\n也可以直接说"今天和小王吃了顿饭"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: BulterFontSize.body,
                color: BulterColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 记忆注入区（Step 7）：可折叠展示本次 LLM 调用注入了哪些记忆。
class _MemoryPanel extends StatefulWidget {
  final MemoryInjectionReport? report;
  final MemoryUpdateResult? updatedCount;
  final int profileFieldCount;
  final String profileName;
  const _MemoryPanel({
    required this.report,
    required this.updatedCount,
    required this.profileFieldCount,
    required this.profileName,
  });

  @override
  State<_MemoryPanel> createState() => _MemoryPanelState();
}

class _MemoryPanelState extends State<_MemoryPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // 没任何信息时整条不显示
    if (widget.report == null &&
        widget.updatedCount == null &&
        widget.profileFieldCount == 0) {
      return const SizedBox.shrink();
    }
    final r = widget.report;
    final u = widget.updatedCount;
    final rag = r?.ragHits ?? 0;
    final rounds = r?.shortTermRounds ?? 0;
    final hasWorking = r?.hasWorkingTask ?? false;
    final fields = widget.profileFieldCount;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BulterSpacing.l,
        vertical: BulterSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(BulterRadius.s),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SvgIcon(
                    'common/sparkles.svg',
                    size: 12,
                    color: BulterColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _summary(rag, rounds, hasWorking, u),
                      style: const TextStyle(
                        fontSize: BulterFontSize.footnote,
                        color: BulterColors.textTertiary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const SvgIcon(
                      'common/expand-more.svg',
                      size: 14,
                      color: BulterColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            _MemoryPanelDetail(
              rag: rag,
              rounds: rounds,
              hasWorking: hasWorking,
              profileFieldCount: fields,
              profileName: widget.profileName,
              update: u,
            ),
        ],
      ),
    );
  }

  String _summary(int rag, int rounds, bool hasWorking, MemoryUpdateResult? u) {
    final parts = <String>[];
    final fields = widget.profileFieldCount;
    if (fields > 0) {
      parts.add('画像 $fields 字段');
    }
    if (rag > 0) {
      parts.add('RAG $rag 条');
    } else {
      parts.add('RAG 0');
    }
    if (hasWorking) parts.add('工作记忆');
    parts.add('短记忆 $rounds 轮');
    if (u != null && u.hasChanges) {
      parts.add('+${u.longTermAdded} 新记忆');
    }
    return parts.join(' · ');
  }
}

class _MemoryPanelDetail extends StatelessWidget {
  final int rag;
  final int rounds;
  final bool hasWorking;
  final int profileFieldCount;
  final String profileName;
  final MemoryUpdateResult? update;
  const _MemoryPanelDetail({
    required this.rag,
    required this.rounds,
    required this.hasWorking,
    required this.profileFieldCount,
    required this.profileName,
    required this.update,
  });

  @override
  Widget build(BuildContext context) {
    final profileLabel = profileFieldCount == 0
        ? '未设置'
        : (profileName.isNotEmpty
              ? '$profileName · $profileFieldCount 字段'
              : '$profileFieldCount 字段');
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.all(BulterSpacing.s),
      decoration: BoxDecoration(
        color: BulterColors.surface,
        borderRadius: BorderRadius.circular(BulterRadius.s),
        border: Border.all(color: BulterColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('common/user.svg', '用户画像', profileLabel),
          _row('common/sparkles.svg', 'RAG 召回', '$rag 条相关记忆'),
          if (hasWorking) _row('common/circle.svg', '工作记忆', '有活跃任务'),
          _row('chat/chat-bubble-outline.svg', '短记忆', '$rounds 轮'),
          if (update != null && update!.hasChanges) ...[
            const SizedBox(height: 4),
            const Divider(height: 0.5, color: BulterColors.divider),
            const SizedBox(height: 4),
            _row(
              'common/plus.svg',
              '本次新记忆',
              '+${update!.longTermAdded} 添加 / ${update!.longTermDeduped} 重复',
            ),
            if (update!.profileUpdated > 0)
              _row('common/user.svg', '画像更新', '${update!.profileUpdated} 个字段'),
          ],
        ],
      ),
    );
  }

  Widget _row(String icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SvgIcon(icon, size: 12, color: BulterColors.textTertiary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: BulterFontSize.footnote,
              color: BulterColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: BulterFontSize.footnote,
              color: BulterColors.textPrimary,
              fontWeight: BulterFontWeight.semibold,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoApiKeyBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _NoApiKeyBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BulterColors.wealth.withValues(alpha: 0.14),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BulterSpacing.l,
            vertical: BulterSpacing.s,
          ),
          child: Row(
            children: [
              const SvgIcon(
                'common/info.svg',
                size: 16,
                color: BulterColors.wealth,
              ),
              const SizedBox(width: BulterSpacing.s),
              const Expanded(
                child: Text(
                  '尚未配置 API Key，点击前往设置',
                  style: TextStyle(
                    fontSize: BulterFontSize.footnote,
                    color: BulterColors.textPrimary,
                  ),
                ),
              ),
              const SvgIcon(
                'common/chevron-right.svg',
                size: 16,
                color: BulterColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Role { user, assistant }

enum _ItemKind { bubble, toolCall, toolResult }

// ignore: must_be_immutable
class _ChatItem extends StatelessWidget {
  _Role role;
  String content;
  bool isError;
  bool streaming;
  _ItemKind kind;
  PendingToolCall? toolCall;
  ToolRunResult? toolResult;

  _ChatItem.bubble(this.role, this.content)
    : isError = false,
      streaming = false,
      kind = _ItemKind.bubble,
      toolCall = null,
      toolResult = null;

  _ChatItem.toolCall(PendingToolCall c)
    : role = _Role.assistant,
      content = '',
      isError = false,
      streaming = false,
      kind = _ItemKind.toolCall,
      toolCall = c,
      toolResult = null;

  _ChatItem.toolResult(ToolRunResult r)
    : role = _Role.assistant,
      content = '',
      isError = false,
      streaming = false,
      kind = _ItemKind.toolResult,
      toolCall = null,
      toolResult = r;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case _ItemKind.bubble:
        if (role == _Role.assistant) {
          return _AssistantBubble(
            content: content,
            streaming: streaming,
            isError: isError,
          );
        }
        return _UserBubble(content: content);
      case _ItemKind.toolCall:
        return _ToolCallCard(call: toolCall!);
      case _ItemKind.toolResult:
        return _ToolResultCard(result: toolResult!);
    }
  }
}

class _UserBubble extends StatelessWidget {
  final String content;
  const _UserBubble({required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BulterSpacing.m),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: BulterSpacing.l,
                vertical: BulterSpacing.m,
              ),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                color: BulterColors.cta,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(BulterRadius.l),
                  topRight: Radius.circular(BulterRadius.l),
                  bottomLeft: Radius.circular(BulterRadius.l),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                content,
                style: const TextStyle(
                  color: BulterColors.ctaText,
                  fontSize: BulterFontSize.body,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final String content;
  final bool streaming;
  final bool isError;
  const _AssistantBubble({
    required this.content,
    required this.streaming,
    required this.isError,
  });

  /// 渲染正文：
  /// - **打字机模式**（streaming=true）：用 [TypewriterText] 逐字显示
  /// - **完成态 + 短文本**（< 2000 字符）：直接 [TypewriterText] streamed=false 显示
  /// - **完成态 + 长文本**（>= 2000 字符）：用 [LongReplyPager] 自动分页
  Widget _renderContent() {
    final style = TextStyle(
      color: isError ? BulterColors.error : BulterColors.textPrimary,
      fontSize: BulterFontSize.body,
      height: 1.45,
    );
    if (streaming) {
      // 流式打字机
      return TypewriterText(
        text: content,
        style: style,
        streamed: true,
        charDelayMs: 30,
      );
    }
    // 完成态：短文本直接展示，长文本自动分页
    if (content.length >= 2000) {
      return LongReplyPager(fullText: content, style: style);
    }
    return TypewriterText(text: content, style: style, streamed: false);
  }

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty && streaming) {
      return const Padding(
        padding: EdgeInsets.only(bottom: BulterSpacing.m),
        child: Row(children: [_TypingDots()]),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: BulterSpacing.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: BulterSpacing.l,
                vertical: BulterSpacing.m,
              ),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                color: isError
                    ? BulterColors.error.withValues(alpha: 0.10)
                    : BulterColors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(BulterRadius.l),
                  topRight: Radius.circular(BulterRadius.l),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(BulterRadius.l),
                ),
                border: isError
                    ? Border.all(
                        color: BulterColors.error.withValues(alpha: 0.4),
                        width: 0.5,
                      )
                    : Border.all(color: BulterColors.divider, width: 0.5),
              ),
              child: _renderContent(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCallCard extends StatelessWidget {
  final PendingToolCall call;
  const _ToolCallCard({required this.call});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BulterSpacing.s),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: BulterSpacing.m,
                vertical: BulterSpacing.s,
              ),
              decoration: BoxDecoration(
                color: BulterColors.canvas,
                borderRadius: BorderRadius.circular(BulterRadius.m),
                border: Border.all(color: BulterColors.divider, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SvgIcon(
                    'common/tune.svg',
                    size: 14,
                    color: BulterColors.textSecondary,
                  ),
                  const SizedBox(width: BulterSpacing.s),
                  Text(
                    '调用 ${call.name}',
                    style: const TextStyle(
                      fontSize: BulterFontSize.footnote,
                      color: BulterColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolResultCard extends StatelessWidget {
  final ToolRunResult result;
  const _ToolResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result.result;
    // Step 8：invoke_sub_agent 工具的特殊卡片（显示子 Agent 标识 + 耗时 + 工具）
    if (result.toolName == 'invoke_sub_agent') {
      return _SubAgentResultCard(result: result);
    }

    final isErr = r.status == 'error';
    final needsConfirm = r.needsConfirmation;
    final iconName = isErr
        ? 'common/error.svg'
        : needsConfirm
        ? 'common/info.svg'
        : 'common/check.svg';
    final color = isErr
        ? BulterColors.error
        : needsConfirm
        ? BulterColors.wealth
        : BulterColors.success;
    return Padding(
      padding: const EdgeInsets.only(bottom: BulterSpacing.s),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: BulterSpacing.m,
                vertical: BulterSpacing.s,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(BulterRadius.m),
                border: Border.all(
                  color: color.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgIcon(iconName, size: 14, color: color),
                  const SizedBox(width: BulterSpacing.s),
                  Flexible(
                    child: Text(
                      r.summary,
                      style: TextStyle(
                        fontSize: BulterFontSize.footnote,
                        color: BulterColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `invoke_sub_agent` 工具结果专用卡：粉色边 + 调度链路头部。
///
/// 显示：模块名（displayName）+ 状态徽标 + 子 Agent 返回的简短摘要 + 耗时 + 调用过的工具。
class _SubAgentResultCard extends StatelessWidget {
  final ToolRunResult result;
  const _SubAgentResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result.result;
    final data = r.data;
    final ok = data['ok'] == true;
    final moduleName = (data['module_name'] as String?) ?? '子模型';
    final elapsedMs = (data['elapsed_ms'] as int?) ?? 0;
    final toolsList =
        (data['tools_used'] as List?)?.cast<String>() ?? const <String>[];
    final color = ok ? BulterColors.relationship : BulterColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: BulterSpacing.s),
      child: Container(
        padding: const EdgeInsets.all(BulterSpacing.m),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(BulterRadius.m),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 0.6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BulterSpacing.s + 2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(BulterRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SvgIcon(
                        'common/users.svg',
                        size: 12,
                        color: BulterColors.ctaText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        moduleName,
                        style: const TextStyle(
                          fontSize: BulterFontSize.caption,
                          color: BulterColors.ctaText,
                          fontWeight: BulterFontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: BulterSpacing.s),
                Text(
                  ok ? '调度成功' : '降级',
                  style: TextStyle(
                    fontSize: BulterFontSize.caption,
                    color: color,
                    fontWeight: BulterFontWeight.semibold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${elapsedMs}ms',
                  style: const TextStyle(
                    fontSize: BulterFontSize.caption,
                    color: BulterColors.textTertiary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: BulterSpacing.s),
            Text(
              r.summary,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: BulterFontSize.footnote,
                color: BulterColors.textPrimary,
                height: 1.45,
              ),
            ),
            if (toolsList.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final t in toolsList)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: BulterColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(
                          fontSize: BulterFontSize.caption,
                          color: BulterColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BulterSpacing.l,
            vertical: BulterSpacing.m,
          ),
          decoration: BoxDecoration(
            color: BulterColors.surface,
            borderRadius: BorderRadius.circular(BulterRadius.l),
            border: Border.all(color: BulterColors.divider, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = ((_ctl.value + i / 3) % 1.0);
              final scale =
                  0.7 + 0.3 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: BulterColors.textTertiary.withValues(
                      alpha: 0.4 + 0.5 * scale,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _StatusBar extends StatelessWidget {
  final int trackedCount;
  final int ragInjectedCount;
  final VoidCallback onConfigure;
  const _StatusBar({
    required this.trackedCount,
    required this.ragInjectedCount,
    required this.onConfigure,
  });

  @override
  Widget build(BuildContext context) {
    final hasKey = ModelRegistry.instance.hasApiKey;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: BulterSpacing.l,
        vertical: BulterSpacing.s,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: hasKey ? BulterColors.success : BulterColors.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: BulterSpacing.s),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    hasKey ? '在线 · $trackedCount 件事已被追踪' : '未配置 API Key · 点击设置',
                    style: TextStyle(
                      fontSize: BulterFontSize.footnote,
                      color: hasKey
                          ? BulterColors.textSecondary
                          : BulterColors.wealth,
                      fontWeight: hasKey
                          ? BulterFontWeight.regular
                          : BulterFontWeight.semibold,
                    ),
                  ),
                ),
                if (ragInjectedCount > 0) ...[
                  const SizedBox(width: BulterSpacing.s),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: BulterColors.growth.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'RAG +$ragInjectedCount',
                      style: const TextStyle(
                        fontSize: BulterFontSize.footnote,
                        color: BulterColors.growth,
                        fontWeight: BulterFontWeight.semibold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Material(
            color: BulterColors.surface,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onConfigure,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: Center(
                  child: SvgIcon(
                    'common/tune.svg',
                    size: 14,
                    color: BulterColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        BulterSpacing.l,
        BulterSpacing.s,
        BulterSpacing.l,
        BulterSpacing.l,
      ),
      decoration: const BoxDecoration(
        color: BulterColors.surface,
        border: Border(
          top: BorderSide(color: BulterColors.divider, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: BulterSpacing.l,
                ),
                decoration: BoxDecoration(
                  color: BulterColors.canvas,
                  borderRadius: BorderRadius.circular(BulterRadius.pill),
                  border: Border.all(color: BulterColors.divider, width: 0.5),
                ),
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    if (enabled) onSend();
                  },
                  decoration: const InputDecoration(
                    hintText: '说点什么…',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: BulterSpacing.s),
            Material(
              color: enabled ? BulterColors.cta : BulterColors.textTertiary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: enabled ? onSend : null,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: SvgIcon(
                      'common/arrow-up.svg',
                      size: 20,
                      color: BulterColors.ctaText,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
