import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/mw_tokens.dart';

@immutable
class StrandSegment {
  const StrandSegment({required this.fraction, required this.color});

  /// Share of the full strand, 0–1.
  final double fraction;
  final Color color;
}

/// Multi-tone horizontal progress (done / in progress / remaining) without
/// binary judgement. Colour is never the only signal: [semanticLabel] is required.
class SegmentedStrand extends StatelessWidget {
  const SegmentedStrand({required this.segments, required this.semanticLabel, this.height = 8, super.key});

  final List<StrandSegment> segments;
  final String semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final track = context.mwColors.sunken;
    final total = segments.fold<double>(0, (sum, s) => sum + s.fraction.clamp(0, 1));
    final scale = total > 1 ? 1 / total : 1.0;

    return Semantics(
      label: semanticLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MwRadii.pill),
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: track)),
                Row(
                  children: [
                    for (final s in segments)
                      AnimatedContainer(
                        duration: MwMotion.slow,
                        curve: MwMotion.standard,
                        width: constraints.maxWidth * s.fraction.clamp(0, 1) * scale,
                        color: s.color,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
