import 'goal.dart';

/// Goals, their measurements and habits. Implementations throw `AppFailure` subclasses.
abstract interface class GoalsRepository {
  Future<List<Goal>> list();
  Future<Goal> get(String id);
  Future<Goal> create(GoalDraft draft);
  Future<Goal> update(String id, GoalDraft draft);
  Future<Goal> setStatus(String id, GoalStatus status);

  /// Archives the goal. Its habits stay linked to steps.
  Future<void> archive(String id);
  Future<Goal> logProgress(String id, {required double value, required DateTime on, String note = ''});
  Future<void> deleteMeasurement(String goalId, String measurementId);
  Future<List<HabitOption>> habits();
  Future<void> createHabit({required String title, String? goalId, bool perWeek = false, int times = 1});
  Future<void> deleteHabit(String id);
}
