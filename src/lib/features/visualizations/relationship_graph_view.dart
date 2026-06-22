import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../modules/relationship/services/graph_service.dart';
import '../../theme/tokens.dart';

/// 关系图谱可视化（Step 13b）。
///
/// **布局**：圆周布局 + 中心主题（最大 importance 居中）
/// - **节点**：圆圈 + 名字首字 + 标签
/// - **大小**：基于 `radiusFactor`（互动 + 重要度）
/// - **颜色**：基于 `daysSinceLastContact`（绿 ≤7d，黄 8-30d，红 >30d，灰 = 未知）
///
/// **响应式**：在 Web 端大屏自适应容器宽度。
class RelationshipGraphView extends StatelessWidget {
  final RelationshipGraph graph;
  final double height;
  final void Function(GraphNode node)? onNodeTap;

  const RelationshipGraphView({
    super.key,
    required this.graph,
    this.height = 320,
    this.onNodeTap,
  });

  @override
  Widget build(BuildContext context) {
    if (graph.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BulterColors.surfaceMuted,
          borderRadius: BorderRadius.circular(BulterRadius.l),
        ),
        child: const Text(
          '还没有联系人，无法生成图谱',
          style: TextStyle(color: BulterColors.textTertiary),
        ),
      );
    }
    return LayoutBuilder(
      builder: (ctx, c) {
        final size = Size(c.maxWidth, height);
        return GestureDetector(
          onTapUp: (d) {
            if (onNodeTap == null) return;
            final hit = _hitTest(d.localPosition, size);
            if (hit != null) onNodeTap!(hit);
          },
          child: CustomPaint(
            size: size,
            painter: _GraphPainter(graph: graph),
          ),
        );
      },
    );
  }

  GraphNode? _hitTest(Offset pos, Size size) {
    if (graph.isEmpty) return null;
    final positions = _layout(size);
    for (final p in positions.entries) {
      if ((p.value - pos).distance <= _radiusFor(p.key)) return p.key;
    }
    return null;
  }

  double _radiusFor(GraphNode n) =>
      16.0 + 8.0 * n.radiusFactor.clamp(0.5, 3.0);

  Map<GraphNode, Offset> _layout(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final nodes = graph.nodes;
    final out = <GraphNode, Offset>{};

    if (nodes.isEmpty) return out;
    if (nodes.length == 1) {
      out[nodes.first] = center;
      return out;
    }

    // 排序：importance 降序 → 中心
    final sorted = [...nodes]
      ..sort((a, b) {
        final c = b.importance.compareTo(a.importance);
        if (c != 0) return c;
        return b.interactionCount.compareTo(a.interactionCount);
      });

    // 第一个放中心
    out[sorted.first] = center;

    // 其余圆周排列（半径 = min(中心到边)/2）
    final radius =
        math.min(size.width, size.height) / 2 - 36.0; // 留 padding
    final ring = <GraphNode>[];
    for (var i = 1; i < sorted.length; i++) {
      ring.add(sorted[i]);
    }
    final count = ring.length;
    for (var i = 0; i < count; i++) {
      final angle = (2 * math.pi * i / count) - math.pi / 2; // 12 点钟方向起
      out[ring[i]] = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
    }
    return out;
  }
}

class _GraphPainter extends CustomPainter {
  final RelationshipGraph graph;
  _GraphPainter({required this.graph});

  @override
  void paint(Canvas canvas, Size size) {
    final positions = _layoutPositions(size);

    // 1) 画中心主题圈（淡灰底）
    if (graph.nodes.isNotEmpty) {
      final center = positions[graph.nodes.first]!;
      final bgPaint = Paint()..color = BulterColors.surfaceMuted;
      canvas.drawCircle(center, 60, bgPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: '你',
          style: TextStyle(
            color: BulterColors.textSecondary,
            fontSize: 14,
            fontWeight: BulterFontWeight.semibold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        center - Offset(tp.width / 2, tp.height / 2),
      );
    }

    // 2) 画边（自环 = 圆弧到中心）
    final edgePaint = Paint()
      ..color = BulterColors.divider
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final e in graph.edges) {
      final from = positions.entries
          .firstWhere((p) => p.key.contactId == e.fromId,
              orElse: () => MapEntry(graph.nodes.first, Offset.zero))
          .value;
      if (from == Offset.zero) continue;
      final to = positions[graph.nodes.first]!;
      canvas.drawLine(from, to, edgePaint..strokeWidth = e.weight.clamp(0.5, 4));
    }

    // 3) 画节点
    for (final entry in positions.entries) {
      final node = entry.key;
      final pos = entry.value;
      final r = _radiusFor(node);

      // 颜色基于距上次联系天数
      final color = _contactColor(node.daysSinceLastContact);

      // 阴影
      canvas.drawCircle(pos, r + 2, Paint()..color = Colors.black.withValues(alpha: 0.06));
      // 主圈
      canvas.drawCircle(pos, r, Paint()..color = color);
      // 边框
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..color = BulterColors.surface
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
      // 首字
      final ch = node.label.isEmpty ? '?' : node.label.characters.first;
      final tp = TextPainter(
        text: TextSpan(
          text: ch,
          style: TextStyle(
            color: BulterColors.ctaText,
            fontSize: r * 0.7,
            fontWeight: BulterFontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
      // 名字（节点下方）
      final namePainter = TextPainter(
        text: TextSpan(
          text: node.label,
          style: TextStyle(
            color: BulterColors.textPrimary,
            fontSize: 11,
            fontWeight: BulterFontWeight.medium,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 80);
      namePainter.paint(canvas, pos + Offset(-namePainter.width / 2, r + 4));
    }
  }

  /// 距上次联系天数 → 节点填充色。
  Color _contactColor(int days) {
    if (days < 0) return BulterColors.textTertiary; // 从未联系
    if (days <= 7) return const Color(0xFF4ADE80); // 绿
    if (days <= 30) return const Color(0xFFFBBF24); // 黄
    if (days <= 90) return const Color(0xFFF87171); // 红
    return BulterColors.textTertiary;
  }

  double _radiusFor(GraphNode n) =>
      16.0 + 8.0 * n.radiusFactor.clamp(0.5, 3.0);

  Map<GraphNode, Offset> _layoutPositions(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final nodes = graph.nodes;
    final out = <GraphNode, Offset>{};
    if (nodes.isEmpty) return out;
    if (nodes.length == 1) {
      out[nodes.first] = center;
      return out;
    }
    final sorted = [...nodes]
      ..sort((a, b) {
        final c = b.importance.compareTo(a.importance);
        if (c != 0) return c;
        return b.interactionCount.compareTo(a.interactionCount);
      });
    out[sorted.first] = center;
    final radius =
        math.min(size.width, size.height) / 2 - 36.0;
    final ring = sorted.sublist(1);
    final count = ring.length;
    for (var i = 0; i < count; i++) {
      final angle = (2 * math.pi * i / count) - math.pi / 2;
      out[ring[i]] = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
    }
    return out;
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) =>
      old.graph != graph;
}
