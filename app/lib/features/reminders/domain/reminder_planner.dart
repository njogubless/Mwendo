import '../../../core/notifications/reminder.dart';
import '../../../core/routing/routes.dart';
import '../../../core/utils/formatting.dart';
import '../../goals/domain/goal.dart';
import '../../routines/domain/routine.dart';
import '../../today/domain/day.dart';
import 'reminder_settings.dart';

/// Most platforms cap pending notifications (iOS: 64). Keep a safe margin.
const maxScheduledReminders = 50;
const routineSoonLead = Duration(minutes: 5);
const shiftedAfter = Duration(minutes: 15);

String _amount(TargetKind kind, double value, String unit) => switch (kind) {
  TargetKind.duration => formatMinutes(value),
  TargetKind.count => '${formatAmount(value)}${unit.isEmpty ? '' : ' $unit'}',
  TargetKind.check => '',
};

/// Plans reminders for today (from the live plan) and the next [futureDays] days (from routine templates).
///
/// Pure: no clock, no plugin — everything comes in as arguments.
List<Reminder> planReminders({
  required ReminderSettings settings,
  required DateTime now,
  Day? today,
  List<Routine> routines = const [],
  int futureDays = 2,
}) {
  if (!settings.isOn) return const [];
  final out = <Reminder>[];
  final todayDate = DateTime(now.year, now.month, now.day);

  // ---- Today, from the server's plan (already adapted: Minimum Day, time budgets, reschedules).
  if (today != null && today.isToday) {
    for (final routine in today.routines) {
      final open = routine.steps.where((s) => s.status == StepStatus.pending && s.scheduledAt != null).toList();
      if (open.isEmpty) continue;
      final untouched = routine.steps.every((s) => s.status == StepStatus.pending || s.status == StepStatus.cancelled);
      final first = open.first;

      if (settings.routineSoon && untouched) {
        out.add(
          Reminder(
            id: Reminder.idFor('soon:${routine.id}'),
            kind: ReminderKind.routineSoon,
            at: first.scheduledAt!.subtract(routineSoonLead),
            title: '${routine.name} starts in 5 minutes',
            body: 'First up: ${first.title}. Start small.',
            route: Routes.today,
          ),
        );
      }
      if (settings.stepStarts) {
        for (final s in open) {
          final amount = _amount(s.targetKind, s.plannedValue, s.unit);
          out.add(
            Reminder(
              id: Reminder.idFor('step:${s.id}'),
              kind: ReminderKind.stepStart,
              at: s.scheduledAt!,
              title: 'Time for ${s.title}',
              body: [if (amount.isNotEmpty) amount, routine.name].join(' · '),
              route: Routes.today,
            ),
          );
        }
      }
      final timed = open.where((s) => s.targetKind == TargetKind.duration);
      if (settings.shiftedNudge && today.mode == DayMode.normal && routine.adjustment == null && timed.isNotEmpty) {
        out.add(
          Reminder(
            id: Reminder.idFor('shifted:${routine.id}'),
            kind: ReminderKind.shifted,
            at: timed.first.scheduledAt!.add(shiftedAfter),
            title: 'Your ${routine.name.toLowerCase()} has shifted a little',
            body: 'Life happens. Want to fit it into the time you have?',
            route: Routes.adapt(routine.id),
          ),
        );
      }
    }
  }

  // ---- Coming days, from templates (the server plans them when the day arrives).
  for (var offset = 1; offset <= futureDays; offset++) {
    final date = todayDate.add(Duration(days: offset));
    for (final routine in routines) {
      final d = routine.details;
      if (!routine.isActive || d.startMinutes == null || !d.daysOfWeek.contains(date.weekday)) continue;
      final steps = routine.steps;
      if (steps.isEmpty) continue;
      var at = date.add(Duration(minutes: d.startMinutes!));
      if (settings.routineSoon) {
        out.add(
          Reminder(
            id: Reminder.idFor('soon:${routine.id}:${date.toIso8601String()}'),
            kind: ReminderKind.routineSoon,
            at: at.subtract(routineSoonLead),
            title: '${routine.name} starts in 5 minutes',
            body: 'First up: ${steps.first.title}. Start small.',
            route: Routes.today,
          ),
        );
      }
      for (final s in steps) {
        if (settings.stepStarts) {
          final amount = _amount(s.targetKind, s.targetValue, s.unit);
          out.add(
            Reminder(
              id: Reminder.idFor('step:${s.id}:${date.toIso8601String()}'),
              kind: ReminderKind.stepStart,
              at: at,
              title: 'Time for ${s.title}',
              body: [if (amount.isNotEmpty) amount, routine.name].join(' · '),
              route: Routes.today,
            ),
          );
        }
        if (s.isTimed) at = at.add(Duration(minutes: s.targetValue.round()));
      }
    }
  }

  // ---- Evening wind-down, today and coming days.
  if (settings.windDown) {
    for (var offset = 0; offset <= futureDays; offset++) {
      final date = todayDate.add(Duration(days: offset));
      out.add(
        Reminder(
          id: Reminder.idFor('winddown:${date.toIso8601String()}'),
          kind: ReminderKind.windDown,
          at: date.add(Duration(minutes: settings.windDownMinutes)),
          title: 'Time to wind down',
          body: 'A moment to look back on today — whatever you managed counts.',
          route: Routes.today,
        ),
      );
    }
  }

  final upcoming = out.where((r) => r.at.isAfter(now)).toList()..sort((a, b) => a.at.compareTo(b.at));
  return upcoming.take(maxScheduledReminders).toList();
}

/// Milestones reached between two snapshots of today: halfway and complete for the day and each routine.
List<Reminder> dayMilestones(Day before, Day after, DateTime now) {
  if (!after.isToday || before.date != after.date) return const [];
  final out = <Reminder>[];
  Reminder m(String key, String title, String body) => Reminder(
    id: Reminder.idFor('milestone:$key:${after.date.toIso8601String()}'),
    kind: ReminderKind.milestone,
    at: now,
    title: title,
    body: body,
    route: Routes.today,
  );

  final b = before.progress;
  final a = after.progress;
  if (a.total > 0 && b.ratio < 1 && a.ratio >= 1) {
    out.add(m('day:100', "That's everything for today", 'You showed up. Rest well — tomorrow is a new opportunity.'));
  } else if (a.total > 0 && b.ratio < 0.5 && a.ratio >= 0.5) {
    out.add(m('day:50', 'Halfway through today', 'Keep moving — you’re doing well.'));
  }

  for (final r in after.routines) {
    final prev = before.routines.where((x) => x.id == r.id).firstOrNull;
    if (prev == null) continue;
    double share(DayRoutine x) {
      final counted = x.steps.where((s) => s.status != StepStatus.cancelled).toList();
      if (counted.isEmpty) return 0;
      return counted.fold<double>(0, (sum, s) => sum + s.completionRatio) / counted.length;
    }

    bool finished(DayRoutine x) => x.steps.every((s) => !s.status.isOpen) && x.steps.any((s) => s.status.isDone);
    if (!finished(prev) && finished(r)) {
      out.add(m('routine:${r.id}:done', '${r.name} complete', 'Nicely done. Small steps add up.'));
    } else if (share(prev) < 0.5 && share(r) >= 0.5) {
      out.add(m('routine:${r.id}:50', '${r.name}: halfway there', 'Keep your rhythm.'));
    }
  }
  return out;
}

/// Goal milestones: crossing 50% and reaching the target.
List<Reminder> goalMilestones(Goal? before, Goal after, DateTime now) {
  final a = after.ratio;
  if (a == null) return const [];
  final b = before?.ratio ?? 0;
  Reminder m(String key, String title, String body) => Reminder(
    id: Reminder.idFor('goal:${after.id}:$key'),
    kind: ReminderKind.milestone,
    at: now,
    title: title,
    body: body,
    route: Routes.goal(after.id),
  );
  if (b < 1 && a >= 1) return [m('100', '${after.title} — target reached', 'That’s worth celebrating.')];
  if (b < 0.5 && a >= 0.5) return [m('50', 'Halfway to ${after.title}', 'Steady progress. Keep going.')];
  return const [];
}
