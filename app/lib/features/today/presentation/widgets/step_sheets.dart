import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/mw_tokens.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/widgets/mw_button.dart';
import '../../../../core/widgets/mw_chips.dart';
import '../../../../core/widgets/mw_sheet.dart';
import '../../../routines/domain/routine.dart';
import '../../domain/day.dart';
import 'step_format.dart';

/// Asks how much was done. Returns the amount (below planned = partial).
Future<double?> showPartialSheet(BuildContext context, DayStep step) {
  return showMwSheet<double>(
    context,
    title: 'How much did you do?',
    builder: (_) => _PartialForm(step: step),
  );
}

class _PartialForm extends StatefulWidget {
  const _PartialForm({required this.step});

  final DayStep step;

  @override
  State<_PartialForm> createState() => _PartialFormState();
}

class _PartialFormState extends State<_PartialForm> {
  late double _value = _initial();

  double get _max => widget.step.plannedValue;

  double _initial() {
    final s = widget.step;
    if (s.targetKind == TargetKind.duration && s.elapsedSeconds > 0) {
      return (s.elapsedSeconds / 60).clamp(1, _max).roundToDouble();
    }
    return (_max / 2).clamp(1, _max).roundToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final s = widget.step;
    final divisions = _max >= 1 ? _max.round().clamp(1, 240) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Partial counts. ${amountLabel(s.targetKind, _value, s.unit)} of ${plannedLabel(s)} is real progress.',
          style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: MwSpace.lg),
        Center(child: Text(amountLabel(s.targetKind, _value, s.unit), style: context.text.displayMedium)),
        Slider(
          value: _value.clamp(1, _max),
          min: _max >= 1 ? 1 : 0,
          max: _max,
          divisions: divisions,
          label: formatAmount(_value),
          onChanged: (v) => setState(() => _value = v.roundToDouble()),
        ),
        Wrap(
          spacing: MwSpace.sm,
          children: [
            for (final share in [0.25, 0.5, 0.75])
              MwChoicePill(
                label: percent(share),
                selected: _value == (_max * share).roundToDouble(),
                onTap: () => setState(() => _value = (_max * share).roundToDouble().clamp(1, _max)),
              ),
          ],
        ),
        const SizedBox(height: MwSpace.lg),
        MwButton(
          label: 'Log ${amountLabel(s.targetKind, _value, s.unit)}',
          onPressed: () => Navigator.pop(context, _value),
        ),
      ],
    );
  }
}

/// Optional reason for skipping. Returns null when dismissed; a reason (or SkipReason.other) to confirm.
Future<SkipReason?> showSkipSheet(BuildContext context, DayStep step) {
  return showMwSheet<SkipReason>(
    context,
    title: 'Skip ${step.title.toLowerCase()}?',
    builder: (context) {
      final c = context.mwColors;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "That's okay. If you like, tell Mwendo why — it helps suggest better plans later.",
            style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: MwSpace.md),
          for (final reason in SkipReason.values)
            Padding(
              padding: const EdgeInsets.only(bottom: MwSpace.sm),
              child: MwButton(
                label: reason.label,
                variant: MwButtonVariant.secondary,
                onPressed: () => Navigator.pop(context, reason),
              ),
            ),
        ],
      );
    },
  );
}

/// A short note about how it went. Returns the note, or null.
Future<String?> showReflectionSheet(BuildContext context, DayStep step) {
  final controller = TextEditingController(text: step.reflection);
  return showMwSheet<String>(
    context,
    title: 'How did it go?',
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Felt grounded and present…'),
        ),
        const SizedBox(height: MwSpace.md),
        MwButton(label: 'Save note', onPressed: () => Navigator.pop(context, controller.text.trim())),
      ],
    ),
  );
}

enum StepAction { start, pause, done, partial, skip, undo, reflect }

/// Everything you can do with a step from the timeline.
Future<StepAction?> showStepActions(BuildContext context, DayStep step) {
  final open = step.status.isOpen;
  final timed = step.targetKind == TargetKind.duration;
  return showMwSheet<StepAction>(
    context,
    title: step.title,
    builder: (context) {
      Widget action(StepAction a, String label, IconData icon, {bool primary = false}) => Padding(
        padding: const EdgeInsets.only(bottom: MwSpace.sm),
        child: MwButton(
          label: label,
          icon: icon,
          variant: primary ? MwButtonVariant.primary : MwButtonVariant.secondary,
          onPressed: () => Navigator.pop(context, a),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(statusLabel(step), style: context.text.bodyMedium?.copyWith(color: context.mwColors.textSecondary)),
          const SizedBox(height: MwSpace.md),
          if (open || step.status == StepStatus.cancelled) ...[
            if (timed && step.status != StepStatus.inProgress)
              action(StepAction.start, 'Start now', Symbols.play_arrow),
            if (step.isRunning) action(StepAction.pause, 'Pause', Symbols.pause),
            action(StepAction.done, 'Mark done', Symbols.check, primary: true),
            if (step.targetKind != TargetKind.check) action(StepAction.partial, 'Log partial', Symbols.timelapse),
            if (open) action(StepAction.skip, 'Skip for today', Symbols.forward),
          ] else ...[
            action(
              StepAction.reflect,
              step.reflection.isEmpty ? 'Add a note' : 'Edit note',
              Symbols.edit_note,
              primary: true,
            ),
            action(StepAction.undo, 'Undo', Symbols.undo),
          ],
        ],
      );
    },
  );
}
