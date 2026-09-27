import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/mw_tokens.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/widgets/mw_icons.dart';
import '../../../../core/widgets/mw_pressable.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../domain/day.dart';
import 'step_format.dart';

/// The day's steps in time order with a connecting rail.
class DayTimeline extends StatelessWidget {
  const DayTimeline({required this.day, required this.onTap, super.key});

  final Day day;
  final ValueChanged<DayStep> onTap;

  @override
  Widget build(BuildContext context) {
    final steps = day.timeline;
    return Column(
      children: [
        for (final (i, s) in steps.indexed)
          _TimelineRow(
            step: s,
            routineName: day.routineOf(s)?.name ?? '',
            isFocus: s.id == day.focusId,
            isFirst: i == 0,
            isLast: i == steps.length - 1,
            onTap: () => onTap(s),
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.routineName,
    required this.isFocus,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final DayStep step;
  final String routineName;
  final bool isFocus;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final muted = step.status == StepStatus.cancelled || step.status == StepStatus.skipped;
    final time = step.scheduledAt == null ? '' : formatDateTimeClock(context, step.scheduledAt!);
    final label = statusLabel(step);
    final labelColor = switch (step.status) {
      StepStatus.completed || StepStatus.partiallyCompleted => c.action,
      StepStatus.inProgress => c.accentText,
      _ => c.textSecondary,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(width: 2, height: 14, color: isFirst ? Colors.transparent : c.border),
                _Node(step: step),
                Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : c.border)),
              ],
            ),
          ),
          const SizedBox(width: MwSpace.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: MwSpace.sm),
              child: Semantics(
                button: true,
                label: '${step.title}, $label${time.isEmpty ? '' : ', $time'}',
                excludeSemantics: true,
                child: MwPressable(
                  onTap: onTap,
                  child: AnimatedOpacity(
                    duration: MwMotion.medium,
                    opacity: muted ? 0.6 : 1,
                    // Clip for the rounded shape: Flutter can't round a border whose sides differ.
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(MwRadii.lg),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.surface,
                          border: Border(
                            left: BorderSide(color: isFocus ? c.accent : c.border, width: isFocus ? 4 : 1),
                            top: BorderSide(color: c.border),
                            right: BorderSide(color: c.border),
                            bottom: BorderSide(color: c.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    [if (time.isNotEmpty) time, label].join(' · ').toUpperCase(),
                                    style: context.text.labelSmall?.copyWith(color: labelColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    step.title,
                                    style: context.text.labelLarge?.copyWith(
                                      decoration: step.status == StepStatus.cancelled
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    step.reflection.isNotEmpty
                                        ? '“${step.reflection}”'
                                        : [
                                            routineName,
                                            if (plannedLabel(step).isNotEmpty) plannedLabel(step),
                                          ].join(' · '),
                                    style: context.text.bodySmall?.copyWith(
                                      color: c.textSecondary,
                                      fontStyle: step.reflection.isNotEmpty ? FontStyle.italic : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (step.isEssential && step.status.isOpen)
                              const Padding(
                                padding: EdgeInsets.only(right: MwSpace.xs),
                                child: StatusPill(label: '★', tone: PillTone.accent),
                              ),
                            Icon(stepIcon(step.icon), size: 20, color: isFocus ? c.accent : c.textTertiary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.step});

  final DayStep step;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return switch (step.status) {
      StepStatus.completed => _circle(c.action, Icon(Symbols.check, size: 13, color: c.onAction)),
      StepStatus.partiallyCompleted => _circle(
        c.action.withValues(alpha: 0.55),
        Icon(Symbols.timelapse, size: 12, color: c.onAction),
      ),
      StepStatus.inProgress => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: c.accent,
          shape: BoxShape.circle,
          border: Border.all(color: c.accentTint, width: 4),
        ),
      ),
      StepStatus.skipped ||
      StepStatus.cancelled => _circle(c.sunken, Icon(Symbols.remove, size: 12, color: c.textTertiary)),
      StepStatus.pending => _circle(
        c.sunken,
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: step.isEssential ? c.accent : c.border, shape: BoxShape.circle),
        ),
      ),
    };
  }

  Widget _circle(Color color, Widget child) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    alignment: Alignment.center,
    child: child,
  );
}
