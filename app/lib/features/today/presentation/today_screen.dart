import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mw_tokens.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/mw_card.dart';
import '../../../core/widgets/mw_page.dart';
import '../../../core/widgets/mw_sheet.dart';
import '../../../core/widgets/section_label.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/application/session_controller.dart';
import '../../reminders/presentation/reminders_prompt.dart';
import '../../routines/application/routines_controller.dart';
import '../../routines/presentation/widgets/routine_details_form.dart';
import '../../routines/presentation/widgets/start_options_card.dart';
import '../application/today_controller.dart';
import '../domain/day.dart';
import 'widgets/banners.dart';
import 'widgets/day_progress_card.dart';
import 'widgets/focus_card.dart';
import 'widgets/step_sheets.dart';
import 'widgets/timeline.dart';

/// Today — answers "What should I focus on now?".
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  static String greetingFor(DateTime now) => switch (now.hour) {
    < 12 => 'Good morning',
    < 17 => 'Good afternoon',
    _ => 'Good evening',
  };

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _modeBusy = false;

  @override
  void initState() {
    super.initState();
    // Coming back to the app may mean a new day, or progress logged elsewhere.
    _lifecycle = AppLifecycleListener(onResume: () => ref.read(todayControllerProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  TodayController get _controller => ref.read(todayControllerProvider.notifier);

  void _report(AppFailure? failure) {
    if (failure != null && mounted) showMwSnack(context, failure.userMessage);
  }

  Future<void> _done(DayStep step) async {
    _report(await _controller.complete(step));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${step.title} — done. Keep moving.'),
          action: SnackBarAction(label: 'Add note', onPressed: () => _reflect(step)),
        ),
      );
  }

  Future<void> _partial(DayStep step) async {
    final amount = await showPartialSheet(context, step);
    if (amount != null) _report(await _controller.complete(step, amount: amount));
  }

  Future<void> _skip(DayStep step) async {
    final reason = await showSkipSheet(context, step);
    if (reason != null) _report(await _controller.skip(step, reason: reason));
  }

  Future<void> _reflect(DayStep step) async {
    final note = await showReflectionSheet(context, step);
    if (note != null && note.isNotEmpty) _report(await _controller.reflect(step, note));
  }

  Future<void> _setMode(DayMode mode) async {
    setState(() => _modeBusy = true);
    _report(await _controller.setMode(mode));
    if (mounted) setState(() => _modeBusy = false);
  }

  /// Create a routine from Today, then open it to add steps.
  Future<void> _buildOwnRoutine() => showRoutineDetailsSheet(
    context,
    onSave: (details) async {
      final routine = await ref.read(routinesControllerProvider.notifier).create(details);
      if (mounted) unawaited(context.push(Routes.routine(routine.id)));
    },
  );

  Future<void> _onTimelineTap(DayStep step) async {
    final action = await showStepActions(context, step);
    if (action == null) return;
    switch (action) {
      case StepAction.start:
        _report(await _controller.start(step));
      case StepAction.pause:
        _report(await _controller.pause(step));
      case StepAction.done:
        await _done(step);
      case StepAction.partial:
        await _partial(step);
      case StepAction.skip:
        await _skip(step);
      case StepAction.undo:
        _report(await _controller.undo(step));
      case StepAction.reflect:
        await _reflect(step);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todayControllerProvider);
    final session = ref.watch(sessionControllerProvider);
    final name = session is SignedIn ? session.user.greetingName : null;
    final now = DateTime.now();

    final header = [
      const MwPageHeader(leading: BrandLockup(title: 'Today')),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MaterialLocalizations.of(context).formatFullDate(now).toUpperCase(),
            style: context.text.labelSmall?.copyWith(color: context.mwColors.action, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: MwSpace.xs),
          Text(
            name == null ? TodayScreen.greetingFor(now) : '${TodayScreen.greetingFor(now)}, $name',
            style: context.text.headlineMedium,
          ),
        ],
      ),
    ];

    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: switch (state) {
        AsyncData(:final value) => _content(context, header, value),
        AsyncError(:final error) when !state.hasValue => MwPage(
          children: [
            ...header,
            MwCard(
              child: ErrorView(
                failure: error is AppFailure ? error : UnknownFailure(cause: error),
                onRetry: () => ref.invalidate(todayControllerProvider),
              ),
            ),
          ],
        ),
        _ when state.hasValue => _content(context, header, state.value!),
        _ => MwPage(
          children: [
            ...header,
            const SizedBox(height: 200, child: LoadingView(message: 'Getting your day ready')),
          ],
        ),
      },
    );
  }

  Widget _content(BuildContext context, List<Widget> header, Day day) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= MwBreakpoints.medium + 120;

    if (day.routines.isEmpty) {
      final routines = ref.watch(routinesControllerProvider).value;
      return MwPage(
        children: [
          ...header,
          if (routines != null && routines.isEmpty)
            StartOptionsCard(title: 'Let’s shape your day', onBuildOwn: _buildOwnRoutine)
          else
            MwCard(
              padding: const EdgeInsets.symmetric(vertical: MwSpace.xl),
              child: EmptyView(
                icon: Symbols.wb_sunny,
                title: 'A quiet day',
                message: 'None of your routines are scheduled today. Rest — or start one now if you’d like.',
                actionLabel: 'Start a routine',
                onAction: () => context.go(Routes.routines),
              ),
            ),
        ],
      );
    }

    final focus = day.focus;
    final focusRoutine = focus == null ? null : day.routineOf(focus);
    final timingRoutine = day.routines.where((r) => r.id == day.timingInstanceId).firstOrNull;
    final adjusted = day.routines.where((r) => r.adjustment?.kind == 'time_budget').toList();

    final primary = <Widget>[
      DayProgressCard(day: day),
      if (RemindersPrompt.isVisible(ref)) const RemindersPrompt(),
      if (day.recoverySuggested)
        RecoveryBanner(
          daysAway: day.daysAway ?? 2,
          onAccept: () => _setMode(DayMode.recovery),
          onDismiss: () async => _report(await _controller.dismissRecovery()),
        )
      else if (day.mode != DayMode.normal)
        ModeBanner(recovery: day.mode == DayMode.recovery, busy: _modeBusy, onRestore: () => _setMode(DayMode.normal))
      else if (focus != null)
        MinimumDayBanner(minutes: day.minimumDayMinutes, busy: _modeBusy, onActivate: () => _setMode(DayMode.minimum)),
      if (focus != null)
        FocusCard(
          step: focus,
          routineName: focusRoutine?.name ?? '',
          fetchedAt: day.fetchedAt,
          shiftedMinutes: day.shiftedMinutes,
          onStart: () async => _report(await _controller.start(focus)),
          onPause: () async => _report(await _controller.pause(focus)),
          onDone: () => _done(focus),
          onPartial: () => _partial(focus),
          onSkip: () => _skip(focus),
        )
      else
        MwCard(
          padding: const EdgeInsets.symmetric(vertical: MwSpace.lg),
          child: EmptyView(
            icon: Symbols.spa,
            title: "That's enough for today",
            message: day.progress.done > 0
                ? 'You showed up. Rest well — tomorrow is a new opportunity.'
                : 'Today is done. Tomorrow is a new opportunity.',
          ),
        ),
      if (day.timing == TimingStatus.shifted &&
          timingRoutine != null &&
          timingRoutine.adjustment == null &&
          day.mode == DayMode.normal)
        ShiftedBanner(
          routineName: timingRoutine.name,
          minutes: day.shiftedMinutes,
          onAdjust: () => context.push(Routes.adapt(timingRoutine.id)),
        ),
      for (final r in adjusted)
        AdjustedBanner(
          routineName: r.name,
          minutes: r.adjustment!.budgetMinutes ?? 0,
          onRestore: () async => _report(await _controller.revert(r.adjustment!.id)),
        ),
    ];

    final sequence = <Widget>[
      SectionLabel(
        "Today's sequence",
        trailing: Text(
          '${day.progress.total + day.progress.cancelled} steps',
          style: context.text.labelSmall?.copyWith(color: context.mwColors.textSecondary),
        ),
      ),
      DayTimeline(day: day, onTap: _onTimelineTap),
      if (_AdjustLink.isVisible(day)) _AdjustLink(day: day),
    ];

    if (!wide) {
      return MwPage(children: [...header, ...primary, ...sequence, const _PrincipleCard()]);
    }
    return MwPage(
      children: [
        ...header,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (final w in primary)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MwSpace.lg),
                      child: w,
                    ),
                ],
              ),
            ),
            const SizedBox(width: MwSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final w in sequence)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MwSpace.md),
                      child: w,
                    ),
                  const _PrincipleCard(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Quiet entry point to fit a routine into less time, even when not running late.
class _AdjustLink extends StatelessWidget {
  const _AdjustLink({required this.day});

  final Day day;

  static bool isVisible(Day day) => day.mode == DayMode.normal && day.routines.any((r) => r.canCompress);

  @override
  Widget build(BuildContext context) {
    final open = day.routines.where((r) => r.canCompress).toList();
    if (!isVisible(day)) return const SizedBox.shrink();
    return MwCard(
      tone: MwCardTone.sunken,
      padding: const EdgeInsets.all(MwSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.auto_fix_high, size: 18, color: context.mwColors.accentText),
              const SizedBox(width: MwSpace.sm),
              Text('Less time today?', style: context.text.labelLarge),
            ],
          ),
          const SizedBox(height: MwSpace.xs),
          Text(
            'Mwendo can compress a routine into the time you have — essentials first.',
            style: context.text.bodySmall?.copyWith(color: context.mwColors.textSecondary),
          ),
          const SizedBox(height: MwSpace.sm),
          Wrap(
            spacing: MwSpace.sm,
            runSpacing: MwSpace.sm,
            children: [
              for (final r in open)
                ActionChip(
                  avatar: const Icon(Symbols.compress, size: 16),
                  label: Text('Adjust ${r.name}'),
                  onPressed: () => context.push(Routes.adapt(r.id)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrincipleCard extends StatelessWidget {
  const _PrincipleCard();

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return MwCard(
      tone: MwCardTone.sunken,
      padding: const EdgeInsets.all(MwSpace.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.accentTint, shape: BoxShape.circle),
            child: Icon(Symbols.filter_vintage, color: c.accentText, size: 20),
          ),
          const SizedBox(width: MwSpace.md),
          Expanded(
            child: Text(
              '“Rhythm is not a cage, but a river. Flow with the bends of your day.”',
              style: context.text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
