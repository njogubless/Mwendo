import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mw_tokens.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/mw_card.dart';
import '../../../core/widgets/mw_page.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/application/session_controller.dart';

/// Today — the core "what should I do now?" experience (built in M3).
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  static String greetingFor(DateTime now) => switch (now.hour) {
    < 12 => 'Good morning',
    < 17 => 'Good afternoon',
    _ => 'Good evening',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final name = session is SignedIn ? session.user.greetingName : null;
    final now = DateTime.now();
    final date = MaterialLocalizations.of(context).formatFullDate(now);

    return MwPage(
      children: [
        const MwPageHeader(leading: BrandLockup(title: 'Today')),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              date.toUpperCase(),
              style: context.text.labelSmall?.copyWith(color: context.mwColors.action, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: MwSpace.xs),
            Text(name == null ? greetingFor(now) : '${greetingFor(now)}, $name', style: context.text.headlineMedium),
          ],
        ),
        const MwCard(
          padding: EdgeInsets.symmetric(vertical: MwSpace.xl),
          child: EmptyView(
            title: 'Your day will appear here',
            message: 'Once you have a routine, Mwendo will show you what to focus on now.',
          ),
        ),
      ],
    );
  }
}
