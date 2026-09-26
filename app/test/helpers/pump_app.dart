import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwendo/core/theme/app_theme.dart';

extension PumpApp on WidgetTester {
  Future<void> pumpThemed(Widget child, {Brightness brightness = Brightness.light, Size? size}) async {
    if (size != null) {
      view.physicalSize = size;
      view.devicePixelRatio = 1;
      addTearDown(view.reset);
    }
    await pumpWidget(
      MaterialApp(
        theme: buildTheme(brightness),
        home: Scaffold(body: child),
      ),
    );
  }
}
