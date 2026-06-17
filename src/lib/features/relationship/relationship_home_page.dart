import 'package:bulter/db/app_database.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../form/chips_input.dart' as chips_util;
import '../form/stream_list_view.dart';
import 'contact_detail.dart';
import 'contact_form.dart';

/// 关系模块主页。
///
/// 顶部为联系人总览卡 + 添加按钮，下方为联系人列表。
/// 点击联系人进入详情页（互动 + 人情）。
class RelationshipHomePage extends StatelessWidget {
  const RelationshipHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Overview(),
        const Expanded(
          child: _ContactList(),
        ),
      ],
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

class _Overview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Contact>>(
      stream: AppDatabase.I.relationshipDao.watchContacts(),
      builder: (context, snap) {
        final count = snap.data?.length ?? 0;
        return Container(
          margin: const EdgeInsets.fromLTRB(
            BulterSpacing.l,
            BulterSpacing.s,
            BulterSpacing.l,
            BulterSpacing.l,
          ),
          padding: const EdgeInsets.all(BulterSpacing.xl),
          decoration: BoxDecoration(
            color: BulterColors.relationship.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(BulterRadius.xxl),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: BulterColors.relationship,
                  borderRadius: BorderRadius.circular(BulterRadius.l),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: BulterColors.ctaText,
                  size: 24,
                ),
              ),
              const SizedBox(width: BulterSpacing.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '联系人 $count 位',
                      style: const TextStyle(
                        fontSize: BulterFontSize.titleS,
                        fontWeight: BulterFontWeight.semibold,
                        color: BulterColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '让关系网被看见',
                      style: TextStyle(
                        fontSize: BulterFontSize.footnote,
                        color: BulterColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: () => RelationshipHomePage.openAddContact(context),
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: BulterColors.cta,
                  foregroundColor: BulterColors.ctaText,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContactList extends StatelessWidget {
  const _ContactList();

  @override
  Widget build(BuildContext context) {
    return StreamListView<Contact>(
      stream: AppDatabase.I.relationshipDao.watchContacts(),
      brandColor: BulterColors.relationship,
      emptyTitle: '还没有联系人',
      emptyHint: '添加家人、朋友、同事，开始编织你的关系网',
      emptyIcon: Icons.people_alt_outlined,
      itemBuilder: (context, c, idx) {
        return _ContactRow(contact: c);
      },
    );
  }
}

class _ContactRow extends StatelessWidget {
  final Contact contact;
  const _ContactRow({required this.contact});

  @override
  Widget build(BuildContext context) {
    final tags = chips_util.jsonToTags(contact.tagsJson);
    return ListCard(
      brandColor: BulterColors.relationship,
      onTap: () => RelationshipHomePage.openContact(context, contact),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: BulterColors.textTertiary,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor:
                BulterColors.relationship.withValues(alpha: 0.15),
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
                  _subtitle(contact, tags),
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

  String _subtitle(Contact c, List<String> tags) {
    final parts = <String>[];
    parts.add(_relLabel(c.relationshipType));
    if (tags.isNotEmpty) parts.add(tags.take(2).join(' / '));
    if ((c.nickname ?? '').isNotEmpty) parts.add('昵称 ${c.nickname}');
    return parts.join(' · ');
  }

  static String _relLabel(String s) => switch (s) {
        'friend' => '朋友',
        'family' => '家人',
        'colleague' => '同事',
        'mentor' => '师长',
        _ => s,
      };
}
