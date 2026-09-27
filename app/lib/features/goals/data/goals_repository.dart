import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/failure_mapper.dart';
import '../../../core/utils/json.dart';
import '../domain/goal.dart';

Goal goalFromJson(Json j) {
  final progress = j['progress'] as Json;
  return Goal(
    id: j['id'] as String,
    draft: GoalDraft(
      title: j['title'] as String,
      description: (j['description'] as String?) ?? '',
      targetValue: toDoubleOrNull(j['target_value']),
      unit: (j['unit'] as String?) ?? '',
      targetDate: j['target_date'] == null ? null : toDate(j['target_date']),
    ),
    status: GoalStatus.values.byName(j['status'] as String),
    currentValue: toDouble(progress['current_value']),
    ratio: toDoubleOrNull(progress['ratio']),
    habits: jsonList(j['habits'])
        .map(
          (h) => HabitSummary(
            id: h['id'] as String,
            title: h['title'] as String,
            perWeek: h['frequency_per'] == 'week',
            frequencyTimes: h['frequency_times'] as int,
            daysDone: h['days_done'] as int,
            daysPlanned: h['days_planned'] as int,
            weeklyTarget: h['weekly_target'] as int,
            linkedSteps: jsonList(h['linked_steps'])
                .map(
                  (s) => LinkedStep(
                    id: s['id'] as String,
                    title: s['title'] as String,
                    routineId: s['routine_id'] as String,
                  ),
                )
                .toList(),
          ),
        )
        .toList(),
    measurements: jsonList(j['measurements'])
        .map(
          (m) => Measurement(
            id: m['id'] as String,
            value: toDouble(m['value']),
            recordedOn: toDate(m['recorded_on']),
            note: (m['note'] as String?) ?? '',
          ),
        )
        .toList(),
  );
}

Json goalDraftToJson(GoalDraft d) => {
  'title': d.title,
  'description': d.description,
  'target_value': d.targetValue,
  'unit': d.unit,
  'target_date': d.targetDate == null ? null : isoDate(d.targetDate!),
};

class GoalsRepository {
  GoalsRepository(this._dio);

  final Dio _dio;

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw mapToFailure(e);
    }
  }

  Future<List<Goal>> list() => _run(() async {
    final r = await _dio.get<List<dynamic>>('/goals/');
    return r.data!.cast<Json>().map(goalFromJson).toList();
  });

  Future<Goal> get(String id) => _run(() async => goalFromJson((await _dio.get<Json>('/goals/$id/')).data!));

  Future<Goal> create(GoalDraft draft) =>
      _run(() async => goalFromJson((await _dio.post<Json>('/goals/', data: goalDraftToJson(draft))).data!));

  Future<Goal> update(String id, GoalDraft draft) =>
      _run(() async => goalFromJson((await _dio.patch<Json>('/goals/$id/', data: goalDraftToJson(draft))).data!));

  Future<Goal> setStatus(String id, GoalStatus status) =>
      _run(() async => goalFromJson((await _dio.patch<Json>('/goals/$id/', data: {'status': status.name})).data!));

  Future<void> archive(String id) => _run(() => _dio.delete<void>('/goals/$id/'));

  Future<Goal> logProgress(String id, {required double value, required DateTime on, String note = ''}) => _run(
    () async => goalFromJson(
      (await _dio.post<Json>(
        '/goals/$id/measurements/',
        data: {'value': value, 'recorded_on': isoDate(on), 'note': note},
      )).data!,
    ),
  );

  Future<void> deleteMeasurement(String goalId, String measurementId) =>
      _run(() => _dio.delete<void>('/goals/$goalId/measurements/$measurementId/'));

  Future<List<HabitOption>> habits() => _run(() async {
    final r = await _dio.get<List<dynamic>>('/habits/');
    return r.data!
        .cast<Json>()
        .map((h) => HabitOption(id: h['id'] as String, title: h['title'] as String, goalId: h['goal_id'] as String?))
        .toList();
  });

  Future<void> createHabit({required String title, String? goalId, bool perWeek = false, int times = 1}) => _run(
    () => _dio.post<Json>(
      '/habits/',
      data: {'title': title, 'goal_id': goalId, 'frequency_per': perWeek ? 'week' : 'day', 'frequency_times': times},
    ),
  );

  Future<void> deleteHabit(String id) => _run(() => _dio.delete<void>('/habits/$id/'));
}

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) => GoalsRepository(ref.watch(apiClientProvider)));
