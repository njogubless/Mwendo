import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/failure_mapper.dart';
import '../../../core/utils/json.dart';
import '../../routines/domain/routine.dart';
import '../domain/day.dart';
import '../domain/day_repository.dart';

AdjustmentRef? _adjustment(Object? j) {
  if (j == null) return null;
  final m = j as Json;
  final params = (m['params'] as Json?) ?? const {};
  return AdjustmentRef(
    id: m['id'] as String,
    kind: m['kind'] as String,
    budgetMinutes: params['budget_minutes'] as int?,
  );
}

DayStep dayStepFromJson(Json j) => DayStep(
  id: j['id'] as String,
  routineInstanceId: j['routine_instance_id'] as String,
  title: j['title'] as String,
  description: (j['description'] as String?) ?? '',
  icon: j['icon'] as String,
  targetKind: TargetKind.parse(j['target_kind'] as String),
  unit: (j['unit'] as String?) ?? '',
  isEssential: j['is_essential'] as bool,
  priority: StepPriority.parse(j['priority'] as String),
  targetValue: toDouble(j['target_value']),
  minimumValue: toDoubleOrNull(j['minimum_value']),
  plannedValue: toDouble(j['planned_value']),
  actualValue: toDoubleOrNull(j['actual_value']),
  status: StepStatus.parse(j['status'] as String),
  completionRatio: toDouble(j['completion_ratio']),
  skipReason: (j['skip_reason'] as String?) ?? '',
  scheduledAt: toDateTimeOrNull(j['scheduled_at']),
  completedAt: toDateTimeOrNull(j['completed_at']),
  elapsedSeconds: j['elapsed_seconds'] as int,
  isRunning: j['is_running'] as bool,
  reflection: (j['reflection'] as String?) ?? '',
);

Day dayFromJson(Json j, {DateTime? fetchedAt}) {
  final p = j['progress'] as Json;
  final timing = j['timing'] as Json;
  final recovery = j['recovery'] as Json;
  return Day(
    date: toDate(j['date']),
    isToday: j['is_today'] as bool,
    mode: DayMode.parse(j['mode'] as String),
    progress: DayProgress(
      ratio: toDouble(p['ratio']),
      total: p['total'] as int,
      completed: p['completed'] as int,
      partial: p['partial'] as int,
      skipped: p['skipped'] as int,
      inProgress: p['in_progress'] as int,
      remaining: p['remaining'] as int,
      cancelled: p['cancelled'] as int,
    ),
    focusId: j['focus_id'] as String?,
    timing: TimingStatus.parse(timing['status'] as String),
    shiftedMinutes: timing['shifted_minutes'] as int,
    timingInstanceId: timing['routine_instance_id'] as String?,
    recoverySuggested: recovery['suggested'] as bool,
    daysAway: recovery['days_away'] as int?,
    adjustments: jsonList(j['adjustments']).map((a) => _adjustment(a)!).toList(),
    fetchedAt: fetchedAt ?? DateTime.now(),
    routines: jsonList(j['routines'])
        .map(
          (r) => DayRoutine(
            id: r['id'] as String,
            routineId: r['routine_id'] as String?,
            name: r['name'] as String,
            category: RoutineCategory.parse(r['category'] as String),
            scheduledStart: toDateTimeOrNull(r['scheduled_start']),
            finishBy: toDateTimeOrNull(r['finish_by']),
            isAdHoc: r['is_ad_hoc'] as bool,
            adjustment: _adjustment(r['adjustment']),
            steps: jsonList(r['completions']).map(dayStepFromJson).toList(),
          ),
        )
        .toList(),
  );
}

AdaptationPreview previewFromJson(Json j) {
  final context = j['context'] as Json;
  return AdaptationPreview(
    instanceId: j['routine_instance_id'] as String,
    routineName: j['routine_name'] as String,
    isMinimum: j['mode'] == 'minimum',
    budgetMinutes: j['budget_minutes'] as int?,
    options: (j['options'] as List<dynamic>).cast<int>(),
    recommended: j['recommended'] as int?,
    shiftedMinutes: context['shifted_minutes'] as int,
    availableMinutes: context['available_minutes'] as int?,
    finishBy: toDateTimeOrNull(context['finish_by']),
    dayMode: DayMode.parse(context['day_mode'] as String),
    activeAdjustment: _adjustment(j['active_adjustment']),
    originalMinutes: j['original_minutes'] as int,
    plannedMinutes: j['planned_minutes'] as int,
    fits: j['fits'] as bool,
    essentialsKept: j['essentials_kept'] as int,
    essentialsTotal: j['essentials_total'] as int,
    items: jsonList(j['items'])
        .map(
          (i) => AdaptationItem(
            completionId: i['completion_id'] as String,
            title: i['title'] as String,
            icon: i['icon'] as String,
            targetKind: TargetKind.parse(i['target_kind'] as String),
            unit: (i['unit'] as String?) ?? '',
            isEssential: i['is_essential'] as bool,
            priority: StepPriority.parse(i['priority'] as String),
            targetValue: toDouble(i['target_value']),
            plannedValue: toDouble(i['planned_value']),
            kept: i['status'] == 'pending',
          ),
        )
        .toList(),
  );
}

class DayRepositoryImpl implements DayRepository {
  DayRepositoryImpl(this._dio);

  final Dio _dio;
  final _random = Random.secure();

  /// A fresh key per user action: retries of the same request are applied once by the server.
  Options _idempotent() => Options(
    headers: {
      'Idempotency-Key': List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join(),
    },
  );

  Future<Day> _day(Future<Response<Json>> Function() call) async {
    try {
      return dayFromJson((await call()).data!);
    } catch (e) {
      throw mapToFailure(e);
    }
  }

  Future<Day> _action(String stepId, String action, [Json? body]) =>
      _day(() => _dio.post<Json>('/completions/$stepId/$action/', data: body ?? const {}, options: _idempotent()));

  @override
  Future<Day> today() => _day(() => _dio.get<Json>('/days/today/'));

  @override
  Future<Day> start(String stepId) => _action(stepId, 'start');

  @override
  Future<Day> pause(String stepId) => _action(stepId, 'pause');

  @override
  Future<Day> complete(String stepId, {double? actualValue}) =>
      _action(stepId, 'complete', {'actual_value': ?actualValue});

  @override
  Future<Day> skip(String stepId, {SkipReason? reason}) => _action(stepId, 'skip', {'reason': reason?.api ?? ''});

  @override
  Future<Day> undo(String stepId) => _action(stepId, 'reset');

  @override
  Future<Day> setMode(DayMode mode) => _day(() => _dio.patch<Json>('/days/today/', data: {'mode': mode.name}));

  @override
  Future<Day> dismissRecovery() => _day(() => _dio.patch<Json>('/days/today/', data: {'recovery_dismissed': true}));

  @override
  Future<void> reflect(String stepId, String note) async {
    try {
      await _dio.post<Json>('/reflections/', data: {'completion_id': stepId, 'note': note});
    } catch (e) {
      throw mapToFailure(e);
    }
  }

  @override
  Future<AdaptationPreview> preview(String instanceId, {int? budgetMinutes, bool minimum = false}) async {
    try {
      final r = await _dio.get<Json>(
        '/routine-instances/$instanceId/adaptation/preview/',
        queryParameters: {'budget_minutes': ?budgetMinutes, if (minimum) 'mode': 'minimum'},
      );
      return previewFromJson(r.data!);
    } catch (e) {
      throw mapToFailure(e);
    }
  }

  @override
  Future<Day> applyBudget(String instanceId, int minutes) => _day(
    () => _dio.post<Json>(
      '/routine-instances/$instanceId/adaptation/apply/',
      data: {'budget_minutes': minutes},
      options: _idempotent(),
    ),
  );

  @override
  Future<Day> revert(String adjustmentId) => _day(() => _dio.post<Json>('/adjustments/$adjustmentId/revert/'));
}

final dayRepositoryProvider = Provider<DayRepository>((ref) => DayRepositoryImpl(ref.watch(apiClientProvider)));
