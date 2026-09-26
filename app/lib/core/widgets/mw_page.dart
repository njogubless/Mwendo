import 'package:flutter/material.dart';

import '../theme/mw_tokens.dart';

/// Standard scrollable page body: responsive margins, 1200px max content
/// width, and bottom clearance for the floating dock on compact screens.
class MwPage extends StatelessWidget {
  const MwPage({required this.children, this.spacing = MwSpace.lg, super.key});

  final List<Widget> children;
  final double spacing;

  static double marginFor(double width) => width < MwBreakpoints.medium
      ? MwSpace.marginCompact
      : width < MwBreakpoints.expanded
      ? MwSpace.marginMedium
      : MwSpace.marginExpanded;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final dockClearance = width < MwBreakpoints.medium ? 112.0 : MwSpace.xl;
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MwBreakpoints.maxContentWidth),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(marginFor(width), MwSpace.md, marginFor(width), dockClearance),
            itemCount: children.length,
            separatorBuilder: (_, _) => SizedBox(height: spacing),
            itemBuilder: (_, i) => children[i],
          ),
        ),
      ),
    );
  }
}

/// Page header: small brand lockup row with an optional trailing action.
class MwPageHeader extends StatelessWidget {
  const MwPageHeader({required this.leading, this.trailing, super.key});

  final Widget leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: leading),
        ),
        ?trailing,
      ],
    );
  }
}
