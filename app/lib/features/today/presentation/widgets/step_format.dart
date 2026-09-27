import '../../../../core/utils/formatting.dart';
import '../../../routines/domain/routine.dart';
import '../../domain/day.dart';

/// "20 min", "20 pages", "" for check steps.
String amountLabel(TargetKind kind, double value, String unit) => switch (kind) {
  TargetKind.duration => formatMinutes(value),
  TargetKind.count => '${formatAmount(value)}${unit.isEmpty ? '' : ' $unit'}',
  TargetKind.check => '',
};

String plannedLabel(DayStep s) => amountLabel(s.targetKind, s.plannedValue, s.unit);

/// Calm status words for the timeline.
String statusLabel(DayStep s) => switch (s.status) {
  StepStatus.completed => 'Done',
  StepStatus.partiallyCompleted => 'Partly done · ${amountLabel(s.targetKind, s.actualValue ?? 0, s.unit)}',
  StepStatus.skipped => 'Skipped · that’s okay',
  StepStatus.cancelled => 'Set aside for today',
  StepStatus.inProgress => s.isRunning ? 'In motion' : 'Paused',
  StepStatus.pending => 'Up next',
};
