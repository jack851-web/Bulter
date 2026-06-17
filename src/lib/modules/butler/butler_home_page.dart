import 'package:flutter/material.dart';

import '../../components/ai_insight_card.dart';
import '../../components/empty_state.dart';
import '../../components/module_card.dart';
import '../../theme/tokens.dart';

/// Butler 中枢主页：5 卡 Bento 布局。
///
/// 布局：
///   1) AI 洞察大卡（顶部跨满宽）
///   2) 4 张模块快览卡（2×2 网格）
class ButlerHomePage extends StatelessWidget {
  const ButlerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: BulterSpacing.s)),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
            BulterSpacing.l,
            BulterSpacing.s,
            BulterSpacing.l,
            BulterSpacing.s,
          ),
          sliver: SliverToBoxAdapter(child: _Greeting()),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
            BulterSpacing.l,
            BulterSpacing.s,
            BulterSpacing.l,
            BulterSpacing.l,
          ),
          sliver: SliverToBoxAdapter(
            child: AiInsightCard(
              headline: '本周你的健康分上升 3 分，预算执行率 78%',
              body: '财富模块提醒：本月餐饮支出已超预算 ¥120，建议适当控制。'
                  '成长模块有个 OKR 进入收尾期，可安排回顾。',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            BulterSpacing.l,
            0,
            BulterSpacing.l,
            BulterSpacing.l,
          ),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: BulterSpacing.m,
            crossAxisSpacing: BulterSpacing.m,
            childAspectRatio: 0.95,
            children: const [
              ModuleCard(
                title: '王老师答应介绍算法工程师',
                subtitle: '关系 · 3 天前',
                brandColor: BulterColors.relationship,
                icon: Icons.favorite_rounded,
                badge: '新',
              ),
              ModuleCard(
                title: '本月餐饮超预算 ¥120',
                subtitle: '财富 · 6 小时前',
                brandColor: BulterColors.wealth,
                icon: Icons.account_balance_wallet_rounded,
                badge: '!',
              ),
              ModuleCard(
                title: '《置身事内》读后感完成',
                subtitle: '思想 · 昨天',
                brandColor: BulterColors.thought,
                icon: Icons.menu_book_rounded,
              ),
              ModuleCard(
                title: '体脂率 22.1% · 较上月 -0.8',
                subtitle: '健康 · 今天',
                brandColor: BulterColors.health,
                icon: Icons.favorite_outline_rounded,
                badge: '↑',
              ),
            ],
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
            BulterSpacing.l,
            0,
            BulterSpacing.l,
            BulterSpacing.l,
          ),
          sliver: SliverToBoxAdapter(child: _QuickActions()),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
            BulterSpacing.l,
            0,
            BulterSpacing.l,
            BulterSpacing.huge,
          ),
          sliver: SliverToBoxAdapter(child: _RecentTimeline()),
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 6
        ? '凌晨好'
        : hour < 11
            ? '早上好'
            : hour < 13
                ? '中午好'
                : hour < 18
                    ? '下午好'
                    : hour < 22
                        ? '晚上好'
                        : '夜深了';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting，',
          style: const TextStyle(
            fontSize: BulterFontSize.body,
            color: BulterColors.textSecondary,
          ),
        ),
        const SizedBox(height: BulterSpacing.xxs),
        const Text(
          '今天想做点什么？',
          style: TextStyle(
            fontSize: BulterFontSize.displayS,
            fontWeight: BulterFontWeight.bold,
            color: BulterColors.textPrimary,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '快捷操作',
          style: TextStyle(
            fontSize: BulterFontSize.titleS,
            fontWeight: BulterFontWeight.semibold,
            color: BulterColors.textPrimary,
          ),
        ),
        const SizedBox(height: BulterSpacing.m),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.add_rounded,
                label: '记一笔',
                color: BulterColors.wealth,
                onTap: () {},
              ),
            ),
            const SizedBox(width: BulterSpacing.m),
            Expanded(
              child: _ActionTile(
                icon: Icons.chat_bubble_outline_rounded,
                label: '问 AI',
                color: BulterColors.cta,
                onTap: () {},
              ),
            ),
            const SizedBox(width: BulterSpacing.m),
            Expanded(
              child: _ActionTile(
                icon: Icons.crop_square_rounded,
                label: '长按截图',
                color: BulterColors.butler,
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(BulterRadius.l),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: BulterSpacing.l,
            horizontal: BulterSpacing.s,
          ),
          decoration: BoxDecoration(
            color: BulterColors.surface,
            borderRadius: BorderRadius.circular(BulterRadius.l),
            border: Border.all(color: BulterColors.divider, width: 0.5),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(BulterRadius.m),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: BulterSpacing.s),
              Text(
                label,
                style: const TextStyle(
                  fontSize: BulterFontSize.footnote,
                  color: BulterColors.textPrimary,
                  fontWeight: BulterFontWeight.medium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTimeline extends StatelessWidget {
  const _RecentTimeline();

  @override
  Widget build(BuildContext context) {
    final items = [
      _TimelineItem(
        color: BulterColors.wealth,
        icon: Icons.account_balance_wallet_rounded,
        title: '记录了一笔支出',
        subtitle: '午餐 · 美式 · ¥38',
        time: '2 小时前',
      ),
      _TimelineItem(
        color: BulterColors.thought,
        icon: Icons.menu_book_rounded,
        title: '完成读后感',
        subtitle: '《置身事内》— 中国政府与经济发展',
        time: '昨天',
      ),
      _TimelineItem(
        color: BulterColors.health,
        icon: Icons.favorite_outline_rounded,
        title: '记录体重',
        subtitle: '68.2 kg · 体脂 22.1%',
        time: '昨天',
      ),
      _TimelineItem(
        color: BulterColors.relationship,
        icon: Icons.favorite_rounded,
        title: '给妈妈打了电话',
        subtitle: '通话 18 分钟',
        time: '前天',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '最近',
          style: TextStyle(
            fontSize: BulterFontSize.titleS,
            fontWeight: BulterFontWeight.semibold,
            color: BulterColors.textPrimary,
          ),
        ),
        const SizedBox(height: BulterSpacing.m),
        ...items.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: BulterSpacing.s),
              child: _TimelineRow(item: e),
            )),
        if (items.isEmpty)
          const EmptyState(
            icon: Icons.timeline_rounded,
            title: '还没有活动',
            hint: '从对话或手动录入开始，AI 会自动汇总到时间线',
          ),
      ],
    );
  }
}

class _TimelineItem {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  const _TimelineItem({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}

class _TimelineRow extends StatelessWidget {
  final _TimelineItem item;
  const _TimelineRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BulterSpacing.m),
      decoration: BoxDecoration(
        color: BulterColors.surface,
        borderRadius: BorderRadius.circular(BulterRadius.l),
        border: Border.all(color: BulterColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(BulterRadius.s),
            ),
            child: Icon(item.icon, size: 16, color: item.color),
          ),
          const SizedBox(width: BulterSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: BulterFontSize.body,
                    fontWeight: BulterFontWeight.semibold,
                    color: BulterColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: BulterFontSize.footnote,
                    color: BulterColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: BulterSpacing.s),
          Text(
            item.time,
            style: const TextStyle(
              fontSize: BulterFontSize.caption,
              color: BulterColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
