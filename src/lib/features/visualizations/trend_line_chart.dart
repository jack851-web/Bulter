import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 通用折线图（Step 13b）。
///
/// **用途**：月度支出趋势 / 健康指标趋势
/// - X 轴：时间点 label
/// - Y 轴：值
/// - 多 series 用不同颜色叠加
class TrendLineChart extends StatelessWidget {
  /// 每个 series 一条线，颜色对应 [seriesColors]。
  final List<List<double>> series;
  final List<String> xLabels;
  final List<String> seriesLabels;
  final List<Color> seriesColors;
  final double height;
  final String? yUnit;
  final List<double>? normalRange; // [low, high] 正常范围阴影

  const TrendLineChart({
    super.key,
    required this.series,
    required this.xLabels,
    required this.seriesLabels,
    required this.seriesColors,
    this.height = 220,
    this.yUnit,
    this.normalRange,
  }) : assert(series.length == seriesLabels.length);

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty || series.first.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BulterColors.surfaceMuted,
          borderRadius: BorderRadius.circular(BulterRadius.l),
        ),
        child: const Text(
          '暂无数据',
          style: TextStyle(color: BulterColors.textTertiary),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(
        BulterSpacing.l,
        BulterSpacing.m,
        BulterSpacing.l,
        BulterSpacing.s,
      ),
      decoration: BoxDecoration(
        color: BulterColors.surface,
        borderRadius: BorderRadius.circular(BulterRadius.l),
        border: Border.all(color: BulterColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图例
          Wrap(
            spacing: BulterSpacing.m,
            runSpacing: 4,
            children: [
              for (var i = 0; i < seriesLabels.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: seriesColors[i % seriesColors.length],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      seriesLabels[i],
                      style: const TextStyle(
                        fontSize: BulterFontSize.footnote,
                        color: BulterColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: BulterSpacing.s),
          SizedBox(
            height: height - 50,
            child: CustomPaint(
              size: Size.infinite,
              painter: _LinePainter(
                series: series,
                xLabels: xLabels,
                seriesColors: seriesColors,
                yUnit: yUnit,
                normalRange: normalRange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<List<double>> series;
  final List<String> xLabels;
  final List<Color> seriesColors;
  final String? yUnit;
  final List<double>? normalRange;

  _LinePainter({
    required this.series,
    required this.xLabels,
    required this.seriesColors,
    this.yUnit,
    this.normalRange,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty || series.first.isEmpty) return;

    const padding = EdgeInsets.fromLTRB(40, 8, 8, 24);
    final chartRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      size.width - padding.horizontal,
      size.height - padding.vertical,
    );

    // 1) 计算全局 min/max
    double globalMin = double.infinity;
    double globalMax = -double.infinity;
    for (final s in series) {
      for (final v in s) {
        if (v < globalMin) globalMin = v;
        if (v > globalMax) globalMax = v;
      }
    }
    if (normalRange != null && normalRange!.length == 2) {
      globalMin = globalMin < normalRange![0] ? globalMin : normalRange![0];
      globalMax = globalMax > normalRange![1] ? globalMax : normalRange![1];
    }
    if (globalMin == globalMax) {
      globalMin -= 1;
      globalMax += 1;
    }

    // 2) Y 轴网格线 + label
    final gridPaint = Paint()
      ..color = BulterColors.divider
      ..strokeWidth = 0.5;
    const ySteps = 4;
    for (var i = 0; i <= ySteps; i++) {
      final t = i / ySteps;
      final y = chartRect.bottom - t * chartRect.height;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
      final v = globalMin + t * (globalMax - globalMin);
      _drawText(
        canvas,
        v.toStringAsFixed(0),
        Offset(0, y - 6),
        BulterColors.textTertiary,
        fontSize: 9,
      );
    }

    // 3) 正常范围阴影
    if (normalRange != null && normalRange!.length == 2) {
      final yLow = chartRect.bottom -
          ((normalRange![0] - globalMin) / (globalMax - globalMin)) *
              chartRect.height;
      final yHigh = chartRect.bottom -
          ((normalRange![1] - globalMin) / (globalMax - globalMin)) *
              chartRect.height;
      final rect = Rect.fromLTRB(
        chartRect.left,
        yHigh,
        chartRect.right,
        yLow,
      );
      canvas.drawRect(
        rect,
        Paint()..color = BulterColors.growth.withValues(alpha: 0.10),
      );
    }

    // 4) 画每条线
    for (var sIdx = 0; sIdx < series.length; sIdx++) {
      final s = series[sIdx];
      if (s.isEmpty) continue;
      final color = seriesColors[sIdx % seriesColors.length];
      final points = <Offset>[];
      for (var i = 0; i < s.length; i++) {
        final x = s.length == 1
            ? chartRect.center.dx
            : chartRect.left + (i / (s.length - 1)) * chartRect.width;
        final t = (s[i] - globalMin) / (globalMax - globalMin);
        final y = chartRect.bottom - t * chartRect.height;
        points.add(Offset(x, y));
      }
      // 线
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, linePaint);
      // 点
      final dotPaint = Paint()..color = color;
      for (final p in points) {
        canvas.drawCircle(p, 3, dotPaint);
        canvas.drawCircle(
          p,
          3,
          Paint()
            ..color = BulterColors.surface
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    // 5) X 轴 label
    if (xLabels.isNotEmpty) {
      final step =
          chartRect.width / (xLabels.length == 1 ? 1 : xLabels.length - 1);
      for (var i = 0; i < xLabels.length; i++) {
        final x = chartRect.left + step * i;
        _drawText(
          canvas,
          xLabels[i],
          Offset(x - 8, chartRect.bottom + 6),
          BulterColors.textTertiary,
          fontSize: 9,
        );
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset pos,
    Color color, {
    double fontSize = 11,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.series != series || old.xLabels != xLabels;
}
