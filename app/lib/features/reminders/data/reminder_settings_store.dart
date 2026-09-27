import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/reminder_settings.dart';

class ReminderSettingsStore {
  ReminderSettingsStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'mwendo.reminders';
  final FlutterSecureStorage _storage;

  Future<ReminderSettings> read() async {
    try {
      final raw = await _storage.read(key: _key);
      return raw == null
          ? const ReminderSettings()
          : ReminderSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return const ReminderSettings();
    }
  }

  Future<void> write(ReminderSettings s) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(s.toJson()));
    } on Object {
      // Not persisted; applies for this session.
    }
  }
}

final reminderSettingsStoreProvider = Provider((ref) => ReminderSettingsStore());
