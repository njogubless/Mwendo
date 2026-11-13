import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend.dart';
import '../../../core/firebase/firebase_failure_mapper.dart';
import '../../../core/firebase/firestore_scope.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/failure_mapper.dart';
import '../../../core/utils/json.dart';
import '../../../core/utils/user_clock.dart';
import '../../today/data/firestore/day_store.dart';
import '../../today/domain/engine/history.dart';
import '../domain/insights.dart';
import '../domain/insights_repository.dart';

export '../domain/insights_repository.dart';

InsightsSummary insightsFromJson(Json j) => InsightsSummary(
  days: j['days'] as int,
  daysShowedUp: j['days_showed_up'] as int,
  daysPlanned: j['days_planned'] as int,
  consistency: toDoubleOrNull(j['consistency']),
  completionRate: toDoubleOrNull(j['completion_rate']),
  partialWins: j['partial_wins'] as int,
  series: jsonList(j['series'])
      .map(
        (p) => DayPoint(
          date: toDate(p['date']),
          planned: p['planned'] as int,
          done: p['done'] as int,
          ratio: toDoubleOrNull(p['ratio']),
        ),
      )
      .toList(),
  routines: jsonList(
    j['routines'],
  ).map((r) => RateRow(label: r['name'] as String, steps: r['steps'] as int, rate: toDouble(r['rate']))).toList(),
  partsOfDay: jsonList(
    j['parts_of_day'],
  ).map((r) => RateRow(label: r['part'] as String, steps: r['steps'] as int, rate: toDouble(r['rate']))).toList(),
  skipReasons: {for (final s in jsonList(j['skip_reasons'])) s['reason'] as String: s['count'] as int},
  observations: jsonList(
    j['observations'],
  ).map((o) => Observation(kind: o['kind'] as String, text: o['text'] as String)).toList(),
);

/// Insights over the Django REST API.
class HttpInsightsRepository implements InsightsRepository {
  HttpInsightsRepository(this._dio);

  final Dio _dio;

  @override
  Future<InsightsSummary> summary(int days) async {
    try {
      final r = await _dio.get<Json>('/insights/summary/', queryParameters: {'days': days});
      return insightsFromJson(r.data!);
    } catch (e) {
      throw mapToFailure(e);
    }
  }
}

/// Insights computed on the device from stored days (port of `insights/selectors.py`).
class FirestoreInsightsRepository implements InsightsRepository {
  FirestoreInsightsRepository(this.scope) : _days = DayStore(scope);

  final FirestoreScope scope;
  final DayStore _days;

  @override
  Future<InsightsSummary> summary(int days) => guardFirebase(() async {
    final ctx = await scope.context();
    final today = ctx.clock.today();
    return buildInsights(await _days.range(addDays(today, -(days - 1)), today), ctx.clock, days: days);
  });
}

final insightsRepositoryProvider = Provider<InsightsRepository>(
  (ref) => switch (ref.watch(backendProvider)) {
    Backend.django => HttpInsightsRepository(ref.watch(apiClientProvider)),
    Backend.firebase => FirestoreInsightsRepository(ref.watch(firestoreScopeProvider)),
  },
);

final insightsProvider = FutureProvider.autoDispose.family<InsightsSummary, int>(
  (ref, days) => ref.watch(insightsRepositoryProvider).summary(days),
);
