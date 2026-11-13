import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/backend.dart';
import '../../core/config/env.dart';
import '../../core/config/server_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/mw_tokens.dart';
import '../../core/widgets/mw_button.dart';
import '../../core/widgets/mw_sheet.dart';
import '../auth/application/session_controller.dart';

/// Debug builds only: shows which server the app uses; tap to change it.
class ServerHint extends ConsumerWidget {
  const ServerHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Env.showDevTools) return const SizedBox.shrink();
    if (ref.watch(backendProvider) == Backend.firebase) {
      return Center(
        child: TextButton.icon(
          onPressed: null,
          icon: const Icon(Symbols.cloud, size: 16),
          label: Text('Backend: Firebase', style: context.text.labelSmall),
        ),
      );
    }
    final url = ref.watch(apiBaseUrlProvider);
    return Center(
      child: TextButton.icon(
        onPressed: Env.canSwitchServer ? () => showServerSettings(context) : null,
        icon: const Icon(Symbols.dns, size: 16),
        label: Text('Server: $url', style: context.text.labelSmall),
      ),
    );
  }
}

Future<void> showServerSettings(BuildContext context) =>
    showMwSheet<void>(context, title: 'Developer · Server', builder: (_) => const _ServerForm());

class _Preset {
  const _Preset(this.label, this.hint, this.url);

  final String label;
  final String hint;
  final String url;
}

class _ServerForm extends ConsumerStatefulWidget {
  const _ServerForm();

  @override
  ConsumerState<_ServerForm> createState() => _ServerFormState();
}

class _ServerFormState extends ConsumerState<_ServerForm> {
  late final _custom = TextEditingController(text: ref.read(apiBaseUrlProvider));
  String? _result;
  bool _ok = false;
  bool _testing = false;

  List<_Preset> get _presets => [
    const _Preset(
      'This computer',
      kIsWeb
          ? 'The backend on the computer running this browser.'
          : 'Phone on USB: run ./tool/run_dev.sh (adb reverse).',
      Env.localApiUrl,
    ),
    if (!kIsWeb)
      const _Preset('Android emulator', 'The emulator reaches your computer at 10.0.2.2.', Env.emulatorApiUrl),
    if (Env.stagingApiUrl.isNotEmpty) const _Preset('Staging', 'The shared staging server.', Env.stagingApiUrl),
  ];

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _result = null;
    });
    final url = normaliseApiUrl(_custom.text);
    try {
      final dio = Dio(
        BaseOptions(connectTimeout: const Duration(seconds: 4), receiveTimeout: const Duration(seconds: 4)),
      );
      final r = await dio.get<Map<String, dynamic>>('$url/health/');
      _ok = r.data?['status'] == 'ok';
      _result = _ok ? 'Connected — database ${r.data?['database']}.' : 'Reached the server, but it reports ${r.data}.';
    } on DioException catch (e) {
      _ok = false;
      _result = e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout
          ? "Can't reach $url. Is the backend running with runserver 0.0.0.0:8001, and is this device on the same network?"
          : 'Reached something, but not the Mwendo API (${e.response?.statusCode ?? e.type.name}).';
    }
    if (mounted) setState(() => _testing = false);
  }

  Future<void> _use(String? url) async {
    await ref.read(apiBaseUrlProvider.notifier).set(url);
    // Accounts belong to a server: sign out so the next sign-in happens on the new one.
    await ref.read(sessionControllerProvider.notifier).signOut();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final current = ref.watch(apiBaseUrlProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Only in debug builds. Release builds always use the production server. Your choice is remembered on this '
          'device, so plain `flutter run` keeps using it.',
          style: context.text.bodySmall?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: MwSpace.md),
        for (final p in _presets)
          ListTile(
            contentPadding: EdgeInsets.zero,
            selected: normaliseApiUrl(_custom.text) == p.url,
            leading: Icon(
              normaliseApiUrl(_custom.text) == p.url ? Symbols.radio_button_checked : Symbols.radio_button_unchecked,
              color: normaliseApiUrl(_custom.text) == p.url ? c.action : c.textTertiary,
            ),
            title: Text(p.label + (p.url == current ? ' · in use' : ''), style: context.text.labelLarge),
            subtitle: Text('${p.url}\n${p.hint}', style: context.text.bodySmall),
            isThreeLine: true,
            onTap: () => setState(() => _custom.text = p.url),
          ),
        const SizedBox(height: MwSpace.sm),
        TextField(
          controller: _custom,
          keyboardType: TextInputType.url,
          onChanged: (_) => setState(() {}),
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Server address',
            hintText: '192.168.1.20:8001',
            helperText: "For a phone on Wi-Fi, use your computer's address (hostname -I) and port 8001.",
            helperMaxLines: 2,
          ),
        ),
        if (_result != null) ...[
          const SizedBox(height: MwSpace.sm),
          Row(
            children: [
              Icon(_ok ? Symbols.check_circle : Symbols.error, size: 18, color: _ok ? c.action : c.gentle),
              const SizedBox(width: MwSpace.sm),
              Expanded(child: Text(_result!, style: context.text.bodySmall)),
            ],
          ),
        ],
        const SizedBox(height: MwSpace.md),
        Row(
          children: [
            Expanded(
              child: MwButton(label: 'Test', variant: MwButtonVariant.secondary, isLoading: _testing, onPressed: _test),
            ),
            const SizedBox(width: MwSpace.sm),
            Expanded(
              child: MwButton(label: 'Use this server', onPressed: () => _use(_custom.text)),
            ),
          ],
        ),
        MwButton(label: 'Reset to default', variant: MwButtonVariant.text, onPressed: () => _use(null)),
      ],
    );
  }
}
