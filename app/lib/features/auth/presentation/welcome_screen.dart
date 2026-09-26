import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mw_tokens.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/mw_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(MwSpace.marginCompact),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  const BrandMark(size: 56),
                  const SizedBox(height: MwSpace.lg),
                  Text('Find your rhythm.\nMove forward.', style: context.text.displayMedium),
                  const SizedBox(height: MwSpace.md),
                  Text(
                    "Mwendo helps you decide what to focus on now — and adapts when life doesn't go to plan.",
                    style: context.text.bodyLarge?.copyWith(color: c.textSecondary),
                  ),
                  const Spacer(flex: 2),
                  MwButton(label: 'Get started', onPressed: () => context.push(Routes.register)),
                  const SizedBox(height: MwSpace.sm),
                  MwButton(
                    label: 'I already have an account',
                    variant: MwButtonVariant.secondary,
                    onPressed: () => context.push(Routes.signIn),
                  ),
                  if (Env.showDevTools)
                    MwButton(
                      label: 'Design system gallery',
                      variant: MwButtonVariant.text,
                      onPressed: () => context.push(Routes.devGallery),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
