import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remembers which first-time guide cards the user dismissed (per device).
class TipsController extends AsyncNotifier<Set<String>> {
  static const _prefix = 'mwendo.tip.';

  FlutterSecureStorage get _storage => ref.read(tipsStorageProvider);

  @override
  Future<Set<String>> build() async {
    try {
      final all = await ref.watch(tipsStorageProvider).readAll();
      return {
        for (final k in all.keys)
          if (k.startsWith(_prefix)) k.substring(_prefix.length),
      };
    } on Object {
      return {}; // Storage trouble just means the guide shows again.
    }
  }

  Future<void> dismiss(String tip) async {
    state = AsyncData({...?state.value, tip});
    try {
      await _storage.write(key: '$_prefix$tip', value: '1');
    } on Object {
      // Not persisted; it stays hidden for this session.
    }
  }
}

final tipsStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

final dismissedTipsProvider = AsyncNotifierProvider<TipsController, Set<String>>(TipsController.new);
