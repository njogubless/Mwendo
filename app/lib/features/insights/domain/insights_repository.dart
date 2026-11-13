import 'insights.dart';

/// Deterministic insights over the last [days] days. Implementations throw `AppFailure`s.
abstract interface class InsightsRepository {
  Future<InsightsSummary> summary(int days);
}
