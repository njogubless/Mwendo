import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/mw_tokens.dart';

/// Pill switch from the Routines / Minimum Day designs, with a 48px hit area.
class MwToggle extends StatelessWidget {
  const MwToggle({required this.value, required this.onChanged, required this.semanticLabel, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: SizedBox(
          width: 56,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: MwMotion.medium,
              curve: MwMotion.standard,
              width: 48,
              height: 28,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? c.action : c.sunken,
                borderRadius: BorderRadius.circular(MwRadii.pill),
                border: value ? null : Border.all(color: c.border),
              ),
              child: AnimatedAlign(
                duration: MwMotion.medium,
                curve: MwMotion.standard,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                    boxShadow: MwShadows.resting(c.shadow),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
