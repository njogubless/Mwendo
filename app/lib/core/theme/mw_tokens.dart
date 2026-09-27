import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Spacing scale (4/8 rhythm).
abstract final class MwSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 40;

  /// Outer page margins per breakpoint.
  static const double marginCompact = 20;
  static const double marginMedium = 32;
  static const double marginExpanded = 48;

  static const double cardPadding = 20;
}

abstract final class MwRadii {
  static const double sm = 8;
  static const double md = 12;

  /// Inputs, buttons, inner modules.
  static const double lg = 16;

  /// Cards and major containers.
  static const double card = 20;
  static const double xl = 24;
  static const double dock = 28;
  static const double pill = 999;
}

/// Layout breakpoints (logical pixels).
abstract final class MwBreakpoints {
  static const double medium = 600;
  static const double expanded = 1024;
  static const double maxContentWidth = 1200;
}

/// Warm, diffuse shadows. Depth comes first from tonal layering; use these sparingly.
abstract final class MwShadows {
  static List<BoxShadow> resting(Color shadow) => [
    BoxShadow(color: shadow.withValues(alpha: 0.07), offset: const Offset(0, 3), blurRadius: 10, spreadRadius: -3),
    BoxShadow(color: shadow.withValues(alpha: 0.04), offset: const Offset(0, 1), blurRadius: 2),
  ];

  static List<BoxShadow> floating(Color shadow) => [
    BoxShadow(color: shadow.withValues(alpha: 0.12), offset: const Offset(0, 12), blurRadius: 32, spreadRadius: -4),
    BoxShadow(color: shadow.withValues(alpha: 0.03), offset: const Offset(0, 4), blurRadius: 12, spreadRadius: -2),
  ];
}

abstract final class MwMotion {
  /// `cubic-bezier(0.2, 0.8, 0.2, 1)` from the design system.
  static const Curve standard = Cubic(0.2, 0.8, 0.2, 1);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 500);
  static const double pressScale = 0.98;
}
