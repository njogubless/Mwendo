import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mw_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/mw_button.dart';
import '../../../core/widgets/mw_card.dart';
import '../../../core/widgets/mw_sheet.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/section_label.dart';
import '../../../core/widgets/state_views.dart';
import '../application/goals_controller.dart';
import '../domain/goal.dart';
import 'goal_sheets.dart';

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({required this.goalId, super.key});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = goalControllerProvider(goalId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    Future<void> guarded(Future<void> Function() action, [String? success]) async {
      try {
        await action();
        if (success != null && context.mounted) showMwSnack(context, success);
      } on AppFailure catch (f) {
        if (context.mounted) showMwSnack(context, f.userMessage);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal'),
        actions: [
          if (state.value != null)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) async {
                final goal = state.value!;
                switch (v) {
                  case 'edit':
                    await showGoalEditor(context, initial: goal.draft, onSave: controller.edit);
                  case 'achieve':
                    await guarded(
                      () => controller.setStatus(GoalStatus.achieved),
                      'Achieved. That’s worth celebrating.',
                    );
                  case 'reopen':
                    await guarded(() => controller.setStatus(GoalStatus.active));
                  case 'pause':
                    await guarded(
                      () => controller.setStatus(GoalStatus.paused),
                      'Paused. Pick it up whenever you like.',
                    );
                  case 'archive':
                    if (await confirmMw(
                      context,
                      title: 'Archive this goal?',
                      message: 'It leaves your list. Its habits stay linked to your steps.',
                      confirmLabel: 'Archive',
                    )) {
                      await guarded(controller.archive);
                      if (context.mounted) context.pop();
                    }
                }
              },
              itemBuilder: (_) {
                final status = state.value!.status;
                return [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (status == GoalStatus.active) ...[
                    const PopupMenuItem(value: 'achieve', child: Text('Mark achieved')),
                    const PopupMenuItem(value: 'pause', child: Text('Pause')),
                  ] else
                    const PopupMenuItem(value: 'reopen', child: Text('Make active')),
                  const PopupMenuItem(value: 'archive', child: Text('Archive')),
                ];
              },
            ),
        ],
      ),
      body: switch (state) {
        AsyncData(:final value) || AsyncLoading(:final value?) => _Body(goal: value, guarded: guarded),
        AsyncError(:final error) => ErrorView(
          failure: error is AppFailure ? error : UnknownFailure(cause: error),
          onRetry: () => ref.invalidate(provider),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.goal, required this.guarded});

  final Goal goal;
  final Future<void> Function(Future<void> Function(), [String?]) guarded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mwColors;
    final controller = ref.read(goalControllerProvider(goal.id).notifier);
    final d = goal.draft;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(MwSpace.marginCompact),
            children: [
              Text(goal.title, style: context.text.headlineMedium),
              if (d.description.isNotEmpty)
                Text(d.description, style: context.text.bodyMedium?.copyWith(color: c.textSecondary)),
              const SizedBox(height: MwSpace.lg),
              MwCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PROGRESS', style: context.text.labelSmall?.copyWith(color: c.action)),
                          const SizedBox(height: MwSpace.xs),
                          Text(
                            goal.hasTarget
                                ? '${formatAmount(goal.currentValue)} of ${formatAmount(d.targetValue!)} ${d.unit}'
                                      .trim()
                                : 'Measured by how you show up',
                            style: context.text.titleLarge,
                          ),
                          if (d.targetDate != null)
                            Text(
                              'By ${MaterialLocalizations.of(context).formatMediumDate(d.targetDate!)}',
                              style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                            ),
                          if (goal.hasTarget) ...[
                            const SizedBox(height: MwSpace.md),
                            MwButton(
                              label: 'Log progress',
                              icon: Symbols.add,
                              size: MwButtonSize.compact,
                              expand: false,
                              onPressed: () => showLogProgressSheet(
                                context,
                                unit: d.unit,
                                onSave: (v, on, note) => controller.logProgress(v, on, note: note),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (goal.hasTarget)
                      ProgressRing(
                        value: goal.ratio ?? 0,
                        size: 84,
                        strokeWidth: 8,
                        semanticLabel: 'Goal progress',
                        center: Text(percent(goal.ratio ?? 0), style: context.text.labelLarge),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: MwSpace.lg),
              SectionLabel(
                'Habits that support it',
                trailing: TextButton.icon(
                  onPressed: () => showAddHabitSheet(
                    context,
                    onSave: (title, perWeek, times) => controller.addHabit(title, perWeek: perWeek, times: times),
                  ),
                  icon: const Icon(Symbols.add, size: 18),
                  label: const Text('Add'),
                ),
              ),
              const SizedBox(height: MwSpace.sm),
              if (goal.habits.isEmpty)
                MwCard(
                  tone: MwCardTone.sunken,
                  child: Text(
                    'Add the small, repeated action that moves this forward — then link it to a step in one of your '
                    'routines.',
                    style: context.text.bodySmall,
                  ),
                ),
              for (final h in goal.habits)
                Padding(
                  padding: const EdgeInsets.only(bottom: MwSpace.sm),
                  child: _HabitCard(
                    habit: h,
                    onRemove: () async {
                      if (await confirmMw(
                        context,
                        title: 'Remove "${h.title}"?',
                        message: 'Linked steps stay in your routines; they just stop counting toward this goal.',
                        confirmLabel: 'Remove',
                      )) {
                        await guarded(() => controller.removeHabit(h.id));
                      }
                    },
                  ),
                ),
              if (goal.measurements.isNotEmpty) ...[
                const SizedBox(height: MwSpace.lg),
                const SectionLabel('Logged'),
                const SizedBox(height: MwSpace.sm),
                MwCard(
                  padding: const EdgeInsets.symmetric(vertical: MwSpace.xs),
                  child: Column(
                    children: [
                      for (final m in goal.measurements)
                        ListTile(
                          title: Text('${m.value > 0 ? '+' : ''}${formatAmount(m.value)} ${d.unit}'.trim()),
                          subtitle: Text(
                            [
                              MaterialLocalizations.of(context).formatMediumDate(m.recordedOn),
                              if (m.note.isNotEmpty) m.note,
                            ].join(' · '),
                          ),
                          trailing: IconButton(
                            tooltip: 'Delete entry',
                            icon: Icon(Symbols.delete, size: 20, color: c.textTertiary),
                            onPressed: () => guarded(() => controller.deleteMeasurement(m.id)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.habit, required this.onRemove});

  final HabitSummary habit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return MwCard(
      padding: const EdgeInsets.all(MwSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit.title, style: context.text.labelLarge),
                    Text(habit.frequencyLabel, style: context.text.bodySmall?.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove habit',
                onPressed: onRemove,
                icon: Icon(Symbols.close, size: 18, color: c.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: MwSpace.sm),
          Semantics(
            label: '${habit.daysDone} of ${habit.weeklyTarget} this week',
            child: Row(
              children: [
                for (var i = 0; i < habit.weeklyTarget; i++)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(color: i < habit.daysDone ? c.action : c.sunken, shape: BoxShape.circle),
                  ),
                const Spacer(),
                Text(
                  '${habit.daysDone}/${habit.weeklyTarget} this week',
                  style: context.text.labelSmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: MwSpace.sm),
          if (habit.linkedSteps.isEmpty)
            Text(
              'Not linked yet — open a routine step and choose this habit under “Supports a habit”.',
              style: context.text.bodySmall?.copyWith(color: c.accentText),
            )
          else
            Wrap(
              spacing: MwSpace.sm,
              children: [
                for (final s in habit.linkedSteps)
                  ActionChip(
                    avatar: const Icon(Symbols.link, size: 16),
                    label: Text(s.title),
                    onPressed: () => context.push(Routes.routine(s.routineId)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
