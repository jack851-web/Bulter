import 'package:bulter/db/app_database.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../form/chips_input.dart' as chips_util;
import '../form/stream_list_view.dart';
import 'contact_form.dart';
import 'favor_form.dart';
import 'interaction_form.dart';

/// 联系人详情页。
///
/// 上半部分展示联系人字段（可点击右上角编辑），
/// 下半部分展示该联系人的互动 + 人情债。
class ContactDetailPage extends StatefulWidget {
  final int contactId;
  const ContactDetailPage({super.key, required this.contactId});

  @override
  State<ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends State<ContactDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dao = AppDatabase.I.relationshipDao;
    return StreamBuilder<Contact?>(
      stream: dao.watchContact(widget.contactId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: BulterColors.canvas,
            body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final c = snap.data;
        if (c == null) {
          return Scaffold(
            backgroundColor: BulterColors.canvas,
            appBar: AppBar(),
            body: const Center(child: Text('联系人不存在或已删除')),
          );
        }
        final tags = chips_util.jsonToTags(c.tagsJson);
        return Scaffold(
          backgroundColor: BulterColors.canvas,
          appBar: AppBar(
            title: Text(c.name),
            actions: [
              IconButton(
                onPressed: () => _openEditContact(c),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: () => _confirmDelete(c),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: BulterColors.error,
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tab,
              labelColor: BulterColors.cta,
              unselectedLabelColor: BulterColors.textSecondary,
              indicatorColor: BulterColors.relationship,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontSize: BulterFontSize.body,
                fontWeight: BulterFontWeight.semibold,
              ),
              tabs: const [
                Tab(text: '互动'),
                Tab(text: '人情'),
              ],
            ),
          ),
          body: Column(
            children: [
              _Header(c: c, tags: tags),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _InteractionsTab(contactId: c.id),
                    _FavorsTab(contactId: c.id),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: AnimatedBuilder(
            animation: _tab,
            builder: (_, __) => FloatingActionButton.extended(
              onPressed: () => _onFab(c),
              backgroundColor: BulterColors.cta,
              foregroundColor: BulterColors.ctaText,
              elevation: 0,
              icon: Icon(_tab.index == 0
                  ? Icons.chat_bubble_outline_rounded
                  : Icons.redeem_rounded),
              label: Text(_tab.index == 0 ? '记一笔' : '记人情'),
            ),
          ),
        );
      },
    );
  }

  void _onFab(Contact c) {
    if (_tab.index == 0) {
      _openAddInteraction(c);
    } else {
      _openAddFavor(c);
    }
  }

  void _openEditContact(Contact c) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContactForm(
          title: '编辑联系人',
          initial: c,
          onSubmit: (data) async {
            await AppDatabase.I.relationshipDao.updateContact(data);
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _openAddInteraction(Contact c) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InteractionForm(
          contactId: c.id,
          title: '新增互动',
          onSubmit: (data) async {
            await AppDatabase.I.relationshipDao.insertInteraction(data);
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _openAddFavor(Contact c) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FavorForm(
          contactId: c.id,
          title: '记一笔人情',
          onSubmit: (data) async {
            await AppDatabase.I.relationshipDao.insertFavor(data);
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Contact c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除联系人'),
        content: Text('确认删除"${c.name}"？该联系人下的互动与人情记录将一并删除，无法恢复。'),
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
    if (ok != true) return;
    await AppDatabase.I.relationshipDao.deleteContact(c.id);
    if (mounted) Navigator.of(context).pop();
  }
}

class _Header extends StatelessWidget {
  final Contact c;
  final List<String> tags;
  const _Header({required this.c, required this.tags});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        BulterSpacing.l,
        BulterSpacing.l,
        BulterSpacing.l,
        BulterSpacing.l,
      ),
      color: BulterColors.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((c.nickname ?? '').isNotEmpty)
            Text(
              '昵称：${c.nickname}',
              style: const TextStyle(
                fontSize: BulterFontSize.body,
                color: BulterColors.textSecondary,
              ),
            ),
          const SizedBox(height: BulterSpacing.xs),
          Row(
            children: [
              _TagPill(text: _relLabel(c.relationshipType)),
              const SizedBox(width: BulterSpacing.s),
              _TagPill(
                text: '重要度 ${c.importance}/10',
                color: BulterColors.warning,
              ),
              if (c.birthday != null) ...[
                const SizedBox(width: BulterSpacing.s),
                _TagPill(
                  text: '生日 ${_birthdayLabel(c.birthday!)}',
                  color: BulterColors.health,
                ),
              ],
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: BulterSpacing.s),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final t in tags) _TagPill(text: '#$t')],
            ),
          ],
          if ((c.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: BulterSpacing.s),
            Text(
              c.notes!,
              style: const TextStyle(
                fontSize: BulterFontSize.body,
                color: BulterColors.textPrimary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _relLabel(String s) => switch (s) {
        'friend' => '朋友',
        'family' => '家人',
        'colleague' => '同事',
        'mentor' => '师长',
        _ => s,
      };

  static String _birthdayLabel(DateTime d) {
    return '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _TagPill extends StatelessWidget {
  final String text;
  final Color? color;
  const _TagPill({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? BulterColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BulterSpacing.s + 2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(BulterRadius.pill),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: BulterFontSize.footnote,
          color: c,
          fontWeight: BulterFontWeight.semibold,
        ),
      ),
    );
  }
}

class _InteractionsTab extends StatelessWidget {
  final int contactId;
  const _InteractionsTab({required this.contactId});

  @override
  Widget build(BuildContext context) {
    return StreamListView<Interaction>(
      stream: AppDatabase.I.relationshipDao.watchInteractionsFor(contactId),
      emptyTitle: '还没有互动记录',
      emptyHint: '点击右下角"记一笔"，留下第一次对话的痕迹',
      emptyIconName: 'chat/chat-bubble-outline.svg',
      itemBuilder: (context, i, idx) {
        return _InteractionRow(interaction: i);
      },
    );
  }
}

class _InteractionRow extends StatelessWidget {
  final Interaction interaction;
  const _InteractionRow({required this.interaction});

  static const _typeLabels = {
    'message': ('消息', Icons.message_outlined),
    'call': ('通话', Icons.phone_outlined),
    'meeting': ('见面', Icons.groups_outlined),
    'meal': ('饭局', Icons.restaurant_outlined),
    'other': ('其他', Icons.bubble_chart_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final t = _typeLabels[interaction.type] ?? _typeLabels['other']!;
    return ListCard(
      brandColor: BulterColors.relationship,
      onTap: () {},
      child: Row(
        children: [
          Icon(t.$2, size: 18, color: BulterColors.textSecondary),
          const SizedBox(width: BulterSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.$1,
                  style: const TextStyle(
                    fontSize: BulterFontSize.footnote,
                    color: BulterColors.textSecondary,
                    fontWeight: BulterFontWeight.semibold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  interaction.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: BulterFontSize.body,
                    color: BulterColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: BulterSpacing.s),
          Text(
            _formatWhen(interaction.happenedAt),
            style: const TextStyle(
              fontSize: BulterFontSize.caption,
              color: BulterColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatWhen(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    if (diff < 7) return '$diff 天前';
    return '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _FavorsTab extends StatelessWidget {
  final int contactId;
  const _FavorsTab({required this.contactId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Favor>>(
      stream: AppDatabase.I.relationshipDao.watchOpenFavors(),
      builder: (context, snap) {
        final all = snap.data ?? const <Favor>[];
        final mine = all.where((f) => f.contactId == contactId).toList();
        return StreamListView<Favor>(
          stream: Stream.value(mine),
          emptyTitle: '没有人情往来',
          emptyHint: '记一笔礼金、礼物、帮忙，回头好记得还',
          emptyIconName: 'modules/briefcase-filled.svg',
          itemBuilder: (context, f, idx) => _FavorRow(favor: f),
        );
      },
    );
  }
}

class _FavorRow extends StatelessWidget {
  final Favor favor;
  const _FavorRow({required this.favor});

  static const _dirLabels = {
    'i_owe': ('我欠对方', BulterColors.error),
    'they_owe': ('对方欠我', BulterColors.success),
    'gift_given': ('送出', BulterColors.warning),
    'gift_received': ('收到', BulterColors.info),
  };

  @override
  Widget build(BuildContext context) {
    final label = _dirLabels[favor.direction] ?? _dirLabels.values.first;
    return ListCard(
      brandColor: label.$2,
      onTap: () async {
        // 点击关闭（仅 open 状态）
        if (favor.status == 'open') {
          await AppDatabase.I.relationshipDao.closeFavor(favor.id);
        }
      },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.$1,
                  style: TextStyle(
                    fontSize: BulterFontSize.footnote,
                    color: label.$2,
                    fontWeight: BulterFontWeight.semibold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  favor.description,
                  style: const TextStyle(
                    fontSize: BulterFontSize.body,
                    color: BulterColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  favor.status == 'open' ? '点击标记为已还清' : '已结清',
                  style: const TextStyle(
                    fontSize: BulterFontSize.caption,
                    color: BulterColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (favor.amountCents > 0)
            Text(
              '¥${(favor.amountCents / 100).toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: BulterFontSize.titleS,
                fontWeight: BulterFontWeight.semibold,
                color: BulterColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}
