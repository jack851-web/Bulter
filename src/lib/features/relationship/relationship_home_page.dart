import 'package:bulter/db/app_database.dart';
import 'package:flutter/material.dart';

import '../../components/svg_icon.dart';
import '../../theme/tokens.dart';
import '../form/chips_input.dart' as chips_util;
import '../form/stream_list_view.dart';
import 'contact_detail.dart';
import 'contact_form.dart';

/// 关系模块主页（对齐 phone-04 原型）。
///
/// **结构**：
///   1) 顶部问候（"早安，小布" + 日期）
///   2) 粉色 AI 关系画像卡（带 4 个数据指标）
///   3) 3 个数据方块（待联系 / 重要 / 人情未还）
///   4) 今日回候（按上次联系天数排序的联系人）
///   5) 联系人完整列表（紧凑行）
class RelationshipHomePage extends StatelessWidget {
  const RelationshipHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Contact>>(
      stream: AppDatabase.I.relationshipDao.watchContacts(),
      builder: (context, snap) {
        final contacts = snap.data ?? const <Contact>[];
        return StreamBuilder<List<Interaction>>(
          stream: AppDatabase.I.relationshipDao.watchAllInteractions(),
          builder: (context, iSnap) {
            final allInteractions = iSnap.data ?? const <Interaction>[];
            return StreamBuilder<List<Favor>>(
              stream: AppDatabase.I.relationshipDao.watchOpenFavors(),
              builder: (context, fSnap) {
                final favors = fSnap.data ?? const <Favor>[];
                return _Body(
                  contacts: contacts,
                  interactions: allInteractions,
                  openFavors: favors.length,
                );
              },
            );
          },
        );
      },
    );
  }

  static void openAddContact(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContactForm(
          title: '新增联系人',
          onSubmit: (data) async {
            await AppDatabase.I.relationshipDao.insertContact(data);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  static void openContact(BuildContext context, Contact c) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContactDetailPage(contactId: c.id),
      ),
    );
  }
}

// ============================================================
// 主页体
// ============================================================

class _Body extends StatelessWidget {
  final List<Contact> contacts;
  final List<Interaction> interactions;
  final int openFavors;

  const _Body({
    required this.contacts,
    required this.interactions,
    required this.openFavors,
  });

  @override
  Widget build(BuildContext context) {
    // 统计：每人的最近互动时间
    final lastContact = <int, DateTime>{};
    for (final i in interactions) {
      final prev = lastContact[i.contactId];
      if (prev == null || i.happenedAt.isAfter(prev)) {
        lastContact[i.contactId] = i.happenedAt;
      }
    }

    // 待回候：按最后联系天数倒序，取前 3
    final sorted = [...contacts]
      ..sort((a, b) {
        final la = lastContact[a.id] ?? DateTime(2000);
        final lb = lastContact[b.id] ?? DateTime(2000);
        return la.compareTo(lb);
      });
    final needsFollowup = sorted
        .where((c) => c.importance >= 5)
        .take(3)
        .toList();

    // 重要联系人（importance >= 7）
    final important = contacts.where((c) => c.importance >= 7).length;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        BulterSpacing.l,
        BulterSpacing.l,
        BulterSpacing.l,
        BulterSpacing.huge,
      ),
      children: [
        const _Greeting(),
        const SizedBox(height: BulterSpacing.l),
        _AiRelationshipCard(contactCount: contacts.length),
        const SizedBox(height: BulterSpacing.l),
        _StatBlocks(
          followupCount: needsFollowup.length,
          importantCount: important,
          favorCount: openFavors,
        ),
        const SizedBox(height: BulterSpacing.xl),
        _FollowupSection(contacts: needsFollowup, lastContact: lastContact),
        const SizedBox(height: BulterSpacing.xl),
        const _AllContactsHeader(),
        const SizedBox(height: BulterSpacing.s),
        if (contacts.isEmpty)
          _EmptyHint(onAdd: () => RelationshipHomePage.openAddContact(context))
        else
          ...contacts.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: BulterSpacing.s),
              child: _ContactRow(contact: c, lastContact: lastContact[c.id]),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// 问候
// ============================================================

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 6
        ? '凌晨'
        : hour < 11
        ? '早安'
        : hour < 13
        ? '中午'
        : hour < 18
        ? '下午'
        : '晚上';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting，小布',
          style: const TextStyle(
            fontSize: BulterFontSize.titleM,
            fontWeight: BulterFontWeight.semibold,
            color: BulterColors.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '周一 · 4 月 8 日',
          style: const TextStyle(
            fontSize: BulterFontSize.footnote,
            color: BulterColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// AI 关系画像（粉色卡）
// ============================================================

class _AiRelationshipCard extends StatelessWidget {
  final int contactCount;
  const _AiRelationshipCard({required this.contactCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BulterSpacing.l),
      decoration: BoxDecoration(
        color: BulterColors.relationship.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(BulterRadius.xl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: BulterColors.relationship,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: BulterSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Text(
                      'AI 关系画像',
                      style: TextStyle(
                        fontSize: BulterFontSize.footnote,
                        color: BulterColors.relationship,
                        fontWeight: BulterFontWeight.semibold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '你的核心关系 5 人\n李华、妈妈、王老师是 3 个\n建议定期关怀。',
                  style: const TextStyle(
                    fontSize: BulterFontSize.body,
                    color: BulterColors.textPrimary,
                    fontWeight: BulterFontWeight.semibold,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 3 个数据方块
// ============================================================

class _StatBlocks extends StatelessWidget {
  final int followupCount;
  final int importantCount;
  final int favorCount;
  const _StatBlocks({
    required this.followupCount,
    required this.importantCount,
    required this.favorCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatBlock(
          label: '待回候',
          value: followupCount.toString(),
          trend: '人',
          color: BulterColors.relationship,
        ),
        const SizedBox(width: BulterSpacing.s),
        _StatBlock(
          label: '重要',
          value: importantCount.toString(),
          trend: '人',
          color: BulterColors.warning,
        ),
        const SizedBox(width: BulterSpacing.s),
        _StatBlock(
          label: '人情未还',
          value: favorCount.toString(),
          trend: '笔',
          color: BulterColors.error,
        ),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final String trend;
  final Color color;
  const _StatBlock({
    required this.label,
    required this.value,
    required this.trend,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(BulterSpacing.m),
        decoration: BoxDecoration(
          color: BulterColors.surface,
          borderRadius: BorderRadius.circular(BulterRadius.l),
          border: Border.all(color: BulterColors.divider, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: BulterFontSize.caption,
                    color: BulterColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: BulterFontSize.titleM,
                    fontWeight: BulterFontWeight.bold,
                    color: BulterColors.textPrimary,
                    height: 1.0,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  trend,
                  style: const TextStyle(
                    fontSize: BulterFontSize.caption,
                    color: BulterColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 今日回候
// ============================================================

class _FollowupSection extends StatelessWidget {
  final List<Contact> contacts;
  final Map<int, DateTime> lastContact;
  const _FollowupSection({required this.contacts, required this.lastContact});

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '今日回候',
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
                color: BulterColors.relationship,
                borderRadius: BorderRadius.circular(BulterRadius.pill),
              ),
              child: Text(
                contacts.length.toString(),
                style: const TextStyle(
                  fontSize: BulterFontSize.caption,
                  color: BulterColors.ctaText,
                  fontWeight: BulterFontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: BulterSpacing.s),
        ...contacts.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: BulterSpacing.s),
            child: _FollowupRow(contact: c, lastContact: lastContact[c.id]),
          ),
        ),
      ],
    );
  }
}

class _FollowupRow extends StatelessWidget {
  final Contact contact;
  final DateTime? lastContact;
  const _FollowupRow({required this.contact, this.lastContact});

  @override
  Widget build(BuildContext context) {
    final days = lastContact == null
        ? null
        : DateTime.now().difference(lastContact!).inDays;
    return Material(
      color: BulterColors.surface,
      borderRadius: BorderRadius.circular(BulterRadius.l),
      child: InkWell(
        borderRadius: BorderRadius.circular(BulterRadius.l),
        onTap: () => RelationshipHomePage.openContact(context, contact),
        child: Container(
          padding: const EdgeInsets.all(BulterSpacing.m),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BulterRadius.l),
            border: Border.all(color: BulterColors.divider, width: 0.6),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: BulterColors.relationship.withValues(
                  alpha: 0.15,
                ),
                child: Text(
                  contact.name.isNotEmpty ? contact.name.characters.first : '?',
                  style: const TextStyle(
                    color: BulterColors.relationship,
                    fontWeight: BulterFontWeight.bold,
                    fontSize: BulterFontSize.titleS,
                  ),
                ),
              ),
              const SizedBox(width: BulterSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(
                        fontSize: BulterFontSize.bodyLg,
                        fontWeight: BulterFontWeight.semibold,
                        color: BulterColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      days == null ? '从未联系' : '上次联系 $days 天前',
                      style: TextStyle(
                        fontSize: BulterFontSize.caption,
                        color: days == null
                            ? BulterColors.textTertiary
                            : (days > 14
                                  ? BulterColors.relationship
                                  : BulterColors.textSecondary),
                        fontWeight: days != null && days > 14
                            ? BulterFontWeight.semibold
                            : BulterFontWeight.regular,
                      ),
                    ),
                  ],
                ),
              ),
              _FollowupAction(label: '回候', onTap: () => _greet(context)),
            ],
          ),
        ),
      ),
    );
  }

  void _greet(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已为「${contact.name}」准备问候草稿'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BulterRadius.m),
        ),
        margin: const EdgeInsets.all(BulterSpacing.l),
      ),
    );
  }
}

class _FollowupAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FollowupAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BulterColors.relationship.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(BulterRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(BulterRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BulterSpacing.m,
            vertical: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SvgIcon(
                'common/heart.svg',
                size: 12,
                color: BulterColors.relationship,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: BulterFontSize.caption,
                  color: BulterColors.relationship,
                  fontWeight: BulterFontWeight.bold,
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
// 联系人完整列表
// ============================================================

class _AllContactsHeader extends StatelessWidget {
  const _AllContactsHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Text(
          '联系人',
          style: TextStyle(
            fontSize: BulterFontSize.titleS,
            fontWeight: BulterFontWeight.semibold,
            color: BulterColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final Contact contact;
  final DateTime? lastContact;
  const _ContactRow({required this.contact, this.lastContact});

  static const _relLabels = {
    'friend': '朋友',
    'family': '家人',
    'colleague': '同事',
    'mentor': '师长',
  };

  @override
  Widget build(BuildContext context) {
    final tags = chips_util.jsonToTags(contact.tagsJson);
    final rel =
        _relLabels[contact.relationshipType] ?? contact.relationshipType;
    final last = lastContact == null ? '未联系' : _relativeTime(lastContact!);
    return ListCard(
      brandColor: BulterColors.relationship,
      onTap: () => RelationshipHomePage.openContact(context, contact),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: BulterColors.relationship.withValues(alpha: 0.15),
            child: Text(
              contact.name.isNotEmpty ? contact.name.characters.first : '?',
              style: const TextStyle(
                color: BulterColors.relationship,
                fontWeight: BulterFontWeight.bold,
                fontSize: BulterFontSize.titleS,
              ),
            ),
          ),
          const SizedBox(width: BulterSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: BulterFontSize.bodyLg,
                    fontWeight: BulterFontWeight.semibold,
                    color: BulterColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$rel · ${tags.isEmpty ? "无标签" : tags.take(2).join("/")} · $last',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: BulterFontSize.footnote,
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

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inDays < 1) return '今天';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} 周前';
    return '${(diff.inDays / 30).floor()} 个月前';
  }
}

// ============================================================
// 空态
// ============================================================

class _EmptyHint extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyHint({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BulterSpacing.xl),
      decoration: BoxDecoration(
        color: BulterColors.relationship.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BulterRadius.xl),
      ),
      child: Column(
        children: [
          const SvgIcon(
            'modules/relationship.svg',
            size: 32,
            color: BulterColors.relationship,
          ),
          const SizedBox(height: BulterSpacing.s),
          const Text(
            '还没有联系人',
            style: TextStyle(
              fontSize: BulterFontSize.titleS,
              fontWeight: BulterFontWeight.semibold,
              color: BulterColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '添加家人、朋友、同事，开始编织你的关系网',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: BulterFontSize.footnote,
              color: BulterColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: BulterSpacing.m),
          Material(
            color: BulterColors.relationship,
            borderRadius: BorderRadius.circular(BulterRadius.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(BulterRadius.pill),
              onTap: onAdd,
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: BulterSpacing.l,
                  vertical: 8,
                ),
                child: Text(
                  '添加第一个联系人',
                  style: TextStyle(
                    fontSize: BulterFontSize.footnote,
                    color: BulterColors.ctaText,
                    fontWeight: BulterFontWeight.semibold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
