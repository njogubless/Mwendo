import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/mw_tokens.dart';
import '../../../../core/widgets/mw_button.dart';
import '../../../../core/widgets/mw_card.dart';

/// "Make one for me" or "build my own" — used on empty Routines and an empty Today.
class StartOptionsCard extends StatelessWidget {
  const StartOptionsCard({required this.onBuildOwn, this.title = 'Let’s shape your first routine', super.key});

  final VoidCallback onBuildOwn;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return MwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accentTint, shape: BoxShape.circle),
            child: Icon(Symbols.spa, color: c.accentText, size: 28),
          ),
          const SizedBox(height: MwSpace.md),
          Text(title, style: context.text.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: MwSpace.xs),
          Text(
            'Answer a few quick questions and Mwendo will suggest routines you can edit — or build your own '
            'from scratch. A glass of water counts.',
            style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MwSpace.lg),
          MwButton(
            label: 'Suggest routines for me',
            icon: Symbols.auto_awesome,
            onPressed: () => context.push(Routes.suggestRoutines),
          ),
          const SizedBox(height: MwSpace.sm),
          MwButton(
            label: 'I’ll build my own',
            icon: Symbols.add,
            variant: MwButtonVariant.secondary,
            onPressed: onBuildOwn,
          ),
        ],
      ),
    );
  }
}
