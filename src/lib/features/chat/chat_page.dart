import 'package:flutter/material.dart';

import '../../components/empty_state.dart';
import '../../theme/tokens.dart';

/// AI 对话页（Step 1 占位，Step 4 实现流式 + 工具调用）
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      role: _Role.assistant,
      content: '你好，我是 Bulter 助理。告诉我今天发生的事，我帮你记录和整理。',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(role: _Role.user, content: text));
      // Step 1 占位回复，Step 4 替换为真实 LLM 流式输出
      _messages.add(_ChatMessage(
        role: _Role.assistant,
        content: '（Step 1 占位）已收到：$text\n真实 AI 对话将在 Step 4 接入。',
      ));
      _controller.clear();
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const EmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: '开始一段对话',
                  hint: '可以问"我最近花了多少钱"，也可以直接说"今天和小王吃了顿饭"',
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(
                    BulterSpacing.l,
                    BulterSpacing.l,
                    BulterSpacing.l,
                    BulterSpacing.l,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) => _Bubble(message: _messages[i]),
                ),
        ),
        _InputBar(
          controller: _controller,
          onSend: _send,
          onMic: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('语音输入将在 Step 11 接入')),
            );
          },
        ),
      ],
    );
  }
}

enum _Role { user, assistant }

class _ChatMessage {
  final _Role role;
  final String content;
  _ChatMessage({required this.role, required this.content});
}

class _Bubble extends StatelessWidget {
  final _ChatMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _Role.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: BulterSpacing.m),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: BulterColors.cta,
                borderRadius: BorderRadius.circular(BulterRadius.s),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 16,
                color: BulterColors.ctaText,
              ),
            ),
          if (!isUser) const SizedBox(width: BulterSpacing.s),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: BulterSpacing.l,
                vertical: BulterSpacing.m,
              ),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                color: isUser ? BulterColors.cta : BulterColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(BulterRadius.l),
                  topRight: const Radius.circular(BulterRadius.l),
                  bottomLeft: Radius.circular(isUser ? BulterRadius.l : 4),
                  bottomRight: Radius.circular(isUser ? 4 : BulterRadius.l),
                ),
                border: isUser
                    ? null
                    : Border.all(color: BulterColors.divider, width: 0.5),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isUser
                      ? BulterColors.ctaText
                      : BulterColors.textPrimary,
                  fontSize: BulterFontSize.body,
                  height: 1.45,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: BulterSpacing.s),
          if (isUser)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: BulterColors.butler,
                borderRadius: BorderRadius.circular(BulterRadius.s),
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 16,
                color: BulterColors.ctaText,
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
  final VoidCallback onMic;
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onMic,
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
            Material(
              color: BulterColors.surfaceMuted,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onLongPress: onMic,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.mic_none_rounded,
                    color: BulterColors.textPrimary,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: BulterSpacing.s),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: BulterSpacing.l),
                decoration: BoxDecoration(
                  color: BulterColors.canvas,
                  borderRadius: BorderRadius.circular(BulterRadius.pill),
                  border: Border.all(color: BulterColors.divider, width: 0.5),
                ),
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
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
              color: BulterColors.cta,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onSend,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: BulterColors.ctaText,
                    size: 20,
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
