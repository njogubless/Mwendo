import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../data/day_repository_impl.dart';
import '../domain/day.dart';
import '../domain/day_repository.dart';

/// Today's plan and every action on it.
///
/// Actions update the UI immediately (optimistic), then replace state with the server's day, which
/// carries the authoritative progress and next focus. On failure the previous day is restored and the
/// failure is returned so the screen can explain it calmly.
class TodayController extends AsyncNotifier<Day> {
  DayRepository get _repo => ref.read(dayRepositoryProvider);

  @override
  Future<Day> build() => ref.watch(dayRepositoryProvider).today();

  Future<void> refresh() async {
    final next = await AsyncValue.guard(_repo.today);
    // Keep showing the last good day if a background refresh fails.
    if (next.hasError && state.hasValue) return;
    state = next;
  }

  Future<AppFailure?> _act(Future<Day> Function() call, {DayStep? optimistic}) async {
    final previous = state.value;
    if (previous != null && optimistic != null) state = AsyncData(previous.withStep(optimistic));
    try {
      state = AsyncData(await call());
      return null;
    } on AppFailure catch (failure) {
      if (previous != null) state = AsyncData(previous);
      return failure;
    }
  }

  Future<AppFailure?> start(DayStep step) =>
      _act(() => _repo.start(step.id), optimistic: step.copyWith(status: StepStatus.inProgress, isRunning: true));

  Future<AppFailure?> pause(DayStep step) =>
      _act(() => _repo.pause(step.id), optimistic: step.copyWith(isRunning: false));

  Future<AppFailure?> complete(DayStep step, {double? amount}) {
    final full = amount == null || amount >= step.plannedValue;
    return _act(
      () => _repo.complete(step.id, actualValue: amount),
      optimistic: step.copyWith(
        status: full ? StepStatus.completed : StepStatus.partiallyCompleted,
        isRunning: false,
        actualValue: amount ?? step.plannedValue,
        completionRatio: full ? 1 : (amount / step.plannedValue).clamp(0, 1),
      ),
    );
  }

  Future<AppFailure?> skip(DayStep step, {SkipReason? reason}) => _act(
    () => _repo.skip(step.id, reason: reason),
    optimistic: step.copyWith(status: StepStatus.skipped, isRunning: false),
  );

  Future<AppFailure?> undo(DayStep step) =>
      _act(() => _repo.undo(step.id), optimistic: step.copyWith(status: StepStatus.pending, isRunning: false));

  Future<AppFailure?> setMode(DayMode mode) => _act(() => _repo.setMode(mode));

  Future<AppFailure?> dismissRecovery() => _act(_repo.dismissRecovery);

  Future<AppFailure?> reflect(DayStep step, String note) async {
    try {
      await _repo.reflect(step.id, note);
      await refresh();
      return null;
    } on AppFailure catch (failure) {
      return failure;
    }
  }

  Future<AppFailure?> applyBudget(String instanceId, int minutes) => _act(() => _repo.applyBudget(instanceId, minutes));

  Future<AppFailure?> revert(String adjustmentId) => _act(() => _repo.revert(adjustmentId));
}

final todayControllerProvider = AsyncNotifierProvider<TodayController, Day>(TodayController.new);

/// Adaptation preview for one routine instance, keyed by (instance, budget, minimum).
typedef PreviewArgs = ({String instanceId, int? budget, bool minimum});

final adaptationPreviewProvider = FutureProvider.autoDispose.family<AdaptationPreview, PreviewArgs>(
  (ref, args) =>
      ref.watch(dayRepositoryProvider).preview(args.instanceId, budgetMinutes: args.budget, minimum: args.minimum),
);
