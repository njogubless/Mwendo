import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwendo/core/theme/app_theme.dart';
import 'package:mwendo/features/dev/gallery_screen.dart';

void main() {
  for (final width in [320.0, 390.0, 800.0, 1280.0]) {
    testWidgets('design-system gallery lays out without overflow at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const GalleryScreen()));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);

      // Switch to dark mode and re-check.
      await tester.tap(find.bySemanticsLabel('Dark mode'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    });
  }
}
