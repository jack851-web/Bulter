import 'package:flutter/material.dart';

import '../bulter_module.dart';
import '../module_placeholder_page.dart';
import '../../theme/tokens.dart';

/// 关系模块
class RelationshipModule implements BulterModule {
  const RelationshipModule();

  @override
  String get id => ModuleId.relationship;

  @override
  String get displayName => '关系';

  @override
  Color get brandColor => BulterColors.relationship;

  @override
  String get iconName => 'heart';

  @override
  String get entryRoute => '/relationship';

  @override
  Widget buildHomePage(BuildContext context) => const ModulePlaceholderPage(
        moduleName: '关系',
        brandColor: BulterColors.relationship,
        icon: Icons.favorite_rounded,
        features: [
          '联系人 CRUD · 标签 · 备注 · 最近互动',
          '互动记录（通话 / 见面 / 消息）',
          '关系分组（家人 / 朋友 / 同事 / 客户）',
          '聊天记录导入（截图识别 → 结构化）',
          '智能回复建议（基于历史风格）',
          '约定管理（到期提醒）',
          '人情往来记录（送礼 / 收礼）',
          '关系图谱（Web 端可视化）',
        ],
      );

  @override
  List<ModuleTab> get tabs => const [
        ModuleTab(
          id: 'list',
          label: '联系人',
          icon: Icons.people_alt_outlined,
          builder: _placeholder,
        ),
        ModuleTab(
          id: 'timeline',
          label: '互动',
          icon: Icons.timeline_rounded,
          builder: _placeholder,
        ),
        ModuleTab(
          id: 'favors',
          label: '人情',
          icon: Icons.redeem_rounded,
          builder: _placeholder,
        ),
        ModuleTab(
          id: 'appts',
          label: '约定',
          icon: Icons.event_note_rounded,
          builder: _placeholder,
        ),
      ];

  @override
  SpecialistAgent? get subAgent => const SpecialistAgent(
        moduleId: ModuleId.relationship,
        name: 'Relation Specialist',
      );

  @override
  List<ToolDefinition> get tools => const [];

  @override
  BriefingGenerator? get briefingGenerator => null;

  @override
  Future<void> onRegister() async {}

  @override
  Future<void> onDispose() async {}
}

Widget _placeholder(BuildContext context) => const SizedBox.shrink();
