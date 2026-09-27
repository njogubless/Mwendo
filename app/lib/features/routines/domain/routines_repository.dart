import 'routine.dart';

abstract interface class RoutinesRepository {
  Future<List<Routine>> list();
  Future<Routine> get(String id);
  Future<Routine> create(RoutineDetails details, {List<RoutineStep> steps = const []});
  Future<Routine> updateDetails(String id, RoutineDetails details);
  Future<Routine> setStatus(String id, RoutineStatus status);
  Future<void> archive(String id);
  Future<void> addStep(String routineId, RoutineStep step);
  Future<void> updateStep(String routineId, RoutineStep step);
  Future<void> removeStep(String routineId, String stepId);
  Future<Routine> reorder(String routineId, List<String> stepIds);

  /// Starts the routine now, outside its schedule.
  Future<void> startNow(String routineId);

  Future<List<RoutineDraft>> generate({required List<String> focusAreas, required String structure, int? wakeMinutes});
}
