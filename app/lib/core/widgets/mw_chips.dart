import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/mw_tokens.dart';
import 'mw_pressable.dart';

/// Selectable pill (filter chips, day chips, budget pills). 38px interactive height, 48px hit area.
class MwChoicePill extends StatelessWidget {
  const MwChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.trailing,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final fg = selected ? c.onAction : c.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: MwPressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: MwMotion.medium,
              curve: MwMotion.standard,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? c.action : c.sunken,
                borderRadius: BorderRadius.circular(MwRadii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                  Text(label, style: context.text.labelMedium?.copyWith(color: fg)),
                  if (trailing != null) ...[const SizedBox(width: 6), trailing!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal single-select row that scrolls when it doesn't fit.
class MwPillRow<T> extends StatelessWidget {
  const MwPillRow({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final List<T> options;
  final T? selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: MwSpace.sm),
              child: MwChoicePill(label: labelOf(o), selected: o == selected, onTap: () => onSelected(o)),
            ),
        ],
      ),
    );
  }
}
