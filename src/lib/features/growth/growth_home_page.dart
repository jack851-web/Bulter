import 'package:bulter/db/app_database.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../form/stream_list_view.dart';
import 'goal_form.dart';
import 'learning_form.dart';

/// 成长模块主页：Tab 切换「目标 / 学习 / OKR / 项目」。
class GrowthHomePage extends StatelessWidget {
  const GrowthHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: BulterColors.canvas,
            child: TabBar(
              labelColor: BulterColors.cta,
              unselectedLabelColor: BulterColors.textSecondary,
              indicatorColor: BulterColors.growth,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontSize: BulterFontSize.bodyLg,
                fontWeight: BulterFontWeight.semibold,
              ),
              tabs: const [
                Tab(text: '目标'),
                Tab(text: '学习'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _GoalsTab(),
                _LearningTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalsTab extends StatelessWidget {
  const _GoalsTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BulterColors.canvas,
      body: StreamListView<Goal>(
        stream: AppDatabase.I.growthDao.watchActiveGoals(),
        brandColor: BulterColors.growth,
        emptyTitle: '还没有目标',
        emptyHint: '把模糊的愿望变成可追踪的目标',
        emptyIcon: Icons.flag_outlined,
        itemBuilder: (context, g, idx) => _GoalRow(goal: g),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddGoal(context),
        backgroundColor: BulterColors.cta,
        foregroundColor: BulterColors.ctaText,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新目标'),
      ),
    );
  }

  static void _openAddGoal(BuildContext context) {
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
}

class _GoalRow extends StatelessWidget {
  final Goal goal;
  const _GoalRow({required this.goal});

  static const _catLabels = {
    'career': '事业',
    'skill': '技能',
    'health': '健康',
    'relationship': '关系',
    'finance': '财务',
    'other': '其他',
  };

  @override
  Widget build(BuildContext context) {
    final cat = _catLabels[goal.category] ?? goal.category;
    return ListCard(
      brandColor: BulterColors.growth,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GoalForm(
            title: '编辑目标',
            initial: goal,
            onSubmit: (data) async {
              await AppDatabase.I.growthDao.updateGoal(data);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ),
      ),
      trailing: IconButton(
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: BulterColors.error,
        ),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('删除目标'),
              content: Text('确认删除"${goal.title}"？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text(
                    '删除',
                    style: TextStyle(color: BulterColors.error),
                  ),
                ),
              ],
            ),
          );
          if (ok == true) {
            await AppDatabase.I.growthDao.deleteGoal(goal.id);
          }
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  style: const TextStyle(
                    fontSize: BulterFontSize.bodyLg,
                    fontWeight: BulterFontWeight.semibold,
                    color: BulterColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: BulterSpacing.s,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: BulterColors.growth.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(BulterRadius.pill),
                ),
                child: Text(
                  cat,
                  style: const TextStyle(
                    fontSize: BulterFontSize.caption,
                    color: BulterColors.growth,
                    fontWeight: BulterFontWeight.semibold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BulterSpacing.s),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(BulterRadius.pill),
                  child: LinearProgressIndicator(
                    value: goal.progress / 100.0,
                    minHeight: 6,
                    backgroundColor: BulterColors.surfaceMuted,
                    valueColor:
                        const AlwaysStoppedAnimation(BulterColors.growth),
                  ),
                ),
              ),
              const SizedBox(width: BulterSpacing.m),
              Text(
                '${goal.progress}%',
                style: const TextStyle(
                  fontSize: BulterFontSize.footnote,
                  fontWeight: BulterFontWeight.semibold,
                  color: BulterColors.textSecondary,
                ),
              ),
            ],
          ),
          if (goal.targetDate != null) ...[
            const SizedBox(height: BulterSpacing.xs),
            Text(
              '目标日期：${goal.targetDate!.year}-${goal.targetDate!.month.toString().padLeft(2, '0')}-${goal.targetDate!.day.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: BulterFontSize.caption,
                color: BulterColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LearningTab extends StatelessWidget {
  const _LearningTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BulterColors.canvas,
      body: StreamListView<LearningRecord>(
        stream: AppDatabase.I.growthDao.watchLearning(),
        brandColor: BulterColors.growth,
        emptyTitle: '还没有学习记录',
        emptyHint: '每读一本书、看一门课，都值得记一笔',
        emptyIcon: Icons.menu_book_outlined,
        itemBuilder: (context, l, idx) => _LearningRow(record: l),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddLearning(context),
        backgroundColor: BulterColors.cta,
        foregroundColor: BulterColors.ctaText,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text('记一条'),
      ),
    );
  }

  static void _openAddLearning(BuildContext context) {
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

class _LearningRow extends StatelessWidget {
  final LearningRecord record;
  const _LearningRow({required this.record});

  static const _sourceLabels = {
    'book': ('书', Icons.menu_book_rounded),
    'course': ('课程', Icons.school_outlined),
    'article': ('文章', Icons.article_outlined),
    'video': ('视频', Icons.play_circle_outline_rounded),
    'podcast': ('播客', Icons.podcasts_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final src = _sourceLabels[record.source] ?? _sourceLabels['book']!;
    return ListCard(
      brandColor: BulterColors.growth,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LearningForm(
            title: '编辑学习记录',
            initial: record,
            onSubmit: (data) async {
              await AppDatabase.I.growthDao.updateLearning(data);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(src.$2, color: BulterColors.growth, size: 22),
          const SizedBox(width: BulterSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: const TextStyle(
                    fontSize: BulterFontSize.bodyLg,
                    fontWeight: BulterFontWeight.semibold,
                    color: BulterColors.textPrimary,
                  ),
                ),
                if ((record.author ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${src.$1} · ${record.author}',
                      style: const TextStyle(
                        fontSize: BulterFontSize.footnote,
                        color: BulterColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (record.rating != null)
            Row(
              children: [
                for (var i = 0; i < 5; i++)
                  Icon(
                    i < record.rating!
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: BulterColors.warning,
                    size: 14,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
