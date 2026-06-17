import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';

/// 数字滑块（0-100）。用于"目标进度"、"重要度"等场景。
class ProgressSliderField extends StatelessWidget {
  final String? label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String Function(int)? formatter;

  const ProgressSliderField({
    super.key,
    this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final display = formatter?.call(value) ?? '$value%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label!,
                style: const TextStyle(
                  fontSize: BulterFontSize.footnote,
                  fontWeight: BulterFontWeight.semibold,
                  color: BulterColors.textSecondary,
                ),
              ),
              Text(
                display,
                style: const TextStyle(
                  fontSize: BulterFontSize.footnote,
                  fontWeight: BulterFontWeight.semibold,
                  color: BulterColors.textPrimary,
                ),
              ),
            ],
          ),
        if (label != null) const SizedBox(height: BulterSpacing.xs),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: BulterColors.cta,
            inactiveTrackColor: BulterColors.surfaceMuted,
            thumbColor: BulterColors.cta,
            overlayColor: BulterColors.cta.withValues(alpha: 0.12),
          ),
          child: Slider(
            min: min.toDouble(),
            max: max.toDouble(),
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            divisions: max - min,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}

/// 把 cents 转成中文大写金额（适合收据/表单预览，不做完整人民币大写）。
String formatCentsCompact(int cents) {
  final yuan = cents ~/ 100;
  if (yuan < 10000) return '$yuan';
  final w = yuan ~/ 10000;
  final rest = (yuan % 10000) / 1000;
  if (rest == 0) return '${w}万';
  return '$w.${rest.toStringAsFixed(0).replaceAll(RegExp(r'0+$'), '')}万';
}

/// 数字输入（仅整数），用于"重要度 0-10"、"页数"等。
class IntegerInput extends StatelessWidget {
  final String? label;
  final int? value;
  final ValueChanged<int?> onChanged;
  final int? min;
  final int? max;
  final String? suffix;
  final String? hint;

  const IntegerInput({
    super.key,
    this.label,
    required this.value,
    required this.onChanged,
    this.min,
    this.max,
    this.suffix,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(
      text: value == null ? '' : value.toString(),
    );
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
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
          const SizedBox(height: BulterSpacing.xs + 2),
        ],
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(9),
          ],
          onChanged: (raw) {
            if (raw.isEmpty) {
              onChanged(null);
              return;
            }
            final v = int.tryParse(raw);
            if (v == null) return;
            if (min != null && v < min!) return;
            if (max != null && v > max!) return;
            onChanged(v);
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
              fontSize: BulterFontSize.bodyLg,
            ),
            suffixText: suffix,
            suffixStyle: const TextStyle(
              color: BulterColors.textSecondary,
              fontSize: BulterFontSize.body,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: BulterSpacing.l,
              vertical: BulterSpacing.m + 2,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BulterRadius.m),
              borderSide: const BorderSide(
                color: BulterColors.divider,
                width: 0.8,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BulterRadius.m),
              borderSide: const BorderSide(
                color: BulterColors.cta,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
