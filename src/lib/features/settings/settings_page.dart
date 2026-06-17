import 'package:flutter/material.dart';

import '../../components/bulter_scaffold.dart';
import '../../theme/tokens.dart';

/// 设置页（Step 1 占位，Step 4 后接入模型配置 / 数据导出等）
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BulterScaffold(
      title: '设置',
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: BulterSpacing.s),
          _Section(
            title: 'AI',
            items: const [
              _Item(
                icon: Icons.key_rounded,
                title: 'API Key',
                subtitle: 'Step 4 接入',
              ),
              _Item(
                icon: Icons.model_training_rounded,
                title: '模型',
                subtitle: '默认 MiniMax M3',
              ),
            ],
          ),
          const SizedBox(height: BulterSpacing.l),
          _Section(
            title: '数据',
            items: const [
              _Item(
                icon: Icons.download_rounded,
                title: '导出数据',
                subtitle: 'Step 20 接入',
              ),
              _Item(
                icon: Icons.upload_rounded,
                title: '导入数据',
                subtitle: 'Step 20 接入',
              ),
            ],
          ),
          const SizedBox(height: BulterSpacing.l),
          _Section(
            title: '关于',
            items: const [
              _Item(
                icon: Icons.info_outline_rounded,
                title: '关于 Bulter',
                subtitle: 'v0.1.0 · Step 1',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
                if (i > 0) const Divider(height: 0.5, indent: BulterSpacing.l + 32),
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
  final IconData icon;
  final String title;
  final String subtitle;
  const _Item({required this.icon, required this.title, required this.subtitle});
}

class _ItemTile extends StatelessWidget {
  final _Item item;
  const _ItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BulterSpacing.l,
            vertical: BulterSpacing.m + 2,
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 20, color: BulterColors.textPrimary),
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
                      style: const TextStyle(
                        fontSize: BulterFontSize.footnote,
                        color: BulterColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: BulterColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
