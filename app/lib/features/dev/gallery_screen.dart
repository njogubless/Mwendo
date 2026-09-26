import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/mw_tokens.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/mw_button.dart';
import '../../core/widgets/mw_card.dart';
import '../../core/widgets/mw_page.dart';
import '../../core/widgets/mw_toggle.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/segmented_strand.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_pill.dart';

/// Developer-only showcase of the design system (route `/dev/gallery`).
/// Used for visual review against the Stitch reference; not shipped in release.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  bool _dark = false;
  bool _toggle = true;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildTheme(_dark ? Brightness.dark : Brightness.light),
      child: Builder(
        builder: (context) {
          final c = context.mwColors;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Design system'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: MwSpace.sm),
                  child: MwToggle(
                    value: _dark,
                    onChanged: (v) => setState(() => _dark = v),
                    semanticLabel: 'Dark mode',
                  ),
                ),
              ],
            ),
            body: MwPage(
              children: [
                const _Section('Brand'),
                const BrandLockup(title: 'Today'),
                const _Section('Colour'),
                Wrap(
                  spacing: MwSpace.sm,
                  runSpacing: MwSpace.sm,
                  children: [
                    for (final (name, color) in [
                      ('canvas', c.canvas),
                      ('sunken', c.sunken),
                      ('surface', c.surface),
                      ('action', c.action),
                      ('accent', c.accent),
                      ('accentText', c.accentText),
                      ('gentle', c.gentle),
                      ('sage', c.sage),
                      ('sand', c.sand),
                    ])
                      _Swatch(name: name, color: color),
                  ],
                ),
                const _Section('Type'),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Display 34', style: context.text.displayMedium),
                    Text('Headline 26', style: context.text.headlineMedium),
                    Text('Headline 22', style: context.text.headlineSmall),
                    Text('Title 18', style: context.text.titleLarge),
                    Text('Body 17 — Start small. Keep moving.', style: context.text.bodyLarge),
                    Text('Body 15 — Today is a new opportunity.', style: context.text.bodyMedium),
                    Text('Body 13 — That’s enough for today.', style: context.text.bodySmall),
                    Text('LABEL 11 · MICRO', style: context.text.labelSmall),
                  ],
                ),
                const _Section('Buttons'),
                MwButton(label: 'Mark done', icon: Symbols.check, onPressed: () {}),
                MwButton(label: 'Create routine', icon: Symbols.add, variant: MwButtonVariant.accent, onPressed: () {}),
                Row(
                  children: [
                    Expanded(
                      child: MwButton(
                        label: 'Pause',
                        icon: Symbols.pause,
                        size: MwButtonSize.compact,
                        variant: MwButtonVariant.secondary,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: MwSpace.sm),
                    Expanded(
                      child: MwButton(
                        label: 'Skip',
                        icon: Symbols.forward,
                        size: MwButtonSize.compact,
                        variant: MwButtonVariant.secondary,
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
                MwButton(
                  label: 'Tap to load',
                  isLoading: _loading,
                  onPressed: () async {
                    setState(() => _loading = true);
                    await Future<void>.delayed(const Duration(seconds: 1));
                    if (mounted) setState(() => _loading = false);
                  },
                ),
                const MwButton(label: 'Disabled', onPressed: null),
                MwButton(label: 'Restore original schedule', variant: MwButtonVariant.text, onPressed: () {}),
                const _Section('Pills & toggle'),
                Wrap(
                  spacing: MwSpace.sm,
                  runSpacing: MwSpace.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const StatusPill(label: 'NOW', tone: PillTone.success, icon: Symbols.play_circle),
                    const StatusPill(label: 'Essential', tone: PillTone.accent, icon: Symbols.star),
                    const StatusPill(label: 'Priority', tone: PillTone.gentle),
                    const StatusPill(label: '8 min left'),
                    MwToggle(value: _toggle, onChanged: (v) => setState(() => _toggle = v), semanticLabel: 'Active'),
                  ],
                ),
                const _Section('Composition — Today progress'),
                MwCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Today's progress", style: context.text.labelMedium?.copyWith(color: c.action)),
                                const SizedBox(height: MwSpace.xs),
                                Text('68% of your day', style: context.text.titleLarge),
                                Text(
                                  '4 of 6 steps done',
                                  style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          ProgressRing(
                            value: 0.68,
                            semanticLabel: "Today's progress",
                            center: Icon(Symbols.vital_signs, color: c.accentText, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: MwSpace.md),
                      SegmentedStrand(
                        semanticLabel: '4 done, 1 in progress, 1 to go',
                        segments: [
                          StrandSegment(fraction: 0.45, color: c.action),
                          StrandSegment(fraction: 0.23, color: c.accent),
                        ],
                      ),
                    ],
                  ),
                ),
                MwCard(
                  tone: MwCardTone.supportive,
                  padding: const EdgeInsets.all(MwSpace.md),
                  child: Row(
                    children: [
                      Icon(Symbols.energy_savings_leaf, color: c.onSuccessTint),
                      const SizedBox(width: MwSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Low on energy?', style: context.text.labelLarge?.copyWith(color: c.onSuccessTint)),
                            Text(
                              'Switch to a Minimum Day — 13 minutes of essentials.',
                              style: context.text.bodySmall?.copyWith(color: c.onSuccessTint),
                            ),
                          ],
                        ),
                      ),
                      MwButton(label: 'Switch', expand: false, size: MwButtonSize.compact, onPressed: () {}),
                    ],
                  ),
                ),
                const _Section('States'),
                const MwCard(
                  child: SizedBox(height: 120, child: LoadingView(message: 'Getting your day ready')),
                ),
                const MwCard(
                  child: EmptyView(
                    title: "That's enough for today",
                    message: 'You showed up. Rest well — tomorrow is a new opportunity.',
                  ),
                ),
                const MwCard(child: OfflineBanner()),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: MwSpace.md),
    child: SectionLabel(title),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(MwRadii.md),
            border: Border.all(color: context.mwColors.border),
          ),
        ),
        const SizedBox(height: MwSpace.xs),
        Text(name, style: context.text.labelSmall),
      ],
    );
  }
}
