import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The Mwendo emblem (from the Stitch export, stored locally in
/// `assets/images/mwendo_mark.png`). Reads on both light and dark surfaces.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 32, super.key});

  static const assetPath = 'assets/images/mwendo_mark.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mwendo',
      image: true,
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// Emblem plus "MWENDO" micro-label and an optional title (app bar lockup).
class BrandLockup extends StatelessWidget {
  const BrandLockup({this.title, super.key});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'MWENDO',
              style: context.text.labelSmall?.copyWith(color: c.action, fontWeight: FontWeight.w700),
            ),
            if (title != null) Text(title!, style: context.text.titleLarge),
          ],
        ),
      ],
    );
  }
}
