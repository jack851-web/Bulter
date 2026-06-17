import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'svg_icon.dart';

/// AI 常驻入口：黑色圆形按钮 + 闪光图标。点击进入对话。
class AiChatFab extends StatelessWidget {
  final VoidCallback onTap;
  const AiChatFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: BulterShadow.fab,
      ),
      child: Material(
        color: BulterColors.cta,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 60,
            height: 60,
            child: Center(
              child: SvgIcon(
                'common/sparkles.svg',
                size: 26,
                color: BulterColors.ctaText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
