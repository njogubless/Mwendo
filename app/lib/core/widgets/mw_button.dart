import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/mw_tokens.dart';
import 'mw_pressable.dart';

enum MwButtonVariant {
  /// Forest fill, white text. The one main action on a surface.
  primary,

  /// Ochre fill, charcoal text. Energetic, used sparingly (e.g. "Create routine").
  accent,

  /// Sand fill. Secondary choices (Pause, Skip).
  secondary,

  /// No fill. Tertiary / text links ("Restore original schedule").
  text,
}

enum MwButtonSize { regular, compact }

class MwButton extends StatelessWidget {
  const MwButton({
    required this.label,
    required this.onPressed,
    this.variant = MwButtonVariant.primary,
    this.size = MwButtonSize.regular,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final MwButtonVariant variant;
  final MwButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final (background, foreground) = switch (variant) {
      MwButtonVariant.primary => (c.action, c.onAction),
      MwButtonVariant.accent => (c.accent, c.onAccent),
      MwButtonVariant.secondary => (c.sunken, c.textPrimary),
      MwButtonVariant.text => (Colors.transparent, c.textSecondary),
    };
    final height = size == MwButtonSize.regular ? 48.0 : 40.0;
    final textStyle = (size == MwButtonSize.regular ? context.text.labelLarge : context.text.labelMedium)?.copyWith(
      color: foreground,
    );

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: foreground))
        else if (icon != null)
          Icon(icon, size: size == MwButtonSize.regular ? 20 : 16, color: foreground),
        if (isLoading || icon != null) const SizedBox(width: MwSpace.sm),
        Flexible(
          child: Text(label, style: textStyle, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: isLoading ? '$label, in progress' : null,
      excludeSemantics: isLoading,
      child: AnimatedOpacity(
        opacity: onPressed == null ? 0.5 : 1,
        duration: MwMotion.fast,
        child: MwPressable(
          onTap: onPressed,
          enabled: _enabled,
          child: Container(
            height: height,
            constraints: const BoxConstraints(minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: MwSpace.md),
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(MwRadii.lg)),
            child: content,
          ),
        ),
      ),
    );
  }
}
