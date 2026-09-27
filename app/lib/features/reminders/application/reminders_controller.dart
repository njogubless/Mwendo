import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notifications_service.dart';
import '../../../core/notifications/reminder.dart';
import '../../goals/domain/goal.dart';
import '../../routines/application/routines_controller.dart';
import '../../today/application/today_controller.dart';
import '../data/reminder_settings_store.dart';
import '../domain/reminder_planner.dart';
import '../domain/reminder_settings.dart';

class ReminderSettingsController extends AsyncNotifier<ReminderSettings> {
  @override
  Future<ReminderSettings> build() => ref.watch(reminderSettingsStoreProvider).read();

  Future<void> _save(ReminderSettings next) async {
    state = AsyncData(next);
    await ref.read(reminderSettingsStoreProvider).write(next);
  }

  /// Turns reminders on, asking the OS for permission. Returns false when the user declined.
  Future<bool> enable() async {
    final granted = await ref.read(notificationsServiceProvider).requestPermission();
    await _save((state.value ?? const ReminderSettings()).copyWith(enabled: granted));
    return granted;
  }

  Future<void> disable() async {
    await _save((state.value ?? const ReminderSettings()).copyWith(enabled: false));
    await ref.read(notificationsServiceProvider).cancelAll();
  }

  Future<void> change(ReminderSettings Function(ReminderSettings) edit) async =>
      _save(edit(state.value ?? const ReminderSettings()));
}

final reminderSettingsProvider = AsyncNotifierProvider<ReminderSettingsController, ReminderSettings>(
  ReminderSettingsController.new,
);

/// Keeps scheduled reminders in step with today's plan, routines and settings.
/// Watched by the app while signed in (see `app.dart`).
final reminderSyncProvider = Provider<void>((ref) {
  final service = ref.watch(notificationsServiceProvider);
  if (!service.isSupported) return;
  final settings = ref.watch(reminderSettingsProvider).value;
  if (settings == null) return;
  if (!settings.isOn) {
    unawaited(service.cancelAll());
    return;
  }
  final plan = planReminders(
    settings: settings,
    now: DateTime.now(),
    today: ref.watch(todayControllerProvider).value,
    routines: ref.watch(routinesControllerProvider).value ?? const [],
  );
  unawaited(service.replaceScheduled(plan).catchError((Object _) {}));

  // Day and routine milestones, as they happen.
  ref.listen(todayControllerProvider, (previous, next) {
    final before = previous?.value;
    final after = next.value;
    if (before == null || after == null || !settings.milestones) return;
    for (final m in dayMilestones(before, after, DateTime.now())) {
      unawaited(service.showNow(m).catchError((Object _) {}));
    }
  });
});

/// Announces goal milestones (called by the goal controller after progress changes).
final goalMilestoneAnnouncerProvider = Provider<void Function(Goal? before, Goal after)>((ref) {
  return (before, after) {
    final settings = ref.read(reminderSettingsProvider).value;
    final service = ref.read(notificationsServiceProvider);
    if (settings == null || !settings.isOn || !settings.milestones || !service.isSupported) return;
    for (final Reminder m in goalMilestones(before, after, DateTime.now())) {
      unawaited(service.showNow(m).catchError((Object _) {}));
    }
  };
});
