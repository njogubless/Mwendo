import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/mw_tokens.dart';
import 'mw_pressable.dart';

enum MwCardTone {
  /// Ceramic surface with hairline and resting shadow — primary content tiles.
  elevated,

  /// Recessed sand — secondary groupings (adaptive buffer, principle card).
  sunken,

  /// Soft green tint — supportive suggestions (Minimum Day banner).
  supportive,

  /// Warm ochre tint — gentle context (running late).
  warm,
}

class MwCard extends StatelessWidget {
  const MwCard({
    required this.child,
    this.tone = MwCardTone.elevated,
    this.padding = const EdgeInsets.all(MwSpace.cardPadding),
    this.radius = MwRadii.card,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final MwCardTone tone;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final (color, border, shadow) = switch (tone) {
      MwCardTone.elevated => (c.surface, c.border, MwShadows.resting(c.shadow)),
      MwCardTone.sunken => (c.sunken, null, null),
      MwCardTone.supportive => (c.successTint, null, null),
      MwCardTone.warm => (c.accentTint, null, null),
    };

    Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border == null ? null : Border.all(color: border),
        boxShadow: shadow,
      ),
      child: child,
    );

    if (onTap != null) {
      card = MwPressable(onTap: onTap, child: card);
    }
    if (semanticLabel != null || onTap != null) {
      card = Semantics(button: onTap != null, label: semanticLabel, child: card);
    }
    return card;
  }
}
