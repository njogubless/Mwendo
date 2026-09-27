import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/notifications/notifications_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mw_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/mw_card.dart';
import '../../../core/widgets/mw_sheet.dart';
import '../../../core/widgets/mw_toggle.dart';
import '../../../core/widgets/section_label.dart';
import '../application/reminders_controller.dart';
import '../domain/reminder_settings.dart';

/// Profile › Reminders: a master switch plus one switch per kind of reminder.
class RemindersSettingsSection extends ConsumerWidget {
  const RemindersSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supported = ref.watch(notificationsServiceProvider).isSupported;
    final settings = ref.watch(reminderSettingsProvider).value ?? const ReminderSettings();
    final controller = ref.read(reminderSettingsProvider.notifier);
    final c = context.mwColors;

    Widget toggle(String title, String subtitle, bool value, ReminderSettings Function(bool) apply) => _Row(
      title: title,
      subtitle: subtitle,
      value: value,
      enabled: settings.isOn,
      onChanged: (v) => controller.change((_) => apply(v)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Reminders'),
        const SizedBox(height: MwSpace.sm),
        MwCard(
          padding: const EdgeInsets.symmetric(horizontal: MwSpace.md, vertical: MwSpace.sm),
          child: !supported
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: MwSpace.sm),
                  child: Text(
                    'Reminders work in the Mwendo phone app.',
                    style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                )
              : Column(
                  children: [
                    _Row(
                      title: 'Reminders',
                      subtitle: settings.isOn ? 'On — they follow your plan as it changes.' : 'Off',
                      value: settings.isOn,
                      enabled: true,
                      emphasised: true,
                      onChanged: (on) async {
                        if (!on) return controller.disable();
                        final granted = await controller.enable();
                        if (!granted && context.mounted) {
                          showMwSnack(
                            context,
                            'Notifications are blocked. Allow them for Mwendo in your phone settings.',
                          );
                        }
                      },
                    ),
                    const Divider(),
                    toggle(
                      'Each step',
                      '“Time for Move · 20 min”',
                      settings.stepStarts,
                      (v) => settings.copyWith(stepStarts: v),
                    ),
                    toggle(
                      'Routine about to start',
                      'Five minutes before a routine begins.',
                      settings.routineSoon,
                      (v) => settings.copyWith(routineSoon: v),
                    ),
                    toggle(
                      'When the day shifts',
                      'A calm offer to fit things into the time you have.',
                      settings.shiftedNudge,
                      (v) => settings.copyWith(shiftedNudge: v),
                    ),
                    toggle(
                      'Milestones',
                      'Halfway and done — for your day, routines and goals.',
                      settings.milestones,
                      (v) => settings.copyWith(milestones: v),
                    ),
                    toggle(
                      'Evening wind-down',
                      'A gentle moment to look back on the day.',
                      settings.windDown,
                      (v) => settings.copyWith(windDown: v),
                    ),
                    if (settings.windDown)
                      ListTile(
                        enabled: settings.isOn,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Symbols.bedtime, color: c.textSecondary),
                        title: Text('Wind-down time', style: context.text.labelLarge),
                        trailing: Text(formatClock(context, settings.windDownMinutes), style: context.text.labelLarge),
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: settings.windDownMinutes ~/ 60,
                              minute: settings.windDownMinutes % 60,
                            ),
                          );
                          if (t != null) {
                            await controller.change((s) => s.copyWith(windDownMinutes: t.hour * 60 + t.minute));
                          }
                        },
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.emphasised = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final bool emphasised;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: emphasised ? context.text.titleMedium : context.text.labelLarge),
                Text(subtitle, style: context.text.bodySmall?.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          MwToggle(value: value, semanticLabel: title, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}
