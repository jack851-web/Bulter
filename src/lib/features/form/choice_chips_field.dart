import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 单选胶囊（segment-like）选择器。
///
/// 适合"关系类型 / 收支类型 / 优先级"等枚举字段。
class ChoiceChipsField extends StatelessWidget {
  final String? label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final Color? brandColor;
  final Map<String, String>? labels; // option → 中文展示

  const ChoiceChipsField({
    super.key,
    this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.brandColor,
    this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final accent = brandColor ?? BulterColors.cta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: BulterFontSize.footnote,
              fontWeight: BulterFontWeight.semibold,
              color: BulterColors.textSecondary,
            ),
          ),
          const SizedBox(height: BulterSpacing.s),
        ],
        Wrap(
          spacing: BulterSpacing.s,
          runSpacing: BulterSpacing.s,
          children: [
            for (final opt in options)
              InkWell(
                borderRadius: BorderRadius.circular(BulterRadius.pill),
                onTap: () => onChanged(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: BulterSpacing.l,
                    vertical: BulterSpacing.s + 2,
                  ),
                  decoration: BoxDecoration(
                    color: value == opt ? accent : BulterColors.surface,
                    borderRadius: BorderRadius.circular(BulterRadius.pill),
                    border: Border.all(
                      color: value == opt ? accent : BulterColors.divider,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    labels?[opt] ?? opt,
                    style: TextStyle(
                      color: value == opt
                          ? (accent == BulterColors.cta
                              ? BulterColors.ctaText
                              : BulterColors.textPrimary)
                          : BulterColors.textPrimary,
                      fontSize: BulterFontSize.body,
                      fontWeight: value == opt
                          ? BulterFontWeight.semibold
                          : BulterFontWeight.medium,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
