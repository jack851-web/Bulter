import 'package:flutter/material.dart';

import '../../components/empty_state.dart';
import '../../theme/tokens.dart';

/// AI 对话页（原型：phone-02-ai-chat.png）。
///
/// 布局（自上而下）：
///   1) 顶部状态条：在线 · 3 件事已被追踪
///   2) 消息流（AI 左侧浅色泡 / 用户右侧纯黑泡）
///   3) 黑色 CTA 胶囊按钮 "先点下今天收支持页"
///   4) 3 张数据卡（总支出 / 餐饮 / 预算剩余）
///   5) AI 概览卡（带橙底"查看详情 →"链接）
///   6) 底部输入区（单行输入 + 圆形黑色发送）
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatItem> _items = [
    _ChatItem.bubble(_Role.assistant, '下午好，小明。\n我用把今天的 3 件事整理好了。'),
    _CtaPillItem(label: '先点下今天收支持页'),
    _StatCardsItem(
      cards: [
        _StatCard(label: '总支出', value: '¥4,820', trend: ''),
        _StatCard(label: '餐饮', value: '↑18%', trend: '超预算'),
        _StatCard(label: '预算剩余', value: '¥680', trend: ''),
      ],
    ),
    _OverviewItem(
      description: '餐饮支出比上月多 18%，\n建议食堂外卖频次（12 次/月）',
      action: '查看详情',
    ),
    _ChatItem.bubble(_Role.user, '我今天中午吃了顿烧烤'),
    _ChatItem.bubble(_Role.assistant, '记下了：8 月 7 日午餐 烧烤 ¥120。\n已记入【财富】模块。'),
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
      _items.add(_ChatItem.bubble(_Role.user, text));
      // Step 4 替换为真实 LLM 流式输出
      _items.add(
        _ChatItem.bubble(
          _Role.assistant,
          '（占位回复）已收到：$text\n真实 AI 对话将在 Step 4 接入。',
        ),
      );
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
        const _StatusBar(),
        Expanded(
          child: _items.isEmpty
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
                  itemCount: _items.length,
                  itemBuilder: (context, i) => _buildItem(_items[i]),
                ),
        ),
        _InputBar(controller: _controller, onSend: _send),
      ],
    );
  }

  Widget _buildItem(_ChatItem item) {
    if (item is _BubbleItem) {
      return _Bubble(message: item.message);
    }
    if (item is _CtaPillItem) {
      return _CtaPill(label: item.label);
    }
    if (item is _StatCardsItem) {
      return _StatCards(cards: item.cards);
    }
    if (item is _OverviewItem) {
      return _OverviewCard(description: item.description, action: item.action);
    }
    return const SizedBox.shrink();
  }
}

enum _Role { user, assistant }

class _ChatItem {
  const _ChatItem();
  factory _ChatItem.bubble(_Role role, String content) = _BubbleItem.fromValues;
}

class _BubbleItem extends _ChatItem {
  final _ChatMessage message;
  _BubbleItem(this.message);
  factory _BubbleItem.fromValues(_Role role, String content) =>
      _BubbleItem(_ChatMessage(role: role, content: content));
}

class _CtaPillItem extends _ChatItem {
  final String label;
  const _CtaPillItem({required this.label});
}

class _StatCard {
  final String label;
  final String value;
  final String trend;
  const _StatCard({
    required this.label,
    required this.value,
    required this.trend,
  });
}

class _StatCardsItem extends _ChatItem {
  final List<_StatCard> cards;
  const _StatCardsItem({required this.cards});
}

class _OverviewItem extends _ChatItem {
  final String description;
  final String action;
  const _OverviewItem({required this.description, required this.action});
}

class _ChatMessage {
  final _Role role;
  final String content;
  _ChatMessage({required this.role, required this.content});
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
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
            decoration: const BoxDecoration(
              color: BulterColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: BulterSpacing.s),
          const Text(
            '在线 · 3 件事已被追踪',
            style: TextStyle(
              fontSize: BulterFontSize.footnote,
              color: BulterColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
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
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
        ],
      ),
    );
  }
}

class _CtaPill extends StatelessWidget {
  final String label;
  const _CtaPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BulterSpacing.l),
      child: Align(
        alignment: Alignment.center,
        child: Material(
          color: BulterColors.cta,
          borderRadius: BorderRadius.circular(BulterRadius.pill),
          child: InkWell(
            borderRadius: BorderRadius.circular(BulterRadius.pill),
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: BulterSpacing.xl,
                vertical: BulterSpacing.m,
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: BulterColors.ctaText,
                  fontSize: BulterFontSize.body,
                  fontWeight: BulterFontWeight.semibold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCards extends StatelessWidget {
  final List<_StatCard> cards;
  const _StatCards({required this.cards});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BulterSpacing.l),
      child: Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            Expanded(child: _StatCardView(card: cards[i])),
            if (i != cards.length - 1) const SizedBox(width: BulterSpacing.s),
          ],
        ],
      ),
    );
  }
}

class _StatCardView extends StatelessWidget {
  final _StatCard card;
  const _StatCardView({required this.card});

  @override
  Widget build(BuildContext context) {
    final isWarning = card.trend == '超预算';
    return Container(
      padding: const EdgeInsets.all(BulterSpacing.m),
      decoration: BoxDecoration(
        color: BulterColors.surface,
        borderRadius: BorderRadius.circular(BulterRadius.l),
        border: Border.all(color: BulterColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.label,
            style: const TextStyle(
              fontSize: BulterFontSize.caption,
              color: BulterColors.textSecondary,
            ),
          ),
          const SizedBox(height: BulterSpacing.xs + 2),
          Text(
            card.value,
            style: TextStyle(
              fontSize: BulterFontSize.titleS,
              fontWeight: BulterFontWeight.bold,
              color: isWarning ? BulterColors.wealth : BulterColors.textPrimary,
            ),
          ),
          if (card.trend.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              card.trend,
              style: const TextStyle(
                fontSize: BulterFontSize.caption,
                color: BulterColors.wealth,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String description;
  final String action;
  const _OverviewCard({required this.description, required this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BulterSpacing.l),
      child: Container(
        padding: const EdgeInsets.all(BulterSpacing.l),
        decoration: BoxDecoration(
          color: BulterColors.surface,
          borderRadius: BorderRadius.circular(BulterRadius.l),
          border: Border.all(color: BulterColors.divider, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '本月支出概览',
              style: TextStyle(
                fontSize: BulterFontSize.body,
                fontWeight: BulterFontWeight.semibold,
                color: BulterColors.textPrimary,
              ),
            ),
            const SizedBox(height: BulterSpacing.s),
            Text(
              description,
              style: const TextStyle(
                fontSize: BulterFontSize.footnote,
                color: BulterColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: BulterSpacing.m),
            Material(
              color: BulterColors.wealth,
              borderRadius: BorderRadius.circular(BulterRadius.pill),
              child: InkWell(
                borderRadius: BorderRadius.circular(BulterRadius.pill),
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BulterSpacing.l,
                    vertical: BulterSpacing.s,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        action,
                        style: const TextStyle(
                          color: BulterColors.ctaText,
                          fontSize: BulterFontSize.footnote,
                          fontWeight: BulterFontWeight.semibold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: BulterColors.ctaText,
                        size: 14,
                      ),
                    ],
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

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.onSend});

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
