import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mw_tokens.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/state_views.dart';
import '../application/session_controller.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    return Scaffold(
      body: switch (session) {
        SessionUnavailable(:final failure) => ErrorView(
          failure: failure,
          onRetry: () => ref.read(sessionControllerProvider.notifier).restore(),
        ),
        _ => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 56),
              const SizedBox(height: MwSpace.md),
              Text('Mwendo', style: context.text.headlineSmall),
            ],
          ),
        ),
      },
    );
  }
}
