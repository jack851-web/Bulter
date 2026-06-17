import 'package:flutter/material.dart';

import '../../components/empty_state.dart';
import '../../theme/tokens.dart';

/// 通用模块占位页（Step 1 用，Step 3 起改为真实 CRUD）。
///
/// 展示模块品牌色 + 名称 + "建设中"提示，确保切换流畅、品牌色一致。
class ModulePlaceholderPage extends StatelessWidget {
  final String moduleName;
  final Color brandColor;
  final IconData icon;
  final List<String> features;

  const ModulePlaceholderPage({
    super.key,
    required this.moduleName,
    required this.brandColor,
    required this.icon,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        BulterSpacing.l,
        BulterSpacing.l,
        BulterSpacing.l,
        BulterSpacing.huge,
      ),
      children: [
        // 模块头
        Container(
          padding: const EdgeInsets.all(BulterSpacing.xl),
          decoration: BoxDecoration(
            color: brandColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(BulterRadius.xxl),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: brandColor,
                  borderRadius: BorderRadius.circular(BulterRadius.l),
                ),
                child: Icon(icon, color: BulterColors.ctaText, size: 28),
              ),
              const SizedBox(width: BulterSpacing.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moduleName,
                      style: const TextStyle(
                        fontSize: BulterFontSize.titleL,
                        fontWeight: BulterFontWeight.bold,
                        color: BulterColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: BulterSpacing.xxs),
                    const Text(
                      'Step 1 阶段 · 基础骨架就绪',
                      style: TextStyle(
                        fontSize: BulterFontSize.footnote,
                        color: BulterColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: BulterSpacing.xl),
        const Text(
          '本模块将提供',
          style: TextStyle(
            fontSize: BulterFontSize.titleS,
            fontWeight: BulterFontWeight.semibold,
            color: BulterColors.textPrimary,
          ),
        ),
        const SizedBox(height: BulterSpacing.m),
        ...features.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: BulterSpacing.s),
            child: Container(
              padding: const EdgeInsets.all(BulterSpacing.l),
              decoration: BoxDecoration(
                color: BulterColors.surface,
                borderRadius: BorderRadius.circular(BulterRadius.l),
                border: Border.all(color: BulterColors.divider, width: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: brandColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: BulterSpacing.m),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                        fontSize: BulterFontSize.body,
                        color: BulterColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: BulterSpacing.xl),
        const EmptyState(
          icon: Icons.handyman_outlined,
          title: '基础架构就绪',
          hint: '完整功能将在后续 Step 中接入',
        ),
      ],
    );
  }
}
