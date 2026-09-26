import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/mw_tokens.dart';

/// Uppercase micro-label heading a section, with an optional trailing widget.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {this.trailing, this.color, super.key});

  final String text;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MwSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text.toUpperCase(),
                style: context.text.labelSmall?.copyWith(
                  color: color ?? context.mwColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
