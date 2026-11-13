import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/firebase/firebase_failure_mapper.dart';
import '../../../core/firebase/firestore_scope.dart';
import '../../../core/utils/ids.dart';
import '../../../core/utils/json.dart';
import '../../../core/utils/user_clock.dart';
import '../../today/data/firestore/day_store.dart';
import '../../today/domain/engine/day_engine.dart';
import '../../today/domain/engine/history.dart';
import '../domain/routine.dart';
import '../domain/routine_generator.dart';
import '../domain/routines_repository.dart';

/// Routines on Firestore (`users/{uid}/routines/{id}`, steps embedded in order).
///
/// Mirrors `routines/services.py`: every template change also brings today's untouched steps in line
/// ([DayEngine.syncToday]), written in the same batch so the template and today never disagree.
class FirestoreRoutinesRepository implements RoutinesRepository {
  FirestoreRoutinesRepository(this.scope) : _days = DayStore(scope);

  final FirestoreScope scope;
  final DayStore _days;

  @override
  Future<List<Routine>> list() => guardFirebase(() async {
    final ctx = await scope.context();
    final snap = await scope.routines.get();
    final routines = [
      for (final d in snap.docs) routineFromDoc(d.id, d.data()),
    ].where((r) => r.status != RoutineStatus.archived).toList()..sort(_byStartThenName);
    return _withStats(routines, ctx.clock);
  });

  @override
  Future<Routine> get(String id) => guardFirebase(() async {
    final ctx = await scope.context();
    return (await _withStats([await _load(id)], ctx.clock)).single;
  });

  @override
  Future<Routine> create(RoutineDetails details, {List<RoutineStep> steps = const []}) => guardFirebase(() async {
    _validateDetails(details);
    steps.forEach(_validateStep);
    final routine = Routine(
      id: scope.routines.doc().id,
      details: _normalised(details),
      status: RoutineStatus.active,
      steps: [for (final (i, s) in steps.indexed) _withId(s, position: i)],
      stats: RoutineStats.empty,
    );
    await _save(routine, created: true);
    return get(routine.id);
  });

  @override
  Future<Routine> updateDetails(String id, RoutineDetails details) => guardFirebase(() async {
    _validateDetails(details);
    final r = await _load(id);
    await _save(_copy(r, details: _normalised(details)));
    return get(id);
  });

  @override
  Future<Routine> setStatus(String id, RoutineStatus status) => guardFirebase(() async {
    final r = await _load(id);
    await _save(_copy(r, status: status));
    return get(id);
  });

  @override
  Future<void> archive(String id) => setStatus(id, RoutineStatus.archived);

  @override
  Future<void> addStep(String routineId, RoutineStep step) => guardFirebase(() async {
    _validateStep(step);
    final r = await _load(routineId);
    final last = r.steps.fold(-1, (m, s) => s.position > m ? s.position : m);
    await _save(
      _copy(
        r,
        steps: [
          ...r.steps,
          _withId(step, position: last + 1),
        ],
      ),
    );
  });

  @override
  Future<void> updateStep(String routineId, RoutineStep step) => guardFirebase(() async {
    _validateStep(step);
    final r = await _load(routineId);
    if (!r.steps.any((s) => s.id == step.id)) throw const NotFoundFailure();
    await _save(_copy(r, steps: [for (final s in r.steps) s.id == step.id ? _withId(step, position: s.position) : s]));
  });

  @override
  Future<void> removeStep(String routineId, String stepId) => guardFirebase(() async {
    final r = await _load(routineId);
    if (!r.steps.any((s) => s.id == stepId)) throw const NotFoundFailure();
    await _save(_copy(r, steps: r.steps.where((s) => s.id != stepId).toList()));
  });

  @override
  Future<Routine> reorder(String routineId, List<String> stepIds) => guardFirebase(() async {
    final r = await _load(routineId);
    final byId = {for (final s in r.steps) s.id!: s};
    if (stepIds.length != byId.length || !stepIds.toSet().containsAll(byId.keys)) {
      throw const ValidationFailure(userMessage: 'Send every step of the routine exactly once.', code: 'invalid_order');
    }
    await _save(_copy(r, steps: [for (final (i, id) in stepIds.indexed) _withId(byId[id]!, position: i)]));
    return get(routineId);
  });

  @override
  Future<void> startNow(String routineId) => guardFirebase(() async {
    final ctx = await scope.context();
    final routines = await _all();
    final routine = routines.firstWhere((r) => r.id == routineId, orElse: () => throw const NotFoundFailure());
    final (:day, :offline) = await _days.load(ctx.clock.today());
    final engine = DayEngine(ctx.clock)..ensureToday(day, routines);
    engine.startRoutineNow(day, routine);
    final batch = scope.db.batch();
    _days.write(batch, day);
    await scope.commit(batch, offline: ctx.offline || offline);
  });

  @override
  Future<List<RoutineDraft>> generate({
    required List<String> focusAreas,
    required String structure,
    int? wakeMinutes,
  }) async => generateRoutines(focusAreas: focusAreas, structure: structure, wakeMinutes: wakeMinutes);

  // ------------------------------------------------------------------------------------------ internals

  Future<Routine> _load(String id) async {
    final snap = await scope.routines.doc(id).get();
    final data = snap.data();
    if (data == null) throw const NotFoundFailure();
    return routineFromDoc(id, data);
  }

  Future<List<Routine>> _all() async => [
    for (final d in (await scope.routines.get()).docs) routineFromDoc(d.id, d.data()),
  ];

  /// Writes the template and re-syncs today's plan in one batch.
  Future<void> _save(Routine routine, {bool created = false}) async {
    final ctx = await scope.context();
    final batch = scope.db.batch();
    batch.set(scope.routines.doc(routine.id), {
      ...routineToDoc(routine),
      if (created) 'createdAt': FieldValue.serverTimestamp(),
      'archivedAt': routine.status == RoutineStatus.archived ? FieldValue.serverTimestamp() : null,
    }, SetOptions(merge: true));
    final (:day, :offline) = await _days.load(ctx.clock.today());
    if (day.persisted) {
      DayEngine(ctx.clock).syncToday(day, routine);
      _days.write(batch, day);
    }
    await scope.commit(batch, offline: ctx.offline || offline);
  }

  Future<List<Routine>> _withStats(List<Routine> routines, UserClock clock) async {
    final today = clock.today();
    final days = await _days.range(addDays(today, -consistencyWindowDays), today);
    final consistency = routineConsistency(days, today);
    return [for (final r in routines) _copy(r, stats: statsFor(r, consistency[r.id]))];
  }

  RoutineStep _withId(RoutineStep s, {required int position}) {
    final check = s.targetKind == TargetKind.check;
    return RoutineStep(
      id: s.id ?? newId(),
      position: position,
      title: s.title.trim(),
      description: s.description,
      icon: s.icon,
      targetKind: s.targetKind,
      targetValue: check ? 1 : s.targetValue,
      minimumValue: check ? null : s.minimumValue,
      unit: s.unit,
      isEssential: s.isEssential,
      priority: s.priority,
      habitId: s.habitId,
    );
  }
}

int _byStartThenName(Routine a, Routine b) {
  final sa = a.details.startMinutes, sb = b.details.startMinutes;
  if (sa != sb) {
    if (sa == null) return 1;
    if (sb == null) return -1;
    return sa.compareTo(sb);
  }
  return a.name.compareTo(b.name);
}

RoutineStats statsFor(Routine r, double? consistency) {
  final timed = r.steps.where((s) => s.isTimed);
  final essentials = r.steps.where((s) => s.isEssential);
  return RoutineStats(
    steps: r.steps.length,
    totalMinutes: timed.fold(0.0, (total, s) => total + s.targetValue).floor(),
    essentialSteps: essentials.length,
    minimumMinutes: essentials
        .where((s) => s.isTimed)
        .fold(0.0, (total, s) => total + (s.minimumValue ?? s.targetValue))
        .floor(),
    consistency: consistency,
  );
}

Routine _copy(
  Routine r, {
  RoutineDetails? details,
  RoutineStatus? status,
  List<RoutineStep>? steps,
  RoutineStats? stats,
}) => Routine(
  id: r.id,
  details: details ?? r.details,
  status: status ?? r.status,
  steps: steps ?? r.steps,
  stats: stats ?? r.stats,
);

RoutineDetails _normalised(RoutineDetails d) => RoutineDetails(
  name: d.name.trim(),
  category: d.category,
  description: d.description.trim(),
  daysOfWeek: (d.daysOfWeek.toSet().toList()..sort()),
  startMinutes: d.startMinutes,
  finishByMinutes: d.finishByMinutes,
);

ValidationFailure _invalid(String field, String message) => ValidationFailure(
  userMessage: message,
  fieldErrors: {
    field: [message],
  },
);

void _validateDetails(RoutineDetails d) {
  final name = d.name.trim();
  if (name.isEmpty) throw _invalid('name', 'Give the routine a name.');
  if (name.length > 80) throw _invalid('name', 'Keep the name under 80 characters.');
  if (d.description.length > 240) throw _invalid('description', 'Keep the description under 240 characters.');
  if (d.daysOfWeek.any((x) => x < 1 || x > 7)) throw _invalid('days_of_week', 'Days go from 1 (Monday) to 7 (Sunday).');
}

void _validateStep(RoutineStep s) {
  final title = s.title.trim();
  if (title.isEmpty) throw _invalid('title', 'Give the step a name.');
  if (title.length > 80) throw _invalid('title', 'Keep the name under 80 characters.');
  if (s.targetKind == TargetKind.check) return;
  if (s.targetValue <= 0) throw _invalid('target_value', 'Set a target above zero.');
  final min = s.minimumValue;
  if (min != null && (min <= 0 || min > s.targetValue)) {
    throw _invalid('minimum_value', 'The minimum version must be above zero and no more than the target.');
  }
}

// ---------------------------------------------------------------------------------------------- mapping

Json routineToDoc(Routine r) => {
  'name': r.details.name,
  'category': r.details.category.name,
  'description': r.details.description,
  'daysOfWeek': r.details.daysOfWeek,
  'startMinutes': r.details.startMinutes,
  'finishByMinutes': r.details.finishByMinutes,
  'status': r.status.name,
  'updatedAt': FieldValue.serverTimestamp(),
  'steps': [
    for (final s in r.steps)
      {
        'id': s.id,
        'position': s.position,
        'title': s.title,
        'description': s.description,
        'icon': s.icon,
        'targetKind': s.targetKind.name,
        'targetValue': s.targetValue,
        'minimumValue': s.minimumValue,
        'unit': s.unit,
        'isEssential': s.isEssential,
        'priority': s.priority.name,
        'habitId': s.habitId,
      },
  ],
};

Routine routineFromDoc(String id, Json m) => Routine(
  id: id,
  details: RoutineDetails(
    name: (m['name'] as String?) ?? '',
    category: RoutineCategory.parse((m['category'] as String?) ?? 'other'),
    description: (m['description'] as String?) ?? '',
    daysOfWeek: [for (final d in (m['daysOfWeek'] as List<dynamic>?) ?? const []) (d as num).toInt()],
    startMinutes: (m['startMinutes'] as num?)?.toInt(),
    finishByMinutes: (m['finishByMinutes'] as num?)?.toInt(),
  ),
  status: RoutineStatus.values.byName((m['status'] as String?) ?? 'active'),
  steps: [
    for (final s in readMaps(m['steps']))
      RoutineStep(
        id: s['id'] as String,
        position: (s['position'] as num?)?.toInt() ?? 0,
        title: (s['title'] as String?) ?? '',
        description: (s['description'] as String?) ?? '',
        icon: (s['icon'] as String?) ?? 'check_circle',
        targetKind: TargetKind.parse((s['targetKind'] as String?) ?? 'check'),
        targetValue: toDouble(s['targetValue'] ?? 1),
        minimumValue: toDoubleOrNull(s['minimumValue']),
        unit: (s['unit'] as String?) ?? '',
        isEssential: (s['isEssential'] as bool?) ?? false,
        priority: StepPriority.parse((s['priority'] as String?) ?? 'standard'),
        habitId: s['habitId'] as String?,
      ),
  ]..sort((a, b) => a.position.compareTo(b.position)),
  stats: RoutineStats.empty,
);
