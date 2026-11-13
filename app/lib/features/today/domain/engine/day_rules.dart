import '../../../routines/domain/routine.dart';
import '../day.dart';
import 'day_record.dart';

// Pure rules for a day, ported 1:1 from backend `apps/tracking/domain/{progress,focus}.py`.

/// Today's progress (D-007): Σ completion ratio / steps, excluding `cancelled` (set aside by an approved
/// adaptation). Skipped steps count as 0 but stay in the denominator — honest data, shown neutrally.
DayProgress computeProgress(Iterable<StepRecord> steps) {
  var completed = 0, partial = 0, skipped = 0, inProgress = 0, pending = 0, cancelled = 0;
  var ratioSum = 0.0;
  for (final s in steps) {
    switch (s.status) {
      case StepStatus.completed:
        completed++;
      case StepStatus.partiallyCompleted:
        partial++;
      case StepStatus.skipped:
        skipped++;
      case StepStatus.inProgress:
        inProgress++;
      case StepStatus.pending:
        pending++;
      case StepStatus.cancelled:
        cancelled++;
    }
    if (s.status != StepStatus.cancelled) ratioSum += s.completionRatio;
  }
  final total = completed + partial + skipped + inProgress + pending;
  return DayProgress(
    ratio: total == 0 ? 0 : round3(ratioSum / total),
    total: total,
    completed: completed,
    partial: partial,
    skipped: skipped,
    inProgress: inProgress,
    remaining: pending,
    cancelled: cancelled,
  );
}

double completionRatio(double actual, double planned) {
  if (planned <= 0) return 1;
  return round3((actual / planned).clamp(0, 1).toDouble());
}

double round3(double v) => (v * 1000).roundToDouble() / 1000;

final _far = DateTime.utc(9999);
final _never = DateTime.utc(0);

/// "What should I focus on now?": a running step wins, then a paused one (latest started), else the earliest
/// scheduled pending step.
StepRecord? selectFocus(Iterable<StepRecord> steps) {
  final inProgress = steps.where((s) => s.status == StepStatus.inProgress).toList();
  if (inProgress.isNotEmpty) {
    inProgress.sort((a, b) {
      final running = (b.runningSince != null ? 1 : 0) - (a.runningSince != null ? 1 : 0);
      if (running != 0) return running;
      return (b.startedAt ?? _never).compareTo(a.startedAt ?? _never);
    });
    return inProgress.first;
  }
  final pending = steps.where((s) => s.status == StepStatus.pending).toList()
    ..sort((a, b) {
      final byTime = (a.scheduledAt ?? _far).compareTo(b.scheduledAt ?? _far);
      return byTime != 0 ? byTime : a.position.compareTo(b.position);
    });
  return pending.isEmpty ? null : pending.first;
}

/// Minutes the focus step is behind its plan (0 when on time, unscheduled or already started).
int shiftedMinutes(StepRecord? focus, DateTime now) {
  if (focus == null || focus.scheduledAt == null || focus.status != StepStatus.pending) return 0;
  final minutes = now.difference(focus.scheduledAt!).inSeconds ~/ 60;
  return minutes < 0 ? 0 : minutes;
}

int elapsedSeconds(StepRecord s, DateTime now) {
  final running = s.runningSince == null ? 0 : now.difference(s.runningSince!).inSeconds;
  return s.activeSeconds + (running < 0 ? 0 : running);
}

/// Steps an adaptation may touch: untouched (never started) pending or set-aside steps.
bool isAdaptable(StepRecord s) =>
    (s.status == StepStatus.pending || s.status == StepStatus.cancelled) && s.startedAt == null;

bool isTimedKind(TargetKind k) => k == TargetKind.duration;
