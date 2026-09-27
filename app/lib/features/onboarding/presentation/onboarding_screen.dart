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
import '../../../core/widgets/mw_button.dart';
import '../../../core/widgets/mw_card.dart';
import '../../../core/widgets/mw_icons.dart';
import '../../../core/widgets/mw_sheet.dart';
import '../../../core/widgets/mw_toggle.dart';
import '../../../core/widgets/segmented_strand.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/application/session_controller.dart';
import '../../routines/domain/routine.dart';
import '../application/onboarding_controller.dart';

/// Four short steps: what matters, how much structure, when your day starts, and your first routine.
///
/// With [suggestOnly] the same flow serves existing users ("Suggest routines for me"): it closes instead of
/// signing out, skips the day-start question, and only adds the routines they keep.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({this.suggestOnly = false, super.key});

  final bool suggestOnly;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _steps = 4;
  int _step = 0;
  bool _busy = false;
  AppFailure? _failure;

  OnboardingController get _c => ref.read(onboardingControllerProvider.notifier);

  Future<void> _guard(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await action();
    } on AppFailure catch (f) {
      if (mounted) setState(() => _failure = f);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    if (_step == 2) {
      await _guard(_c.generate);
      if (_failure != null) return;
    }
    if (_step < _steps - 1) setState(() => _step++);
  }

  void _close() => context.canPop() ? context.pop() : context.go(Routes.routines);

  Future<void> _finish() async {
    if (!widget.suggestOnly) return _guard(_c.finish);
    var created = 0;
    await _guard(() async => created = await _c.addSuggested());
    if (!mounted || _failure != null) return;
    showMwSnack(context, 'Added $created ${created == 1 ? 'routine' : 'routines'}. Adjust anything in Routines.');
    context.go(Routes.today);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(onboardingControllerProvider);
    final c = context.mwColors;
    final canContinue = switch (_step) {
      0 => s.focus.isNotEmpty,
      3 => s.included.isNotEmpty,
      _ => true,
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(MwSpace.marginCompact, MwSpace.md, MwSpace.marginCompact, 0),
                  child: Row(
                    children: [
                      if (_step > 0)
                        IconButton(
                          tooltip: 'Back',
                          onPressed: _busy ? null : () => setState(() => _step--),
                          icon: const Icon(Symbols.arrow_back),
                        )
                      else if (widget.suggestOnly)
                        IconButton(tooltip: 'Close', onPressed: _busy ? null : _close, icon: const Icon(Symbols.close))
                      else
                        const BrandMark(size: 32),
                      const SizedBox(width: MwSpace.md),
                      Expanded(
                        child: SegmentedStrand(
                          semanticLabel: 'Step ${_step + 1} of $_steps',
                          segments: [StrandSegment(fraction: (_step + 1) / _steps, color: c.action)],
                        ),
                      ),
                      if (!widget.suggestOnly)
                        TextButton(
                          onPressed: _busy ? null : () => ref.read(sessionControllerProvider.notifier).signOut(),
                          child: const Text('Sign out'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(MwSpace.marginCompact),
                    children: [
                      AnimatedSwitcher(
                        duration: MwMotion.medium,
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: switch (_step) {
                            0 => _FocusStep(state: s, controller: _c),
                            1 => _StructureStep(state: s, controller: _c),
                            2 => _TimeStep(state: s, controller: _c, askDayStart: !widget.suggestOnly),
                            _ => _ReviewStep(state: s, controller: _c),
                          },
                        ),
                      ),
                      if (_failure != null) ...[
                        const SizedBox(height: MwSpace.md),
                        MwCard(
                          tone: MwCardTone.sunken,
                          padding: const EdgeInsets.all(MwSpace.md),
                          child: Text(_failure!.userMessage, style: context.text.bodySmall),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(MwSpace.marginCompact),
                  child: Column(
                    children: [
                      MwButton(
                        label: _step == _steps - 1
                            ? (widget.suggestOnly ? 'Add these routines' : 'Create my routines')
                            : 'Continue',
                        isLoading: _busy,
                        onPressed: canContinue ? (_step == _steps - 1 ? _finish : _next) : null,
                      ),
                      if (_step == _steps - 1 && !widget.suggestOnly)
                        MwButton(
                          label: "Skip — I'll build my own",
                          variant: MwButtonVariant.text,
                          onPressed: _busy ? null : () => _guard(() => _c.finish(withRoutines: false)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: context.text.headlineMedium),
      const SizedBox(height: MwSpace.sm),
      Text(subtitle, style: context.text.bodyMedium?.copyWith(color: context.mwColors.textSecondary)),
      const SizedBox(height: MwSpace.lg),
    ],
  );
}

class _FocusStep extends StatelessWidget {
  const _FocusStep({required this.state, required this.controller});

  final OnboardingState state;
  final OnboardingController controller;

  static const _icons = {
    'health': Symbols.directions_run,
    'mind': Symbols.self_improvement,
    'learning': Symbols.menu_book,
    'focus': Symbols.psychology,
    'relationships': Symbols.favorite,
    'rest': Symbols.bedtime,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Title('What would you like more of?', 'Pick a few. You can change everything later.'),
        for (final area in focusAreas)
          Padding(
            padding: const EdgeInsets.only(bottom: MwSpace.sm),
            child: _SelectCard(
              selected: state.focus.contains(area.id),
              onTap: () => controller.toggleFocus(area.id),
              icon: _icons[area.id]!,
              title: area.label,
              subtitle: area.hint,
              checkColor: c.action,
            ),
          ),
      ],
    );
  }
}

class _StructureStep extends StatelessWidget {
  const _StructureStep({required this.state, required this.controller});

  final OnboardingState state;
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    const options = [
      ('loose', Symbols.air, 'A few anchors', 'Light structure — just the essentials to hold the day.'),
      ('balanced', Symbols.balance, 'Balanced', 'Clear routines with room to breathe.'),
      ('structured', Symbols.view_timeline, 'Structured', 'Fuller routines with times to aim for.'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Title('How much structure suits you?', 'There is no right answer. Mwendo adapts either way.'),
        for (final (id, icon, title, subtitle) in options)
          Padding(
            padding: const EdgeInsets.only(bottom: MwSpace.sm),
            child: _SelectCard(
              selected: state.structure == id,
              onTap: () => controller.setStructure(id),
              icon: icon,
              title: title,
              subtitle: subtitle,
              checkColor: context.mwColors.action,
            ),
          ),
      ],
    );
  }
}

class _TimeStep extends StatelessWidget {
  const _TimeStep({required this.state, required this.controller, this.askDayStart = true});

  final OnboardingState state;
  final OnboardingController controller;
  final bool askDayStart;

  Future<int?> _pick(BuildContext context, int minutes) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Title('When does your day begin?', 'Your first routine will start shortly after you wake.'),
        MwCard(
          onTap: () async {
            final m = await _pick(context, state.wakeMinutes);
            if (m != null) controller.setWake(m);
          },
          child: Row(
            children: [
              Icon(Symbols.wb_sunny, color: c.accentText),
              const SizedBox(width: MwSpace.md),
              Expanded(child: Text('I usually wake at', style: context.text.titleMedium)),
              Text(formatClock(context, state.wakeMinutes), style: context.text.headlineSmall),
            ],
          ),
        ),
        if (askDayStart) ...[
          const SizedBox(height: MwSpace.md),
          MwCard(
            tone: MwCardTone.sunken,
            onTap: () async {
              final m = await _pick(context, state.dayStartMinutes);
              if (m != null) controller.setDayStart(m);
            },
            child: Row(
              children: [
                Icon(Symbols.bedtime, color: c.textSecondary),
                const SizedBox(width: MwSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('A new day starts at', style: context.text.titleMedium),
                      Text(
                        'Late nights before this still count as the day before.',
                        style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(formatClock(context, state.dayStartMinutes), style: context.text.titleLarge),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.state, required this.controller});

  final OnboardingState state;
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    final drafts = state.drafts;
    if (drafts == null) return const SizedBox(height: 240, child: LoadingView(message: 'Shaping your first routines'));
    final c = context.mwColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Title(
          'Here’s a gentle start',
          'Keep what feels right. Steps marked ★ are your essentials — they stay even on low days.',
        ),
        for (final (i, d) in drafts.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: MwSpace.md),
            child: MwCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.details.name, style: context.text.titleLarge),
                            Text(
                              [
                                formatDays(d.details.daysOfWeek),
                                if (d.details.startMinutes != null) formatClock(context, d.details.startMinutes!),
                                if (d.totalMinutes > 0) formatMinutes(d.totalMinutes),
                              ].join(' · '),
                              style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      MwToggle(
                        value: state.included.contains(i),
                        semanticLabel: 'Include ${d.details.name}',
                        onChanged: (_) => controller.toggleDraft(i),
                      ),
                    ],
                  ),
                  const SizedBox(height: MwSpace.sm),
                  for (final step in d.steps) _DraftStep(step: step),
                ],
              ),
            ),
          ),
        Text(
          'You can edit steps, times and essentials any time in Routines.',
          style: context.text.bodySmall?.copyWith(color: c.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DraftStep extends StatelessWidget {
  const _DraftStep({required this.step});

  final RoutineStep step;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final amount = switch (step.targetKind) {
      TargetKind.duration => formatMinutes(step.targetValue),
      TargetKind.count => '${formatAmount(step.targetValue)} ${step.unit}'.trim(),
      TargetKind.check => '',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(stepIcon(step.icon), size: 18, color: c.action),
          const SizedBox(width: MwSpace.sm),
          Expanded(child: Text(step.title, style: context.text.bodyMedium)),
          if (step.isEssential) Icon(Symbols.star, size: 16, fill: 1, color: c.accent),
          if (amount.isNotEmpty) ...[
            const SizedBox(width: MwSpace.sm),
            Text(amount, style: context.text.labelSmall?.copyWith(color: c.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.checkColor,
  });

  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color checkColor;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return Semantics(
      selected: selected,
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: MwCard(
        onTap: onTap,
        padding: const EdgeInsets.all(MwSpace.md),
        tone: selected ? MwCardTone.supportive : MwCardTone.elevated,
        child: Row(
          children: [
            Icon(icon, color: selected ? c.onSuccessTint : c.textSecondary),
            const SizedBox(width: MwSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleMedium),
                  Text(subtitle, style: context.text.bodySmall?.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: MwMotion.fast,
              opacity: selected ? 1 : 0,
              child: Icon(Symbols.check_circle, fill: 1, color: checkColor),
            ),
          ],
        ),
      ),
    );
  }
}
