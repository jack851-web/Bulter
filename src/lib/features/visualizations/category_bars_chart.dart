import 'package:flutter/material.dart';

import '../../modules/wealth/services/chart_service.dart';
import '../../theme/tokens.dart';

/// 分类支出柱图（Step 13b）。
///
/// **横向柱**：
/// - 左：分类 label
/// - 中：进度条（按 ratio）
/// - 右：金额 + 百分比
///
/// **响应式**：宽度自适应父容器。
class CategoryBarsChart extends StatelessWidget {
  final List<CategoryBar> bars;
  final double height;

  const CategoryBarsChart({
    super.key,
    required this.bars,
    this.height = 280,
  });

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BulterColors.surfaceMuted,
          borderRadius: BorderRadius.circular(BulterRadius.l),
        ),
        child: const Text(
          '本月暂无支出',
          style: TextStyle(color: BulterColors.textTertiary),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(BulterSpacing.l),
      decoration: BoxDecoration(
        color: BulterColors.surface,
        borderRadius: BorderRadius.circular(BulterRadius.l),
        border: Border.all(color: BulterColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final b in bars) ...[
            _BarRow(bar: b),
            const SizedBox(height: BulterSpacing.m),
          ],
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final CategoryBar bar;
  const _BarRow({required this.bar});

  static const _palette = [
    Color(0xFFEF4444), // red
    Color(0xFFF97316), // orange
    Color(0xFFEAB308), // yellow
    Color(0xFF22C55E), // green
    Color(0xFF06B6D4), // cyan
    Color(0xFF3B82F6), // blue
    Color(0xFFA855F7), // purple
    Color(0xFF6B7280), // gray
  ];

  Color get _color => _palette[bar.colorIndex % _palette.length];

  @override
  Widget build(BuildContext context) {
    final amount = (bar.amountCents / 100).toStringAsFixed(0);
    final pct = (bar.ratio * 100).toStringAsFixed(1);
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            bar.label,
            style: const TextStyle(
              fontSize: BulterFontSize.body,
              color: BulterColors.textPrimary,
              fontWeight: BulterFontWeight.medium,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: BulterColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: bar.ratio.clamp(0.02, 1.0),
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: BulterSpacing.m),
        SizedBox(
          width: 80,
          child: Text(
            '¥$amount',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: BulterFontSize.body,
              color: BulterColors.textPrimary,
              fontWeight: BulterFontWeight.semibold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: BulterFontSize.footnote,
              color: BulterColors.textTertiary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
