import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mwendo/core/routing/adaptive_shell.dart';
import 'package:mwendo/core/theme/app_theme.dart';

Widget _app() {
  final router = GoRouter(
    initialLocation: '/a',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AdaptiveShell(navigationShell: shell),
        branches: [
          for (final (i, d) in shellDestinations.indexed)
            StatefulShellBranch(
              routes: [GoRoute(path: '/${String.fromCharCode(97 + i)}', builder: (_, _) => Text('page ${d.label}'))],
            ),
        ],
      ),
    ],
  );
  return MaterialApp.router(theme: buildTheme(Brightness.light), routerConfig: router);
}

Future<void> _pumpAt(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('compact width uses the floating dock and switches tabs', (tester) async {
    await _pumpAt(tester, 390);

    expect(find.byType(MwBottomDock), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await tester.tap(find.bySemanticsLabel('Goals'));
    await tester.pumpAndSettle();
    expect(find.text('page Goals'), findsOneWidget);
  });

  testWidgets('medium width uses a navigation rail', (tester) async {
    await _pumpAt(tester, 800);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(MwBottomDock), findsNothing);
  });

  testWidgets('expanded width uses the sidebar', (tester) async {
    await _pumpAt(tester, 1280);

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(MwBottomDock), findsNothing);
    expect(find.widgetWithText(ListTile, 'Insights'), findsOneWidget);
  });
}
