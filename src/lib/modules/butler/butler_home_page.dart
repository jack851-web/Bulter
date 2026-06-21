import 'package:flutter/material.dart';

import '../../ai/briefing/briefing_models.dart';
import '../../ai/briefing/briefing_store.dart';
import '../../components/svg_icon.dart';
import '../../theme/tokens.dart';
import '../../features/relationship/relationship_home_page.dart';
import '../../features/growth/growth_home_page.dart';
import '../../features/wealth/wealth_home_page.dart';
import '../../features/thought/thought_home_page.dart';
import '../../features/health/health_home_page.dart';
import '../../modules/bulter_module.dart';

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
            children: [
              const SizedBox(height: BulterSpacing.m),
              _BriefingModuleCard(
                moduleId: ModuleId.relationship,
                moduleName: '关系',
                brandColor: BulterColors.relationship,
                icon: 'modules/relationship.svg',
                fallbackHeadline: '李华、妈妈、王老师是你的核心 3 人',
                fallbackSubtitle: '让关系网被看见',
                fallbackChips: const [
                  _ChipData('待联系', '2 位'),
                  _ChipData('人情', '1 笔未还'),
                ],
                onTap: _openRelationship,
              ),
              const SizedBox(height: BulterSpacing.m),
              _BriefingModuleCard(
                moduleId: ModuleId.growth,
                moduleName: '成长',
                brandColor: BulterColors.growth,
                icon: 'modules/growth.svg',
                fallbackHeadline: 'OKR 收尾期：完成《Kotlin 协程》读书',
                fallbackSubtitle: '把模糊的愿望变成可追踪的目标',
                fallbackChips: const [
                  _ChipData('OKR 进度', '50%'),
                  _ChipData('进行中', '3 项'),
                ],
                onTap: _openGrowth,
              ),
              const SizedBox(height: BulterSpacing.m),
              _BriefingModuleCard(
                moduleId: ModuleId.wealth,
                moduleName: '财富',
                brandColor: BulterColors.wealth,
                icon: 'modules/wealth.svg',
                fallbackHeadline: '本月餐饮支出已超预算 ¥120',
                fallbackSubtitle: '知道钱去哪里',
                fallbackChips: const [
                  _ChipData('余额', '¥4,820'),
                  _ChipData('预算剩余', '¥680'),
                ],
                onTap: _openWealth,
              ),
              const SizedBox(height: BulterSpacing.m),
              _BriefingModuleCard(
                moduleId: ModuleId.thought,
                moduleName: '思想',
                brandColor: BulterColors.thought,
                icon: 'modules/thought.svg',
                fallbackHeadline: '《置身事内》读后感完成',
                fallbackSubtitle: '把灵感沉淀为可回看的笔记',
                fallbackChips: const [
                  _ChipData('想法', '5 条'),
                  _ChipData('信件', '2 封'),
                ],
                onTap: _openThought,
              ),
              const SizedBox(height: BulterSpacing.m),
              _BriefingModuleCard(
                moduleId: ModuleId.health,
                moduleName: '健康',
                brandColor: BulterColors.health,
                icon: 'modules/health.svg',
                fallbackHeadline: '日均睡眠 7.2h，体脂 22.1%',
                fallbackSubtitle: '身体是其他一切的基础',
                fallbackChips: const [
                  _ChipData('记录', '14 次'),
                  _ChipData('睡眠均值', '8.0h'),
                ],
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
          '$greeting，小明',
          style: const TextStyle(
            fontSize: BulterFontSize.displayS,
            fontWeight: BulterFontWeight.bold,
            color: BulterColors.textPrimary,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        ValueListenableBuilder<ModuleBriefing?>(
          valueListenable: BriefingStore.instance.watchBriefing(
            ModuleId.butler,
          ),
          builder: (_, b, __) {
            final hint = b?.summary.isNotEmpty == true
                ? b!.summary.replaceAll('\n', ' · ')
                : '正在为你汇总今日简报…';
            return Text(
              hint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: BulterFontSize.footnote,
                color: BulterColors.textSecondary,
                height: 1.4,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ButlerInsight extends StatelessWidget {
  const _ButlerInsight();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ModuleBriefing?>(
      valueListenable: BriefingStore.instance.watchBriefing(ModuleId.butler),
      builder: (_, b, __) {
        final headline = b?.headline ?? '今天有 0 件无法决定';
        final summary = b?.summary ?? '正在汇总今日简报…';
        final chips = b?.chips ?? const <BriefingChip>[];
        final stale = b?.isStale() ?? true;
        return Container(
          padding: const EdgeInsets.all(BulterSpacing.xl),
          decoration: BoxDecoration(
            color: BulterColors.butler.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(BulterRadius.xxl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  const Spacer(),
                  if (b != null)
                    Text(
                      stale
                          ? '过期 · ${b.freshnessLabel()}'
                          : '更新于 ${b.freshnessLabel()}',
                      style: const TextStyle(
                        fontSize: BulterFontSize.caption,
                        color: BulterColors.textTertiary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: BulterSpacing.s),
              Text(
                headline,
                style: const TextStyle(
                  fontSize: BulterFontSize.titleM,
                  fontWeight: BulterFontWeight.bold,
                  color: BulterColors.textPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: BulterSpacing.s),
              Text(
                summary,
                style: const TextStyle(
                  fontSize: BulterFontSize.body,
                  color: BulterColors.textSecondary,
                  height: 1.5,
                ),
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: BulterSpacing.l),
                Wrap(
                  spacing: BulterSpacing.s,
                  runSpacing: BulterSpacing.s,
                  children: [
                    for (final c in chips.take(4))
                      _ButlerPill(label: '${c.label} ${c.value}'),
                  ],
                ),
              ],
            ],
          ),
        );
      },
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

class _BriefingModuleCard extends StatelessWidget {
  final String moduleId;
  final String moduleName;
  final Color brandColor;
  final String icon;
  final String fallbackHeadline;
  final String fallbackSubtitle;
  final List<_ChipData> fallbackChips;
  final ValueChanged<BuildContext> onTap;

  const _BriefingModuleCard({
    required this.moduleId,
    required this.moduleName,
    required this.brandColor,
    required this.icon,
    required this.fallbackHeadline,
    required this.fallbackSubtitle,
    required this.fallbackChips,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ModuleBriefing?>(
      valueListenable: BriefingStore.instance.watchBriefing(moduleId),
      builder: (_, b, __) {
        final headline = b?.headline ?? fallbackHeadline;
        final subtitle = b?.summary.isNotEmpty == true
            ? b!.summary
            : fallbackSubtitle;
        final chips = b != null && b.chips.isNotEmpty
            ? [for (final c in b.chips) _ChipData(c.label, c.value)]
            : fallbackChips;
        final stale = b?.isStale() ?? true;

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
                          borderRadius: BorderRadius.circular(
                            BulterRadius.pill,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgIcon(
                              icon,
                              size: 12,
                              color: BulterColors.ctaText,
                            ),
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
                      if (b != null)
                        Text(
                          stale ? '过期' : b.freshnessLabel(),
                          style: TextStyle(
                            fontSize: BulterFontSize.caption,
                            color: stale
                                ? BulterColors.warning
                                : BulterColors.textTertiary,
                          ),
                        ),
                      const SizedBox(width: 6),
                      SvgIcon(
                        'common/chevron-right.svg',
                        size: 18,
                        color: brandColor,
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
      },
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
