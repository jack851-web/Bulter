import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// AI 洞察大卡（主页 Bento 第 1 张）。
class AiInsightCard extends StatelessWidget {
  final String headline;
  final String body;
  final VoidCallback? onTap;

  const AiInsightCard({
    super.key,
    required this.headline,
    required this.body,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(BulterRadius.xxl),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(BulterSpacing.xl),
          decoration: BoxDecoration(
            color: BulterColors.cta,
            borderRadius: BorderRadius.circular(BulterRadius.xxl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: BulterColors.butler,
                      borderRadius: BorderRadius.circular(BulterRadius.s),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: BulterColors.cta,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: BulterSpacing.s),
                  const Text(
                    'AI 洞察',
                    style: TextStyle(
                      color: BulterColors.ctaText,
                      fontSize: BulterFontSize.footnote,
                      fontWeight: BulterFontWeight.medium,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BulterSpacing.l),
              Text(
                headline,
                style: const TextStyle(
                  color: BulterColors.ctaText,
                  fontSize: BulterFontSize.titleL,
                  fontWeight: BulterFontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: BulterSpacing.m),
              Text(
                body,
                style: TextStyle(
                  color: BulterColors.ctaText.withValues(alpha: 0.78),
                  fontSize: BulterFontSize.body,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
