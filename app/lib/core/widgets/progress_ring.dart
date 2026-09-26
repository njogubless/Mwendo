import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/mw_tokens.dart';

/// Circular gauge with rounded caps (Today progress card).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.value,
    required this.semanticLabel,
    this.size = 64,
    this.strokeWidth = 6,
    this.color,
    this.trackColor,
    this.center,
    super.key,
  });

  /// 0–1; values outside are clamped.
  final double value;
  final String semanticLabel;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final clamped = value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(clamped * 100).round()}%',
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: clamped),
          duration: MwMotion.slow,
          curve: MwMotion.standard,
          builder: (context, animated, child) => CustomPaint(
            painter: _RingPainter(
              value: animated,
              strokeWidth: strokeWidth,
              color: color ?? c.accent,
              trackColor: trackColor ?? c.sunken,
            ),
            child: child,
          ),
          child: center == null ? null : Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.strokeWidth, required this.color, required this.trackColor});

  final double value;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = trackColor);
    if (value > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.trackColor != trackColor || old.strokeWidth != strokeWidth;
}
