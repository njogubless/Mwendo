import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reminders/application/reminders_controller.dart';
import '../data/goals_repository.dart';
import '../domain/goal.dart';

final goalsProvider = FutureProvider<List<Goal>>((ref) => ref.watch(goalsRepositoryProvider).list());

final habitOptionsProvider = FutureProvider<List<HabitOption>>((ref) => ref.watch(goalsRepositoryProvider).habits());

class GoalController extends AsyncNotifier<Goal> {
  GoalController(this.id);

  final String id;

  GoalsRepository get _repo => ref.read(goalsRepositoryProvider);

  @override
  Future<Goal> build() => ref.watch(goalsRepositoryProvider).get(id);

  Future<void> _set(Future<Goal> Function() action) async {
    final before = state.value;
    final after = await action();
    state = AsyncData(after);
    ref.invalidate(goalsProvider);
    ref.read(goalMilestoneAnnouncerProvider)(before, after);
  }

  Future<void> edit(GoalDraft draft) => _set(() => _repo.update(id, draft));

  Future<void> setStatus(GoalStatus status) => _set(() => _repo.setStatus(id, status));

  Future<void> logProgress(double value, DateTime on, {String note = ''}) =>
      _set(() => _repo.logProgress(id, value: value, on: on, note: note));

  Future<void> deleteMeasurement(String measurementId) => _set(() async {
    await _repo.deleteMeasurement(id, measurementId);
    return _repo.get(id);
  });

  Future<void> addHabit(String title, {bool perWeek = false, int times = 1}) => _set(() async {
    await _repo.createHabit(title: title, goalId: id, perWeek: perWeek, times: times);
    ref.invalidate(habitOptionsProvider);
    return _repo.get(id);
  });

  Future<void> removeHabit(String habitId) => _set(() async {
    await _repo.deleteHabit(habitId);
    ref.invalidate(habitOptionsProvider);
    return _repo.get(id);
  });

  Future<void> archive() async {
    await _repo.archive(id);
    ref.invalidate(goalsProvider);
  }
}

final goalControllerProvider = AsyncNotifierProvider.autoDispose.family<GoalController, Goal, String>(
  GoalController.new,
);
