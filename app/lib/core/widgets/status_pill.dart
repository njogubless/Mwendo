import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/mw_tokens.dart';

enum PillTone { neutral, success, accent, gentle }

/// Compact tonal tag ("Essential", "Now", "Priority").
class StatusPill extends StatelessWidget {
  const StatusPill({required this.label, this.tone = PillTone.neutral, this.icon, super.key});

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final (background, foreground) = switch (tone) {
      PillTone.neutral => (c.sunken, c.textSecondary),
      PillTone.success => (c.successTint, c.onSuccessTint),
      PillTone.accent => (c.accentTint, c.accentText),
      PillTone.gentle => (c.gentleTint, c.onGentleTint),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(MwRadii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: foreground), const SizedBox(width: MwSpace.xs)],
          Text(label, style: context.text.labelSmall?.copyWith(color: foreground)),
        ],
      ),
    );
  }
}
