import 'package:bulter/db/app_database.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'letter_form.dart';
import 'thought_form.dart';

/// 思想模块主页（原型：phone-07-thoughts.png）。
///
/// 布局：
///   1) 紫色 AI 总结顶卡（本周 · 想法 / 信件数）
///   2) 紧凑列表：圆形彩色 icon + 标题 + 副标题 + 右上时间
class ThoughtHomePage extends StatelessWidget {
  const ThoughtHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BulterColors.canvas,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          BulterSpacing.l,
          BulterSpacing.l,
          BulterSpacing.l,
          BulterSpacing.huge,
        ),
        children: const [
          _AiSummaryCard(),
          SizedBox(height: BulterSpacing.l),
          _SectionTitle('想法 · 本周'),
          SizedBox(height: BulterSpacing.s),
          _ThoughtCompactList(),
          SizedBox(height: BulterSpacing.l),
          _SectionTitle('信件 · 待拆'),
          SizedBox(height: BulterSpacing.s),
          _LetterCompactList(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddThought(context),
        backgroundColor: BulterColors.cta,
        foregroundColor: BulterColors.ctaText,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text('记一条'),
      ),
    );
  }

  static void _openAddThought(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ThoughtForm(
          title: '记一条想法',
          onSubmit: (data) async {
            await AppDatabase.I.thoughtDao.insertThought(data);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

class _AiSummaryCard extends StatelessWidget {
  const _AiSummaryCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Thought>>(
      stream: AppDatabase.I.thoughtDao.watchRecentThoughts(limit: 100),
      builder: (context, tSnap) {
        final thoughts = tSnap.data ?? const <Thought>[];
        return StreamBuilder<List<Letter>>(
          stream: AppDatabase.I.thoughtDao.watchUnopenedLetters(),
          builder: (context, lSnap) {
            final letters = lSnap.data ?? const <Letter>[];
            final thoughtCount = thoughts.length;
            return Container(
              padding: const EdgeInsets.all(BulterSpacing.l),
              decoration: BoxDecoration(
                color: BulterColors.thought.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(BulterRadius.xl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: BulterSpacing.s,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: BulterColors.thought,
                          borderRadius: BorderRadius.circular(
                            BulterRadius.pill,
                          ),
                        ),
                        child: const Text(
                          'AI 总结 · 本周',
                          style: TextStyle(
                            color: BulterColors.ctaText,
                            fontSize: BulterFontSize.caption,
                            fontWeight: BulterFontWeight.semibold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: BulterSpacing.s),
                  Text(
                    '你想了 $thoughtCount 条灵感。\n留下了 ${letters.length} 封待拆信件。',
                    style: const TextStyle(
                      fontSize: BulterFontSize.bodyLg,
                      color: BulterColors.textPrimary,
                      fontWeight: BulterFontWeight.semibold,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: BulterSpacing.s),
                  const Text(
                    '打开读书《置身事内》/ 留下了 3 个高亮。',
                    style: TextStyle(
                      fontSize: BulterFontSize.footnote,
                      color: BulterColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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

class _ThoughtCompactList extends StatelessWidget {
  const _ThoughtCompactList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Thought>>(
      stream: AppDatabase.I.thoughtDao.watchRecentThoughts(limit: 8),
      builder: (context, snap) {
        final items = snap.data ?? const <Thought>[];
        if (items.isEmpty) {
          return _EmptyHint(
            icon: Icons.lightbulb_outline_rounded,
            text: '还没有想法 · 摘录一句让你反复想的话',
          );
        }
        return Column(
          children: [
            for (final t in items)
              Padding(
                padding: const EdgeInsets.only(bottom: BulterSpacing.s),
                child: _ThoughtRow(thought: t),
              ),
          ],
        );
      },
    );
  }
}

class _ThoughtRow extends StatelessWidget {
  final Thought thought;
  const _ThoughtRow({required this.thought});

  static const _sourceLabels = {
    'book': ('书', Icons.menu_book_outlined),
    'article': ('文章', Icons.article_outlined),
    'movie': ('电影', Icons.movie_outlined),
    'conversation': ('对话', Icons.chat_bubble_outline_rounded),
    'other': ('其他', Icons.bubble_chart_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final src = _sourceLabels[thought.source] ?? _sourceLabels['other']!;
    return Material(
      color: BulterColors.surface,
      borderRadius: BorderRadius.circular(BulterRadius.l),
      child: InkWell(
        borderRadius: BorderRadius.circular(BulterRadius.l),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ThoughtForm(
              title: '编辑想法',
              initial: thought,
              onSubmit: (data) async {
                await AppDatabase.I.thoughtDao.updateThought(data);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(BulterSpacing.m),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BulterRadius.l),
            border: Border.all(color: BulterColors.divider, width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: BulterColors.thought.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(src.$2, color: BulterColors.thought, size: 18),
              ),
              const SizedBox(width: BulterSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          src.$1,
                          style: const TextStyle(
                            fontSize: BulterFontSize.caption,
                            color: BulterColors.thought,
                            fontWeight: BulterFontWeight.semibold,
                          ),
                        ),
                        if ((thought.sourceRef ?? '').isNotEmpty) ...[
                          const SizedBox(width: BulterSpacing.s),
                          Expanded(
                            child: Text(
                              thought.sourceRef!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: BulterFontSize.caption,
                                color: BulterColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      thought.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: BulterFontSize.body,
                        color: BulterColors.textPrimary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: BulterSpacing.s),
              Text(
                _relativeTime(thought.recordedAt),
                style: const TextStyle(
                  fontSize: BulterFontSize.caption,
                  color: BulterColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) {
      return diff.inMinutes <= 1 ? '刚刚' : '${diff.inMinutes} 分钟';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} 小时';
    }
    if (diff.inDays < 30) {
      return '${diff.inDays} 天';
    }
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}

class _LetterCompactList extends StatelessWidget {
  const _LetterCompactList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Letter>>(
      stream: AppDatabase.I.thoughtDao.watchUnopenedLetters(),
      builder: (context, snap) {
        final items = snap.data ?? const <Letter>[];
        if (items.isEmpty) {
          return _EmptyHint(
            icon: Icons.mail_outline_rounded,
            text: '没有待拆信件 · 给未来的自己写一封',
          );
        }
        return Column(
          children: [
            for (final l in items)
              Padding(
                padding: const EdgeInsets.only(bottom: BulterSpacing.s),
                child: _LetterRow(letter: l),
              ),
          ],
        );
      },
    );
  }
}

class _LetterRow extends StatelessWidget {
  final Letter letter;
  const _LetterRow({required this.letter});

  static const _typeLabels = {
    'to_self': ('自己', Icons.self_improvement_rounded),
    'to_others': ('他人', Icons.send_rounded),
    'to_future': ('未来', Icons.schedule_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final type = _typeLabels[letter.type] ?? _typeLabels['to_self']!;
    return Material(
      color: BulterColors.surface,
      borderRadius: BorderRadius.circular(BulterRadius.l),
      child: InkWell(
        borderRadius: BorderRadius.circular(BulterRadius.l),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LetterForm(
              title: '编辑信件',
              initial: letter,
              onSubmit: (data) async {
                await AppDatabase.I.thoughtDao.updateLetter(data);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(BulterSpacing.m),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BulterRadius.l),
            border: Border.all(color: BulterColors.divider, width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: BulterColors.thought.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(type.$2, color: BulterColors.thought, size: 18),
              ),
              const SizedBox(width: BulterSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.$1,
                      style: const TextStyle(
                        fontSize: BulterFontSize.caption,
                        color: BulterColors.thought,
                        fontWeight: BulterFontWeight.semibold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      letter.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: BulterFontSize.body,
                        fontWeight: BulterFontWeight.semibold,
                        color: BulterColors.textPrimary,
                      ),
                    ),
                    if (letter.targetDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '投递：${letter.targetDate!.year}-${letter.targetDate!.month.toString().padLeft(2, '0')}-${letter.targetDate!.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: BulterFontSize.caption,
                          color: BulterColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: BulterSpacing.s),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.mark_email_read_outlined,
                  color: BulterColors.success,
                  size: 18,
                ),
                tooltip: '标记为已读',
                onPressed: () async {
                  await AppDatabase.I.thoughtDao.markLetterOpened(letter.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BulterSpacing.l),
      decoration: BoxDecoration(
        color: BulterColors.surface,
        borderRadius: BorderRadius.circular(BulterRadius.l),
        border: Border.all(color: BulterColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: BulterColors.textTertiary, size: 20),
          const SizedBox(width: BulterSpacing.m),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: BulterFontSize.body,
                color: BulterColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
