import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../models/reminder_model.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'govchat_reminders';
  static const _channelName = 'Reminders';
  static const _primaryColor = Color(0xFF4ADE80);

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await _plugin.initialize(
        const InitializationSettings(
            android: androidSettings, iOS: iosSettings),
      );
      _initialized = true;
    } catch (e) {
      debugPrint('[NotificationService] init error: $e');
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> scheduleReminder(ReminderModel reminder) async {
    if (!_initialized) await initialize();
    if (!reminder.notificationEnabled) return;

    final notifTime = reminder.notificationTime;
    final now = DateTime.now();

    // Skip past one-shot notifications
    if (notifTime.isBefore(now) &&
        reminder.repeatType == ReminderRepeatType.none) {
      return;
    }

    final id = _idFor(reminder.id);
    final scheduled = tz.TZDateTime.from(
      notifTime.isBefore(now)
          ? now.add(const Duration(seconds: 5))
          : notifTime,
      tz.local,
    );

    DateTimeComponents? repeat;
    switch (reminder.repeatType) {
      case ReminderRepeatType.daily:
        repeat = DateTimeComponents.time;
        break;
      case ReminderRepeatType.weekly:
        repeat = DateTimeComponents.dayOfWeekAndTime;
        break;
      case ReminderRepeatType.monthly:
        repeat = DateTimeComponents.dayOfMonthAndTime;
        break;
      default:
        repeat = null;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'GovChat employee reminders',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: _primaryColor,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        reminder.title,
        reminder.description.isNotEmpty ? reminder.description : null,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: repeat,
        payload: reminder.id,
      );
    } catch (e) {
      debugPrint('[NotificationService] schedule error: $e');
    }
  }

  Future<void> cancelReminder(String reminderId) async {
    try {
      await _plugin.cancel(_idFor(reminderId));
    } catch (e) {
      debugPrint('[NotificationService] cancel error: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[NotificationService] cancelAll error: $e');
    }
  }

  int _idFor(String reminderId) =>
      reminderId.hashCode.abs() % 2147483647;
}
