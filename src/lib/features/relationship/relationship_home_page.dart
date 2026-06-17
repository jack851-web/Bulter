import 'package:bulter/db/app_database.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../form/chips_input.dart' as chips_util;
import '../form/stream_list_view.dart';
import 'contact_detail.dart';
import 'contact_form.dart';

/// 关系模块主页（原型：phone-04-relations.png）。
///
/// 布局：
///   1) 顶部问候 "早安，小布" + 时间
///   2) AI 洞察卡（粉色 alpha 0.10 底）
///   3) 3 个数据方块：待联系 / 重要 / 人情未还
///   4) 子模块 Tab：近期 / 待跟进 / 温暖 / 分析
///   5) 联系人列表（每项：头像 + 姓名 + 关系标签 + 时间 + "回候"/"回后" 按钮）
class RelationshipHomePage extends StatelessWidget {
  const RelationshipHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Greeting(),
        const _AiInsight(),
        const _StatBlocks(),
        const Expanded(child: _RecentTab()),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BulterSpacing.l,
        BulterSpacing.m,
        BulterSpacing.l,
        BulterSpacing.s,
      ),
      child: Text(
        '$greeting，小明',
        style: const TextStyle(
          fontSize: BulterFontSize.titleM,
          fontWeight: BulterFontWeight.semibold,
          color: BulterColors.textPrimary,
        ),
      ),
    );
  }
}

class _AiInsight extends StatelessWidget {
  const _AiInsight();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: BulterSpacing.l),
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
            height: 32,
            decoration: BoxDecoration(
              color: BulterColors.relationship,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: BulterSpacing.m),
          const Expanded(
            child: Text(
              '你的核心关系 5 人，\n王老师、李华、妈妈、本东、父亲。\n建议定期关怀。',
              style: TextStyle(
                fontSize: BulterFontSize.footnote,
                color: BulterColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlocks extends StatelessWidget {
  const _StatBlocks();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BulterSpacing.l,
        BulterSpacing.l,
        BulterSpacing.l,
        0,
      ),
      child: Row(
        children: const [
          _StatBlock(
            label: '待联系',
            value: '5',
            trend: '5 人',
            color: BulterColors.relationship,
          ),
          SizedBox(width: BulterSpacing.s),
          _StatBlock(
            label: '重要',
            value: '8',
            trend: '8 人',
            color: BulterColors.relationship,
          ),
          SizedBox(width: BulterSpacing.s),
          _StatBlock(
            label: '人情未还',
            value: '3',
            trend: '3 人',
            color: BulterColors.relationship,
          ),
        ],
      ),
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
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: BulterSpacing.xs),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: BulterFontSize.caption,
                    color: BulterColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: BulterSpacing.xs),
            Text(
              value,
              style: const TextStyle(
                fontSize: BulterFontSize.titleM,
                fontWeight: BulterFontWeight.bold,
                color: BulterColors.textPrimary,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              trend,
              style: const TextStyle(
                fontSize: BulterFontSize.caption,
                color: BulterColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTab extends StatelessWidget {
  const _RecentTab();

  @override
  Widget build(BuildContext context) {
    return StreamListView<Contact>(
      stream: AppDatabase.I.relationshipDao.watchContacts(),
      brandColor: BulterColors.relationship,
      emptyTitle: '还没有联系人',
      emptyHint: '添加家人、朋友、同事，开始编织你的关系网',
      emptyIconName: 'modules/relationship.svg',
      itemBuilder: (context, c, idx) => _ContactRow(contact: c),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final Contact contact;
  const _ContactRow({required this.contact});

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
                  '$rel · ${tags.isEmpty ? "无标签" : tags.take(2).join("/")}',
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
          const SizedBox(width: BulterSpacing.s),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: BulterColors.relationship,
              size: 18,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.send_outlined,
              color: BulterColors.relationship,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
