import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 模块快览卡片（主页 Bento 4 卡之一）。
class ModuleCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? badge;
  final Color brandColor;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  const ModuleCard({
    super.key,
    required this.title,
    required this.brandColor,
    required this.icon,
    this.subtitle,
    this.badge,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(BulterRadius.xl),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(BulterSpacing.l),
          decoration: BoxDecoration(
            color: BulterColors.surface,
            borderRadius: BorderRadius.circular(BulterRadius.xl),
            border: Border.all(color: BulterColors.divider, width: 0.5),
            boxShadow: BulterShadow.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: brandColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(BulterRadius.m),
                    ),
                    child: Icon(icon, color: brandColor, size: 18),
                  ),
                  const Spacer(),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BulterSpacing.s,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: brandColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(BulterRadius.pill),
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          color: brandColor,
                          fontSize: BulterFontSize.caption,
                          fontWeight: BulterFontWeight.semibold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: BulterSpacing.m),
              Text(
                title,
                style: const TextStyle(
                  fontSize: BulterFontSize.titleS,
                  fontWeight: BulterFontWeight.semibold,
                  color: BulterColors.textPrimary,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: BulterSpacing.xs),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: BulterFontSize.footnote,
                    color: BulterColors.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(height: BulterSpacing.m),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
