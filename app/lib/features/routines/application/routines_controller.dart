import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../today/application/today_controller.dart';
import '../data/routines_repository_impl.dart';
import '../domain/routine.dart';

/// The routines list. Every change also refreshes Today (templates shape today's plan).
class RoutinesController extends AsyncNotifier<List<Routine>> {
  @override
  Future<List<Routine>> build() => ref.watch(routinesRepositoryProvider).list();

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => ref.read(routinesRepositoryProvider).list());
  }

  void _replace(Routine routine) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([for (final r in current) r.id == routine.id ? routine : r]);
  }

  Future<void> setActive(Routine routine, bool active) async {
    final updated = await ref
        .read(routinesRepositoryProvider)
        .setStatus(routine.id, active ? RoutineStatus.active : RoutineStatus.paused);
    _replace(updated);
    ref.invalidate(todayControllerProvider);
  }

  Future<Routine> create(RoutineDetails details) async {
    final routine = await ref.read(routinesRepositoryProvider).create(details);
    state = AsyncData([...?state.value, routine]);
    ref.invalidate(todayControllerProvider);
    return routine;
  }

  Future<void> archive(String id) async {
    await ref.read(routinesRepositoryProvider).archive(id);
    state = AsyncData([...?state.value?.where((r) => r.id != id)]);
    ref.invalidate(todayControllerProvider);
  }

  Future<void> startNow(String id) async {
    await ref.read(routinesRepositoryProvider).startNow(id);
    ref.invalidate(todayControllerProvider);
  }
}

final routinesControllerProvider = AsyncNotifierProvider<RoutinesController, List<Routine>>(RoutinesController.new);

/// One routine being edited. Each action is saved immediately, then the list and Today are refreshed.
class RoutineController extends AsyncNotifier<Routine> {
  RoutineController(this.id);

  final String id;

  @override
  Future<Routine> build() => ref.watch(routinesRepositoryProvider).get(id);

  Future<void> _after(Future<void> Function() action) async {
    await action();
    state = AsyncData(await ref.read(routinesRepositoryProvider).get(id));
    ref
      ..invalidate(routinesControllerProvider)
      ..invalidate(todayControllerProvider);
  }

  Future<void> updateDetails(RoutineDetails details) =>
      _after(() => ref.read(routinesRepositoryProvider).updateDetails(id, details));

  Future<void> saveStep(RoutineStep step) => _after(
    () => step.id == null
        ? ref.read(routinesRepositoryProvider).addStep(id, step)
        : ref.read(routinesRepositoryProvider).updateStep(id, step),
  );

  Future<void> removeStep(String stepId) => _after(() => ref.read(routinesRepositoryProvider).removeStep(id, stepId));

  Future<void> toggleEssential(RoutineStep step) => saveStep(step.copyWith(isEssential: !step.isEssential));

  /// Optimistic reorder: the list moves immediately, then syncs.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final routine = state.value;
    if (routine == null) return;
    final steps = [...routine.steps];
    final moved = steps.removeAt(oldIndex);
    steps.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, moved);
    state = AsyncData(
      Routine(id: routine.id, details: routine.details, status: routine.status, steps: steps, stats: routine.stats),
    );
    try {
      await _after(() => ref.read(routinesRepositoryProvider).reorder(id, [for (final s in steps) s.id!]));
    } catch (_) {
      state = AsyncData(routine);
      rethrow;
    }
  }
}

final routineControllerProvider = AsyncNotifierProvider.autoDispose.family<RoutineController, Routine, String>(
  RoutineController.new,
);
