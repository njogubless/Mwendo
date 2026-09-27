import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/failure_mapper.dart';
import '../../../core/utils/json.dart';
import '../domain/insights.dart';

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

class InsightsRepository {
  InsightsRepository(this._dio);

  final Dio _dio;

  Future<InsightsSummary> summary(int days) async {
    try {
      final r = await _dio.get<Json>('/insights/summary/', queryParameters: {'days': days});
      return insightsFromJson(r.data!);
    } catch (e) {
      throw mapToFailure(e);
    }
  }
}

final insightsRepositoryProvider = Provider((ref) => InsightsRepository(ref.watch(apiClientProvider)));

final insightsProvider = FutureProvider.autoDispose.family<InsightsSummary, int>(
  (ref, days) => ref.watch(insightsRepositoryProvider).summary(days),
);
