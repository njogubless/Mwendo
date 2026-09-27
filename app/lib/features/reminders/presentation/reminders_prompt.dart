import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/notifications/notifications_service.dart';
import '../../../core/widgets/mw_card.dart';
import '../../../core/widgets/mw_sheet.dart';
import '../../today/presentation/widgets/banners.dart';
import '../application/reminders_controller.dart';

/// Asked once, on Today, when there's a plan worth being reminded about.
class RemindersPrompt extends ConsumerWidget {
  const RemindersPrompt({super.key});

  /// Whether the prompt would show — lets pages leave it out entirely (no empty gap).
  static bool isVisible(WidgetRef ref) =>
      ref.watch(notificationsServiceProvider).isSupported &&
      ref.watch(reminderSettingsProvider).value?.enabled == null &&
      ref.watch(reminderSettingsProvider).hasValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isVisible(ref)) return const SizedBox.shrink();
    final controller = ref.read(reminderSettingsProvider.notifier);
    return ContextBanner(
      icon: Symbols.notifications_active,
      tone: MwCardTone.sunken,
      title: 'Want a gentle nudge?',
      message: 'Mwendo can tell you when it’s time for the next step — and adjust when your plan changes.',
      actionLabel: 'Turn on reminders',
      onAction: () async {
        final granted = await controller.enable();
        if (context.mounted) {
          showMwSnack(
            context,
            granted
                ? 'Reminders are on. Change them any time in Profile.'
                : 'No problem — you can turn them on in Profile.',
          );
        }
      },
      secondaryLabel: 'Not now',
      onSecondary: () => controller.change((s) => s.copyWith(enabled: false)),
    );
  }
}
