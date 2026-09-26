import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwendo/core/errors/app_failure.dart';
import 'package:mwendo/core/widgets/brand_mark.dart';
import 'package:mwendo/core/widgets/mw_button.dart';
import 'package:mwendo/core/widgets/mw_toggle.dart';
import 'package:mwendo/core/widgets/progress_ring.dart';
import 'package:mwendo/core/widgets/segmented_strand.dart';
import 'package:mwendo/core/widgets/state_views.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('MwButton calls onPressed and blocks taps while loading', (tester) async {
    var taps = 0;
    await tester.pumpThemed(MwButton(label: 'Mark done', onPressed: () => taps++));
    await tester.tap(find.text('Mark done'));
    expect(taps, 1);

    await tester.pumpThemed(MwButton(label: 'Mark done', isLoading: true, onPressed: () => taps++));
    await tester.tap(find.byType(MwButton));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Mark done, in progress'), findsOneWidget);
  });

  testWidgets('MwToggle flips value and exposes toggled semantics', (tester) async {
    bool? changed;
    await tester.pumpThemed(MwToggle(value: false, onChanged: (v) => changed = v, semanticLabel: 'Minimum Day'));

    await tester.tap(find.byType(MwToggle));
    expect(changed, isTrue);
    expect(tester.getSemantics(find.bySemanticsLabel('Minimum Day')), isSemantics(isToggled: false, isEnabled: true));
  });

  testWidgets('ProgressRing clamps and announces its value', (tester) async {
    await tester.pumpThemed(const ProgressRing(value: 1.4, semanticLabel: "Today's progress"));
    await tester.pumpAndSettle();

    final semantics = tester.getSemantics(find.bySemanticsLabel("Today's progress"));
    expect(semantics.value, '100%');
  });

  testWidgets('SegmentedStrand never overflows when segments exceed 100%', (tester) async {
    await tester.pumpThemed(
      const SizedBox(
        width: 200,
        child: SegmentedStrand(
          semanticLabel: 'progress',
          segments: [
            StrandSegment(fraction: 0.8, color: Colors.green),
            StrandSegment(fraction: 0.8, color: Colors.orange),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ErrorView shows offline copy and retry for network failures', (tester) async {
    var retried = false;
    await tester.pumpThemed(ErrorView(failure: const NetworkFailure(), onRetry: () => retried = true));

    expect(find.text("You're offline"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('BrandMark renders the bundled emblem with a label', (tester) async {
    await tester.pumpThemed(const BrandMark(size: 40));

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, BrandMark.assetPath);
    expect(find.bySemanticsLabel('Mwendo'), findsOneWidget);
    expect(tester.getSize(find.byType(Image)), const Size(40, 40));
  });
}
