import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';

/// 金额输入字段。统一处理：
/// - 仅允许数字 + 一个小数点
/// - 内部按"分"存储（避免浮点误差，对应 DAO 字段约定）
/// - 展示时按 `¥` + 千分位格式化
class AmountInput extends StatelessWidget {
  final String? label;
  final int? cents; // 内部以"分"存储；null = 空
  final ValueChanged<int?> onChanged;
  final String currency; // 暂只用于前缀显示
  final String? hint;
  final String? errorText;

  const AmountInput({
    super.key,
    this.label,
    required this.cents,
    required this.onChanged,
    this.currency = 'CNY',
    this.hint,
    this.errorText,
  });

  String get _symbol => switch (currency) {
    'USD' => r'$',
    'EUR' => '€',
    'JPY' => '¥',
    _ => '¥',
  };

  String _format(int c) {
    final sign = c < 0 ? '-' : '';
    final abs = c.abs();
    final yuan = abs ~/ 100;
    final fen = abs % 100;
    final yuanStr = yuan.toString();
    final buf = StringBuffer();
    for (var i = 0; i < yuanStr.length; i++) {
      if (i > 0 && (yuanStr.length - i) % 3 == 0) buf.write(',');
      buf.write(yuanStr[i]);
    }
    return '$sign$buf.$_fen2';
  }

  String get _fen2 {
    final c = cents ?? 0;
    final fen = (c.abs() % 100).toString().padLeft(2, '0');
    return fen;
  }

  String get _displayValue {
    if (cents == null) return '';
    return _format(cents!);
  }

  void _onTextChange(String raw) {
    final cleaned = raw.replaceAll(',', '').trim();
    if (cleaned.isEmpty) {
      onChanged(null);
      return;
    }
    final v = double.tryParse(cleaned);
    if (v == null) return;
    // 容错：若用户直接输入 "200" 而没有小数点，按整数 200 元处理。
    final c = (v * 100).round();
    onChanged(c);
  }

  @override
  Widget build(BuildContext context) {
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
          controller: TextEditingController(text: _displayValue)
            ..selection = TextSelection.collapsed(offset: _displayValue.length),
          onChanged: _onTextChange,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          style: const TextStyle(
            fontSize: BulterFontSize.bodyLg,
            color: BulterColors.textPrimary,
            fontWeight: BulterFontWeight.semibold,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: BulterColors.surface,
            hintText: hint ?? '0.00',
            hintStyle: const TextStyle(
              color: BulterColors.textTertiary,
              fontSize: BulterFontSize.bodyLg,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BulterSpacing.l,
                vertical: BulterSpacing.m + 4,
              ),
              child: Text(
                _symbol,
                style: const TextStyle(
                  fontSize: BulterFontSize.bodyLg,
                  color: BulterColors.textSecondary,
                  fontWeight: BulterFontWeight.semibold,
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BulterRadius.m),
              borderSide: const BorderSide(
                color: BulterColors.divider,
                width: 0.8,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BulterRadius.m),
              borderSide: const BorderSide(color: BulterColors.cta, width: 1.4),
            ),
          ),
        ),
        if (errorText != null && errorText!.isNotEmpty) ...[
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

/// 工具函数：cents → "¥1,234.56"。UI 列表展示用。
String formatCents(int cents, {String currency = 'CNY'}) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final fen = (abs % 100).toString().padLeft(2, '0');
  final yuanStr = yuan.toString();
  final buf = StringBuffer();
  for (var i = 0; i < yuanStr.length; i++) {
    if (i > 0 && (yuanStr.length - i) % 3 == 0) buf.write(',');
    buf.write(yuanStr[i]);
  }
  final sym = switch (currency) {
    'USD' => r'$',
    'EUR' => '€',
    'JPY' => '¥',
    _ => '¥',
  };
  return '$sign$sym$buf.$fen';
}
