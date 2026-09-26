import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Broadcasts session-level events from infrastructure (e.g. refresh failed)
/// to the auth feature without core depending on features.
class SessionEvents {
  final _expired = StreamController<void>.broadcast();

  Stream<void> get expired => _expired.stream;

  void notifyExpired() => _expired.add(null);

  Future<void> dispose() => _expired.close();
}

final sessionEventsProvider = Provider<SessionEvents>((ref) {
  final events = SessionEvents();
  ref.onDispose(events.dispose);
  return events;
});
