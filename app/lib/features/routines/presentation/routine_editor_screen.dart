import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mw_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/mw_button.dart';
import '../../../core/widgets/mw_card.dart';
import '../../../core/widgets/mw_icons.dart';
import '../../../core/widgets/mw_sheet.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_pill.dart';
import '../application/routines_controller.dart';
import '../domain/routine.dart';
import 'widgets/routine_details_form.dart';
import 'widgets/step_editor_sheet.dart';

/// Edit one routine: details, steps (reorder by dragging), essentials ★. Changes save immediately.
class RoutineEditorScreen extends ConsumerWidget {
  const RoutineEditorScreen({required this.routineId, super.key});

  final String routineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = routineControllerProvider(routineId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    Future<void> guarded(Future<void> Function() action) async {
      try {
        await action();
      } on AppFailure catch (f) {
        if (context.mounted) showMwSnack(context, f.userMessage);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(state.value?.name ?? 'Routine'),
        actions: [
          if (state.value != null)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) async {
                if (value == 'details') {
                  await showRoutineDetailsSheet(
                    context,
                    initial: state.value!.details,
                    onSave: controller.updateDetails,
                  );
                } else if (value == 'archive') {
                  final ok = await confirmMw(
                    context,
                    title: 'Archive this routine?',
                    message: "It leaves your schedule. Everything you've done stays in your history.",
                    confirmLabel: 'Archive',
                  );
                  if (ok) {
                    await guarded(() => ref.read(routinesControllerProvider.notifier).archive(routineId));
                    if (context.mounted) context.pop();
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'details', child: Text('Edit details')),
                PopupMenuItem(value: 'archive', child: Text('Archive')),
              ],
            ),
        ],
      ),
      body: switch (state) {
        AsyncData(:final value) || AsyncLoading(:final value?) => _Body(routine: value, guarded: guarded),
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
  const _Body({required this.routine, required this.guarded});

  final Routine routine;
  final Future<void> Function(Future<void> Function()) guarded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mwColors;
    final controller = ref.read(routineControllerProvider(routine.id).notifier);
    final d = routine.details;
    final s = routine.stats;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(MwSpace.marginCompact, MwSpace.md, MwSpace.marginCompact, 0),
                sliver: SliverList.list(
                  children: [
                    MwCard(
                      onTap: () => showRoutineDetailsSheet(context, initial: d, onSave: controller.updateDetails),
                      semanticLabel: 'Edit details',
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.category.label.toUpperCase(),
                                  style: context.text.labelSmall?.copyWith(color: c.action),
                                ),
                                const SizedBox(height: MwSpace.xs),
                                Text(
                                  [
                                    formatDays(d.daysOfWeek),
                                    if (d.startMinutes != null) 'from ${formatClock(context, d.startMinutes!)}',
                                    if (d.finishByMinutes != null)
                                      'done by ${formatClock(context, d.finishByMinutes!)}',
                                  ].join(' · '),
                                  style: context.text.bodyMedium,
                                ),
                                if (!routine.isActive)
                                  Text('Paused', style: context.text.bodySmall?.copyWith(color: c.textSecondary)),
                              ],
                            ),
                          ),
                          Icon(Symbols.edit, color: c.textTertiary, size: 20),
                        ],
                      ),
                    ),
                    const SizedBox(height: MwSpace.lg),
                    Row(
                      children: [
                        Expanded(child: Text('Steps', style: context.text.titleLarge)),
                        if (s.steps > 0) StatusPill(label: '${formatMinutes(s.totalMinutes)} total'),
                      ],
                    ),
                    const SizedBox(height: MwSpace.sm),
                    MwCard(
                      tone: MwCardTone.sunken,
                      padding: const EdgeInsets.all(MwSpace.md),
                      child: Row(
                        children: [
                          Icon(Symbols.star, color: c.accentText, size: 18),
                          const SizedBox(width: MwSpace.sm),
                          Expanded(
                            child: Text(
                              s.essentialSteps == 0
                                  ? 'Tap ★ on the steps that matter most. They stay on Minimum Days.'
                                  : '${s.essentialSteps} essential ${s.essentialSteps == 1 ? 'step' : 'steps'} · '
                                        'Minimum Day takes ${formatMinutes(s.minimumMinutes)}.',
                              style: context.text.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: MwSpace.sm),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: MwSpace.marginCompact),
                sliver: SliverReorderableList(
                  itemCount: routine.steps.length,
                  onReorder: (from, to) => guarded(() => controller.reorder(from, to)),
                  itemBuilder: (context, i) {
                    final step = routine.steps[i];
                    return _StepTile(
                      key: ValueKey(step.id),
                      index: i,
                      step: step,
                      onTap: () => showStepEditor(context, initial: step, onSave: controller.saveStep),
                      onToggleEssential: () => guarded(() => controller.toggleEssential(step)),
                      onDelete: () async {
                        final ok = await confirmMw(
                          context,
                          title: 'Remove "${step.title}"?',
                          message: 'It leaves this routine from today on. Past days keep their record.',
                          confirmLabel: 'Remove',
                        );
                        if (ok) await guarded(() => controller.removeStep(step.id!));
                      },
                    );
                  },
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  MwSpace.marginCompact,
                  MwSpace.sm,
                  MwSpace.marginCompact,
                  MwSpace.xl,
                ),
                sliver: SliverList.list(
                  children: [
                    if (routine.steps.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: MwSpace.lg),
                        child: Text(
                          'No steps yet. Start with something small — it can grow later.',
                          style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    MwButton(
                      label: 'Add a step',
                      icon: Symbols.add_circle,
                      variant: MwButtonVariant.secondary,
                      onPressed: () => showStepEditor(context, onSave: controller.saveStep),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.step,
    required this.onTap,
    required this.onToggleEssential,
    required this.onDelete,
    super.key,
  });

  final int index;
  final RoutineStep step;
  final VoidCallback onTap;
  final VoidCallback onToggleEssential;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final amount = switch (step.targetKind) {
      TargetKind.duration => formatMinutes(step.targetValue),
      TargetKind.count => '${formatAmount(step.targetValue)} ${step.unit}'.trim(),
      TargetKind.check => '',
    };
    final minimum = step.minimumValue == null ? '' : ' · at least ${formatAmount(step.minimumValue!)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: MwSpace.sm),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(MwRadii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(MwRadii.lg),
          onTap: onTap,
          onLongPress: onDelete,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MwRadii.lg),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Semantics(
                    label: 'Drag to reorder',
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(Symbols.drag_indicator, color: c.textTertiary),
                    ),
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(MwRadii.md)),
                  child: Icon(stepIcon(step.icon), size: 18, color: c.action),
                ),
                const SizedBox(width: MwSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.title, style: context.text.labelLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(
                        [
                          if (amount.isNotEmpty) '$amount$minimum',
                          if (step.priority != StepPriority.standard) step.priority.label,
                        ].join(' · '),
                        style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: step.isEssential ? 'Essential — tap to unmark' : 'Mark as essential',
                  onPressed: onToggleEssential,
                  icon: Icon(
                    step.isEssential ? Symbols.star : Symbols.star,
                    fill: step.isEssential ? 1 : 0,
                    color: step.isEssential ? c.accent : c.textTertiary,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove step',
                  onPressed: onDelete,
                  icon: Icon(Symbols.delete, size: 20, color: c.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
