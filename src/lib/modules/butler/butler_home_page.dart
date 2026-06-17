import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../features/relationship/relationship_home_page.dart';
import '../../features/growth/growth_home_page.dart';
import '../../features/wealth/wealth_home_page.dart';
import '../../features/thought/thought_home_page.dart';
import '../../features/health/health_home_page.dart';

/// Butler 中枢主页（原型：phone-01-home.png）。
///
/// 布局：
///   1) 顶部问候
///   2) 橙色 Butler · 今日 AI 洞察大卡 + 2 个小状态胶囊
///   3) 5 张全宽模块快览卡（关系 / 成长 / 财富 / 思想 / 健康）
class ButlerHomePage extends StatelessWidget {
  const ButlerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
            BulterSpacing.l,
            BulterSpacing.l,
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
          sliver: SliverToBoxAdapter(child: _ButlerInsight()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            BulterSpacing.l,
            0,
            BulterSpacing.l,
            BulterSpacing.huge,
          ),
          sliver: SliverList.list(
            children: const [
              SizedBox(height: BulterSpacing.m),
              _ModuleCard(
                moduleName: '关系',
                brandColor: BulterColors.relationship,
                icon: Icons.favorite_rounded,
                subtitle: '让关系网被看见',
                headline: '李华、妈妈、王老师是你的核心 3 人',
                chips: [_ChipData('待联系', '2 位'), _ChipData('人情', '1 笔未还')],
                onTap: _openRelationship,
              ),
              SizedBox(height: BulterSpacing.m),
              _ModuleCard(
                moduleName: '成长',
                brandColor: BulterColors.growth,
                icon: Icons.trending_up_rounded,
                subtitle: '把模糊的愿望变成可追踪的目标',
                headline: 'OKR 收尾期：完成《Kotlin 协程》读书',
                chips: [_ChipData('OKR 进度', '50%'), _ChipData('进行中', '3 项')],
                onTap: _openGrowth,
              ),
              SizedBox(height: BulterSpacing.m),
              _ModuleCard(
                moduleName: '财富',
                brandColor: BulterColors.wealth,
                icon: Icons.account_balance_wallet_rounded,
                subtitle: '知道钱去哪里',
                headline: '本月餐饮支出已超预算 ¥120',
                chips: [_ChipData('余额', '¥4,820'), _ChipData('预算剩余', '¥680')],
                onTap: _openWealth,
              ),
              SizedBox(height: BulterSpacing.m),
              _ModuleCard(
                moduleName: '思想',
                brandColor: BulterColors.thought,
                icon: Icons.menu_book_rounded,
                subtitle: '把灵感沉淀为可回看的笔记',
                headline: '《置身事内》读后感完成',
                chips: [_ChipData('想法', '5 条'), _ChipData('信件', '2 封')],
                onTap: _openThought,
              ),
              SizedBox(height: BulterSpacing.m),
              _ModuleCard(
                moduleName: '健康',
                brandColor: BulterColors.health,
                icon: Icons.favorite_outline_rounded,
                subtitle: '身体是其他一切的基础',
                headline: '日均睡眠 7.2h，体脂 22.1%',
                chips: [_ChipData('记录', '14 次'), _ChipData('睡眠均值', '8.0h')],
                onTap: _openHealth,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static void _openRelationship(BuildContext context) =>
      _navigate(context, const RelationshipHomePage());
  static void _openGrowth(BuildContext context) =>
      _navigate(context, const GrowthHomePage());
  static void _openWealth(BuildContext context) =>
      _navigate(context, const WealthHomePage());
  static void _openThought(BuildContext context) =>
      _navigate(context, const ThoughtHomePage());
  static void _openHealth(BuildContext context) =>
      _navigate(context, const HealthHomePage());

  static void _navigate(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
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
            height: 1.4,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          '下午好，小明',
          style: TextStyle(
            fontSize: BulterFontSize.displayS,
            fontWeight: BulterFontWeight.bold,
            color: BulterColors.textPrimary,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '今天 3 件事待已入栈，4 件事待呈',
          style: TextStyle(
            fontSize: BulterFontSize.footnote,
            color: BulterColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ButlerInsight extends StatelessWidget {
  const _ButlerInsight();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BulterSpacing.xl),
      decoration: BoxDecoration(
        color: BulterColors.butler.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(BulterRadius.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI 助理',
            style: TextStyle(
              fontSize: BulterFontSize.caption,
              fontWeight: BulterFontWeight.semibold,
              color: BulterColors.butler,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: BulterSpacing.s),
          const Text(
            'Butler · 今日',
            style: TextStyle(
              fontSize: BulterFontSize.titleM,
              fontWeight: BulterFontWeight.bold,
              color: BulterColors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: BulterSpacing.s),
          const Text(
            '今天有 3 件事无法被你来决定。\n已为已规划的时间段。',
            style: TextStyle(
              fontSize: BulterFontSize.body,
              color: BulterColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: BulterSpacing.l),
          Row(
            children: const [
              _ButlerPill(label: '2 个待呈'),
              SizedBox(width: BulterSpacing.s),
              _ButlerPill(label: '1 个待人'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ButlerPill extends StatelessWidget {
  final String label;
  const _ButlerPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BulterSpacing.m,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: BulterColors.surface,
        borderRadius: BorderRadius.circular(BulterRadius.pill),
        border: Border.all(
          color: BulterColors.butler.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: BulterFontSize.footnote,
          fontWeight: BulterFontWeight.semibold,
          color: BulterColors.textPrimary,
        ),
      ),
    );
  }
}

class _ChipData {
  final String label;
  final String value;
  const _ChipData(this.label, this.value);
}

class _ModuleCard extends StatelessWidget {
  final String moduleName;
  final Color brandColor;
  final IconData icon;
  final String subtitle;
  final String headline;
  final List<_ChipData> chips;
  final ValueChanged<BuildContext> onTap;

  const _ModuleCard({
    required this.moduleName,
    required this.brandColor,
    required this.icon,
    required this.subtitle,
    required this.headline,
    required this.chips,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(BulterRadius.xxl),
        onTap: () => onTap(context),
        child: Container(
          padding: const EdgeInsets.all(BulterSpacing.xl),
          decoration: BoxDecoration(
            color: brandColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(BulterRadius.xxl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: BulterSpacing.s + 2,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: brandColor,
                      borderRadius: BorderRadius.circular(BulterRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: BulterColors.ctaText, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          moduleName,
                          style: const TextStyle(
                            color: BulterColors.ctaText,
                            fontSize: BulterFontSize.caption,
                            fontWeight: BulterFontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: brandColor,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: BulterSpacing.m),
              Text(
                headline,
                style: const TextStyle(
                  fontSize: BulterFontSize.bodyLg,
                  fontWeight: BulterFontWeight.semibold,
                  color: BulterColors.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: BulterFontSize.footnote,
                  color: BulterColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: BulterSpacing.m),
                Wrap(
                  spacing: BulterSpacing.s,
                  runSpacing: BulterSpacing.s,
                  children: [for (final c in chips) _ModulePill(data: c)],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModulePill extends StatelessWidget {
  final _ChipData data;
  const _ModulePill({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BulterSpacing.m,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: BulterColors.surface,
        borderRadius: BorderRadius.circular(BulterRadius.pill),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${data.label} ',
              style: const TextStyle(
                fontSize: BulterFontSize.footnote,
                color: BulterColors.textSecondary,
              ),
            ),
            TextSpan(
              text: data.value,
              style: const TextStyle(
                fontSize: BulterFontSize.footnote,
                fontWeight: BulterFontWeight.bold,
                color: BulterColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
