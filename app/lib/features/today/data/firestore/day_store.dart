import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_scope.dart';
import '../../../../core/utils/json.dart';
import '../../../routines/domain/routine.dart';
import '../../domain/day.dart';
import '../../domain/engine/day_record.dart';

/// Reads and writes `users/{uid}/days/{YYYY-MM-DD}` — one document per day holding its routine runs, step
/// outcomes and adjustments. One document per day keeps every day action a single atomic write.
class DayStore {
  DayStore(this.scope);

  final FirestoreScope scope;

  DocumentReference<Json> doc(String date) => scope.days.doc(date);

  /// The stored day, or an empty, not-yet-persisted record. `offline` is true when served from the cache.
  Future<({DayRecord day, bool offline})> load(String date) async {
    final snap = await doc(date).get();
    final data = snap.data();
    return (day: data == null ? DayRecord(date: date) : dayFromMap(date, data), offline: snap.metadata.isFromCache);
  }

  void write(WriteBatch batch, DayRecord day) => batch.set(doc(day.date), dayToMap(day));

  /// Stored days with `from <= date <= to` (ISO dates sort lexically).
  Future<List<DayRecord>> range(String from, String to) async {
    final q = await scope.days.where('date', isGreaterThanOrEqualTo: from).where('date', isLessThanOrEqualTo: to).get();
    return [for (final d in q.docs) dayFromMap(d.id, d.data())];
  }

  /// The most recent stored days before [date] (for "days away").
  Future<List<DayRecord>> recentBefore(String date, {int limit = 30}) async {
    final q = await scope.days.where('date', isLessThan: date).orderBy('date', descending: true).limit(limit).get();
    return [for (final d in q.docs) dayFromMap(d.id, d.data())];
  }
}

// ---------------------------------------------------------------------------------------------- mapping

String statusToApi(StepStatus s) => switch (s) {
  StepStatus.inProgress => 'in_progress',
  StepStatus.partiallyCompleted => 'partially_completed',
  _ => s.name,
};

Json dayToMap(DayRecord d) => {
  'date': d.date,
  'mode': d.mode.name,
  'recoveryDismissed': d.recoveryDismissed,
  'hasProgress': d.hasProgress,
  'updatedAt': FieldValue.serverTimestamp(),
  'instances': [for (final i in d.instances) _instanceToMap(i)],
  'adjustments': [for (final a in d.adjustments) _adjustmentToMap(a)],
};

DayRecord dayFromMap(String id, Json m) => DayRecord(
  date: (m['date'] as String?) ?? id,
  mode: DayMode.parse((m['mode'] as String?) ?? 'normal'),
  recoveryDismissed: (m['recoveryDismissed'] as bool?) ?? false,
  instances: [for (final i in readMaps(m['instances'])) _instanceFromMap(i)],
  adjustments: [for (final a in readMaps(m['adjustments'])) _adjustmentFromMap(a)],
  persisted: true,
);

Json _instanceToMap(InstanceRecord i) => {
  'id': i.id,
  'routineId': i.routineId,
  'routineName': i.routineName,
  'category': i.category.name,
  'scheduledStart': writeTime(i.scheduledStart),
  'finishBy': writeTime(i.finishBy),
  'isAdHoc': i.isAdHoc,
  'createdAt': writeTime(i.createdAt),
  'steps': [for (final s in i.steps) _stepToMap(s)],
};

InstanceRecord _instanceFromMap(Json m) => InstanceRecord(
  id: m['id'] as String,
  routineId: m['routineId'] as String?,
  routineName: (m['routineName'] as String?) ?? '',
  category: RoutineCategory.parse((m['category'] as String?) ?? 'other'),
  scheduledStart: readTime(m['scheduledStart']),
  finishBy: readTime(m['finishBy']),
  isAdHoc: (m['isAdHoc'] as bool?) ?? false,
  createdAt: readTime(m['createdAt']) ?? DateTime.utc(2000),
  steps: [for (final s in readMaps(m['steps'])) _stepFromMap(s)],
);

Json _stepToMap(StepRecord s) => {
  'id': s.id,
  'activityId': s.activityId,
  'position': s.position,
  'title': s.title,
  'description': s.description,
  'icon': s.icon,
  'targetKind': s.targetKind.name,
  'unit': s.unit,
  'isEssential': s.isEssential,
  'priority': s.priority.name,
  'targetValue': s.targetValue,
  'minimumValue': s.minimumValue,
  'plannedValue': s.plannedValue,
  'actualValue': s.actualValue,
  'completionRatio': s.completionRatio,
  'status': statusToApi(s.status),
  'skipReason': s.skipReason,
  'scheduledAt': writeTime(s.scheduledAt),
  'startedAt': writeTime(s.startedAt),
  'runningSince': writeTime(s.runningSince),
  'completedAt': writeTime(s.completedAt),
  'activeSeconds': s.activeSeconds,
  'reflections': s.reflections,
};

StepRecord _stepFromMap(Json m) => StepRecord(
  id: m['id'] as String,
  activityId: m['activityId'] as String?,
  position: (m['position'] as num?)?.toInt() ?? 0,
  title: (m['title'] as String?) ?? '',
  description: (m['description'] as String?) ?? '',
  icon: (m['icon'] as String?) ?? 'check_circle',
  targetKind: TargetKind.parse((m['targetKind'] as String?) ?? 'check'),
  unit: (m['unit'] as String?) ?? '',
  isEssential: (m['isEssential'] as bool?) ?? false,
  priority: StepPriority.parse((m['priority'] as String?) ?? 'standard'),
  targetValue: toDouble(m['targetValue'] ?? 1),
  minimumValue: toDoubleOrNull(m['minimumValue']),
  plannedValue: toDouble(m['plannedValue'] ?? m['targetValue'] ?? 1),
  actualValue: toDoubleOrNull(m['actualValue']),
  completionRatio: toDouble(m['completionRatio'] ?? 0),
  status: StepStatus.parse((m['status'] as String?) ?? 'pending'),
  skipReason: (m['skipReason'] as String?) ?? '',
  scheduledAt: readTime(m['scheduledAt']),
  startedAt: readTime(m['startedAt']),
  runningSince: readTime(m['runningSince']),
  completedAt: readTime(m['completedAt']),
  activeSeconds: (m['activeSeconds'] as num?)?.toInt() ?? 0,
  reflections: [...((m['reflections'] as List<dynamic>?) ?? const []).cast<String>()],
);

Json _stateToMap(StepState s) => {
  'plannedValue': s.plannedValue,
  'status': statusToApi(s.status),
  'scheduledAt': writeTime(s.scheduledAt),
};

StepState _stateFromMap(Json m) => StepState(
  plannedValue: toDouble(m['plannedValue']),
  status: StepStatus.parse(m['status'] as String),
  scheduledAt: readTime(m['scheduledAt']),
);

Json _adjustmentToMap(AdjustmentRecord a) => {
  'id': a.id,
  'kind': a.kind.api,
  'instanceId': a.instanceId,
  'budgetMinutes': a.budgetMinutes,
  'mode': a.mode?.name,
  'revertedAt': writeTime(a.revertedAt),
  'createdAt': writeTime(a.createdAt),
  'changes': [
    for (final c in a.changes) {'stepId': c.stepId, 'before': _stateToMap(c.before), 'after': _stateToMap(c.after)},
  ],
};

AdjustmentRecord _adjustmentFromMap(Json m) => AdjustmentRecord(
  id: m['id'] as String,
  kind: AdjustmentKind.parse(m['kind'] as String),
  instanceId: m['instanceId'] as String?,
  budgetMinutes: (m['budgetMinutes'] as num?)?.toInt(),
  mode: m['mode'] == null ? null : DayMode.parse(m['mode'] as String),
  revertedAt: readTime(m['revertedAt']),
  createdAt: readTime(m['createdAt']) ?? DateTime.utc(2000),
  changes: [
    for (final c in readMaps(m['changes']))
      StepChange(
        stepId: c['stepId'] as String,
        before: _stateFromMap(readMap(c['before'])),
        after: _stateFromMap(readMap(c['after'])),
      ),
  ],
);
