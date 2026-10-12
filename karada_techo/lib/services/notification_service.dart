import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/metric.dart';
import '../models/settings.dart';

/// Daily measurement reminders, scheduled on the device (no server).
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'measurement_reminders',
      '測定のリマインダー',
      channelDescription: '毎日の測定時間をお知らせします',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      // The first release targets Japan. For other markets, add flutter_timezone
      // and pass the device's IANA zone here instead.
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
      const settings = InitializationSettings(
        // Monochrome status-bar icon (an adaptive launcher icon here crashes Android 8).
        android: AndroidInitializationSettings('ic_stat_notify'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings);
      _ready = true;
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  static Future<bool> requestPermission() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await android?.requestNotificationsPermission() ?? false;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
    } catch (e) {
      debugPrint('Notification permission failed: $e');
    }
    return false;
  }

  /// Replaces all scheduled reminders with the enabled ones in [reminders].
  static Future<void> schedule(List<Reminder> reminders) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      for (var i = 0; i < reminders.length; i++) {
        final r = reminders[i];
        if (!r.enabled) continue;
        await _plugin.zonedSchedule(
          100 + i,
          '${r.label}の時間です',
          reminderTip(r),
          _nextInstance(r.hour, r.minute),
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (e) {
      debugPrint('Scheduling reminders failed: $e');
    }
  }

  static tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }
}

/// A short, gentle measuring tip shown in the notification body.
String reminderTip(Reminder r) {
  if (r.type == MetricType.bp) {
    return r.slot == BpSlot.evening
        ? '寝る前に、いすに座って1〜2分休んでから測りましょう。'
        : '起床後1時間以内、朝食や服薬の前に測りましょう。';
  }
  return infoOf(r.type).tip;
}
