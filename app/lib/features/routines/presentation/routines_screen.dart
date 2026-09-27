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
import '../../../core/widgets/mw_chips.dart';
import '../../../core/widgets/mw_icons.dart';
import '../../../core/widgets/mw_page.dart';
import '../../../core/widgets/mw_sheet.dart';
import '../../../core/widgets/mw_toggle.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_pill.dart';
import '../application/routines_controller.dart';
import '../domain/routine.dart';
import 'widgets/routine_details_form.dart';
import 'widgets/start_options_card.dart';

class RoutinesScreen extends ConsumerStatefulWidget {
  const RoutinesScreen({super.key});

  @override
  ConsumerState<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends ConsumerState<RoutinesScreen> {
  RoutineCategory? _filter;

  Future<void> _create() => showRoutineDetailsSheet(
    context,
    onSave: (details) async {
      final routine = await ref.read(routinesControllerProvider.notifier).create(details);
      if (mounted) {
        showMwSnack(context, 'Created. Now add your first step.');
        unawaited(context.push(Routes.routine(routine.id)));
      }
    },
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routinesControllerProvider);
    final header = [
      const MwPageHeader(leading: BrandLockup(title: 'Routines')),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My routines', style: context.text.headlineMedium),
          Text(
            'Shaped around your life, not a rigid checklist.',
            style: context.text.bodyMedium?.copyWith(color: context.mwColors.textSecondary),
          ),
        ],
      ),
    ];

    return RefreshIndicator(
      onRefresh: ref.read(routinesControllerProvider.notifier).refresh,
      child: switch (state) {
        AsyncData(:final value) || AsyncLoading(:final value?) || AsyncError(:final value?) => _list(header, value),
        AsyncError(:final error) => MwPage(
          children: [
            ...header,
            MwCard(
              child: ErrorView(
                failure: error is AppFailure ? error : UnknownFailure(cause: error),
                onRetry: () => ref.invalidate(routinesControllerProvider),
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

  Widget _list(List<Widget> header, List<Routine> routines) {
    if (routines.isEmpty) {
      return MwPage(
        children: [
          ...header,
          const GuideCard(tipId: 'routines', title: Guides.routinesTitle, steps: Guides.routines, alwaysShow: true),
          StartOptionsCard(onBuildOwn: _create),
        ],
      );
    }
    final categories = {for (final r in routines) r.details.category}.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final shown = _filter == null ? routines : routines.where((r) => r.details.category == _filter).toList();
    final rated = routines.where((r) => r.stats.consistency != null).toList();
    final avg = rated.isEmpty ? null : rated.fold<double>(0, (s, r) => s + r.stats.consistency!) / rated.length;

    return MwPage(
      children: [
        ...header,
        _SummaryCard(active: routines.where((r) => r.isActive).length, consistency: avg),
        if (GuideCard.isVisible(ref, 'routines'))
          const GuideCard(tipId: 'routines', title: Guides.routinesTitle, steps: Guides.routines),
        if (categories.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: MwSpace.sm),
                  child: MwChoicePill(
                    label: 'All (${routines.length})',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                ),
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: MwSpace.sm),
                    child: MwChoicePill(
                      label: c.label,
                      selected: _filter == c,
                      onTap: () => setState(() => _filter = c),
                    ),
                  ),
              ],
            ),
          ),
        for (final r in shown) _RoutineCard(routine: r),
        MwButton(label: 'Create routine', icon: Symbols.add, variant: MwButtonVariant.accent, onPressed: _create),
        MwButton(
          label: 'Suggest routines for me',
          icon: Symbols.auto_awesome,
          variant: MwButtonVariant.text,
          onPressed: () => context.push(Routes.suggestRoutines),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.active, this.consistency});

  final int active;
  final double? consistency;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return MwCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LAST TWO WEEKS', style: context.text.labelSmall?.copyWith(color: c.action)),
                const SizedBox(height: MwSpace.xs),
                Text(
                  consistency == null ? 'Building your rhythm' : '${percent(consistency!)} followed through',
                  style: context.text.titleLarge,
                ),
                Text(
                  '$active active ${active == 1 ? 'routine' : 'routines'}',
                  style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Symbols.waves, color: c.accent, size: 36),
        ],
      ),
    );
  }
}

class _RoutineCard extends ConsumerWidget {
  const _RoutineCard({required this.routine});

  final Routine routine;

  Color _accent(BuildContext context) {
    final c = context.mwColors;
    return switch (routine.details.category) {
      RoutineCategory.morning => c.accent,
      RoutineCategory.work => c.action,
      RoutineCategory.evening => c.gentle,
      RoutineCategory.rest => c.sage,
      RoutineCategory.other => c.textTertiary,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mwColors;
    final d = routine.details;
    final s = routine.stats;
    final schedule = [
      formatDays(d.daysOfWeek),
      if (d.startMinutes != null) formatClock(context, d.startMinutes!),
    ].join(' · ');

    Future<void> guarded(Future<void> Function() action, String success) async {
      try {
        await action();
        if (context.mounted) showMwSnack(context, success);
      } on AppFailure catch (f) {
        if (context.mounted) showMwSnack(context, f.userMessage);
      }
    }

    return MwCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push(Routes.routine(routine.id)),
      semanticLabel: '${routine.name}, $schedule',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MwRadii.card),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: routine.isActive ? _accent(context) : c.border),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(MwSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: MwSpace.sm,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(routine.name, style: context.text.titleLarge),
                                StatusPill(
                                  label: routine.isActive ? d.category.label : 'Paused',
                                  tone: routine.isActive ? PillTone.success : PillTone.neutral,
                                ),
                              ],
                            ),
                          ),
                          MwToggle(
                            value: routine.isActive,
                            semanticLabel: 'Active',
                            onChanged: (v) => guarded(
                              () => ref.read(routinesControllerProvider.notifier).setActive(routine, v),
                              v ? 'Routine is back on your schedule.' : 'Paused. Your history is kept.',
                            ),
                          ),
                        ],
                      ),
                      Text(schedule, style: context.text.bodySmall?.copyWith(color: c.textSecondary)),
                      const SizedBox(height: MwSpace.md),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              icon: Symbols.schedule,
                              label: 'Length',
                              value: s.steps == 0
                                  ? 'No steps yet'
                                  : '${s.steps} steps · ${formatMinutes(s.totalMinutes)}',
                            ),
                          ),
                          const SizedBox(width: MwSpace.sm),
                          Expanded(
                            child: _StatTile(
                              icon: Symbols.energy_savings_leaf,
                              label: 'Minimum Day',
                              value: s.essentialSteps == 0
                                  ? 'Mark essentials ★'
                                  : '${s.essentialSteps} ★ · ${formatMinutes(s.minimumMinutes)}',
                            ),
                          ),
                        ],
                      ),
                      if (routine.steps.isNotEmpty) ...[
                        const SizedBox(height: MwSpace.md),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (final (i, step) in routine.steps.take(6).indexed) ...[
                              if (i > 0) Icon(Symbols.arrow_forward, size: 12, color: c.textTertiary),
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: step.isEssential ? c.accentTint : c.sunken,
                                  borderRadius: BorderRadius.circular(MwRadii.sm),
                                ),
                                child: Icon(stepIcon(step.icon), size: 16, color: c.textSecondary),
                              ),
                            ],
                            if (routine.steps.length > 6)
                              Text('+${routine.steps.length - 6}', style: context.text.labelSmall),
                          ],
                        ),
                      ],
                      const SizedBox(height: MwSpace.md),
                      Row(
                        children: [
                          if (s.consistency != null)
                            Expanded(
                              child: Text(
                                '${percent(s.consistency!)} followed through lately',
                                style: context.text.labelSmall?.copyWith(color: c.textSecondary),
                              ),
                            )
                          else
                            const Spacer(),
                          if (routine.steps.isNotEmpty)
                            MwButton(
                              label: 'Start now',
                              icon: Symbols.play_arrow,
                              variant: MwButtonVariant.secondary,
                              size: MwButtonSize.compact,
                              expand: false,
                              onPressed: () => guarded(
                                () => ref.read(routinesControllerProvider.notifier).startNow(routine.id),
                                '${routine.name} added to today. Find it on Today.',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(MwRadii.md)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textSecondary),
          const SizedBox(width: MwSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.labelSmall?.copyWith(color: c.textSecondary)),
                Text(value, style: context.text.labelMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
