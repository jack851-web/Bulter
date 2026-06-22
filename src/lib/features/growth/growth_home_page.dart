import 'package:bulter/db/app_database.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../form/stream_list_view.dart';
import 'goal_form.dart';
import 'learning_form.dart';

/// 成长模块主页（原型：phone-05-growth.png）。
///
/// 布局：
///   1) 顶部 OKR 周报大卡（深绿底 + 大标题 + 进度条）
///   2) 紧凑目标 / 学习列表（彩色 icon + 标题 + 副标题 + 进度）
class GrowthHomePage extends StatelessWidget {
  const GrowthHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        BulterSpacing.l,
        BulterSpacing.l,
        BulterSpacing.l,
        BulterSpacing.huge,
      ),
      children: const [
        _WeeklyHeader(),
        SizedBox(height: BulterSpacing.l),
        _SectionTitle('本月 · OKR 收尾期'),
        SizedBox(height: BulterSpacing.s),
        _OkrCard(),
        SizedBox(height: BulterSpacing.l),
        _SectionTitle('目标 / 学习记录'),
        SizedBox(height: BulterSpacing.s),
        _GoalLearningList(),
      ],
    );
  }

  static void openAddGoal(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GoalForm(
          title: '新增目标',
          onSubmit: (data) async {
            await AppDatabase.I.growthDao.insertGoal(data);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  static void openAddLearning(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LearningForm(
          title: '新增学习记录',
          onSubmit: (data) async {
            await AppDatabase.I.growthDao.insertLearning(data);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

class _WeeklyHeader extends StatelessWidget {
  const _WeeklyHeader();

  /// 计算 [d] 是本月的第几周（基于 1 号是周几 + 当前日期）。
  ///
  /// 与 [DateTime.weekday]（1=Mon..7=Sun）不同，**这是月内周序号**。
  static int _weekOfMonth(DateTime d) {
    final firstDay = DateTime(d.year, d.month, 1);
    final offset = firstDay.weekday; // 1 号是周几（1-7）
    return ((d.day + offset - 2) ~/ 7) + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BulterSpacing.m,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: BulterColors.growth,
            borderRadius: BorderRadius.circular(BulterRadius.pill),
          ),
          child: const Text(
            '本月',
            style: TextStyle(
              color: BulterColors.ctaText,
              fontSize: BulterFontSize.caption,
              fontWeight: BulterFontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: BulterSpacing.s),
        Text(
          '第 ${_weekOfMonth(DateTime.now())} 周',
          style: const TextStyle(
            fontSize: BulterFontSize.body,
            color: BulterColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: BulterFontSize.bodyLg,
        fontWeight: BulterFontWeight.semibold,
        color: BulterColors.textPrimary,
      ),
    );
  }
}

class _OkrCard extends StatelessWidget {
  const _OkrCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BulterSpacing.xl),
      decoration: BoxDecoration(
        color: BulterColors.growth,
        borderRadius: BorderRadius.circular(BulterRadius.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本月 · 21 周报',
            style: TextStyle(
              color: BulterColors.ctaText,
              fontSize: BulterFontSize.caption,
              fontWeight: BulterFontWeight.semibold,
            ),
          ),
          const SizedBox(height: BulterSpacing.s),
          const Text(
            'Kotlin 协程',
            style: TextStyle(
              color: BulterColors.ctaText,
              fontSize: BulterFontSize.displayS,
              fontWeight: BulterFontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: BulterSpacing.s),
          const Text(
            '6 章 · 40% 周报 · 10 月末完成',
            style: TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: BulterFontSize.footnote,
            ),
          ),
          const SizedBox(height: BulterSpacing.l),
          ClipRRect(
            borderRadius: BorderRadius.circular(BulterRadius.pill),
            child: LinearProgressIndicator(
              value: 0.50,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(BulterColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalLearningList extends StatelessWidget {
  const _GoalLearningList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Section(
          title: '目标',
          stream: AppDatabase.I.growthDao.watchActiveGoals(),
        ),
        const SizedBox(height: BulterSpacing.l),
        _Section(title: '学习', stream: AppDatabase.I.growthDao.watchLearning()),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Stream<List<dynamic>> stream;
  const _Section({required this.title, required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<dynamic>>(
      stream: stream,
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: BulterSpacing.s),
            child: Text(
              '暂无 $title',
              style: const TextStyle(
                fontSize: BulterFontSize.footnote,
                color: BulterColors.textTertiary,
              ),
            ),
          );
        }
        return Column(
          children: [for (final item in items) _Row(item: item, kind: title)],
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  final dynamic item;
  final String kind;
  const _Row({required this.item, required this.kind});

  static const _goalCatLabels = {
    'career': ('事业', Icons.work_outline_rounded),
    'skill': ('技能', Icons.school_outlined),
    'health': ('健康', Icons.favorite_outline_rounded),
    'relationship': ('关系', Icons.people_outline_rounded),
    'finance': ('财务', Icons.account_balance_wallet_outlined),
    'other': ('其他', Icons.flag_outlined),
  };

  static const _sourceLabels = {
    'book': ('书', Icons.menu_book_rounded),
    'course': ('课程', Icons.school_outlined),
    'article': ('文章', Icons.article_outlined),
    'video': ('视频', Icons.play_circle_outline_rounded),
    'podcast': ('播客', Icons.podcasts_rounded),
  };

  @override
  Widget build(BuildContext context) {
    if (item is Goal) {
      final g = item as Goal;
      final cat = _goalCatLabels[g.category] ?? _goalCatLabels['other']!;
      return ListCard(
        brandColor: BulterColors.growth,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GoalForm(
              title: '编辑目标',
              initial: g,
              onSubmit: (data) async {
                await AppDatabase.I.growthDao.updateGoal(data);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: BulterColors.growth.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(BulterRadius.s),
              ),
              child: Icon(cat.$2, color: BulterColors.growth, size: 16),
            ),
            const SizedBox(width: BulterSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.title,
                    style: const TextStyle(
                      fontSize: BulterFontSize.body,
                      fontWeight: BulterFontWeight.semibold,
                      color: BulterColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${cat.$1} · ${g.progress}%${g.targetDate != null ? " · ${g.targetDate!.year}-${g.targetDate!.month.toString().padLeft(2, "0")}-${g.targetDate!.day.toString().padLeft(2, "0")}" : ""}',
                    style: const TextStyle(
                      fontSize: BulterFontSize.caption,
                      color: BulterColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (item is LearningRecord) {
      final l = item as LearningRecord;
      final src = _sourceLabels[l.source] ?? _sourceLabels['book']!;
      return ListCard(
        brandColor: BulterColors.growth,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LearningForm(
              title: '编辑学习记录',
              initial: l,
              onSubmit: (data) async {
                await AppDatabase.I.growthDao.updateLearning(data);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: BulterColors.growth.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(BulterRadius.s),
              ),
              child: Icon(src.$2, color: BulterColors.growth, size: 16),
            ),
            const SizedBox(width: BulterSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.title,
                    style: const TextStyle(
                      fontSize: BulterFontSize.body,
                      fontWeight: BulterFontWeight.semibold,
                      color: BulterColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${src.$1}${l.author != null ? " · ${l.author}" : ""}',
                    style: const TextStyle(
                      fontSize: BulterFontSize.caption,
                      color: BulterColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (l.rating != null)
              Row(
                children: [
                  for (var i = 0; i < 5; i++)
                    Icon(
                      i < l.rating!
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: BulterColors.warning,
                      size: 12,
                    ),
                ],
              ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
