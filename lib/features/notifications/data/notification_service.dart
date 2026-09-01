import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/models/notification_preferences.dart';

/// Wraps `flutter_local_notifications` — the only file in the app that
/// should import it or `timezone` directly.
///
/// Uses [AndroidScheduleMode.inexactAllowWhileIdle] for every schedule,
/// deliberately NOT exact-alarm scheduling. None of these three
/// reminders (goal reminder, evening reflection, weekly review) are
/// time-critical — arriving a few minutes late is fine — and skipping
/// exact alarms means the app never needs Android's
/// `SCHEDULE_EXACT_ALARM` permission, which itself requires additional
/// user-facing permission UI on Android 12+. A deliberate scope cut to
/// keep the permission story simple, not an oversight.
///
/// Also deliberately does NOT wire notification-tap deep-linking to a
/// specific screen — tapping any of these currently just opens the app
/// to wherever the router's normal redirect logic lands (Today, most
/// often). Routing a tap to, say, the reflection compose screen
/// specifically is a reasonable follow-up, not built here.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Fixed IDs, one per reminder type — each type has at most one active
  // schedule, so re-scheduling with the same ID replaces the previous
  // one rather than stacking duplicates.
  static const _goalReminderId = 1001;
  static const _eveningReflectionId = 1002;
  static const _weeklyReviewId = 1003;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz.identifier));
      debugPrint('NotificationService: using timezone ${localTz.identifier}');
    } catch (e) {
      debugPrint(
        'NotificationService: timezone detection failed ($e), '
        'scheduling will use UTC until this resolves.',
      );
    }
    debugPrint(
      'NotificationService: device time now is ${DateTime.now()}, '
      'tz.local "now" is ${tz.TZDateTime.now(tz.local)}',
    );

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
    );

    _initialized = true;
  }

  /// Requests the OS notification permission. Call this ONLY when the
  /// user actively enables a notification toggle — never eagerly at app
  /// startup. That's the "default behavior should be conservative"
  /// principle from TRD §19 applied to permission prompts, not just
  /// default toggle states.
  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Reconciles all three scheduled notifications against [prefs] in one
  /// call — schedules whichever are enabled, cancels whichever aren't.
  /// Callers never need to schedule/cancel individually; just build the
  /// new preferences object and call this.
  ///
  /// Each schedule/cancel is wrapped individually so one failure (e.g.
  /// goal reminder) can't silently prevent the others from running, AND
  /// so failures are visible (via debugPrint) instead of vanishing —
  /// this method is called from a fire-and-forget listener in main.dart,
  /// which would otherwise swallow any thrown exception entirely.
  Future<void> applyPreferences(NotificationPreferences prefs) async {
    await initialize();

    if (prefs.goalReminderEnabled) {
      await _tryOrLog(
        'goal reminder schedule',
        () => _scheduleDaily(
          id: _goalReminderId,
          title: "Today's goals",
          // No live goal count here — see this class's doc comment on
          // why a scheduled notification can't know that at fire time.
          body: "Take a moment to check in on today's goals.",
          hour: prefs.goalReminderHour,
          minute: prefs.goalReminderMinute,
        ),
      );
    } else {
      await _tryOrLog(
        'goal reminder cancel',
        () => _plugin.cancel(id: _goalReminderId),
      );
    }

    if (prefs.eveningReflectionEnabled) {
      await _tryOrLog(
        'evening reflection schedule',
        () => _scheduleDaily(
          id: _eveningReflectionId,
          title: 'Anything worth remembering?',
          body: 'Add a quick reflection on today, if you feel like it.',
          hour: prefs.eveningReflectionHour,
          minute: prefs.eveningReflectionMinute,
        ),
      );
    } else {
      await _tryOrLog(
        'evening reflection cancel',
        () => _plugin.cancel(id: _eveningReflectionId),
      );
    }

    if (prefs.weeklyReviewEnabled) {
      await _tryOrLog(
        'weekly review schedule',
        () => _scheduleWeekly(
          id: _weeklyReviewId,
          title: 'Your week is complete',
          body: 'Want to look back at how it went?',
          weekday: DateTime.sunday,
          hour: 18,
          minute: 0,
        ),
      );
    } else {
      await _tryOrLog(
        'weekly review cancel',
        () => _plugin.cancel(id: _weeklyReviewId),
      );
    }
  }

  Future<void> _tryOrLog(String label, Future<void> Function() action) async {
    try {
      await action();
      debugPrint('NotificationService: $label succeeded');
    } catch (e, stack) {
      debugPrint('NotificationService: $label FAILED: $e\n$stack');
    }
  }

  /// Diagnostic only — schedules (not shows immediately) a notification
  /// 30 seconds out. Unlike `show()`, this exercises the actual
  /// `zonedSchedule` + `inexactAllowWhileIdle` path the real reminders
  /// use, so it isolates "scheduling itself is delayed/blocked" from
  /// "I didn't wait long enough" or "the API call is wrong." Wire a
  /// temporary debug button to this the same way as your other test.
  Future<void> debugScheduleTestIn30Seconds() async {
    await initialize();
    await _plugin.zonedSchedule(
      id: 9998,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test notifications',
          channelDescription: 'Testing scheduled delivery',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      title: 'Scheduled test',
      body:
          'If this arrived ~30s after you tapped the button, scheduling works.',
      scheduledDate: tz.TZDateTime.now(
        tz.local,
      ).add(const Duration(seconds: 30)),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> testNotification() async {
    await initialize();

    await _plugin.show(
      id: 9999,
      title: 'Zahee test',
      body: 'Local notifications are working.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test notifications',
          channelDescription: 'Testing local notifications',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> cancelAll() async => _plugin.cancelAll();

  /// Diagnostic helper — prints what the OS actually has queued. Wire a
  /// temporary debug button to this (same pattern as your test button)
  /// to check whether a schedule call is actually registering with the
  /// OS, independent of whether it later fires.
  Future<void> debugPrintPending() async {
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('NotificationService: ${pending.length} pending request(s)');
    for (final p in pending) {
      debugPrint('  id=${p.id} title=${p.title} body=${p.body}');
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminders',
          'Daily reminders',
          channelDescription: 'Goal and reflection reminders',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfTime(hour, minute),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required int weekday, // DateTime.monday..DateTime.sunday
    required int hour,
    required int minute,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_review',
          'Weekly review',
          channelDescription: 'Weekly review reminder',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfWeekday(weekday, hour, minute),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
