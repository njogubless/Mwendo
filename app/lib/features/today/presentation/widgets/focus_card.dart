import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/mw_tokens.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/widgets/mw_button.dart';
import '../../../../core/widgets/mw_card.dart';
import '../../../../core/widgets/mw_icons.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../routines/domain/routine.dart';
import '../../domain/day.dart';
import 'step_format.dart';

/// "What should I do now?" — the one step that matters right now, with its actions.
class FocusCard extends StatelessWidget {
  const FocusCard({
    required this.step,
    required this.routineName,
    required this.fetchedAt,
    required this.onStart,
    required this.onPause,
    required this.onDone,
    required this.onPartial,
    required this.onSkip,
    this.shiftedMinutes = 0,
    super.key,
  });

  final DayStep step;
  final String routineName;
  final DateTime fetchedAt;
  final int shiftedMinutes;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onDone;
  final VoidCallback onPartial;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final started = step.status == StepStatus.inProgress;
    final timed = step.targetKind == TargetKind.duration;
    final canPartial = step.targetKind != TargetKind.check;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'Right now',
          trailing: Text(
            shiftedMinutes >= 10 ? 'Shifted ${formatMinutes(shiftedMinutes)}' : 'On rhythm',
            style: context.text.labelSmall?.copyWith(color: c.accentText),
          ),
        ),
        const SizedBox(height: MwSpace.sm),
        MwCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: MwSpace.sm,
                runSpacing: MwSpace.xs,
                children: [
                  StatusPill(
                    label: started ? (step.isRunning ? 'NOW · IN MOTION' : 'PAUSED') : 'UP NEXT',
                    tone: started ? PillTone.success : PillTone.accent,
                    icon: started ? Symbols.play_circle : Symbols.arrow_forward,
                  ),
                  if (step.isEssential) const StatusPill(label: 'Essential', icon: Symbols.star),
                ],
              ),
              const SizedBox(height: MwSpace.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: c.accentTint, borderRadius: BorderRadius.circular(MwRadii.md)),
                    child: Icon(stepIcon(step.icon), color: c.accentText),
                  ),
                  const SizedBox(width: MwSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.title, style: context.text.headlineSmall),
                        Text(
                          [routineName, if (plannedLabel(step).isNotEmpty) plannedLabel(step)].join(' · '),
                          style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (step.description.isNotEmpty) ...[
                const SizedBox(height: MwSpace.sm),
                Text(step.description, style: context.text.bodyMedium?.copyWith(color: c.textSecondary)),
              ],
              if (step.isAdapted && step.targetKind != TargetKind.check) ...[
                const SizedBox(height: MwSpace.sm),
                Text(
                  'Shortened from ${amountLabel(step.targetKind, step.targetValue, step.unit)} — still counts.',
                  style: context.text.bodySmall?.copyWith(color: c.accentText),
                ),
              ],
              if (timed && started) ...[
                const SizedBox(height: MwSpace.md),
                _TimerBed(step: step, fetchedAt: fetchedAt),
              ],
              const SizedBox(height: MwSpace.md),
              if (!started && timed)
                MwButton(label: 'Start', icon: Symbols.play_arrow, onPressed: onStart)
              else
                MwButton(label: 'Mark done', icon: Symbols.check, onPressed: onDone),
              const SizedBox(height: MwSpace.sm),
              Row(
                children: [
                  if (started && timed) ...[
                    Expanded(
                      child: MwButton(
                        label: step.isRunning ? 'Pause' : 'Resume',
                        icon: step.isRunning ? Symbols.pause : Symbols.play_arrow,
                        variant: MwButtonVariant.secondary,
                        size: MwButtonSize.compact,
                        onPressed: step.isRunning ? onPause : onStart,
                      ),
                    ),
                    const SizedBox(width: MwSpace.sm),
                  ],
                  if (!started && timed) ...[
                    Expanded(
                      child: MwButton(
                        label: 'Done',
                        icon: Symbols.check,
                        variant: MwButtonVariant.secondary,
                        size: MwButtonSize.compact,
                        onPressed: onDone,
                      ),
                    ),
                    const SizedBox(width: MwSpace.sm),
                  ],
                  if (canPartial) ...[
                    Expanded(
                      child: MwButton(
                        label: 'Partial',
                        icon: Symbols.timelapse,
                        variant: MwButtonVariant.secondary,
                        size: MwButtonSize.compact,
                        onPressed: onPartial,
                      ),
                    ),
                    const SizedBox(width: MwSpace.sm),
                  ],
                  Expanded(
                    child: MwButton(
                      label: 'Skip',
                      icon: Symbols.forward,
                      variant: MwButtonVariant.secondary,
                      size: MwButtonSize.compact,
                      onPressed: onSkip,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Live "12 min done / 20 min" bed. Ticks locally from the last server snapshot.
class _TimerBed extends StatefulWidget {
  const _TimerBed({required this.step, required this.fetchedAt});

  final DayStep step;
  final DateTime fetchedAt;

  @override
  State<_TimerBed> createState() => _TimerBedState();
}

class _TimerBedState extends State<_TimerBed> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.step.isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final elapsed = liveElapsedSeconds(widget.step, widget.fetchedAt, DateTime.now());
    final plannedSeconds = widget.step.plannedValue * 60;
    final ratio = plannedSeconds == 0 ? 0.0 : (elapsed / plannedSeconds).clamp(0.0, 1.0);
    final over = elapsed >= plannedSeconds;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(MwRadii.lg)),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                formatElapsed(elapsed),
                style: context.text.labelLarge?.copyWith(
                  color: c.action,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                over ? 'Target reached — nicely done' : '${plannedLabel(widget.step)} target',
                style: context.text.labelMedium?.copyWith(color: c.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: MwSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(MwRadii.pill),
            child: LinearProgressIndicator(value: ratio, minHeight: 8, color: c.action, backgroundColor: c.surface),
          ),
        ],
      ),
    );
  }
}
