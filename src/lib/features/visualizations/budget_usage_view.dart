import 'package:flutter/material.dart';

import '../../modules/wealth/services/chart_service.dart';
import '../../theme/tokens.dart';

/// 预算 vs 实际 视图（Step 13b）。
///
/// 每个预算一行：
/// - 进度条（绿 ≤80%，黄 80-100%，红 >100%）
/// - 数字 ¥spent / ¥limit
/// - 超支时显示警示图标
class BudgetUsageView extends StatelessWidget {
  final List<BudgetUsage> usages;
  final double height;

  const BudgetUsageView({
    super.key,
    required this.usages,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (usages.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BulterColors.surfaceMuted,
          borderRadius: BorderRadius.circular(BulterRadius.l),
        ),
        child: const Text(
          '尚未设置预算',
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
          for (final u in usages) ...[
            _BudgetRow(usage: u),
            const SizedBox(height: BulterSpacing.m),
          ],
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final BudgetUsage usage;
  const _BudgetRow({required this.usage});

  Color get _barColor {
    if (usage.isOverBudget) return BulterColors.error;
    if (usage.ratio > 0.8) return const Color(0xFFFBBF24);
    return BulterColors.growth;
  }

  @override
  Widget build(BuildContext context) {
    final spent = (usage.spentCents / 100).toStringAsFixed(0);
    final limit = (usage.limitCents / 100).toStringAsFixed(0);
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            usage.label,
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
                widthFactor: usage.ratio.clamp(0.02, 1.5),
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: _barColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: BulterSpacing.m),
        SizedBox(
          width: 100,
          child: Text(
            '¥$spent / ¥$limit',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: BulterFontSize.body,
              color: usage.isOverBudget
                  ? BulterColors.error
                  : BulterColors.textPrimary,
              fontWeight: BulterFontWeight.semibold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (usage.isOverBudget) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: BulterColors.error,
          ),
        ],
      ],
    );
  }
}
