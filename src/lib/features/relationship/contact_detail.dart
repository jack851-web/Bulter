import 'package:bulter/db/app_database.dart';
import 'package:flutter/material.dart';

import '../../components/mastery_ring.dart';
import '../../components/svg_icon.dart';
import '../../components/timeline.dart' show Timeline, TimelineNode;
import '../../components/timeline.dart' as tl;
import '../../theme/tokens.dart';
import '../form/chips_input.dart' as chips_util;
import '../form/stream_list_view.dart';
import 'contact_form.dart';
import 'favor_form.dart';
import 'interaction_form.dart';

/// 联系人详情页（对齐 phone-08 / phone-20 原型）。
///
/// **结构（自上而下）**：
///   1) 自定义顶栏（左上：返回；右上：编辑 / 删除）
///   2) 粉色 hero 卡：头像 + 名字 + Mastery Ring + 标签
///   3) 联系方式 3 胶囊（微信 / 约时间 / 标记）
///   4) AI 维护建议 卡（基于"距上次联系天数 / 重要度"动态生成）
///   5) 关系时间线（最近 5 条互动 / 人情，用一条彩色细线串起）
///   6) Tab：互动 / 人情
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
        return StreamBuilder<List<Interaction>>(
          stream: dao.watchInteractionsFor(c.id),
          builder: (context, iSnap) {
            final interactions = iSnap.data ?? const <Interaction>[];
            return StreamBuilder<List<Favor>>(
              stream: dao.watchOpenFavors(),
              builder: (context, fSnap) {
                final allFavors = fSnap.data ?? const <Favor>[];
                final favors = allFavors
                    .where((f) => f.contactId == c.id)
                    .toList();
                return _ContactDetailScaffold(
                  contact: c,
                  interactions: interactions,
                  favors: favors,
                  tab: _tab,
                  onTabChange: (i) => setState(() {}),
                  onEdit: () => _openEditContact(c),
                  onDelete: () => _confirmDelete(c),
                  onAddInteraction: () => _openAddInteraction(c),
                  onAddFavor: () => _openAddFavor(c),
                );
              },
            );
          },
        );
      },
    );
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BulterRadius.l),
        ),
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

/// 详情页主 scaffold：自定义顶栏 + hero + 3 胶囊 + AI 卡 + 时间线 + Tab 内容。
class _ContactDetailScaffold extends StatelessWidget {
  final Contact contact;
  final List<Interaction> interactions;
  final List<Favor> favors;
  final TabController tab;
  final ValueChanged<int> onTabChange;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddInteraction;
  final VoidCallback onAddFavor;

  const _ContactDetailScaffold({
    required this.contact,
    required this.interactions,
    required this.favors,
    required this.tab,
    required this.onTabChange,
    required this.onEdit,
    required this.onDelete,
    required this.onAddInteraction,
    required this.onAddFavor,
  });

  @override
  Widget build(BuildContext context) {
    final tags = chips_util.jsonToTags(contact.tagsJson);
    final mastery = _calculateMastery(contact, interactions.length);
    return Scaffold(
      backgroundColor: BulterColors.canvas,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _TopBar(onEdit: onEdit, onDelete: onDelete),
          ),
          SliverToBoxAdapter(
            child: _Hero(
              contact: contact,
              tags: tags,
              mastery: mastery,
              interactionCount: interactions.length,
            ),
          ),
          SliverToBoxAdapter(child: _ActionRow(contact: contact)),
          SliverToBoxAdapter(
            child: _AiAdvice(contact: contact, interactions: interactions),
          ),
          SliverToBoxAdapter(
            child: _TimelineSection(
              contact: contact,
              interactions: interactions,
              favors: favors,
            ),
          ),
          SliverToBoxAdapter(
            child: _TabBar(controller: tab, onChange: onTabChange),
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: TabBarView(
              controller: tab,
              children: [
                _InteractionsTab(contactId: contact.id),
                _FavorsTab(contactId: contact.id),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: tab,
        builder: (_, __) => _Fab(
          index: tab.index,
          onAddInteraction: onAddInteraction,
          onAddFavor: onAddFavor,
        ),
      ),
    );
  }
}

/// Mastery 计算：基础分 = 重要度 × 10（0-100），互动加成 +min(次数, 10)，封顶 100。
int _calculateMastery(Contact c, int interactionCount) {
  final base = (c.importance.clamp(0, 10)) * 10;
  final bonus = interactionCount.clamp(0, 10);
  return (base + bonus).clamp(0, 100);
}

// ============================================================
// 顶栏
// ============================================================

class _TopBar extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _TopBar({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BulterSpacing.s,
          BulterSpacing.s,
          BulterSpacing.l,
          BulterSpacing.s,
        ),
        child: Row(
          children: [
            SvgIconButton(
              iconName: 'common/chevron-left.svg',
              onTap: () => Navigator.of(context).maybePop(),
              size: 36,
              iconSize: 18,
            ),
            const Spacer(),
            SvgIconButton(
              iconName: 'common/tune.svg',
              onTap: onEdit,
              size: 36,
              iconSize: 16,
            ),
            const SizedBox(width: BulterSpacing.s),
            SvgIconButton(
              iconName: 'common/close.svg',
              onTap: onDelete,
              size: 36,
              iconSize: 16,
              color: BulterColors.error,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Hero：粉色大卡 + 头像 + 名字 + Mastery Ring + 标签
// ============================================================

class _Hero extends StatelessWidget {
  final Contact contact;
  final List<String> tags;
  final int mastery;
  final int interactionCount;

  const _Hero({
    required this.contact,
    required this.tags,
    required this.mastery,
    required this.interactionCount,
  });

  @override
  Widget build(BuildContext context) {
    final initial = contact.name.isEmpty
        ? '?'
        : contact.name.characters.first.toUpperCase();
    return Container(
      margin: const EdgeInsets.fromLTRB(
        BulterSpacing.l,
        BulterSpacing.s,
        BulterSpacing.l,
        BulterSpacing.l,
      ),
      padding: const EdgeInsets.fromLTRB(
        BulterSpacing.xl,
        BulterSpacing.l,
        BulterSpacing.l,
        BulterSpacing.l,
      ),
      decoration: BoxDecoration(
        color: BulterColors.relationship.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(BulterRadius.xxl),
      ),
      child: Row(
        children: [
          // 头像
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: BulterColors.relationship,
              borderRadius: BorderRadius.circular(BulterRadius.l),
              boxShadow: BulterShadow.card,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: BulterFontWeight.heavy,
                color: BulterColors.ctaText,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: BulterSpacing.l),
          // 名字 + 标签
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: BulterFontSize.titleL,
                    fontWeight: BulterFontWeight.bold,
                    color: BulterColors.textPrimary,
                    height: 1.15,
                  ),
                ),
                if ((contact.nickname ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '昵称：${contact.nickname}',
                    style: const TextStyle(
                      fontSize: BulterFontSize.footnote,
                      color: BulterColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: BulterSpacing.s),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Pill(
                      text: _relLabel(contact.relationshipType),
                      color: BulterColors.relationship,
                    ),
                    _Pill(
                      text: '重要度 ${contact.importance}/10',
                      color: BulterColors.warning,
                    ),
                    if (contact.birthday != null)
                      _Pill(
                        text: '生日 ${_birthdayLabel(contact.birthday!)}',
                        color: BulterColors.health,
                      ),
                    for (final t in tags.take(2))
                      _Pill(text: '#$t', color: BulterColors.textSecondary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: BulterSpacing.s),
          // Mastery Ring（签名元素）
          MasteryRing(score: mastery, radius: 30, strokeWidth: 4),
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

  static String _birthdayLabel(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BulterSpacing.s + 2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(BulterRadius.pill),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: BulterFontSize.caption,
          color: color,
          fontWeight: BulterFontWeight.semibold,
        ),
      ),
    );
  }
}

// ============================================================
// 联系方式 3 胶囊（微信 / 约时间 / 标记）
// ============================================================

class _ActionRow extends StatelessWidget {
  final Contact contact;
  const _ActionRow({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BulterSpacing.l,
        0,
        BulterSpacing.l,
        BulterSpacing.l,
      ),
      child: Row(
        children: [
          _ContactAction(
            icon: 'common/circle.svg',
            label: '发消息',
            color: BulterColors.relationship,
            onTap: () => _snack(context, '已为你打开"${contact.name}"的对话'),
          ),
          const SizedBox(width: BulterSpacing.s),
          _ContactAction(
            icon: 'common/clock.svg',
            label: '约时间',
            color: BulterColors.health,
            onTap: () => _snack(context, '已记下与"${contact.name}"的约定'),
          ),
          const SizedBox(width: BulterSpacing.s),
          _ContactAction(
            icon: 'common/bookmark.svg',
            label: '标记',
            color: BulterColors.warning,
            onTap: () => _snack(context, '已标记"${contact.name}"为重要'),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BulterRadius.m),
        ),
        margin: const EdgeInsets.all(BulterSpacing.l),
      ),
    );
  }
}

class _ContactAction extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ContactAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(BulterRadius.l),
        child: InkWell(
          borderRadius: BorderRadius.circular(BulterRadius.l),
          onTap: onTap,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BulterRadius.l),
              border: Border.all(
                color: color.withValues(alpha: 0.18),
                width: 0.6,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgIcon(icon, size: 18, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: BulterFontSize.caption,
                    color: color,
                    fontWeight: BulterFontWeight.semibold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// AI 维护建议（基于"距上次联系天数"动态生成）
// ============================================================

class _AiAdvice extends StatelessWidget {
  final Contact contact;
  final List<Interaction> interactions;
  const _AiAdvice({required this.contact, required this.interactions});

  @override
  Widget build(BuildContext context) {
    final days = _daysSinceLastContact(contact, interactions);
    final (headline, body, action, actionIcon) = _compose(days, contact);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        BulterSpacing.l,
        0,
        BulterSpacing.l,
        BulterSpacing.l,
      ),
      padding: const EdgeInsets.all(BulterSpacing.l),
      decoration: BoxDecoration(
        color: BulterColors.relationship.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BulterRadius.xl),
        border: Border.all(
          color: BulterColors.relationship.withValues(alpha: 0.20),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: BulterSpacing.s + 2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: BulterColors.relationship,
                  borderRadius: BorderRadius.circular(BulterRadius.pill),
                ),
                child: const Text(
                  'AI 维护建议',
                  style: TextStyle(
                    fontSize: BulterFontSize.caption,
                    color: BulterColors.ctaText,
                    fontWeight: BulterFontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BulterSpacing.s),
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
            body,
            style: const TextStyle(
              fontSize: BulterFontSize.footnote,
              color: BulterColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: BulterSpacing.m),
            _AdviceAction(label: action, icon: actionIcon),
          ],
        ],
      ),
    );
  }

  /// 距上次互动的天数。若无任何互动，按"重要度"估算"应联系"天数。
  int _daysSinceLastContact(Contact c, List<Interaction> interactions) {
    if (interactions.isEmpty) {
      // 全新联系人 → 直接视为 30 天
      return 30;
    }
    final last =
        interactions.first.happenedAt; // watchInteractionsFor 已按 desc 排
    return DateTime.now().difference(last).inDays;
  }

  /// 组合文案 / 建议动作。
  (String, String, String?, String) _compose(int days, Contact c) {
    if (days <= 3) {
      return ('联系频次很好。', '你们最近互动很频繁，关系网很稳。', '回看最近一次', 'common/clock.svg');
    }
    if (days <= 14) {
      return (
        '建议这个周末问候。',
        '距上次联系已经 $days 天，可以找个轻松的话题。',
        '记一笔',
        'common/plus.svg',
      );
    }
    if (days <= 30) {
      return (
        '已经 $days 天没联系了。',
        '重要度 ${c.importance}/10 的人不应沉默太久。发条短消息或约个时间。',
        '去问候',
        'common/handshake.svg',
      );
    }
    return (
      '已超过一个月。',
      '已经 $days 天没联系。建议发个关心，或安排一次见面。',
      '安排一次',
      'common/calendar.svg',
    );
  }
}

class _AdviceAction extends StatelessWidget {
  final String label;
  final String icon;
  const _AdviceAction({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BulterColors.relationship,
      borderRadius: BorderRadius.circular(BulterRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(BulterRadius.pill),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BulterSpacing.l,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(icon, size: 14, color: BulterColors.ctaText),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: BulterFontSize.footnote,
                  color: BulterColors.ctaText,
                  fontWeight: BulterFontWeight.semibold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 关系时间线（最近互动 / 人情 用一条彩色细线串起）
// ============================================================

class _TimelineSection extends StatelessWidget {
  final Contact contact;
  final List<Interaction> interactions;
  final List<Favor> favors;
  const _TimelineSection({
    required this.contact,
    required this.interactions,
    required this.favors,
  });

  @override
  Widget build(BuildContext context) {
    if (interactions.isEmpty && favors.isEmpty) {
      return const SizedBox.shrink();
    }
    // 合并两类事件，按时间倒序
    final merged = <_MixedEvent>[
      for (final i in interactions)
        _MixedEvent(at: i.happenedAt, kind: _EventKind.interaction, data: i),
      for (final f in favors)
        _MixedEvent(at: f.happenedAt, kind: _EventKind.favor, data: f),
    ]..sort((a, b) => b.at.compareTo(a.at));

    final nodes = <TimelineNode>[];
    for (final e in merged.take(5)) {
      switch (e.kind) {
        case _EventKind.interaction:
          final i = e.data as Interaction;
          nodes.add(
            TimelineNode(
              icon: SvgIcon(_interactionIcon(i.type), size: 14),
              iconColor: BulterColors.relationship,
              title: _interactionTitle(i),
              subtitle: i.summary,
              rightLabel: _relativeTime(i.happenedAt),
            ),
          );
          break;
        case _EventKind.favor:
          final f = e.data as Favor;
          nodes.add(
            TimelineNode(
              icon: const SvgIcon('common/handshake.svg', size: 14),
              iconColor: BulterColors.warning,
              title: _favorTitle(f),
              subtitle: f.description,
              rightLabel: _relativeTime(f.happenedAt),
              trailing: [
                if (f.amountCents > 0)
                  Text(
                    '¥${(f.amountCents / 100).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: BulterFontSize.footnote,
                      color: BulterColors.textPrimary,
                      fontWeight: BulterFontWeight.bold,
                    ),
                  ),
                tl.ActionChip(
                  label: f.direction == 'gift_given' ? '送出' : '收到',
                  color: BulterColors.relationship,
                ),
              ],
            ),
          );
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BulterSpacing.l,
        0,
        BulterSpacing.l,
        BulterSpacing.l,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '关系时间线',
                style: TextStyle(
                  fontSize: BulterFontSize.titleS,
                  fontWeight: BulterFontWeight.semibold,
                  color: BulterColors.textPrimary,
                ),
              ),
              const SizedBox(width: BulterSpacing.s),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: BulterSpacing.s,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: BulterColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(BulterRadius.pill),
                ),
                child: Text(
                  '${merged.length} 个事件',
                  style: const TextStyle(
                    fontSize: BulterFontSize.caption,
                    color: BulterColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          Timeline(
            nodes: nodes,
            lineColor: BulterColors.relationship.withValues(alpha: 0.30),
            iconSize: 32,
            padding: const EdgeInsets.only(top: BulterSpacing.s),
          ),
        ],
      ),
    );
  }

  String _interactionIcon(String type) => switch (type) {
    'message' => 'chat/chat-bubble.svg',
    'call' => 'common/phone.svg',
    'meeting' => 'common/users.svg',
    'meal' => 'common/sparkles.svg',
    _ => 'common/circle.svg',
  };

  String _interactionTitle(Interaction i) => switch (i.type) {
    'message' => '消息',
    'call' => '通话',
    'meeting' => '见面',
    'meal' => '饭局',
    _ => '其他',
  };

  String _favorTitle(Favor f) => switch (f.direction) {
    'i_owe' => '我欠对方',
    'they_owe' => '对方欠我',
    'gift_given' => '送出了礼物',
    'gift_received' => '收到一份礼物',
    _ => '人情往来',
  };

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60 && diff.inMinutes >= 0) {
      return diff.inMinutes == 0 ? '刚刚' : '${diff.inMinutes} 分钟前';
    }
    if (diff.inHours < 24 && diff.inHours >= 0) {
      return '${diff.inHours} 小时前';
    }
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}

enum _EventKind { interaction, favor }

class _MixedEvent {
  final DateTime at;
  final _EventKind kind;
  final Object data;
  _MixedEvent({required this.at, required this.kind, required this.data});
}

// ============================================================
// Tab Bar
// ============================================================

class _TabBar extends StatelessWidget {
  final TabController controller;
  final ValueChanged<int> onChange;
  const _TabBar({required this.controller, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: BulterSpacing.l),
      decoration: BoxDecoration(
        color: BulterColors.surfaceMuted,
        borderRadius: BorderRadius.circular(BulterRadius.pill),
      ),
      child: TabBar(
        controller: controller,
        onTap: onChange,
        labelColor: BulterColors.ctaText,
        unselectedLabelColor: BulterColors.textSecondary,
        indicator: BoxDecoration(
          color: BulterColors.cta,
          borderRadius: BorderRadius.circular(BulterRadius.pill),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        labelStyle: const TextStyle(
          fontSize: BulterFontSize.body,
          fontWeight: BulterFontWeight.semibold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: BulterFontSize.body,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: '互动'),
          Tab(text: '人情'),
        ],
      ),
    );
  }
}

// ============================================================
// Tab 内容：互动 / 人情
// ============================================================

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
      padding: const EdgeInsets.fromLTRB(
        BulterSpacing.l,
        BulterSpacing.m,
        BulterSpacing.l,
        BulterSpacing.huge,
      ),
      itemBuilder: (context, i, idx) => _InteractionRow(interaction: i),
    );
  }
}

class _InteractionRow extends StatelessWidget {
  final Interaction interaction;
  const _InteractionRow({required this.interaction});

  @override
  Widget build(BuildContext context) {
    return ListCard(
      brandColor: BulterColors.relationship,
      child: Row(
        children: [
          SvgIcon(
            'common/clock.svg',
            size: 16,
            color: BulterColors.textSecondary,
          ),
          const SizedBox(width: BulterSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
          emptyIconName: 'common/handshake.svg',
          padding: const EdgeInsets.fromLTRB(
            BulterSpacing.l,
            BulterSpacing.m,
            BulterSpacing.l,
            BulterSpacing.huge,
          ),
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

// ============================================================
// FAB
// ============================================================

class _Fab extends StatelessWidget {
  final int index;
  final VoidCallback onAddInteraction;
  final VoidCallback onAddFavor;
  const _Fab({
    required this.index,
    required this.onAddInteraction,
    required this.onAddFavor,
  });

  @override
  Widget build(BuildContext context) {
    final isInteraction = index == 0;
    return FloatingActionButton.extended(
      onPressed: isInteraction ? onAddInteraction : onAddFavor,
      backgroundColor: BulterColors.cta,
      foregroundColor: BulterColors.ctaText,
      elevation: 0,
      icon: SvgIcon('common/plus.svg', size: 16, color: BulterColors.ctaText),
      label: Text(isInteraction ? '记一笔' : '记人情'),
    );
  }
}
