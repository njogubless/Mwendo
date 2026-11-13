import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwendo/core/config/backend.dart';
import 'package:mwendo/core/config/env.dart';
import 'package:mwendo/core/config/server_config.dart';
import 'package:mwendo/features/dev/server_settings.dart';

import '../helpers/pump_screen.dart';

class _MemoryStore implements ServerStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? url) async => value = url;
}

void main() {
  group('resolveApiBaseUrl', () {
    test('a build-time URL always wins', () {
      expect(
        resolveApiBaseUrl(defined: 'https://staging.example.com', release: true, saved: 'http://x:1'),
        'https://staging.example.com/api/v1',
      );
    });

    test('release builds use production, ignoring any saved developer choice', () {
      expect(resolveApiBaseUrl(defined: '', release: true, saved: 'http://192.168.1.2:8001'), Env.productionApiUrl);
    });

    test('debug builds use the saved server, else this computer', () {
      expect(
        resolveApiBaseUrl(defined: '', release: false, saved: '192.168.1.2:8001'),
        'http://192.168.1.2:8001/api/v1',
      );
      expect(resolveApiBaseUrl(defined: '', release: false), Env.localApiUrl);
    });
  });

  test('normaliseApiUrl accepts the ways people type addresses', () {
    expect(normaliseApiUrl('192.168.1.2:8001'), 'http://192.168.1.2:8001/api/v1');
    expect(normaliseApiUrl(' http://host:8001/ '), 'http://host:8001/api/v1');
    expect(normaliseApiUrl('https://api.example.com/api/v1/'), 'https://api.example.com/api/v1');
  });

  test('switching server persists the choice and resets to default', () async {
    final store = _MemoryStore();
    final container = ProviderContainer(overrides: [serverStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);

    await container.read(apiBaseUrlProvider.notifier).set('192.168.31.222:8001');
    expect(container.read(apiBaseUrlProvider), 'http://192.168.31.222:8001/api/v1');
    expect(store.value, 'http://192.168.31.222:8001/api/v1');

    await container.read(apiBaseUrlProvider.notifier).set(null);
    expect(container.read(apiBaseUrlProvider), Env.localApiUrl);
    expect(store.value, isNull);
  });

  testWidgets('the server hint shows the current server and opens the picker', (tester) async {
    await pumpScreen(
      tester,
      const ServerHint(),
      overrides: [
        backendProvider.overrideWithValue(Backend.django),
        savedServerProvider.overrideWithValue('http://192.168.31.222:8001/api/v1'),
      ],
    );

    expect(find.text('Server: http://192.168.31.222:8001/api/v1'), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.text('Developer · Server'), findsOneWidget);
    expect(find.text('Use this server'), findsOneWidget);
  });

  testWidgets('with the Firebase backend the hint names it and offers no server picker', (tester) async {
    await pumpScreen(tester, const ServerHint(), overrides: [backendProvider.overrideWithValue(Backend.firebase)]);

    expect(find.text('Backend: Firebase'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);
  });
}
