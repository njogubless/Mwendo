import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/firebase/firebase_failure_mapper.dart';
import '../../../core/firebase/firestore_scope.dart';
import '../../../core/utils/ids.dart';
import '../../../core/utils/json.dart';
import '../../../core/utils/user_clock.dart';
import '../../routines/data/firestore_routines_repository.dart';
import '../../routines/domain/routine.dart';
import '../../today/data/firestore/day_store.dart';
import '../../today/domain/engine/history.dart';
import '../domain/goal.dart';
import '../domain/goals_repository.dart';

/// Goals on Firestore: `users/{uid}/goals/{id}` (measurements embedded) and `users/{uid}/habits/{id}`.
/// Progress is derived, never stored (port of `goals/selectors.py`).
class FirestoreGoalsRepository implements GoalsRepository {
  FirestoreGoalsRepository(this.scope) : _days = DayStore(scope);

  final FirestoreScope scope;
  final DayStore _days;

  @override
  Future<List<Goal>> list() => guardFirebase(() async {
    final docs = (await scope.goals.get()).docs.where((d) => d.data()['status'] != GoalStatus.archived.name).toList()
      ..sort((a, b) {
        final byStatus = (a.data()['status'] as String).compareTo(b.data()['status'] as String);
        if (byStatus != 0) return byStatus;
        return (readTime(b.data()['createdAt']) ?? DateTime(0)).compareTo(
          readTime(a.data()['createdAt']) ?? DateTime(0),
        );
      });
    return _build([for (final d in docs) (d.id, d.data())]);
  });

  @override
  Future<Goal> get(String id) => guardFirebase(() async => (await _build([(id, await _load(id))])).single);

  @override
  Future<Goal> create(GoalDraft draft) => guardFirebase(() async {
    _validate(draft);
    final ref = scope.goals.doc();
    await _commit(
      (b) => b.set(ref, {
        ..._draftToMap(draft),
        'status': GoalStatus.active.name,
        'achievedAt': null,
        'measurements': <Json>[],
        'createdAt': writeTime(scope.now()),
      }),
    );
    return get(ref.id);
  });

  @override
  Future<Goal> update(String id, GoalDraft draft) => guardFirebase(() async {
    _validate(draft);
    await _load(id);
    await _commit((b) => b.update(scope.goals.doc(id), _draftToMap(draft)));
    return get(id);
  });

  @override
  Future<Goal> setStatus(String id, GoalStatus status) => guardFirebase(() async {
    final data = await _load(id);
    final achievedAt = status == GoalStatus.achieved ? (data['achievedAt'] ?? writeTime(scope.now())) : null;
    await _commit((b) => b.update(scope.goals.doc(id), {'status': status.name, 'achievedAt': achievedAt}));
    return get(id);
  });

  @override
  Future<void> archive(String id) => guardFirebase(() async {
    await _load(id);
    await _commit((b) => b.update(scope.goals.doc(id), {'status': GoalStatus.archived.name}));
  });

  @override
  Future<Goal> logProgress(String id, {required double value, required DateTime on, String note = ''}) =>
      guardFirebase(() async {
        if (value == 0) {
          throw const ValidationFailure(
            userMessage: 'Log an amount other than zero.',
            fieldErrors: {
              'value': ['Log an amount other than zero.'],
            },
          );
        }
        final data = await _load(id);
        final entry = {
          'id': newId(),
          'value': value,
          'recordedOn': isoDate(on),
          'note': note.trim(),
          'createdAt': writeTime(scope.now()),
        };
        await _commit(
          (b) => b.update(scope.goals.doc(id), {
            'measurements': [...readMaps(data['measurements']), entry],
          }),
        );
        return get(id);
      });

  @override
  Future<void> deleteMeasurement(String goalId, String measurementId) => guardFirebase(() async {
    final data = await _load(goalId);
    final kept = readMaps(data['measurements']).where((m) => m['id'] != measurementId).toList();
    await _commit((b) => b.update(scope.goals.doc(goalId), {'measurements': kept}));
  });

  @override
  Future<List<HabitOption>> habits() => guardFirebase(() async {
    final docs = await _activeHabits();
    return [
      for (final d in docs)
        HabitOption(id: d.id, title: d.data()['title'] as String, goalId: d.data()['goalId'] as String?),
    ];
  });

  @override
  Future<void> createHabit({required String title, String? goalId, bool perWeek = false, int times = 1}) =>
      guardFirebase(() async {
        if (title.trim().isEmpty) {
          throw const ValidationFailure(
            userMessage: 'Give the habit a name.',
            fieldErrors: {
              'title': ['Give the habit a name.'],
            },
          );
        }
        if (times < 1 || (perWeek && times > 7) || (!perWeek && times > 10)) {
          throw const ValidationFailure(
            userMessage: 'Choose a realistic number of times.',
            fieldErrors: {
              'frequency_times': ['Choose a realistic number of times.'],
            },
          );
        }
        await _commit(
          (b) => b.set(scope.habits.doc(), {
            'goalId': goalId,
            'title': title.trim(),
            'frequencyPer': perWeek ? 'week' : 'day',
            'frequencyTimes': times,
            'archivedAt': null,
            'createdAt': writeTime(scope.now()),
          }),
        );
      });

  /// Archives the habit and unlinks it from routine steps (their history stays).
  @override
  Future<void> deleteHabit(String id) => guardFirebase(() async {
    final routines = (await scope.routines.get()).docs;
    await _commit((b) {
      b.update(scope.habits.doc(id), {'archivedAt': writeTime(scope.now())});
      for (final r in routines) {
        final steps = readMaps(r.data()['steps']);
        if (steps.any((s) => s['habitId'] == id)) {
          b.update(r.reference, {
            'steps': [
              for (final s in steps) s['habitId'] == id ? {...s, 'habitId': null} : s,
            ],
          });
        }
      }
    });
  });

  // ------------------------------------------------------------------------------------------ internals

  Future<Json> _load(String id) async {
    final data = (await scope.goals.doc(id).get()).data();
    if (data == null) throw const NotFoundFailure();
    return data;
  }

  Future<void> _commit(void Function(WriteBatch batch) fill) async {
    final ctx = await scope.context();
    final batch = scope.db.batch();
    fill(batch);
    await scope.commit(batch, offline: ctx.offline);
  }

  Future<List<QueryDocumentSnapshot<Json>>> _activeHabits() async {
    final docs = (await scope.habits.get()).docs.where((d) => d.data()['archivedAt'] == null).toList()
      ..sort(
        (a, b) =>
            (readTime(a.data()['createdAt']) ?? DateTime(0)).compareTo(readTime(b.data()['createdAt']) ?? DateTime(0)),
      );
    return docs;
  }

  Future<List<Goal>> _build(List<(String, Json)> goals) async {
    final ctx = await scope.context();
    final today = ctx.clock.today();
    final habits = await _activeHabits();
    final routines = [for (final d in (await scope.routines.get()).docs) routineFromDoc(d.id, d.data())];
    final habitOfActivity = <String, String>{
      for (final r in routines)
        for (final s in r.steps)
          if (s.habitId != null && s.id != null) s.id!: s.habitId!,
    };
    final days = await _days.range(addDays(today, -(habitWindowDays - 1)), today);
    final stats = habitStats(days, today, habitOfActivity);

    return [
      for (final (id, g) in goals)
        _goal(id, g, [
          for (final h in habits)
            if (h.data()['goalId'] == id) _habit(h.id, h.data(), stats[h.id], routines),
        ]),
    ];
  }

  HabitSummary _habit(String id, Json h, HabitDays? days, List<Routine> routines) {
    final perWeek = h['frequencyPer'] == 'week';
    final times = (h['frequencyTimes'] as num?)?.toInt() ?? 1;
    return HabitSummary(
      id: id,
      title: h['title'] as String,
      perWeek: perWeek,
      frequencyTimes: times,
      daysDone: days?.done ?? 0,
      daysPlanned: days?.planned ?? 0,
      weeklyTarget: perWeek ? times : habitWindowDays,
      linkedSteps: [
        for (final r in routines)
          for (final s in r.steps)
            if (s.habitId == id) LinkedStep(id: s.id!, title: s.title, routineId: r.id),
      ],
    );
  }

  Goal _goal(String id, Json g, List<HabitSummary> habits) {
    final measurements =
        [
          for (final m in readMaps(g['measurements']))
            (
              Measurement(
                id: m['id'] as String,
                value: toDouble(m['value']),
                recordedOn: toDate(m['recordedOn']),
                note: (m['note'] as String?) ?? '',
              ),
              readTime(m['createdAt']) ?? DateTime(0),
            ),
        ]..sort((a, b) {
          final byDay = b.$1.recordedOn.compareTo(a.$1.recordedOn);
          return byDay != 0 ? byDay : b.$2.compareTo(a.$2);
        });
    final current = measurements.fold(0.0, (total, m) => total + m.$1.value);
    final target = toDoubleOrNull(g['targetValue']);
    return Goal(
      id: id,
      draft: GoalDraft(
        title: g['title'] as String,
        description: (g['description'] as String?) ?? '',
        targetValue: target,
        unit: (g['unit'] as String?) ?? '',
        targetDate: g['targetDate'] == null ? null : toDate(g['targetDate']),
      ),
      status: GoalStatus.values.byName((g['status'] as String?) ?? 'active'),
      currentValue: current,
      ratio: target == null || target == 0 ? null : (current / target).clamp(double.negativeInfinity, 1).toDouble(),
      habits: habits,
      measurements: [for (final m in measurements) m.$1],
    );
  }
}

Json _draftToMap(GoalDraft d) => {
  'title': d.title.trim(),
  'description': d.description.trim(),
  'targetValue': d.targetValue,
  'unit': d.unit.trim(),
  'targetDate': d.targetDate == null ? null : isoDate(d.targetDate!),
};

void _validate(GoalDraft d) {
  if (d.title.trim().isEmpty) {
    throw const ValidationFailure(
      userMessage: 'Give the goal a name.',
      fieldErrors: {
        'title': ['Give the goal a name.'],
      },
    );
  }
  if (d.targetValue != null && d.targetValue! <= 0) {
    throw const ValidationFailure(
      userMessage: 'Set a target above zero, or leave it empty.',
      fieldErrors: {
        'target_value': ['Set a target above zero, or leave it empty.'],
      },
    );
  }
}
