import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mwendo/core/errors/app_failure.dart';
import 'package:mwendo/core/utils/user_clock.dart';
import 'package:mwendo/features/routines/domain/routine.dart';
import 'package:mwendo/features/routines/domain/routine_generator.dart';
import 'package:mwendo/features/today/domain/day.dart';
import 'package:mwendo/features/today/domain/engine/adaptation_planner.dart';
import 'package:mwendo/features/today/domain/engine/day_engine.dart';
import 'package:mwendo/features/today/domain/engine/day_record.dart';
import 'package:mwendo/features/today/domain/engine/history.dart';

/// Nairobi is UTC+3 with no DST. 2026-11-13 is a Friday.
const _tz = 'Africa/Nairobi';

DateTime _utc(int h, int m, {int day = 13}) => DateTime.utc(2026, 11, day, h, m);

UserClock _clock(DateTime Function() now) => UserClock(timezone: _tz, dayStart: const Duration(hours: 4), now: now);

RoutineStep _s(
  String id,
  String title, {
  int position = 0,
  TargetKind kind = TargetKind.duration,
  double target = 10,
  double? min,
  bool essential = false,
  StepPriority priority = StepPriority.standard,
}) => RoutineStep(
  id: id,
  title: title,
  position: position,
  targetKind: kind,
  targetValue: kind == TargetKind.check ? 1 : target,
  minimumValue: min,
  isEssential: essential,
  priority: priority,
);

Routine _morning({List<RoutineStep>? steps, String name = 'Morning', List<int> days = const [1, 2, 3, 4, 5, 6, 7]}) =>
    Routine(
      id: 'r-morning',
      details: RoutineDetails(
        name: name,
        category: RoutineCategory.morning,
        daysOfWeek: days,
        startMinutes: 6 * 60 + 30,
        finishByMinutes: 8 * 60,
      ),
      status: RoutineStatus.active,
      stats: RoutineStats.empty,
      steps:
          steps ??
          [
            _s('water', 'Water', kind: TargetKind.check, essential: true, priority: StepPriority.core),
            _s('move', 'Move', position: 1, target: 20, min: 5, essential: true, priority: StepPriority.core),
            _s('read', 'Read', position: 2, target: 15, priority: StepPriority.optional),
            _s('plan', 'Plan', position: 3, target: 5, min: 2),
          ],
    );

void main() {
  late DateTime now;
  late DayEngine engine;
  late DayRecord day;

  String stepId(String activityId) => day.steps.firstWhere((s) => s.activityId == activityId).id;
  StepRecord step(String activityId) => day.steps.firstWhere((s) => s.activityId == activityId);

  setUp(() {
    now = _utc(3, 0); // 06:00 in Nairobi
    engine = DayEngine(_clock(() => now));
    day = DayRecord(date: '2026-11-13');
    engine.ensureToday(day, [_morning()]);
  });

  group('UserClock', () {
    test("before the user's day start it is still yesterday", () {
      expect(_clock(() => _utc(0, 30)).today(), '2026-11-12'); // 03:30 local
      expect(_clock(() => _utc(1, 30)).today(), '2026-11-13'); // 04:30 local
    });

    test('wall-clock times are placed in the user time zone', () {
      expect(_clock(() => now).atLocal('2026-11-13', 6 * 60 + 30), _utc(3, 30));
    });
  });

  group('materialisation', () {
    test('creates a run per scheduled routine with steps laid back to back', () {
      expect(day.persisted, isTrue);
      expect(day.instances, hasLength(1));
      expect(day.instances.single.finishBy, _utc(5, 0));
      expect(step('water').scheduledAt, _utc(3, 30)); // untimed: takes no clock time
      expect(step('move').scheduledAt, _utc(3, 30));
      expect(step('read').scheduledAt, _utc(3, 50));
      expect(step('plan').scheduledAt, _utc(4, 5));
    });

    test('is idempotent', () {
      expect(engine.ensureToday(day, [_morning()]), isFalse);
      expect(day.instances, hasLength(1));
    });

    test('skips routines not scheduled today, paused routines and other days', () {
      final fresh = DayRecord(date: '2026-11-13');
      engine.ensureToday(fresh, [
        _morning(days: [1]),
      ]);
      expect(fresh.instances, isEmpty);

      final past = DayRecord(date: '2026-11-10');
      expect(engine.ensureToday(past, [_morning()]), isFalse);
      expect(past.instances, isEmpty);
    });
  });

  group('focus, progress and transitions', () {
    test('focus is the earliest pending step; a running step wins', () {
      expect(engine.buildDay(day).focus?.title, 'Water');
      engine.start(day, stepId('read'));
      expect(engine.buildDay(day).focus?.title, 'Read');
    });

    test('only one step runs at a time and paused time is kept', () {
      engine.start(day, stepId('move'));
      now = now.add(const Duration(minutes: 3));
      engine.start(day, stepId('read'));
      expect(step('move').isRunning, isFalse);
      expect(step('move').activeSeconds, 180);
      expect(step('read').isRunning, isTrue);
    });

    test('partial completion always counts; skipped is honest 0; cancelled is left out', () {
      engine.complete(day, stepId('move'), actualValue: 10);
      expect(step('move').status, StepStatus.partiallyCompleted);
      expect(step('move').completionRatio, 0.5);
      engine.complete(day, stepId('water'));
      engine.skip(day, stepId('read'), reason: 'no_time');

      final progress = engine.buildDay(day).progress;
      expect(progress.total, 4);
      expect(progress.completed, 1);
      expect(progress.partial, 1);
      expect(progress.skipped, 1);
      expect(progress.ratio, 0.375); // (1 + 0.5 + 0 + 0) / 4
    });

    test('rule violations carry the same codes as the API', () {
      expect(
        () => engine.complete(day, stepId('move'), actualValue: 0),
        throwsA(isA<ValidationFailure>().having((f) => f.code, 'code', 'invalid_amount')),
      );
      engine.complete(day, stepId('move'));
      expect(
        () => engine.start(day, stepId('move')),
        throwsA(isA<ConflictFailure>().having((f) => f.code, 'code', 'already_done')),
      );
      expect(
        () => engine.pause(day, stepId('read')),
        throwsA(isA<ConflictFailure>().having((f) => f.code, 'code', 'not_in_progress')),
      );
      final yesterday = DayRecord(date: '2026-11-12', instances: [...day.instances], persisted: true);
      expect(
        () => engine.complete(yesterday, stepId('read')),
        throwsA(isA<ConflictFailure>().having((f) => f.code, 'code', 'not_today')),
      );
    });

    test('undo puts a step back as if nothing happened', () {
      engine.complete(day, stepId('move'), actualValue: 10);
      engine.reset(day, stepId('move'));
      expect(step('move').status, StepStatus.pending);
      expect(step('move').actualValue, isNull);
      expect(step('move').completedAt, isNull);
    });

    test('timing shifts once the focus is 10+ minutes late', () {
      now = _utc(3, 39);
      expect(engine.buildDay(day).timing, TimingStatus.onTrack);
      now = _utc(3, 41);
      final d = engine.buildDay(day);
      expect(d.timing, TimingStatus.shifted);
      expect(d.shiftedMinutes, 11);
      expect(d.timingInstanceId, day.instances.single.id);
    });

    test('reflections are kept newest first', () {
      engine.reflect(day, stepId('move'), 'felt good');
      engine.reflect(day, stepId('move'), 'even better');
      expect(engine.buildDay(day).stepById(stepId('move'))!.reflection, 'even better');
    });
  });

  group('adaptation', () {
    test('Minimum Day keeps essentials at their floor and sets the rest aside, revertibly', () {
      engine.setDayMode(day, DayMode.minimum);
      expect(step('move').plannedValue, 5);
      expect(step('read').status, StepStatus.cancelled);
      expect(step('plan').status, StepStatus.cancelled);
      final d = engine.buildDay(day);
      expect(d.progress.total, 2);
      expect(d.dayAdjustment?.kind, 'minimum_day');

      engine.revertAdjustment(day, d.dayAdjustment!.id);
      expect(day.mode, DayMode.normal);
      expect(step('move').plannedValue, 20);
      expect(step('read').status, StepStatus.pending);
      expect(engine.buildDay(day).adjustments, isEmpty);
    });

    test('a time budget drops optional steps first and fits the budget', () {
      final instanceId = day.instances.single.id;
      final preview = engine.buildPreview(day, instanceId, budgetMinutes: 15);
      expect(preview.originalMinutes, 40);
      expect(preview.plannedMinutes, 15);
      expect(preview.fits, isTrue);
      expect(day.steps.every((s) => s.status == StepStatus.pending), isTrue, reason: 'preview never changes the day');

      engine.applyTimeBudget(day, instanceId, 15);
      expect(step('read').status, StepStatus.cancelled);
      expect(step('plan').plannedValue, 2, reason: 'kept at its floor; spare minutes go to core steps first');
      expect(step('move').plannedValue, 13);
      expect(step('water').status, StepStatus.pending, reason: 'untimed steps are never shrunk (D-021)');

      final adjustment = engine.buildDay(day).routines.single.adjustment!;
      expect(adjustment.budgetMinutes, 15);
      engine.revertAdjustment(day, adjustment.id);
      expect(step('read').status, StepStatus.pending);
      expect(step('move').plannedValue, 20);
    });

    test('a step the user already acted on stays as they left it after a revert', () {
      final instanceId = day.instances.single.id;
      final adjustment = engine.applyTimeBudget(day, instanceId, 15);
      engine.complete(day, stepId('move'));
      engine.revertAdjustment(day, adjustment.id);
      expect(step('move').status, StepStatus.completed);
      expect(step('move').plannedValue, 13);
    });

    test('time budgets are blocked during Minimum Day', () {
      engine.setDayMode(day, DayMode.minimum);
      expect(
        () => engine.applyTimeBudget(day, day.instances.single.id, 15),
        throwsA(isA<ConflictFailure>().having((f) => f.code, 'code', 'minimum_day_active')),
      );
    });

    test('recovery is suggested after 2+ days away until dismissed', () {
      expect(engine.buildDay(day, daysAway: 3).recoverySuggested, isTrue);
      expect(engine.buildDay(day, daysAway: 1).recoverySuggested, isFalse);
      engine.dismissRecovery(day);
      expect(engine.buildDay(day, daysAway: 3).recoverySuggested, isFalse);
    });

    test('days away counts from the last day with progress', () {
      final done = DayRecord(date: '2026-11-10', persisted: true)
        ..instances.add(
          InstanceRecord(
            id: 'i',
            routineName: 'M',
            category: RoutineCategory.morning,
            createdAt: now,
            steps: [
              StepRecord(
                id: 's',
                title: 'x',
                targetKind: TargetKind.check,
                priority: StepPriority.core,
                targetValue: 1,
                plannedValue: 1,
                status: StepStatus.completed,
              ),
            ],
          ),
        );
      expect(daysAwayFrom('2026-11-13', [DayRecord(date: '2026-11-12', persisted: true), done]), 3);
      expect(daysAwayFrom('2026-11-13', const []), isNull);
    });
  });

  group('template sync and start now', () {
    test("a template edit updates today's untouched steps only", () {
      engine.complete(day, stepId('move'));
      final edited = _morning(
        name: 'Calm morning',
        steps: [
          _s('water', 'Big glass of water', kind: TargetKind.check, essential: true),
          _s('move', 'Move (renamed)', position: 1, target: 30),
          _s('stretch', 'Stretch', position: 2, target: 5),
        ],
      );
      engine.syncToday(day, edited);

      expect(day.instances.single.routineName, 'Calm morning');
      expect(step('water').title, 'Big glass of water');
      expect(step('move').title, 'Move', reason: 'finished steps keep their snapshot (D-006)');
      expect(day.steps.any((s) => s.activityId == 'read'), isFalse);
      expect(step('stretch').status, StepStatus.pending);
    });

    test('pausing a routine removes its untouched steps from today', () {
      engine.complete(day, stepId('water'));
      engine.syncToday(day, _morning(days: const []));
      expect(day.steps.map((s) => s.activityId), ['water']);
    });

    test('"Start now" reuses an open run, else adds an ad-hoc one (D-022)', () {
      final routine = _morning();
      expect(engine.startRoutineNow(day, routine).id, day.instances.single.id);
      for (final s in [...day.steps]) {
        engine.complete(day, s.id);
      }
      final extra = engine.startRoutineNow(day, routine);
      expect(extra.isAdHoc, isTrue);
      expect(extra.scheduledStart, now);
      expect(day.instances, hasLength(2));
    });

    test('starting an empty routine explains what to do', () {
      for (final s in [...day.steps]) {
        engine.skip(day, s.id);
      }
      expect(
        () => engine.startRoutineNow(day, _morning(steps: const [])),
        throwsA(isA<ValidationFailure>().having((f) => f.code, 'code', 'routine_empty')),
      );
    });
  });

  group('adaptation planner guarantees', () {
    test('kept steps never go below their floor, essentials are kept, the plan fits when it can', () {
      final random = Random(7);
      for (var run = 0; run < 300; run++) {
        final items = [
          for (var i = 0; i < 1 + random.nextInt(7); i++)
            () {
              final kind = random.nextInt(5) == 0 ? TargetKind.count : TargetKind.duration;
              final target = (5 + random.nextInt(40)).toDouble();
              return PlanItem(
                id: '$i',
                targetKind: kind,
                targetValue: target,
                minimumValue: random.nextBool() ? (1 + random.nextInt(target.toInt())).toDouble() : null,
                isEssential: random.nextInt(3) == 0,
                priority: StepPriority.values[random.nextInt(3)],
                position: i,
              );
            }(),
        ];
        final budget = random.nextInt(90);
        final plan = planTimeBudget(items, budget);
        final byId = {for (final i in items) i.id: i};
        var planned = 0.0;
        for (final o in plan.items) {
          final item = byId[o.id]!;
          if (item.isEssential) expect(o.status, StepStatus.pending);
          if (o.status == StepStatus.pending) {
            expect(o.plannedValue, greaterThanOrEqualTo(item.isTimed ? item.floor : item.targetValue));
            expect(o.plannedValue, lessThanOrEqualTo(item.targetValue));
            if (item.isTimed) planned += o.plannedValue;
          }
        }
        final essentialFloors = items.where((i) => i.isEssential && i.isTimed).fold(0.0, (t, i) => t + i.floor);
        if (essentialFloors <= budget) {
          expect(plan.fits, isTrue);
          expect(planned, lessThanOrEqualTo(budget));
        }
      }
    });

    test('Minimum Day keeps the most important step when nothing is essential', () {
      final plan = planMinimumDay(const [
        PlanItem(
          id: 'a',
          targetKind: TargetKind.duration,
          targetValue: 10,
          isEssential: false,
          priority: StepPriority.standard,
          position: 0,
        ),
        PlanItem(
          id: 'b',
          targetKind: TargetKind.duration,
          targetValue: 10,
          minimumValue: 3,
          isEssential: false,
          priority: StepPriority.core,
          position: 1,
        ),
      ]);
      expect(plan.items.where((o) => o.status == StepStatus.pending).single.id, 'b');
      expect(plan.plannedMinutes, 3);
    });

    test('budget suggestions fit the time available', () {
      final fitting = suggestedBudgets(40, 50);
      expect(fitting.options, [15, 30, 45]);
      expect(fitting.recommended, 30);
      final unknown = suggestedBudgets(null, 10);
      expect(unknown.options, [15]);
      expect(unknown.recommended, isNull);
    });
  });

  group('history', () {
    test('insights summarise the last days without counting open steps', () {
      engine.complete(day, stepId('water'));
      engine.complete(day, stepId('move'), actualValue: 10);
      engine.skip(day, stepId('read'), reason: 'low_energy');
      final summary = buildInsights([day], engine.clock);
      expect(summary.daysPlanned, 1);
      expect(summary.daysShowedUp, 1);
      expect(summary.partialWins, 1);
      expect(summary.completionRate, 0.5); // (1 + 0.5 + 0) / 3; "plan" is still open today
      expect(summary.skipReasons, {'low_energy': 1});
      expect(summary.partsOfDay.single.label, 'morning');
      expect(summary.series, hasLength(7));
    });

    test('routine consistency and habit stats', () {
      engine.complete(day, stepId('move'));
      expect(routineConsistency([day], '2026-11-13'), {'r-morning': 1.0});
      final stats = habitStats([day], '2026-11-13', {'move': 'h1', 'read': 'h2'});
      expect(stats['h1']!.done, 1);
      expect(stats.containsKey('h2'), isFalse, reason: "today's untouched step isn't planned-and-missed yet");
    });
  });

  test('the onboarding generator matches the server', () {
    final structured = generateRoutines(
      focusAreas: ['health', 'learning'],
      structure: 'structured',
      wakeMinutes: 6 * 60,
    );
    expect(structured.map((r) => r.details.name), ['Morning', 'Focus block', 'Evening wind-down']);
    expect(structured.first.details.startMinutes, 6 * 60 + 10);
    expect(structured.first.details.finishByMinutes, isNotNull);
    final loose = generateRoutines(focusAreas: const [], structure: 'loose');
    expect(loose.map((r) => r.details.name), ['Morning', 'Evening wind-down']);
    expect(loose.first.steps.map((s) => s.position), [0, 1, 2]);
  });
}
