import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mw_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/mw_card.dart';
import '../../../core/widgets/mw_chips.dart';
import '../../../core/widgets/mw_page.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/section_label.dart';
import '../../../core/widgets/segmented_strand.dart';
import '../../../core/widgets/state_views.dart';
import '../data/insights_repository.dart';
import '../domain/insights.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(insightsProvider(_days));
    final header = [
      const MwPageHeader(leading: BrandLockup(title: 'Insights')),
      Row(
        children: [
          Expanded(child: Text('Your rhythm', style: context.text.headlineMedium)),
          MwPillRow<int>(
            options: const [7, 30],
            selected: _days,
            labelOf: (d) => d == 7 ? 'Week' : 'Month',
            onSelected: (d) => setState(() => _days = d),
          ),
        ],
      ),
    ];
    return RefreshIndicator(
      onRefresh: () => ref.refresh(insightsProvider(_days).future),
      child: switch (state) {
        AsyncData(:final value) || AsyncLoading(:final value?) => MwPage(children: [...header, ..._content(value)]),
        AsyncError(:final error) => MwPage(
          children: [
            ...header,
            MwCard(
              child: ErrorView(
                failure: error is AppFailure ? error : UnknownFailure(cause: error),
                onRetry: () => ref.invalidate(insightsProvider(_days)),
              ),
            ),
          ],
        ),
        _ => MwPage(
          children: [
            ...header,
            const SizedBox(height: 200, child: LoadingView()),
          ],
        ),
      },
    );
  }

  List<Widget> _content(InsightsSummary s) {
    final c = context.mwColors;
    if (!s.hasData) {
      return [
        const MwCard(
          padding: EdgeInsets.symmetric(vertical: MwSpace.xl),
          child: EmptyView(
            icon: Symbols.insights,
            title: 'Building your rhythm',
            message: 'After a few days, Mwendo will show what helps you keep moving.',
          ),
        ),
      ];
    }
    return [
      MwCard(
        child: Row(
          children: [
            ProgressRing(
              value: s.consistency ?? 0,
              size: 84,
              strokeWidth: 8,
              color: c.action,
              semanticLabel: 'Consistency',
              center: Text(percent(s.consistency ?? 0), style: context.text.labelLarge),
            ),
            const SizedBox(width: MwSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CONSISTENCY', style: context.text.labelSmall?.copyWith(color: c.action)),
                  const SizedBox(height: MwSpace.xs),
                  Text(
                    'Showed up ${s.daysShowedUp} of ${s.daysPlanned} ${s.daysPlanned == 1 ? 'day' : 'days'}',
                    style: context.text.titleLarge,
                  ),
                  Text(
                    [
                      if (s.completionRate != null) '${percent(s.completionRate!)} of steps done',
                      if (s.partialWins > 0) '${s.partialWins} partial ${s.partialWins == 1 ? 'win' : 'wins'}',
                    ].join(' · '),
                    style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      for (final o in s.observations)
        MwCard(
          tone: o.kind == 'suggestion' ? MwCardTone.warm : MwCardTone.sunken,
          padding: const EdgeInsets.all(MwSpace.md),
          child: Row(
            children: [
              Icon(switch (o.kind) {
                'timing' => Symbols.schedule,
                'partial' => Symbols.timelapse,
                'suggestion' => Symbols.lightbulb,
                'learning' => Symbols.spa,
                _ => Symbols.check_circle,
              }, color: o.kind == 'suggestion' ? c.accentText : c.action),
              const SizedBox(width: MwSpace.md),
              Expanded(child: Text(o.text, style: context.text.bodyMedium)),
            ],
          ),
        ),
      const SectionLabel('Day by day'),
      MwCard(child: _DayBars(series: s.series)),
      if (s.routines.isNotEmpty) ...[
        const SectionLabel('By routine'),
        MwCard(
          child: Column(
            children: [for (final r in s.routines) _RateBar(row: r, color: c.action)],
          ),
        ),
      ],
      if (s.partsOfDay.isNotEmpty) ...[
        const SectionLabel('By time of day'),
        MwCard(
          child: Column(
            children: [
              for (final r in s.partsOfDay)
                _RateBar(
                  row: RateRow(label: r.label[0].toUpperCase() + r.label.substring(1), steps: r.steps, rate: r.rate),
                  color: c.accent,
                ),
            ],
          ),
        ),
      ],
    ];
  }
}

class _RateBar extends StatelessWidget {
  const _RateBar({required this.row, required this.color});

  final RateRow row;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(row.label, style: context.text.labelLarge)),
              Text(
                '${percent(row.rate)} · ${row.steps} steps',
                style: context.text.labelSmall?.copyWith(color: context.mwColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SegmentedStrand(
            semanticLabel: '${row.label} ${percent(row.rate)}',
            segments: [StrandSegment(fraction: row.rate, color: color)],
          ),
        ],
      ),
    );
  }
}

/// Simple vertical bars, one per day. Days with nothing planned show a faint dot.
class _DayBars extends StatelessWidget {
  const _DayBars({required this.series});

  final List<DayPoint> series;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final dense = series.length > 10;
    return Semantics(
      label: 'Daily completion chart',
      child: SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final p in series)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: dense ? 1.5 : 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (p.ratio == null)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: c.border, shape: BoxShape.circle),
                        )
                      else
                        Tooltip(
                          message:
                              '${MaterialLocalizations.of(context).formatShortMonthDay(p.date)}: '
                              '${percent(p.ratio!)}',
                          child: Container(
                            height: 8 + 96 * p.ratio!,
                            decoration: BoxDecoration(
                              color: p.ratio! > 0 ? c.action : c.sunken,
                              borderRadius: BorderRadius.circular(MwRadii.sm),
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      if (!dense)
                        Text(
                          weekdayShort[p.date.weekday - 1].substring(0, 1),
                          style: context.text.labelSmall?.copyWith(color: c.textTertiary),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
