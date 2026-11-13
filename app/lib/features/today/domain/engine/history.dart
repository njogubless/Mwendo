import '../../../../core/utils/user_clock.dart';
import '../../../insights/domain/insights.dart';
import '../day.dart';
import 'day_record.dart';
import 'day_rules.dart';

// Read models over past days, ported from backend `routines/selectors.py` (consistency),
// `goals/selectors.py` (habit stats) and `insights/selectors.py` (summary). Pure: callers pass stored days.

const consistencyWindowDays = 14;
const habitWindowDays = 7;

/// A step with the day and run it happened in.
typedef _Row = ({String date, InstanceRecord instance, StepRecord step});

Iterable<_Row> _rows(Iterable<DayRecord> days) sync* {
  for (final d in days) {
    for (final i in d.instances) {
      for (final s in i.steps) {
        yield (date: d.date, instance: i, step: s);
      }
    }
  }
}

/// Average completion per routine over the last 14 days (today's untouched steps aren't "missed").
Map<String, double> routineConsistency(Iterable<DayRecord> days, String today) {
  final since = addDays(today, -consistencyWindowDays);
  final sums = <String, ({double sum, int n})>{};
  for (final r in _rows(days)) {
    final routineId = r.instance.routineId;
    if (routineId == null || r.date.compareTo(since) < 0 || r.date.compareTo(today) > 0) continue;
    if (r.step.status == StepStatus.cancelled) continue;
    if (r.step.status == StepStatus.pending && r.date == today) continue;
    final prev = sums[routineId] ?? (sum: 0.0, n: 0);
    sums[routineId] = (sum: prev.sum + r.step.completionRatio, n: prev.n + 1);
  }
  return {for (final e in sums.entries) e.key: round3(e.value.sum / e.value.n)};
}

class HabitDays {
  const HabitDays({required this.done, required this.planned});

  final int done;
  final int planned;
}

/// Per habit, over the last 7 days: days it happened and days it was planned.
/// [habitOfActivity] maps template step ids to the habit they're linked to now.
Map<String, HabitDays> habitStats(Iterable<DayRecord> days, String today, Map<String, String> habitOfActivity) {
  final since = addDays(today, -(habitWindowDays - 1));
  final planned = <String, Set<String>>{};
  final done = <String, Set<String>>{};
  for (final r in _rows(days)) {
    final habit = habitOfActivity[r.step.activityId];
    if (habit == null || r.date.compareTo(since) < 0 || r.date.compareTo(today) > 0) continue;
    if (r.step.status == StepStatus.cancelled) continue;
    if (!(r.date == today && r.step.status == StepStatus.pending)) (planned[habit] ??= {}).add(r.date);
    if (r.step.status.isDone) (done[habit] ??= {}).add(r.date);
  }
  return {
    for (final h in {...planned.keys, ...done.keys})
      h: HabitDays(done: done[h]?.length ?? 0, planned: planned[h]?.length ?? 0),
  };
}

// ---------------------------------------------------------------------------------------------- insights

const _minSamples = 5; // below this we don't claim a pattern
const _partsOfDay = [('morning', 4, 12), ('afternoon', 12, 17), ('evening', 17, 28)];

String _partOfDay(int localHour) {
  final hour = localHour < 4 ? localHour + 24 : localHour;
  return _partsOfDay.firstWhere((p) => p.$2 <= hour && hour < p.$3).$1;
}

class _Acc {
  String name = '';
  int planned = 0;
  int done = 0;
  double ratioSum = 0;
}

/// Deterministic insights from completion history. No ML: every statement is traceable to counts.
InsightsSummary buildInsights(Iterable<DayRecord> stored, UserClock clock, {int days = 7}) {
  final today = clock.today();
  final since = addDays(today, -(days - 1));
  final rows = _rows(stored).where(
    (r) =>
        r.date.compareTo(since) >= 0 &&
        r.date.compareTo(today) <= 0 &&
        r.step.status != StepStatus.cancelled &&
        // Today's untouched steps are still open, not missed.
        !(r.date == today && r.step.status == StepStatus.pending),
  );

  final perDay = <String, _Acc>{};
  final perRoutine = <String?, _Acc>{};
  final perPart = <String, _Acc>{};
  final skipReasons = <String, int>{};
  var partials = 0;
  for (final r in rows) {
    final ratio = r.step.completionRatio;
    final day = perDay[r.date] ??= _Acc();
    day
      ..planned += 1
      ..ratioSum += ratio
      ..done += r.step.status.isDone ? 1 : 0;
    final routine = perRoutine[r.instance.routineId] ??= _Acc();
    routine
      ..name = r.instance.routineName
      ..planned += 1
      ..ratioSum += ratio;
    if (r.step.scheduledAt != null) {
      (perPart[_partOfDay(clock.localHour(r.step.scheduledAt!))] ??= _Acc())
        ..planned += 1
        ..ratioSum += ratio;
    }
    if (r.step.status == StepStatus.skipped && r.step.skipReason.isNotEmpty) {
      skipReasons[r.step.skipReason] = (skipReasons[r.step.skipReason] ?? 0) + 1;
    }
    if (r.step.status == StepStatus.partiallyCompleted) partials++;
  }

  final series = [
    for (var offset = 0; offset < days; offset++)
      () {
        final date = addDays(since, offset);
        final d = perDay[date];
        final day = parseIsoDay(date);
        return DayPoint(
          date: DateTime(day.year, day.month, day.day),
          planned: d?.planned ?? 0,
          done: d?.done ?? 0,
          ratio: d != null && d.planned > 0 ? round3(d.ratioSum / d.planned) : null,
        );
      }(),
  ];
  final plannedDays = series.where((s) => s.planned > 0).toList();
  final showedUp = plannedDays.where((s) => s.done > 0).length;
  final totalPlanned = perDay.values.fold(0, (total, d) => total + d.planned);
  final ratioTotal = perDay.values.fold(0.0, (total, d) => total + d.ratioSum);

  final routines = [
    for (final v in perRoutine.values)
      if (v.planned > 0) RateRow(label: v.name, steps: v.planned, rate: round3(v.ratioSum / v.planned)),
  ]..sort((a, b) => b.rate.compareTo(a.rate));
  final parts = [
    for (final (name, _, _) in _partsOfDay)
      if ((perPart[name]?.planned ?? 0) > 0)
        RateRow(
          label: name,
          steps: perPart[name]!.planned,
          rate: round3(perPart[name]!.ratioSum / perPart[name]!.planned),
        ),
  ];
  final sortedSkips = skipReasons.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  return InsightsSummary(
    days: days,
    daysShowedUp: showedUp,
    daysPlanned: plannedDays.length,
    consistency: plannedDays.isEmpty ? null : round3(showedUp / plannedDays.length),
    completionRate: totalPlanned == 0 ? null : round3(ratioTotal / totalPlanned),
    partialWins: partials,
    series: series,
    routines: routines,
    partsOfDay: parts,
    skipReasons: {for (final e in sortedSkips) e.key: e.value},
    observations: _observations(showedUp, plannedDays.length, parts, partials, skipReasons, totalPlanned),
  );
}

List<Observation> _observations(
  int showedUp,
  int plannedDays,
  List<RateRow> parts,
  int partials,
  Map<String, int> skipReasons,
  int total,
) {
  if (total < _minSamples) {
    return const [
      Observation(kind: 'learning', text: 'Keep going — after a few more days Mwendo will show what helps you most.'),
    ];
  }
  final notes = <Observation>[];
  if (plannedDays > 0) {
    notes.add(Observation(kind: 'consistency', text: 'You showed up on $showedUp of $plannedDays planned days.'));
  }
  final solid = parts.where((p) => p.steps >= _minSamples).toList();
  if (solid.length >= 2) {
    final best = solid.reduce((a, b) => b.rate > a.rate ? b : a);
    final worst = solid.reduce((a, b) => b.rate < a.rate ? b : a);
    if (best.rate - worst.rate >= 0.2) {
      notes.add(
        Observation(
          kind: 'timing',
          text:
              'Your ${best.label} steps go best (${(best.rate * 100).round()}%). '
              'Consider moving something from the ${worst.label} (${(worst.rate * 100).round()}%).',
        ),
      );
    }
  }
  if (partials > 0) {
    notes.add(
      Observation(kind: 'partial', text: '$partials partial ${partials == 1 ? 'win' : 'wins'} — small actions count.'),
    );
  }
  if (skipReasons.isNotEmpty) {
    final top = skipReasons.entries.reduce((a, b) => b.value > a.value ? b : a);
    if (top.key == 'no_time' && top.value >= 3) {
      notes.add(
        const Observation(
          kind: 'suggestion',
          text: 'Time was tight on several days. A shorter minimum version could help.',
        ),
      );
    } else if (top.key == 'low_energy' && top.value >= 3) {
      notes.add(
        const Observation(
          kind: 'suggestion',
          text: 'Energy was low a few times. Minimum Day is there when you need it.',
        ),
      );
    }
  }
  return notes;
}
