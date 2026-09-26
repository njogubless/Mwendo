import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/mw_tokens.dart';
import 'brand_mark.dart';
import 'mw_card.dart';
import 'mw_page.dart';
import 'state_views.dart';

/// Frame for tabs whose features land in later milestones.
class TabPlaceholder extends StatelessWidget {
  const TabPlaceholder({required this.title, required this.emptyTitle, required this.emptyMessage, super.key});

  final String title;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return MwPage(
      children: [
        MwPageHeader(leading: BrandLockup(title: title)),
        Text(title, style: context.text.headlineMedium),
        MwCard(
          padding: const EdgeInsets.symmetric(vertical: MwSpace.xl),
          child: EmptyView(title: emptyTitle, message: emptyMessage),
        ),
      ],
    );
  }
}
