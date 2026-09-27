import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/failure_mapper.dart';
import '../../../core/utils/json.dart';
import '../domain/routine.dart';
import '../domain/routines_repository.dart';

RoutineStep stepFromJson(Json j) => RoutineStep(
  id: j['id'] as String?,
  position: (j['position'] as int?) ?? 0,
  title: j['title'] as String,
  description: (j['description'] as String?) ?? '',
  icon: (j['icon'] as String?) ?? 'check_circle',
  targetKind: TargetKind.parse(j['target_kind'] as String),
  targetValue: toDouble(j['target_value']),
  minimumValue: toDoubleOrNull(j['minimum_value']),
  unit: (j['unit'] as String?) ?? '',
  isEssential: j['is_essential'] as bool? ?? false,
  priority: StepPriority.parse(j['priority'] as String? ?? 'standard'),
  habitId: j['habit_id'] as String?,
);

Json stepToJson(RoutineStep s) => {
  'title': s.title,
  'description': s.description,
  'icon': s.icon,
  'target_kind': s.targetKind.name,
  'target_value': s.targetKind == TargetKind.check ? 1 : s.targetValue,
  'minimum_value': s.targetKind == TargetKind.check ? null : s.minimumValue,
  'unit': s.unit,
  'is_essential': s.isEssential,
  'priority': s.priority.name,
  'habit_id': s.habitId,
};

RoutineDetails detailsFromJson(Json j) => RoutineDetails(
  name: j['name'] as String,
  category: RoutineCategory.parse(j['category'] as String),
  description: (j['description'] as String?) ?? '',
  daysOfWeek: (j['days_of_week'] as List<dynamic>).cast<int>(),
  startMinutes: parseClock(j['start_time']),
  finishByMinutes: parseClock(j['finish_by']),
);

Json detailsToJson(RoutineDetails d) => {
  'name': d.name,
  'category': d.category.name,
  'description': d.description,
  'days_of_week': d.daysOfWeek,
  'start_time': d.startMinutes == null ? null : formatClockForApi(d.startMinutes!),
  'finish_by': d.finishByMinutes == null ? null : formatClockForApi(d.finishByMinutes!),
};

Routine routineFromJson(Json j) {
  final stats = j['stats'] as Json?;
  return Routine(
    id: j['id'] as String,
    details: detailsFromJson(j),
    status: RoutineStatus.values.byName(j['status'] as String),
    steps: jsonList(j['activities']).map(stepFromJson).toList(),
    stats: stats == null
        ? RoutineStats.empty
        : RoutineStats(
            steps: stats['steps'] as int,
            totalMinutes: stats['total_minutes'] as int,
            essentialSteps: stats['essential_steps'] as int,
            minimumMinutes: stats['minimum_minutes'] as int,
            consistency: toDoubleOrNull(stats['consistency']),
          ),
  );
}

class RoutinesRepositoryImpl implements RoutinesRepository {
  RoutinesRepositoryImpl(this._dio);

  final Dio _dio;

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw mapToFailure(e);
    }
  }

  @override
  Future<List<Routine>> list() => _run(() async {
    final r = await _dio.get<List<dynamic>>('/routines/');
    return r.data!.cast<Json>().map(routineFromJson).toList();
  });

  @override
  Future<Routine> get(String id) => _run(() async {
    final r = await _dio.get<Json>('/routines/$id/');
    return routineFromJson(r.data!);
  });

  @override
  Future<Routine> create(RoutineDetails details, {List<RoutineStep> steps = const []}) => _run(() async {
    final r = await _dio.post<Json>(
      '/routines/',
      data: {...detailsToJson(details), 'activities': steps.map(stepToJson).toList()},
    );
    return routineFromJson(r.data!);
  });

  @override
  Future<Routine> updateDetails(String id, RoutineDetails details) => _run(() async {
    final r = await _dio.patch<Json>('/routines/$id/', data: detailsToJson(details));
    return routineFromJson(r.data!);
  });

  @override
  Future<Routine> setStatus(String id, RoutineStatus status) => _run(() async {
    final r = await _dio.patch<Json>('/routines/$id/', data: {'status': status.name});
    return routineFromJson(r.data!);
  });

  @override
  Future<void> archive(String id) => _run(() => _dio.delete<void>('/routines/$id/'));

  @override
  Future<void> addStep(String routineId, RoutineStep step) =>
      _run(() => _dio.post<Json>('/routines/$routineId/activities/', data: stepToJson(step)));

  @override
  Future<void> updateStep(String routineId, RoutineStep step) =>
      _run(() => _dio.patch<Json>('/routines/$routineId/activities/${step.id}/', data: stepToJson(step)));

  @override
  Future<void> removeStep(String routineId, String stepId) =>
      _run(() => _dio.delete<void>('/routines/$routineId/activities/$stepId/'));

  @override
  Future<Routine> reorder(String routineId, List<String> stepIds) => _run(() async {
    final r = await _dio.post<Json>('/routines/$routineId/reorder/', data: {'ids': stepIds});
    return routineFromJson(r.data!);
  });

  @override
  Future<void> startNow(String routineId) => _run(() => _dio.post<Json>('/routines/$routineId/start/'));

  @override
  Future<List<RoutineDraft>> generate({
    required List<String> focusAreas,
    required String structure,
    int? wakeMinutes,
  }) => _run(() async {
    final r = await _dio.post<List<dynamic>>(
      '/routines/generate/',
      data: {
        'focus_areas': focusAreas,
        'structure': structure,
        'wake_time': wakeMinutes == null ? null : formatClockForApi(wakeMinutes),
      },
    );
    return r.data!
        .cast<Json>()
        .map(
          (j) => RoutineDraft(details: detailsFromJson(j), steps: jsonList(j['activities']).map(stepFromJson).toList()),
        )
        .toList();
  });
}

final routinesRepositoryProvider = Provider<RoutinesRepository>(
  (ref) => RoutinesRepositoryImpl(ref.watch(apiClientProvider)),
);
