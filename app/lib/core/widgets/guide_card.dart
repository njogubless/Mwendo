import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../storage/tips_store.dart';
import '../theme/app_theme.dart';
import '../theme/mw_tokens.dart';
import 'mw_card.dart';

/// A short, numbered "how this works" card for first-time users.
///
/// Always shown when [alwaysShow] (e.g. the page is empty); otherwise shown until dismissed with "Got it".
class GuideCard extends ConsumerWidget {
  const GuideCard({required this.tipId, required this.title, required this.steps, this.alwaysShow = false, super.key});

  final String tipId;
  final String title;
  final List<String> steps;
  final bool alwaysShow;

  /// Whether the card would show — lets pages leave it out entirely (no empty gap).
  static bool isVisible(WidgetRef ref, String tipId, {bool alwaysShow = false}) =>
      alwaysShow || !(ref.watch(dismissedTipsProvider).value?.contains(tipId) ?? true);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isVisible(ref, tipId, alwaysShow: alwaysShow)) return const SizedBox.shrink();
    final c = context.mwColors;
    return MwCard(
      tone: MwCardTone.warm,
      padding: const EdgeInsets.all(MwSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.lightbulb, size: 20, color: c.accentText),
              const SizedBox(width: MwSpace.sm),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: context.text.titleMedium?.copyWith(color: c.accentText)),
                ),
              ),
              if (!alwaysShow)
                TextButton(
                  onPressed: () => ref.read(dismissedTipsProvider.notifier).dismiss(tipId),
                  child: const Text('Got it'),
                ),
            ],
          ),
          const SizedBox(height: MwSpace.sm),
          for (final (i, step) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: MwSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: context.text.labelSmall?.copyWith(color: c.accentText)),
                  ),
                  const SizedBox(width: MwSpace.sm),
                  Expanded(
                    child: Text(step, style: context.text.bodySmall?.copyWith(color: c.textPrimary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Guide copy, kept together so tone stays consistent.
abstract final class Guides {
  static const routinesTitle = 'How routines work';
  static const routines = [
    'A routine is a few steps you repeat — like Morning, Focus or Evening. Give it days and a start time.',
    'Each step has a target (20 min, 10 pages…) and, if you like, a smaller minimum version for busy days.',
    'Tap ★ on the steps that matter most. They stay on Minimum Days and are never dropped when time is tight.',
    'Scheduled routines appear on Today, which tells you what to do now.',
  ];

  static const goalsTitle = 'How goals work';
  static const goals = [
    'A goal is where you’re heading — “Read 12 books this year”. A number is optional.',
    'Add a habit: the small, repeated action behind it, like “Read 20 pages”.',
    'Link that habit to a step in one of your routines. Each time you do the step, you’ll see it here.',
    'Use “Log progress” for milestones, like finishing a book.',
  ];
}
