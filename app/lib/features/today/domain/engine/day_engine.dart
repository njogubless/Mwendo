import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/ids.dart';
import '../../../../core/utils/user_clock.dart';
import '../../../routines/domain/routine.dart';
import '../day.dart';
import 'adaptation_planner.dart';
import 'day_record.dart';
import 'day_rules.dart';

const shiftThresholdMinutes = 10;
const recoveryAfterDays = 2;
const _maxActual = 100000.0;

/// Business operations on one day, run on the device (Firebase backend, D-031).
///
/// A faithful port of backend `apps/tracking/services.py` and `selectors.py`: the same materialisation,
/// focus, progress, step transitions, adaptation and template sync, with the same rule violations
/// (same `code`s). Storage-agnostic: callers load a [DayRecord], call one method, then save the record.
/// Only today can change (D-024); read-only days are passed to [buildDay] as they are.
class DayEngine {
  DayEngine(this.clock);

  final UserClock clock;

  DateTime get _now => clock.now();

  // ------------------------------------------------------------------ materialisation

  /// Idempotently materialise today: add a run for every active routine scheduled today that has none yet.
  /// Returns true when [day] changed and must be saved.
  bool ensureToday(DayRecord day, List<Routine> routines) {
    if (day.date != clock.today()) return false;
    final existing = {
      for (final i in day.instances)
        if (!i.isAdHoc) i.routineId,
    };
    final weekday = isoWeekday(day.date);
    final created = <InstanceRecord>[];
    for (final r in routines) {
      if (r.isActive && r.details.daysOfWeek.contains(weekday) && !existing.contains(r.id)) {
        final instance = _createInstance(day, r);
        if (instance != null) created.add(instance);
      }
    }
    if (created.isNotEmpty && day.mode != DayMode.normal) _applyDayModeTo(day, created);
    final changed = created.isNotEmpty || !day.persisted;
    day.persisted = true;
    return changed;
  }

  InstanceRecord? _createInstance(DayRecord day, Routine routine, {bool adHoc = false}) {
    final steps = [...routine.steps]..sort((a, b) => a.position.compareTo(b.position));
    if (steps.isEmpty) return null;
    final start = adHoc ? _now : clock.atLocal(day.date, routine.details.startMinutes);
    var finishBy = adHoc ? null : clock.atLocal(day.date, routine.details.finishByMinutes);
    if (finishBy != null && start != null && !finishBy.isAfter(start)) {
      finishBy = finishBy.add(const Duration(days: 1));
    }
    final instance = InstanceRecord(
      id: newId(),
      routineId: routine.id,
      routineName: routine.name,
      category: routine.details.category,
      scheduledStart: start,
      finishBy: finishBy,
      isAdHoc: adHoc,
      createdAt: _now,
      steps: [for (final s in steps) _snapshot(s)],
    );
    day.instances.add(instance);
    reschedule(instance, start);
    return instance;
  }

  StepRecord _snapshot(RoutineStep s) => _applySnapshot(
    StepRecord(
      id: newId(),
      title: s.title,
      targetKind: s.targetKind,
      priority: s.priority,
      targetValue: s.targetValue,
      plannedValue: s.targetValue,
    ),
    s,
  );

  StepRecord _applySnapshot(StepRecord row, RoutineStep s) => row
    ..activityId = s.id
    ..position = s.position
    ..title = s.title
    ..description = s.description
    ..icon = s.icon
    ..targetKind = s.targetKind
    ..unit = s.unit
    ..isEssential = s.isEssential
    ..priority = s.priority
    ..targetValue = s.targetValue
    ..minimumValue = s.minimumValue
    ..plannedValue = s.targetValue;

  /// Lay open steps back-to-back from [start] by planned duration. Finished steps keep their times.
  void reschedule(InstanceRecord instance, DateTime? start) {
    if (start == null) return;
    var cursor = start;
    instance.steps.sort((a, b) => a.position.compareTo(b.position));
    for (final s in instance.steps) {
      if (s.status == StepStatus.pending || s.status == StepStatus.cancelled) s.scheduledAt = cursor;
      if ((s.status == StepStatus.pending || s.status == StepStatus.inProgress) && s.isTimed) {
        cursor = cursor.add(Duration(microseconds: (s.plannedValue * Duration.microsecondsPerMinute).round()));
      }
    }
  }

  /// "Start now" (D-022): reuse today's run if it still has open steps, otherwise add an ad-hoc run.
  InstanceRecord startRoutineNow(DayRecord today, Routine routine) {
    final open = today.instances.where((i) => i.routineId == routine.id && i.steps.any((s) => s.status.isOpen)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (open.isNotEmpty) return open.first;
    final instance = _createInstance(today, routine, adHoc: true);
    if (instance == null) {
      throw const ValidationFailure(
        userMessage: 'Add a step to this routine before starting it.',
        code: 'routine_empty',
      );
    }
    return instance;
  }

  /// After a template edit, bring today's *untouched* steps in line. Started/finished steps never change.
  /// [today] is the already-materialised day; when today isn't materialised it will pick up the template.
  void syncToday(DayRecord today, Routine routine) {
    if (today.date != clock.today() || !today.persisted) return;
    final scheduled = routine.isActive && routine.details.daysOfWeek.contains(isoWeekday(today.date));
    InstanceRecord? instance;
    for (final i in today.instances) {
      if (i.routineId == routine.id && !i.isAdHoc) instance = i;
    }

    if (instance == null) {
      if (!scheduled) return;
      final created = _createInstance(today, routine);
      if (created != null && today.mode != DayMode.normal) _applyDayModeTo(today, [created]);
      return;
    }

    final untouched = instance.steps.where(isAdaptable).toList();
    if (!scheduled) {
      instance.steps.removeWhere(untouched.contains);
      if (instance.steps.isEmpty) today.instances.remove(instance);
      return;
    }

    final active = {for (final s in routine.steps) s.id: s};
    final rows = {for (final s in instance.steps) s.activityId};
    for (final row in untouched) {
      final template = active[row.activityId];
      if (template == null) {
        instance.steps.remove(row);
      } else {
        _applySnapshot(row, template).status = StepStatus.pending;
      }
    }
    for (final s in routine.steps) {
      if (!rows.contains(s.id)) instance.steps.add(_snapshot(s));
    }
    instance
      ..routineName = routine.name
      ..category = routine.details.category;
    for (final a in today.adjustments) {
      if (a.instanceId == instance.id && a.isActive) a.revertedAt = _now;
    }
    if (today.mode != DayMode.normal) _applyDayModeTo(today, [instance]);
    reschedule(instance, _later(instance.scheduledStart, _now));
  }

  DateTime _later(DateTime? a, DateTime b) => a != null && a.isAfter(b) ? a : b;

  // ------------------------------------------------------------------ step transitions

  StepRecord _todayStep(DayRecord day, String stepId) {
    final step = day.step(stepId);
    if (step == null || day.date != clock.today()) {
      throw const ConflictFailure(userMessage: "Only today's steps can be changed.", code: 'not_today');
    }
    return step;
  }

  void _stopClock(StepRecord s) {
    if (s.runningSince != null) {
      final seconds = _now.difference(s.runningSince!).inSeconds;
      s.activeSeconds += seconds < 0 ? 0 : seconds;
      s.runningSince = null;
    }
  }

  void start(DayRecord day, String stepId) {
    final s = _todayStep(day, stepId);
    if (s.status == StepStatus.completed ||
        s.status == StepStatus.partiallyCompleted ||
        s.status == StepStatus.skipped) {
      throw const ConflictFailure(
        userMessage: 'This step is already wrapped up. Undo it first to start again.',
        code: 'already_done',
      );
    }
    if (s.isRunning) return;
    // Only one step runs at a time: pause any other running step.
    for (final other in day.steps) {
      if (other != s && other.isRunning) _stopClock(other);
    }
    s
      ..status = StepStatus.inProgress
      ..startedAt ??= _now
      ..runningSince = _now;
  }

  void pause(DayRecord day, String stepId) {
    final s = _todayStep(day, stepId);
    if (s.status != StepStatus.inProgress) {
      throw const ConflictFailure(userMessage: 'Only a step in progress can be paused.', code: 'not_in_progress');
    }
    _stopClock(s);
  }

  /// Full completion when [actualValue] is omitted; partial when it is below the planned value.
  void complete(DayRecord day, String stepId, {double? actualValue}) {
    final s = _todayStep(day, stepId);
    var actual = s.targetKind == TargetKind.check ? 1.0 : (actualValue ?? s.plannedValue);
    if (actual <= 0 || actual > _maxActual) {
      throw const ValidationFailure(
        userMessage: 'Log an amount above zero, or skip the step instead.',
        code: 'invalid_amount',
      );
    }
    actual = (actual * 100).roundToDouble() / 100;
    _stopClock(s);
    s
      ..actualValue = actual
      ..completionRatio = completionRatio(actual, s.plannedValue)
      ..status = actual >= s.plannedValue ? StepStatus.completed : StepStatus.partiallyCompleted
      ..skipReason = ''
      ..startedAt ??= _now
      ..completedAt = _now;
  }

  void skip(DayRecord day, String stepId, {String reason = ''}) {
    final s = _todayStep(day, stepId);
    _stopClock(s);
    s
      ..status = StepStatus.skipped
      ..skipReason = reason
      ..actualValue = null
      ..completionRatio = 0
      ..completedAt = _now;
  }

  /// Undo: back to pending, as if nothing happened.
  void reset(DayRecord day, String stepId) {
    final s = _todayStep(day, stepId);
    s
      ..status = StepStatus.pending
      ..actualValue = null
      ..completionRatio = 0
      ..skipReason = ''
      ..startedAt = null
      ..runningSince = null
      ..completedAt = null
      ..activeSeconds = 0;
  }

  void reflect(DayRecord day, String stepId, String note) {
    final s = day.step(stepId);
    if (s == null) throw const NotFoundFailure();
    final trimmed = note.trim();
    if (trimmed.length > 500) {
      throw const ValidationFailure(
        userMessage: 'Please check the highlighted fields.',
        fieldErrors: {
          'note': ['Keep it under 500 characters.'],
        },
      );
    }
    if (trimmed.isNotEmpty) s.reflections.insert(0, trimmed);
  }

  // ------------------------------------------------------------------ adaptation

  List<PlanItem> _planItems(Iterable<StepRecord> steps) => [
    for (final s in steps)
      PlanItem(
        id: s.id,
        targetKind: s.targetKind,
        targetValue: s.targetValue,
        minimumValue: s.minimumValue,
        isEssential: s.isEssential,
        priority: s.priority,
        position: s.position,
      ),
  ];

  StepState _state(StepRecord s) =>
      StepState(plannedValue: s.plannedValue, status: s.status, scheduledAt: s.scheduledAt);

  List<StepChange> _applyOutcomes(DayRecord day, AdaptationPlan plan) => [
    for (final o in plan.items) _applyOutcome(day.step(o.id)!, o),
  ];

  StepChange _applyOutcome(StepRecord s, ItemOutcome o) {
    final before = _state(s);
    s
      ..plannedValue = o.plannedValue
      ..status = o.status;
    return StepChange(stepId: s.id, before: before, after: _state(s));
  }

  void _revert(DayRecord day, AdjustmentRecord adjustment) {
    if (!adjustment.isActive) return;
    for (final ch in adjustment.changes) {
      final s = day.step(ch.stepId);
      if (s == null || !isAdaptable(s)) continue; // The user already acted on it; their action stands.
      s
        ..plannedValue = ch.before.plannedValue
        ..status = ch.before.status
        ..scheduledAt = ch.before.scheduledAt;
    }
    adjustment.revertedAt = _now;
  }

  List<StepRecord> _adaptable(InstanceRecord instance) =>
      instance.steps.where(isAdaptable).toList()..sort((a, b) => a.position.compareTo(b.position));

  void _applyDayModeTo(DayRecord day, List<InstanceRecord> instances) {
    var adjustment = day.adjustments.where((a) => a.instanceId == null && a.isActive).firstOrNull;
    if (adjustment == null) {
      adjustment = AdjustmentRecord(
        id: newId(),
        kind: day.mode == DayMode.recovery ? AdjustmentKind.recovery : AdjustmentKind.minimumDay,
        mode: day.mode,
        createdAt: _now,
      );
      day.adjustments.add(adjustment);
    }
    for (final instance in instances) {
      adjustment.changes.addAll(_applyOutcomes(day, planMinimumDay(_planItems(_adaptable(instance)))));
      reschedule(instance, instance.scheduledStart);
    }
  }

  void setDayMode(DayRecord day, DayMode mode) {
    if (day.date != clock.today()) {
      throw const ConflictFailure(userMessage: "Only today's plan can be changed.", code: 'not_today');
    }
    if (day.mode == mode) return;
    final active = day.adjustments.where((a) => a.isActive).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final a in active) {
      _revert(day, a);
    }
    day.mode = mode;
    if (mode != DayMode.normal) _applyDayModeTo(day, [...day.instances]);
  }

  void dismissRecovery(DayRecord day) {
    if (day.date != clock.today()) {
      throw const ConflictFailure(userMessage: "Only today's plan can be changed.", code: 'not_today');
    }
    day.recoveryDismissed = true;
  }

  AdjustmentRecord applyTimeBudget(DayRecord day, String instanceId, int budgetMinutes) {
    final instance = day.instance(instanceId);
    if (instance == null || day.date != clock.today()) {
      throw const ConflictFailure(userMessage: "Only today's routines can be adjusted.", code: 'not_today');
    }
    if (day.mode != DayMode.normal) {
      throw const ConflictFailure(
        userMessage: 'Minimum Day is on. Switch back to a normal day to choose a time budget.',
        code: 'minimum_day_active',
      );
    }
    for (final previous in day.adjustments.where((a) => a.instanceId == instanceId && a.isActive).toList()) {
      _revert(day, previous);
    }
    final steps = _adaptable(instance);
    if (steps.isEmpty) {
      throw const ConflictFailure(
        userMessage: "There's nothing left to adjust in this routine.",
        code: 'nothing_to_adapt',
      );
    }
    final adjustment = AdjustmentRecord(
      id: newId(),
      kind: AdjustmentKind.timeBudget,
      instanceId: instanceId,
      budgetMinutes: budgetMinutes,
      createdAt: _now,
      changes: _applyOutcomes(day, planTimeBudget(_planItems(steps), budgetMinutes)),
    );
    day.adjustments.add(adjustment);
    reschedule(instance, _later(instance.scheduledStart, _now));
    return adjustment;
  }

  void revertAdjustment(DayRecord day, String adjustmentId) {
    final adjustment = day.adjustment(adjustmentId);
    if (adjustment == null || day.date != clock.today()) {
      throw const ConflictFailure(userMessage: "Only today's changes can be undone.", code: 'not_today');
    }
    if (adjustment.instanceId == null) {
      setDayMode(day, DayMode.normal);
    } else {
      _revert(day, adjustment);
    }
  }

  // ------------------------------------------------------------------ read models

  AdjustmentRef _ref(AdjustmentRecord a) => AdjustmentRef(id: a.id, kind: a.kind.api, budgetMinutes: a.budgetMinutes);

  DayStep _step(StepRecord s, String instanceId) => DayStep(
    id: s.id,
    routineInstanceId: instanceId,
    title: s.title,
    description: s.description,
    icon: s.icon,
    targetKind: s.targetKind,
    unit: s.unit,
    isEssential: s.isEssential,
    priority: s.priority,
    targetValue: s.targetValue,
    minimumValue: s.minimumValue,
    plannedValue: s.plannedValue,
    actualValue: s.actualValue,
    status: s.status,
    completionRatio: s.completionRatio,
    skipReason: s.skipReason,
    scheduledAt: s.scheduledAt?.toLocal(),
    completedAt: s.completedAt?.toLocal(),
    elapsedSeconds: elapsedSeconds(s, _now),
    isRunning: s.isRunning,
    reflection: s.reflections.isEmpty ? '' : s.reflections.first,
  );

  /// The `Day` the UI shows: progress, focus, timing and recovery, computed here once (D-020).
  /// [daysAway] is the number of days since the user last made progress (null without history).
  Day buildDay(DayRecord day, {int? daysAway}) {
    final isToday = day.date == clock.today();
    final far = DateTime.utc(9999);
    final instances = [...day.instances]
      ..sort((a, b) {
        final byStart = (a.scheduledStart ?? far).compareTo(b.scheduledStart ?? far);
        return byStart != 0 ? byStart : a.createdAt.compareTo(b.createdAt);
      });
    for (final i in instances) {
      i.steps.sort((a, b) => a.position.compareTo(b.position));
    }
    final items = [for (final i in instances) ...i.steps];
    final progress = computeProgress(items);
    final focus = isToday ? selectFocus(items) : null;
    final shifted = shiftedMinutes(focus, _now);
    final focusInstance = focus == null ? null : day.instanceOf(focus);

    final TimingStatus timing;
    if (items.isEmpty) {
      timing = TimingStatus.empty;
    } else if (focus == null) {
      timing = TimingStatus.done;
    } else if (shifted >= shiftThresholdMinutes) {
      timing = TimingStatus.shifted;
    } else {
      timing = TimingStatus.onTrack;
    }

    final away = isToday ? daysAway : null;
    final recoverySuggested =
        isToday &&
        away != null &&
        away >= recoveryAfterDays &&
        day.persisted &&
        day.mode == DayMode.normal &&
        !day.recoveryDismissed &&
        progress.completed + progress.partial == 0;
    final active = day.adjustments.where((a) => a.isActive).toList();
    final date = parseIsoDay(day.date);

    return Day(
      date: DateTime(date.year, date.month, date.day),
      isToday: isToday,
      mode: day.mode,
      progress: progress,
      focusId: focus?.id,
      timing: timing,
      shiftedMinutes: shifted,
      timingInstanceId: focusInstance?.id,
      recoverySuggested: recoverySuggested,
      daysAway: away,
      adjustments: [for (final a in active) _ref(a)],
      fetchedAt: _now.toLocal(),
      routines: [
        for (final i in instances)
          DayRoutine(
            id: i.id,
            routineId: i.routineId,
            name: i.routineName,
            category: i.category,
            scheduledStart: i.scheduledStart?.toLocal(),
            finishBy: i.finishBy?.toLocal(),
            isAdHoc: i.isAdHoc,
            adjustment: active.where((a) => a.instanceId == i.id).map(_ref).firstOrNull,
            steps: [for (final s in i.steps) _step(s, i.id)],
          ),
      ],
    );
  }

  AdaptationPreview buildPreview(DayRecord day, String instanceId, {int? budgetMinutes, bool minimum = false}) {
    final instance = day.instance(instanceId);
    if (instance == null) throw const NotFoundFailure();
    final steps = _adaptable(instance);
    final items = _planItems(steps);
    final focus = selectFocus(instance.steps);
    final original = items.where((i) => i.isTimed).fold(0.0, (total, i) => total + i.targetValue).floor();
    int? available;
    if (instance.finishBy != null) {
      final minutes = instance.finishBy!.difference(_now).inSeconds ~/ 60;
      available = minutes < 0 ? 0 : minutes;
    }
    final (:options, :recommended) = suggestedBudgets(available, original);

    final int? budget;
    final AdaptationPlan plan;
    if (minimum) {
      budget = null;
      plan = planMinimumDay(items);
    } else {
      budget = (budgetMinutes != null && budgetMinutes > 0) ? budgetMinutes : (recommended ?? options.last);
      plan = planTimeBudget(items, budget);
    }
    final byId = {for (final s in steps) s.id: s};
    final active = day.adjustments.where((a) => a.instanceId == instanceId && a.isActive).firstOrNull;

    return AdaptationPreview(
      instanceId: instance.id,
      routineName: instance.routineName,
      isMinimum: minimum,
      budgetMinutes: budget,
      options: options,
      recommended: recommended,
      shiftedMinutes: shiftedMinutes(focus, _now),
      availableMinutes: available,
      finishBy: instance.finishBy?.toLocal(),
      dayMode: day.mode,
      activeAdjustment: active == null ? null : _ref(active),
      originalMinutes: plan.originalMinutes,
      plannedMinutes: plan.plannedMinutes,
      fits: plan.fits,
      essentialsKept: plan.essentialsKept,
      essentialsTotal: plan.essentialsTotal,
      items: [
        for (final o in plan.items)
          AdaptationItem(
            completionId: o.id,
            title: byId[o.id]!.title,
            icon: byId[o.id]!.icon,
            targetKind: byId[o.id]!.targetKind,
            unit: byId[o.id]!.unit,
            isEssential: byId[o.id]!.isEssential,
            priority: byId[o.id]!.priority,
            targetValue: byId[o.id]!.targetValue,
            plannedValue: o.plannedValue,
            kept: o.status == StepStatus.pending,
          ),
      ],
    );
  }
}

/// Days since the user last made progress before [today], given recent days (any order); null when none of
/// them shows progress.
int? daysAwayFrom(String today, Iterable<DayRecord> history) {
  String? last;
  for (final d in history) {
    if (d.date.compareTo(today) < 0 && d.hasProgress && (last == null || d.date.compareTo(last) > 0)) last = d.date;
  }
  return last == null ? null : daysBetween(last, today);
}
