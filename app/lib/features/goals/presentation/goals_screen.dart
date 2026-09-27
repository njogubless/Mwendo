import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mw_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/guide_card.dart';
import '../../../core/widgets/mw_button.dart';
import '../../../core/widgets/mw_card.dart';
import '../../../core/widgets/mw_page.dart';
import '../../../core/widgets/segmented_strand.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_pill.dart';
import '../application/goals_controller.dart';
import '../data/goals_repository.dart';
import '../domain/goal.dart';
import 'goal_sheets.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goalsProvider);

    Future<void> create() => showGoalEditor(
      context,
      onSave: (draft) async {
        final goal = await ref.read(goalsRepositoryProvider).create(draft);
        ref.invalidate(goalsProvider);
        if (context.mounted) unawaited(context.push(Routes.goal(goal.id)));
      },
    );

    final header = [
      const MwPageHeader(leading: BrandLockup(title: 'Goals')),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What you’re moving toward', style: context.text.headlineMedium),
          Text(
            'Goals connect your daily steps to the bigger picture.',
            style: context.text.bodyMedium?.copyWith(color: context.mwColors.textSecondary),
          ),
        ],
      ),
    ];

    return RefreshIndicator(
      onRefresh: () => ref.refresh(goalsProvider.future),
      child: switch (state) {
        AsyncData(:final value) || AsyncLoading(:final value?) => MwPage(
          children: [
            ...header,
            if (GuideCard.isVisible(ref, 'goals', alwaysShow: value.isEmpty))
              GuideCard(tipId: 'goals', title: Guides.goalsTitle, steps: Guides.goals, alwaysShow: value.isEmpty),
            if (value.isEmpty)
              MwCard(
                padding: const EdgeInsets.symmetric(vertical: MwSpace.xl),
                child: EmptyView(
                  icon: Symbols.flag,
                  title: 'Set a direction',
                  message:
                      'A goal gives your routines a reason. It can be measurable — or simply how you want to feel.',
                  actionLabel: 'Create a goal',
                  onAction: create,
                ),
              )
            else ...[
              for (final g in value) _GoalCard(goal: g),
              MwButton(label: 'New goal', icon: Symbols.add, variant: MwButtonVariant.accent, onPressed: create),
            ],
          ],
        ),
        AsyncError(:final error) => MwPage(
          children: [
            ...header,
            MwCard(
              child: ErrorView(
                failure: error is AppFailure ? error : UnknownFailure(cause: error),
                onRetry: () => ref.invalidate(goalsProvider),
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
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final d = goal.draft;
    return MwCard(
      onTap: () => context.push(Routes.goal(goal.id)),
      semanticLabel: goal.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(goal.title, style: context.text.titleLarge)),
              if (goal.status != GoalStatus.active)
                StatusPill(
                  label: goal.status.label,
                  tone: goal.status == GoalStatus.achieved ? PillTone.success : PillTone.neutral,
                ),
            ],
          ),
          if (goal.hasTarget) ...[
            const SizedBox(height: MwSpace.sm),
            Text(
              '${formatAmount(goal.currentValue)} of ${formatAmount(d.targetValue!)} ${d.unit}'.trim(),
              style: context.text.bodySmall?.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: MwSpace.xs),
            SegmentedStrand(
              semanticLabel: '${percent(goal.ratio ?? 0)} of target',
              segments: [StrandSegment(fraction: goal.ratio ?? 0, color: c.accent)],
            ),
          ],
          if (goal.habits.isNotEmpty) ...[
            const SizedBox(height: MwSpace.md),
            for (final h in goal.habits)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Symbols.repeat, size: 16, color: c.action),
                    const SizedBox(width: MwSpace.sm),
                    Expanded(child: Text(h.title, style: context.text.bodySmall)),
                    Text(
                      '${h.daysDone}/${h.weeklyTarget} this week',
                      style: context.text.labelSmall?.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
          ],
          if (d.targetDate != null) ...[
            const SizedBox(height: MwSpace.sm),
            Text(
              'By ${MaterialLocalizations.of(context).formatMediumDate(d.targetDate!)}',
              style: context.text.labelSmall?.copyWith(color: c.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
