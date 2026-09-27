import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/mw_tokens.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/widgets/mw_card.dart';
import '../../../../core/widgets/progress_ring.dart';
import '../../../../core/widgets/segmented_strand.dart';
import '../../domain/day.dart';

class DayProgressCard extends StatelessWidget {
  const DayProgressCard({required this.day, super.key});

  final Day day;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final p = day.progress;
    final total = p.total == 0 ? 1 : p.total;
    final doneShare = day.timeline
        .where((s) => s.status != StepStatus.cancelled)
        .fold<double>(0, (sum, s) => sum + (s.status.isDone ? s.completionRatio : 0));
    final moving = p.inProgress / total;
    final left = p.remaining + p.inProgress;

    final headline = switch (p.ratio) {
      0 when p.done == 0 => 'Ready when you are',
      >= 1 => "That's everything for today",
      _ => '${percent(p.ratio)} of your day',
    };
    return MwCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: c.action, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text("Today's progress", style: context.text.labelMedium?.copyWith(color: c.action)),
                      ],
                    ),
                    const SizedBox(height: MwSpace.xs),
                    Text(headline, style: context.text.titleLarge),
                    Text(
                      '${p.done} of ${p.total} ${p.total == 1 ? 'step' : 'steps'} done'
                      '${p.partial > 0 ? ' · ${p.partial} partly' : ''}',
                      style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              ProgressRing(
                value: p.ratio,
                semanticLabel: "Today's progress",
                center: Icon(Symbols.vital_signs, color: c.accentText, size: 22),
              ),
            ],
          ),
          const SizedBox(height: MwSpace.md),
          SegmentedStrand(
            semanticLabel: '${p.done} done, ${p.inProgress} in progress, ${p.remaining} to go',
            segments: [
              StrandSegment(fraction: doneShare / total, color: c.action),
              StrandSegment(fraction: moving, color: c.accent),
            ],
          ),
          const SizedBox(height: MwSpace.sm),
          Row(
            children: [
              Icon(Symbols.check_circle, size: 14, color: c.action),
              const SizedBox(width: MwSpace.xs),
              Expanded(
                child: Text(
                  p.done == 0 ? 'Small steps count' : 'Keep moving',
                  style: context.text.labelSmall?.copyWith(color: c.textSecondary),
                ),
              ),
              Text(
                left == 0 ? 'Nothing left' : '$left to go',
                style: context.text.labelSmall?.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
