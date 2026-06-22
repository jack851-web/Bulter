import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ai/ai_service.dart';
import '../../ai/model_registry.dart';
import '../../components/bulter_scaffold.dart';
import '../../components/svg_icon.dart';
import '../../modules/registry.dart';
import '../../theme/tokens.dart';
import 'model_config_page.dart';

/// 设置页（对齐 phone-11 原型）。
///
/// **结构**：
///   1) 顶部用户卡（圆形品牌色头像 + 名字 + 简介 + chevron）
///   2) AI 助理 section（模型 / API Key / 长期记忆 / 用户画像）
///   3) 模块入口 section（关系 / 成长 / 财富 / 思想 / 健康 / 记忆）
///   4) 数据 section（导出 / 导入 - 占位）
///   5) 关于
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final active = ModelRegistry.instance.active;
    final apiStatus = active.apiKey.isNotEmpty ? '已配置' : '未配置';
    final modelStatus = '${active.vendorLabel} · ${active.model}';
    final modules = ModuleRegistry.instance.capsuleModules;

    return BulterScaffold(
      title: '设置',
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          BulterSpacing.l,
          BulterSpacing.s,
          BulterSpacing.l,
          BulterSpacing.huge,
        ),
        children: [
          const _UserCard(),
          const SizedBox(height: BulterSpacing.xl),
          _Section(
            title: 'AI 助理',
            items: [
              _Item(
                icon: 'settings/model.svg',
                title: '模型',
                subtitle: modelStatus,
                onTap: () => _push(context, const ModelConfigPage()),
              ),
              _Item(
                icon: 'settings/key.svg',
                title: 'API Key',
                subtitle: apiStatus,
                onTap: () => _push(context, const ModelConfigPage()),
              ),
              _Item(
                icon: 'modules/memory.svg',
                title: '长期记忆',
                subtitle: '查看 / 管理 AI 记住的内容',
                onTap: () => context.pushNamed('memory'),
              ),
              _Item(
                icon: 'common/user.svg',
                title: '用户画像',
                subtitle: '查看 / 编辑 AI 提取的关于你的信息',
                onTap: () => context.pushNamed('settings.profile'),
              ),
            ],
          ),
          const SizedBox(height: BulterSpacing.l),
          _Section(
            title: '模块',
            items: [
              for (final m in modules.where((m) => m.id != 'butler'))
                _Item(
                  icon: _iconFor(m.id),
                  title: m.displayName,
                  subtitle: _subtitleFor(m.id),
                  brandColor: m.brandColor,
                ),
            ],
          ),
          const SizedBox(height: BulterSpacing.l),
          _Section(
            title: '数据',
            items: const [
              _Item(
                icon: 'common/download.svg',
                title: '导出数据',
                subtitle: '即将推出',
              ),
              _Item(icon: 'common/upload.svg', title: '导入数据', subtitle: '即将推出'),
            ],
          ),
          const SizedBox(height: BulterSpacing.l),
          _Section(
            title: '关于',
            items: const [
              _Item(
                icon: 'common/info.svg',
                title: '关于 Bulter',
                subtitle: 'v0.5.0 · Step 5',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  static String _iconFor(String id) => switch (id) {
    'relationship' => 'modules/relationship.svg',
    'growth' => 'modules/growth.svg',
    'wealth' => 'modules/wealth.svg',
    'thought' => 'modules/thought.svg',
    'health' => 'modules/health.svg',
    'memory' => 'modules/memory.svg',
    'demo' => 'common/circle.svg',
    _ => 'common/circle.svg',
  };

  static String _subtitleFor(String id) => switch (id) {
    'relationship' => '人脉 · 关怀',
    'growth' => '目标 · 学习',
    'wealth' => '账户 · 流水',
    'thought' => '想法 · 信件',
    'health' => '记录 · 体检',
    'memory' => 'RAG 语义记忆',
    'demo' => '模块化验证',
    _ => '',
  };
}

// ============================================================
// 用户卡
// ============================================================

class _UserCard extends StatefulWidget {
  const _UserCard();

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  late Future<_UserInfo> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_UserInfo> _load() async {
    final mem = AiService.rag?.memory;
    if (mem == null) {
      return const _UserInfo(
        displayName: null,
        occupation: null,
        location: null,
      );
    }
    try {
      final p = await mem.userProfile.current();
      return _UserInfo(
        displayName: p.displayName,
        occupation: p.occupation,
        location: p.location,
      );
    } catch (_) {
      return const _UserInfo(
        displayName: null,
        occupation: null,
        location: null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BulterColors.surface,
      borderRadius: BorderRadius.circular(BulterRadius.l),
      child: InkWell(
        borderRadius: BorderRadius.circular(BulterRadius.l),
        onTap: () async {
          await context.pushNamed('settings.profile');
          if (mounted) setState(() => _future = _load());
        },
        child: Container(
          padding: const EdgeInsets.all(BulterSpacing.l),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BulterRadius.l),
            border: Border.all(color: BulterColors.divider, width: 0.5),
          ),
          child: FutureBuilder<_UserInfo>(
            future: _future,
            builder: (ctx, snap) {
              final info = snap.data;
              final name = info?.displayName?.trim().isNotEmpty == true
                  ? info!.displayName!.trim()
                  : '小明';
              final bio = _buildBio(info);
              final firstChar = name.isEmpty ? '?' : name.characters.first;
              return Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          BulterColors.relationship,
                          BulterColors.butler,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(BulterRadius.l),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      firstChar,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: BulterFontWeight.heavy,
                        color: BulterColors.ctaText,
                      ),
                    ),
                  ),
                  const SizedBox(width: BulterSpacing.l),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: BulterFontSize.titleS,
                            fontWeight: BulterFontWeight.semibold,
                            color: BulterColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bio,
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
                  const SvgIcon(
                    'common/chevron-right.svg',
                    size: 18,
                    color: BulterColors.textTertiary,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 拼简介：occupation / location 任一非空 → "occupation · location"。
  /// 都为空 → 显示提示让用户去设置。
  String _buildBio(_UserInfo? info) {
    if (info == null) return '点击右上角"用户画像"完善信息';
    final parts = <String>[];
    final occ = info.occupation?.trim();
    final loc = info.location?.trim();
    if (occ != null && occ.isNotEmpty) parts.add(occ);
    if (loc != null && loc.isNotEmpty) parts.add(loc);
    if (parts.isEmpty) return '点击右上角"用户画像"完善信息';
    return parts.join(' · ');
  }
}

class _UserInfo {
  final String? displayName;
  final String? occupation;
  final String? location;
  const _UserInfo({
    required this.displayName,
    required this.occupation,
    required this.location,
  });
}

// ============================================================
// Section（统一圆角卡容器）
// ============================================================

class _Section extends StatelessWidget {
  final String title;
  final List<_Item> items;
  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BulterSpacing.xs,
            vertical: BulterSpacing.s,
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: BulterFontSize.footnote,
              color: BulterColors.textSecondary,
              fontWeight: BulterFontWeight.semibold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: BulterColors.surface,
            borderRadius: BorderRadius.circular(BulterRadius.l),
            border: Border.all(color: BulterColors.divider, width: 0.5),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  const Divider(height: 0.5, indent: BulterSpacing.l + 40),
                _ItemTile(item: items[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Item {
  final String icon;
  final String title;
  final String subtitle;
  final Color? brandColor;
  final VoidCallback? onTap;
  const _Item({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.brandColor,
    this.onTap,
  });
}

class _ItemTile extends StatelessWidget {
  final _Item item;
  const _ItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.brandColor ?? BulterColors.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BulterSpacing.l,
            vertical: BulterSpacing.m + 2,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(BulterRadius.s),
                ),
                alignment: Alignment.center,
                child: SvgIcon(item.icon, size: 16, color: color),
              ),
              const SizedBox(width: BulterSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: BulterFontSize.body,
                        color: BulterColors.textPrimary,
                        fontWeight: BulterFontWeight.medium,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
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
              if (item.onTap != null)
                const SvgIcon(
                  'common/chevron-right.svg',
                  size: 18,
                  color: BulterColors.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
