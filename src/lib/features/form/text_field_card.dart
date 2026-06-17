import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';

/// Bulter 标准文本输入框（卡片样式）。
///
/// 取代裸 `TextField`，统一圆角、间距、占位文本色。所有模块的表单都使用它。
class TextFieldCard extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool autofocus;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix;
  final Widget? suffix;
  final TextCapitalization textCapitalization;

  const TextFieldCard({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.autofocus = false,
    this.enabled = true,
    this.inputFormatters,
    this.prefix,
    this.suffix,
    this.textCapitalization = TextCapitalization.none,
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
          const SizedBox(height: BulterSpacing.xs + 2),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          autofocus: autofocus,
          enabled: enabled,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
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
            prefixIcon: prefix,
            suffixIcon: suffix,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: BulterSpacing.l,
              vertical: BulterSpacing.m + 2,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BulterRadius.m),
              borderSide: BorderSide(
                color: hasError ? BulterColors.error : BulterColors.divider,
                width: 0.8,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BulterRadius.m),
              borderSide: BorderSide(
                color: hasError ? BulterColors.error : BulterColors.cta,
                width: 1.4,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BulterRadius.m),
              borderSide: const BorderSide(
                color: BulterColors.divider,
                width: 0.8,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: BulterSpacing.xs),
          Text(
            errorText!,
            style: const TextStyle(
              fontSize: BulterFontSize.footnote,
              color: BulterColors.error,
            ),
          ),
        ] else if (helperText != null) ...[
          const SizedBox(height: BulterSpacing.xs),
          Text(
            helperText!,
            style: const TextStyle(
              fontSize: BulterFontSize.footnote,
              color: BulterColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}
