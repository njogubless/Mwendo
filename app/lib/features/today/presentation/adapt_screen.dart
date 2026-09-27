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
import '../../../core/widgets/mw_chips.dart';
import '../../../core/widgets/mw_icons.dart';
import '../../../core/widgets/mw_sheet.dart';
import '../../../core/widgets/mw_toggle.dart';
import '../../../core/widgets/segmented_strand.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_pill.dart';
import '../../routines/domain/routine.dart';
import '../application/today_controller.dart';
import '../domain/day.dart';
import 'widgets/step_format.dart';

/// Fit a routine into the time available (Running Late / Time Budget), or switch to Minimum Day.
/// Nothing changes until the user approves.
class AdaptScreen extends ConsumerStatefulWidget {
  const AdaptScreen({required this.instanceId, super.key});

  final String instanceId;

  @override
  ConsumerState<AdaptScreen> createState() => _AdaptScreenState();
}

class _AdaptScreenState extends ConsumerState<AdaptScreen> {
  int? _budget;
  bool _minimum = false;
  bool _applying = false;

  PreviewArgs get _args => (instanceId: widget.instanceId, budget: _budget, minimum: _minimum);

  Future<void> _customBudget(AdaptationPreview p) async {
    var value = (_budget ?? p.recommended ?? 30).toDouble();
    final picked = await showMwSheet<int>(
      context,
      title: 'How much time do you have?',
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Text(formatMinutes(value), style: context.text.displayMedium)),
            Slider(
              value: value,
              min: 5,
              max: p.originalMinutes.toDouble().clamp(10, 240),
              divisions: 47,
              onChanged: (v) => setSheet(() => value = (v / 5).round() * 5),
            ),
            MwButton(label: 'Use ${formatMinutes(value)}', onPressed: () => Navigator.pop(context, value.round())),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _budget = picked);
  }

  Future<void> _apply(AdaptationPreview p) async {
    setState(() => _applying = true);
    final controller = ref.read(todayControllerProvider.notifier);
    final AppFailure? failure = p.isMinimum
        ? await controller.setMode(DayMode.minimum)
        : await controller.applyBudget(widget.instanceId, p.budgetMinutes!);
    if (!mounted) return;
    setState(() => _applying = false);
    if (failure != null) {
      showMwSnack(context, failure.userMessage);
    } else {
      showMwSnack(context, p.isMinimum ? 'Minimum Day is on. Start small.' : "Done. Let's make this easier.");
      _leave();
    }
  }

  /// Back to Today, even when this screen was opened directly (nothing to pop).
  void _leave() => context.canPop() ? context.pop() : context.go(Routes.today);

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(adaptationPreviewProvider(_args));
    return Scaffold(
      appBar: AppBar(title: const Text('Adjust your routine')),
      body: switch (preview) {
        AsyncData(:final value) => _body(context, value),
        AsyncError(:final error) => ErrorView(
          failure: error is AppFailure ? error : UnknownFailure(cause: error),
          onRetry: () => ref.invalidate(adaptationPreviewProvider(_args)),
        ),
        _ when preview.hasValue => _body(context, preview.value!),
        _ => const LoadingView(),
      },
    );
  }

  Widget _body(BuildContext context, AdaptationPreview p) {
    final c = context.mwColors;
    final selected = _minimum ? null : (_budget ?? p.budgetMinutes);
    final kept = p.items.where((i) => i.kept).length;
    final cta = p.isMinimum ? 'Start Minimum Day' : 'Use this ${formatMinutes(p.plannedMinutes)} plan';

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(MwSpace.marginCompact),
            children: [
              MwCard(
                tone: MwCardTone.warm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GENTLE RE-CALIBRATION',
                      style: context.text.labelSmall?.copyWith(color: c.accentText, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: MwSpace.xs),
                    Text(
                      p.shiftedMinutes >= 10
                          ? 'Your ${p.routineName.toLowerCase()} shifted by ${formatMinutes(p.shiftedMinutes)}.'
                          : 'Less time for ${p.routineName.toLowerCase()} today?',
                      style: context.text.headlineSmall,
                    ),
                    const SizedBox(height: MwSpace.sm),
                    Text(
                      p.finishBy != null && p.availableMinutes != null
                          ? 'Life happens. You have about ${formatMinutes(p.availableMinutes!)} until '
                                '${formatDateTimeClock(context, p.finishBy!)}. Mwendo will keep the essentials so you '
                                'arrive calm.'
                          : 'Life happens. Choose the time you have and Mwendo will keep what matters most.',
                      style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MwSpace.lg),
              if (p.originalMinutes == 0 && !_minimum) ...[
                MwCard(
                  tone: MwCardTone.sunken,
                  child: Text(
                    "What's left in ${p.routineName.toLowerCase()} isn't timed, so there's nothing to shorten. "
                    'If today feels heavy, Minimum Day below keeps just your essentials.',
                    style: context.text.bodyMedium,
                  ),
                ),
                const SizedBox(height: MwSpace.lg),
              ] else ...[
                Text('Time you have right now', style: context.text.titleMedium),
                const SizedBox(height: MwSpace.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final m in p.options)
                        Padding(
                          padding: const EdgeInsets.only(right: MwSpace.sm),
                          child: MwChoicePill(
                            label: formatMinutes(m),
                            selected: selected == m,
                            trailing: m == p.recommended
                                ? StatusPill(label: 'Fits', tone: selected == m ? PillTone.success : PillTone.neutral)
                                : null,
                            onTap: () => setState(() {
                              _minimum = false;
                              _budget = m;
                            }),
                          ),
                        ),
                      MwChoicePill(
                        label: 'Custom',
                        icon: Symbols.tune,
                        selected: selected != null && !p.options.contains(selected),
                        onTap: () => _customBudget(p),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MwSpace.lg),
                MwCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Symbols.auto_fix_high, color: c.action),
                          const SizedBox(width: MwSpace.sm),
                          Expanded(child: Text('Adapted plan', style: context.text.titleLarge)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(formatMinutes(p.plannedMinutes), style: context.text.headlineSmall),
                              Text(
                                'was ${formatMinutes(p.originalMinutes)}',
                                style: context.text.labelSmall?.copyWith(color: c.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (!p.fits) ...[
                        const SizedBox(height: MwSpace.sm),
                        Text(
                          'Your essentials need a little more than this. They stay — everything else is set aside.',
                          style: context.text.bodySmall?.copyWith(color: c.accentText),
                        ),
                      ],
                      const SizedBox(height: MwSpace.md),
                      for (final item in p.items) _AdaptedRow(item: item),
                      const SizedBox(height: MwSpace.sm),
                      Row(
                        children: [
                          Text('Steps kept', style: context.text.labelMedium),
                          const SizedBox(width: MwSpace.sm),
                          Expanded(
                            child: Text(
                              '$kept of ${p.items.length}'
                              '${p.essentialsTotal > 0 ? ' · ${p.essentialsKept}/${p.essentialsTotal} essentials' : ''}',
                              style: context.text.labelMedium?.copyWith(color: c.action),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: MwSpace.sm),
                      SegmentedStrand(
                        semanticLabel: '$kept of ${p.items.length} steps kept',
                        segments: [
                          StrandSegment(fraction: p.items.isEmpty ? 0 : kept / p.items.length, color: c.action),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: MwSpace.lg),
              MwCard(
                tone: MwCardTone.sunken,
                child: Row(
                  children: [
                    Icon(Symbols.energy_savings_leaf, color: c.action),
                    const SizedBox(width: MwSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Minimum Day instead', style: context.text.titleMedium),
                          Text(
                            'Drained or low on energy? Keep only your essentials for the whole day. Zero guilt.',
                            style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    MwToggle(
                      value: _minimum,
                      semanticLabel: 'Minimum Day',
                      onChanged: (v) => setState(() => _minimum = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MwSpace.lg),
              MwButton(
                label: cta,
                icon: Symbols.play_arrow,
                isLoading: _applying,
                onPressed: p.isMinimum || p.originalMinutes > 0 ? () => _apply(p) : null,
              ),
              const SizedBox(height: MwSpace.sm),
              MwButton(label: 'Keep my full routine', variant: MwButtonVariant.text, onPressed: _leave),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdaptedRow extends StatelessWidget {
  const _AdaptedRow({required this.item});

  final AdaptationItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final changed = item.kept && item.plannedValue != item.targetValue;
    final timed = item.targetKind == TargetKind.duration;
    return Opacity(
      opacity: item.kept ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: MwSpace.sm),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.surfaceWarm, borderRadius: BorderRadius.circular(MwRadii.lg)),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: item.kept ? c.successTint : c.sunken, shape: BoxShape.circle),
              child: Icon(stepIcon(item.icon), size: 18, color: item.kept ? c.onSuccessTint : c.textTertiary),
            ),
            const SizedBox(width: MwSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(item.title, style: context.text.labelLarge, overflow: TextOverflow.ellipsis),
                      ),
                      if (item.isEssential) ...[
                        const SizedBox(width: MwSpace.xs),
                        const StatusPill(label: 'Essential', tone: PillTone.accent),
                      ],
                    ],
                  ),
                  Text(
                    item.kept ? (changed ? 'Shortened, still counts' : 'Unchanged') : 'Set aside for today',
                    style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            if (timed || item.targetKind == TargetKind.count)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.kept ? amountLabel(item.targetKind, item.plannedValue, item.unit) : '—',
                    style: context.text.labelLarge?.copyWith(color: changed ? c.accentText : c.textPrimary),
                  ),
                  if (changed || !item.kept)
                    Text(
                      amountLabel(item.targetKind, item.targetValue, item.unit),
                      style: context.text.labelSmall?.copyWith(
                        color: c.textTertiary,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
