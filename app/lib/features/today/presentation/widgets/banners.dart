import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/mw_tokens.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/widgets/mw_button.dart';
import '../../../../core/widgets/mw_card.dart';

/// Tonal banner: icon, title, message and up to two actions.
class ContextBanner extends StatelessWidget {
  const ContextBanner({
    required this.icon,
    required this.title,
    required this.message,
    this.tone = MwCardTone.supportive,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.busy = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final MwCardTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final fg = tone == MwCardTone.warm
        ? c.accentText
        : (tone == MwCardTone.supportive ? c.onSuccessTint : c.textPrimary);
    return MwCard(
      tone: tone,
      padding: const EdgeInsets.all(MwSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(width: MwSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.labelLarge?.copyWith(color: fg)),
                    const SizedBox(height: 2),
                    Text(message, style: context.text.bodySmall?.copyWith(color: fg)),
                  ],
                ),
              ),
            ],
          ),
          if (actionLabel != null || secondaryLabel != null) ...[
            const SizedBox(height: MwSpace.sm),
            // Wrap, not Row: two actions must never overflow on narrow screens or with large text.
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: MwSpace.sm,
                runSpacing: MwSpace.xs,
                children: [
                  if (secondaryLabel != null)
                    MwButton(
                      label: secondaryLabel!,
                      variant: MwButtonVariant.text,
                      size: MwButtonSize.compact,
                      expand: false,
                      onPressed: onSecondary,
                    ),
                  if (actionLabel != null) ...[
                    MwButton(
                      label: actionLabel!,
                      size: MwButtonSize.compact,
                      expand: false,
                      isLoading: busy,
                      onPressed: onAction,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MinimumDayBanner extends StatelessWidget {
  const MinimumDayBanner({required this.minutes, required this.onActivate, this.busy = false, super.key});

  final int minutes;
  final VoidCallback onActivate;
  final bool busy;

  @override
  Widget build(BuildContext context) => ContextBanner(
    icon: Symbols.energy_savings_leaf,
    title: 'Low on energy?',
    message: minutes > 0
        ? 'Switch to a Minimum Day — just your essentials, about ${formatMinutes(minutes)}.'
        : 'Switch to a Minimum Day — just your essentials.',
    actionLabel: 'Switch',
    onAction: onActivate,
    busy: busy,
  );
}

class ModeBanner extends StatelessWidget {
  const ModeBanner({required this.recovery, required this.onRestore, this.busy = false, super.key});

  final bool recovery;
  final VoidCallback onRestore;
  final bool busy;

  @override
  Widget build(BuildContext context) => ContextBanner(
    icon: recovery ? Symbols.favorite : Symbols.energy_savings_leaf,
    title: recovery ? 'Easing back in' : 'Minimum Day is on',
    message: recovery
        ? 'Just the essentials today. Showing up is the win.'
        : "Only your essentials today. Everything else is set aside — that's okay.",
    secondaryLabel: 'Back to full day',
    onSecondary: busy ? null : onRestore,
  );
}

class RecoveryBanner extends StatelessWidget {
  const RecoveryBanner({required this.daysAway, required this.onAccept, required this.onDismiss, super.key});

  final int daysAway;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => ContextBanner(
    icon: Symbols.waving_hand,
    tone: MwCardTone.warm,
    title: 'Welcome back',
    message: "It's been $daysAway days. Today is a new opportunity — want to start with a lighter day of essentials?",
    actionLabel: 'Start lighter',
    onAction: onAccept,
    secondaryLabel: 'Full day',
    onSecondary: onDismiss,
  );
}

class ShiftedBanner extends StatelessWidget {
  const ShiftedBanner({required this.routineName, required this.minutes, required this.onAdjust, super.key});

  final String routineName;
  final int minutes;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) => ContextBanner(
    icon: Symbols.schedule,
    tone: MwCardTone.warm,
    title: 'Your ${routineName.toLowerCase()} shifted by ${formatMinutes(minutes)}',
    message: 'Life happens. Mwendo can fit it into the time you have — no guilt.',
    actionLabel: 'Fit it in',
    onAction: onAdjust,
  );
}

class AdjustedBanner extends StatelessWidget {
  const AdjustedBanner({required this.routineName, required this.minutes, required this.onRestore, super.key});

  final String routineName;
  final int minutes;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) => ContextBanner(
    icon: Symbols.auto_fix_high,
    tone: MwCardTone.sunken,
    title: '$routineName fitted into ${formatMinutes(minutes)}',
    message: 'Essentials kept, the rest shortened or set aside.',
    secondaryLabel: 'Restore full routine',
    onSecondary: onRestore,
  );
}
