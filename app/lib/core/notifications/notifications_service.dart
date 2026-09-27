import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder.dart';

/// Shows and schedules on-device notifications. Implementations: [LocalNotificationsService] (Android/iOS)
/// and [NoopNotificationsService] (web, tests).
abstract interface class NotificationsService {
  bool get isSupported;

  /// Called with a reminder's route when the user taps it.
  set onOpen(void Function(String route)? handler);

  Future<void> init();

  /// Asks the OS for permission. Returns true when notifications may be shown.
  Future<bool> requestPermission();

  /// Replaces every scheduled reminder with [reminders].
  Future<void> replaceScheduled(List<Reminder> reminders);

  Future<void> showNow(Reminder reminder);

  Future<void> cancelAll();

  /// The route of the notification that launched the app, if any (consumed once).
  Future<String?> takeLaunchRoute();
}

class NoopNotificationsService implements NotificationsService {
  @override
  bool get isSupported => false;

  @override
  set onOpen(void Function(String route)? handler) {}

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> replaceScheduled(List<Reminder> reminders) async {}

  @override
  Future<void> showNow(Reminder reminder) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<String?> takeLaunchRoute() async => null;
}

class LocalNotificationsService implements NotificationsService {
  final _plugin = FlutterLocalNotificationsPlugin();
  void Function(String route)? _onOpen;
  bool _ready = false;
  bool _exact = false;

  static const _remindersChannel = AndroidNotificationDetails(
    'mwendo_reminders',
    'Routine reminders',
    channelDescription: 'When it is time for the next step or routine.',
    icon: 'ic_stat_mwendo',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _milestonesChannel = AndroidNotificationDetails(
    'mwendo_milestones',
    'Milestones',
    channelDescription: 'When you reach halfway or finish your day, a routine or a goal.',
    icon: 'ic_stat_mwendo',
  );
  static const _darwin = DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBanner: true);

  @override
  bool get isSupported => true;

  @override
  set onOpen(void Function(String route)? handler) => _onOpen = handler;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> init() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } on Object {
      tz.setLocalLocation(tz.UTC);
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_mwendo'),
        // Permission is requested later, at a meaningful moment — not on first launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.isNotEmpty) _onOpen?.call(route);
      },
    );
    _exact = await _android?.canScheduleExactNotifications() ?? false;
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await init();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final granted = await _android?.requestNotificationsPermission() ?? false;
      // Exact timing is a nicety: without it Android may deliver a few minutes late.
      if (granted && !_exact) {
        await _android?.requestExactAlarmsPermission();
        _exact = await _android?.canScheduleExactNotifications() ?? false;
      }
      return granted;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true, badge: false) ?? false;
  }

  NotificationDetails _details(ReminderKind kind) => NotificationDetails(
    android: kind == ReminderKind.milestone ? _milestonesChannel : _remindersChannel,
    iOS: _darwin,
  );

  @override
  Future<void> replaceScheduled(List<Reminder> reminders) async {
    await init();
    await _plugin.cancelAllPendingNotifications();
    final now = DateTime.now();
    for (final r in reminders) {
      if (!r.at.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: r.id,
        scheduledDate: tz.TZDateTime.from(r.at, tz.local),
        notificationDetails: _details(r.kind),
        androidScheduleMode: _exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
        payload: r.route,
      );
    }
  }

  @override
  Future<void> showNow(Reminder reminder) async {
    await init();
    await _plugin.show(
      id: reminder.id,
      title: reminder.title,
      body: reminder.body,
      notificationDetails: _details(reminder.kind),
      payload: reminder.route,
    );
  }

  @override
  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  @override
  Future<String?> takeLaunchRoute() async {
    await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) return details?.notificationResponse?.payload;
    return null;
  }
}

final notificationsServiceProvider = Provider<NotificationsService>(
  (ref) => kIsWeb ? NoopNotificationsService() : LocalNotificationsService(),
);
