import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';

/// 整数输入卡片。仅接受数字，可配置 min/max 范围。
class IntegerInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final int? value;
  final ValueChanged<int?> onChanged;
  final int? min;
  final int? max;
  final String? errorText;

  const IntegerInput({
    super.key,
    this.label,
    this.hint,
    required this.value,
    required this.onChanged,
    this.min,
    this.max,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
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
        TextField(
          controller: TextEditingController(text: value?.toString() ?? ''),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (raw) {
            if (raw.isEmpty) {
              onChanged(null);
              return;
            }
            final n = int.tryParse(raw);
            if (n == null) return;
            if (min != null && n < min!) return;
            if (max != null && n > max!) return;
            onChanged(n);
          },
          style: const TextStyle(
            fontSize: BulterFontSize.bodyLg,
            color: BulterColors.textPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: BulterColors.surface,
            hintText: hint,
            hintStyle: const TextStyle(
              color: BulterColors.textTertiary,
              fontSize: BulterFontSize.body,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: BulterSpacing.l,
              vertical: BulterSpacing.m,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BulterRadius.m),
              borderSide: BorderSide(
                color: hasError
                    ? BulterColors.error
                    : BulterColors.divider,
                width: 0.8,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BulterRadius.m),
              borderSide: BorderSide(
                color: hasError
                    ? BulterColors.error
                    : BulterColors.divider,
                width: 0.8,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BulterRadius.m),
              borderSide: BorderSide(
                color: hasError
                    ? BulterColors.error
                    : BulterColors.cta,
                width: 1.4,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: BulterSpacing.xs),
          Text(
            errorText!,
            style: const TextStyle(
              fontSize: BulterFontSize.caption,
              color: BulterColors.error,
            ),
          ),
        ],
      ],
    );
  }
}
