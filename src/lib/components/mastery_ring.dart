import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 签名元素：自绘的环形进度（替代 Material CircularProgressIndicator）。
///
/// 设计意图：
/// - **不是动画**：完全静态，体现"AI 量化关系深度"的稳定感。
/// - **双层轨道**：内圈灰底 + 外圈品牌色；右侧起点 12 点钟方向。
/// - **中心数字**：displayL 字重的得分；上方一行 caption 标签。
///
/// 与 LinearProgressIndicator 的区别：本组件强调"分数感"，线性强调"进度感"，
/// 因此前者用于"人格化指标"（Mastery、维度评分），后者用于"过程进度"
/// （OKR 进度条、上传进度）。
class MasteryRing extends StatelessWidget {
  /// 0-100 的得分。
  final int score;

  /// 中心小标签（默认 "Mastery"）。
  final String label;

  /// 进度色（默认用关系品牌色）。
  final Color color;

  /// 半径（含 stroke）。
  final double radius;

  /// 圆环 stroke 宽度。
  final double strokeWidth;

  const MasteryRing({
    super.key,
    required this.score,
    this.label = 'Mastery',
    this.color = BulterColors.relationship,
    this.radius = 26,
    this.strokeWidth = 3.5,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0, 100);
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: CustomPaint(
        painter: _RingPainter(
          progress: clamped / 100.0,
          track: color.withValues(alpha: 0.18),
          progressColor: color,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$clamped',
                style: TextStyle(
                  fontSize: radius * 0.62,
                  fontWeight: BulterFontWeight.heavy,
                  color: color,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  fontSize: radius * 0.22,
                  color: color,
                  fontWeight: BulterFontWeight.semibold,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color track;
  final Color progressColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.track,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(
      center: center,
      radius: size.shortestSide / 2 - strokeWidth / 2,
    );
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);
    if (progress > 0) {
      // -π/2 = 12 点钟方向
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) {
    return old.progress != progress ||
        old.track != track ||
        old.progressColor != progressColor ||
        old.strokeWidth != strokeWidth;
  }
}

/// 把"水平黄色短条"风格的标签进度条（详见原型 phone-08 的 关系总览 区域）封成组件。
///
/// 与 MasteryRing 互补：环表达"总分"，条表达"维度分量"。
class ScoreBar extends StatelessWidget {
  final String label;
  final int value; // 0-100
  final Color color;

  const ScoreBar({
    super.key,
    required this.label,
    required this.value,
    this.color = BulterColors.relationship,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 100);
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: BulterFontSize.footnote,
              color: BulterColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BulterRadius.pill),
            child: Stack(
              children: [
                Container(height: 6, color: BulterColors.surfaceMuted),
                FractionallySizedBox(
                  widthFactor: v / 100.0,
                  child: Container(height: 6, color: color),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: BulterSpacing.s),
        SizedBox(
          width: 36,
          child: Text(
            '$v',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: BulterFontSize.footnote,
              color: BulterColors.textPrimary,
              fontWeight: BulterFontWeight.semibold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
