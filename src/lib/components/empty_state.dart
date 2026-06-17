import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 通用空状态组件
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BulterSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: BulterColors.surfaceMuted,
                borderRadius: BorderRadius.circular(BulterRadius.xxl),
              ),
              child: Icon(icon, size: 32, color: BulterColors.textSecondary),
            ),
            const SizedBox(height: BulterSpacing.l),
            Text(
              title,
              style: const TextStyle(
                fontSize: BulterFontSize.titleS,
                fontWeight: BulterFontWeight.semibold,
                color: BulterColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (hint != null) ...[
              const SizedBox(height: BulterSpacing.s),
              Text(
                hint!,
                style: const TextStyle(
                  fontSize: BulterFontSize.body,
                  color: BulterColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: BulterSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
