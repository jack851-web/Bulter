import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 1-5 星评分输入。常用于学习记录打分。
class RatingInput extends StatelessWidget {
  final String? label;
  final int? value; // 1-5；null = 未评分
  final ValueChanged<int?> onChanged;
  final double size;
  final Color activeColor;

  const RatingInput({
    super.key,
    this.label,
    required this.value,
    required this.onChanged,
    this.size = 32,
    this.activeColor = BulterColors.warning,
  });

  @override
  Widget build(BuildContext context) {
    final v = value ?? 0;
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
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              Padding(
                padding: const EdgeInsets.only(right: BulterSpacing.xs),
                child: InkResponse(
                  radius: size * 0.6,
                  onTap: () {
                    // 同一颗星再点一次 → 清除
                    onChanged(value == i ? null : i);
                  },
                  child: Icon(
                    i <= v ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i <= v ? activeColor : BulterColors.textTertiary,
                    size: size,
                  ),
                ),
              ),
            const Spacer(),
            if (value != null)
              TextButton(
                onPressed: () => onChanged(null),
                child: const Text('清除'),
              ),
          ],
        ),
      ],
    );
  }
}
