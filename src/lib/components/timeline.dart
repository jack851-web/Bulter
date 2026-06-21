import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 一条时间线节点。承载"圆圈图标 + 标题 + 副标 + 右侧时间 + 可选操作"的整行。
///
/// [Timeline] 把多个 [TimelineNode] 用一条彩色细线串起来——这是关系/健康/活动流
/// 的标准表达，比起每条独立的 [ListCard] 更能体现"事件序列"的关系。
class TimelineNode {
  final Widget icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? rightLabel;
  final List<Widget> trailing;

  const TimelineNode({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.rightLabel,
    this.trailing = const [],
  });
}

class Timeline extends StatelessWidget {
  final List<TimelineNode> nodes;
  final Color lineColor;
  final double iconSize;
  final EdgeInsetsGeometry padding;

  const Timeline({
    super.key,
    required this.nodes,
    this.lineColor = BulterColors.divider,
    this.iconSize = 32,
    this.padding = const EdgeInsets.symmetric(vertical: BulterSpacing.s),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (var i = 0; i < nodes.length; i++)
            _TimelineRow(
              node: nodes[i],
              isFirst: i == 0,
              isLast: i == nodes.length - 1,
              lineColor: lineColor,
              iconSize: iconSize,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final TimelineNode node;
  final bool isFirst;
  final bool isLast;
  final Color lineColor;
  final double iconSize;

  const _TimelineRow({
    required this.node,
    required this.isFirst,
    required this.isLast,
    required this.lineColor,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final half = iconSize / 2;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧时间线（节点 + 上下连接线）
          SizedBox(
            width: half + BulterSpacing.m,
            child: Column(
              children: [
                SizedBox(
                  width: half * 2,
                  height: half * 2,
                  child: Center(
                    child: Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: node.iconColor.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: IconTheme(
                        data: IconThemeData(
                          color: node.iconColor,
                          size: 16,
                        ),
                        child: node.icon,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 1.4,
                        color: lineColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 右侧内容
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: half - 8,
                bottom: isLast ? 0 : BulterSpacing.l,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          node.title,
                          style: const TextStyle(
                            fontSize: BulterFontSize.bodyLg,
                            fontWeight: BulterFontWeight.semibold,
                            color: BulterColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (node.rightLabel != null)
                        Text(
                          node.rightLabel!,
                          style: const TextStyle(
                            fontSize: BulterFontSize.footnote,
                            color: BulterColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                  if (node.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      node.subtitle!,
                      style: const TextStyle(
                        fontSize: BulterFontSize.footnote,
                        color: BulterColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                  if (node.trailing.isNotEmpty) ...[
                    const SizedBox(height: BulterSpacing.s),
                    Wrap(
                      spacing: BulterSpacing.s,
                      runSpacing: BulterSpacing.s,
                      children: node.trailing,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 关系/事件类型的轻量小标签（原型 "送" / "回" 按钮）。
class ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const ActionChip({
    super.key,
    required this.label,
    this.color = BulterColors.relationship,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(BulterRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(BulterRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BulterSpacing.m,
            vertical: 4,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: BulterFontSize.caption,
              color: color,
              fontWeight: BulterFontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
