import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mw_tokens.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/mw_button.dart';
import '../../../core/widgets/mw_card.dart';
import '../../../core/widgets/mw_page.dart';
import '../../auth/application/session_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final user = session is SignedIn ? session.user : null;
    final c = context.mwColors;

    return MwPage(
      children: [
        const MwPageHeader(leading: BrandLockup(title: 'Profile')),
        if (user != null)
          MwCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.greetingName, style: context.text.titleLarge),
                const SizedBox(height: MwSpace.xs),
                Text(user.email, style: context.text.bodyMedium?.copyWith(color: c.textSecondary)),
                const SizedBox(height: MwSpace.md),
                Row(
                  children: [
                    Icon(Symbols.public, size: 16, color: c.textTertiary),
                    const SizedBox(width: MwSpace.sm),
                    Text(user.timezone, style: context.text.bodySmall?.copyWith(color: c.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        MwButton(
          label: 'Sign out',
          icon: Symbols.logout,
          variant: MwButtonVariant.secondary,
          onPressed: () => ref.read(sessionControllerProvider.notifier).signOut(),
        ),
      ],
    );
  }
}
