import 'day.dart';

abstract interface class DayRepository {
  Future<Day> today();
  Future<Day> start(String stepId);
  Future<Day> pause(String stepId);

  /// Omit [actualValue] for a full completion; a smaller amount records a partial one.
  Future<Day> complete(String stepId, {double? actualValue});
  Future<Day> skip(String stepId, {SkipReason? reason});
  Future<Day> undo(String stepId);
  Future<Day> setMode(DayMode mode);
  Future<Day> dismissRecovery();
  Future<void> reflect(String stepId, String note);
  Future<AdaptationPreview> preview(String instanceId, {int? budgetMinutes, bool minimum = false});
  Future<Day> applyBudget(String instanceId, int minutes);
  Future<Day> revert(String adjustmentId);
}
