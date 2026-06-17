import 'package:bulter/db/app_database.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../form/chips_input.dart' as chips_util;
import '../form/stream_list_view.dart';
import 'letter_form.dart';
import 'thought_form.dart';

/// 思想模块主页：Tab 切换「想法 / 信件」。
class ThoughtHomePage extends StatelessWidget {
  const ThoughtHomePage({super.key});

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
              indicatorColor: BulterColors.thought,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontSize: BulterFontSize.bodyLg,
                fontWeight: BulterFontWeight.semibold,
              ),
              tabs: const [
                Tab(text: '想法'),
                Tab(text: '信件'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(children: [_ThoughtsTab(), _LettersTab()]),
          ),
        ],
      ),
    );
  }
}

class _ThoughtsTab extends StatelessWidget {
  const _ThoughtsTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BulterColors.canvas,
      body: StreamListView<Thought>(
        stream: AppDatabase.I.thoughtDao.watchRecentThoughts(),
        brandColor: BulterColors.thought,
        emptyTitle: '还没有想法',
        emptyHint: '摘录一句让你反复想的话，留作日后的自己看',
        emptyIcon: Icons.lightbulb_outline_rounded,
        itemBuilder: (context, t, idx) {
          final tags = chips_util.jsonToTags(t.tagsJson);
          return _ThoughtRow(thought: t, tags: tags);
        },
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

class _ThoughtRow extends StatelessWidget {
  final Thought thought;
  final List<String> tags;
  const _ThoughtRow({required this.thought, required this.tags});

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
    return ListCard(
      brandColor: BulterColors.thought,
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
      trailing: IconButton(
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: BulterColors.error,
        ),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('删除想法'),
              content: const Text('确认删除？'),
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
            await AppDatabase.I.thoughtDao.deleteThought(thought.id);
          }
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(src.$2, size: 14, color: BulterColors.textTertiary),
              const SizedBox(width: 4),
              Text(
                src.$1,
                style: const TextStyle(
                  fontSize: BulterFontSize.caption,
                  color: BulterColors.textTertiary,
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
          const SizedBox(height: BulterSpacing.s),
          Text(
            thought.content,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: BulterFontSize.bodyLg,
              color: BulterColors.textPrimary,
              height: 1.55,
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: BulterSpacing.s),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: BulterSpacing.s,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: BulterColors.thought.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(BulterRadius.pill),
                    ),
                    child: Text(
                      '#$t',
                      style: const TextStyle(
                        fontSize: BulterFontSize.caption,
                        color: BulterColors.thought,
                        fontWeight: BulterFontWeight.semibold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LettersTab extends StatelessWidget {
  const _LettersTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BulterColors.canvas,
      body: StreamListView<Letter>(
        stream: AppDatabase.I.thoughtDao.watchUnopenedLetters(),
        brandColor: BulterColors.thought,
        emptyTitle: '没有待拆信件',
        emptyHint: '给未来的自己写一封，定个投递日期',
        emptyIcon: Icons.mail_outline_rounded,
        itemBuilder: (context, l, idx) => _LetterRow(letter: l),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddLetter(context),
        backgroundColor: BulterColors.cta,
        foregroundColor: BulterColors.ctaText,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text('写一封'),
      ),
    );
  }

  static void _openAddLetter(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LetterForm(
          title: '写一封信',
          onSubmit: (data) async {
            await AppDatabase.I.thoughtDao.insertLetter(data);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

class _LetterRow extends StatelessWidget {
  final Letter letter;
  const _LetterRow({required this.letter});

  static const _typeLabels = {
    'to_self': '写给自己',
    'to_others': '写给某人',
    'to_future': '写给未来',
  };

  @override
  Widget build(BuildContext context) {
    return ListCard(
      brandColor: BulterColors.thought,
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
      trailing: IconButton(
        icon: const Icon(
          Icons.mark_email_read_outlined,
          color: BulterColors.success,
        ),
        tooltip: '标记为已读',
        onPressed: () async {
          await AppDatabase.I.thoughtDao.markLetterOpened(letter.id);
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _typeLabels[letter.type] ?? letter.type,
            style: const TextStyle(
              fontSize: BulterFontSize.caption,
              color: BulterColors.thought,
              fontWeight: BulterFontWeight.semibold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            letter.title,
            style: const TextStyle(
              fontSize: BulterFontSize.bodyLg,
              fontWeight: BulterFontWeight.semibold,
              color: BulterColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            letter.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: BulterFontSize.body,
              color: BulterColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (letter.targetDate != null) ...[
            const SizedBox(height: BulterSpacing.s),
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
    );
  }
}
