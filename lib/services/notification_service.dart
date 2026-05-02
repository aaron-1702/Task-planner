import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

import '../core/constants/app_constants.dart';
import '../domain/entities/calendar_event.dart';
import '../domain/entities/task.dart';

/// Manages local (flutter_local_notifications) and
/// remote (FCM) push notifications.
@singleton
class NotificationService {
  NotificationService();

  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    tz.initializeTimeZones();

    // Request FCM permissions
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Local notifications channel (Android)
    const androidChannel = AndroidNotificationChannel(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      description: AppConstants.notificationChannelDesc,
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Initialize plugin
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Handle foreground FCM messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  // ── Task Reminders ─────────────────────────────────────────────────────────

  /// Schedules a local notification `minutesBefore` minutes before [task.deadline].
  Future<void> scheduleTaskReminder(
    Task task, {
    int minutesBefore = 30,
  }) async {
    if (task.deadline == null) return;

    final scheduledTime =
        task.deadline!.subtract(Duration(minutes: minutesBefore));
    if (scheduledTime.isBefore(DateTime.now())) return;

    final notificationId = task.id.hashCode;

    await _localNotifications.zonedSchedule(
      notificationId,
      '⏰ Task due soon: ${task.title}',
      task.deadline != null
          ? 'Due in $minutesBefore minutes'
          : 'Deadline approaching',
      tz.TZDateTime.from(scheduledTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notificationChannelId,
          AppConstants.notificationChannelName,
          channelDescription: AppConstants.notificationChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF6366F1),
          actions: [
            const AndroidNotificationAction('done', 'Mark Done',
                showsUserInterface: false),
            const AndroidNotificationAction('snooze', 'Snooze 15min',
                showsUserInterface: false),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime,
      payload: task.id,
    );
  }

  Future<void> cancelTaskReminder(String taskId) async {
    await _localNotifications.cancel(taskId.hashCode);
  }

  Future<void> cancelAllReminders() async {
    await _localNotifications.cancelAll();
  }

  // ── Calendar Event Reminders ───────────────────────────────────────────────

  /// Schedules a reminder for a [CalendarEvent] based on its [reminderMinutes].
  Future<void> scheduleEventReminder(CalendarEvent event) async {
    final minutes = event.reminderMinutes;
    if (minutes == null) return;

    final scheduledTime =
        event.startDate.subtract(Duration(minutes: minutes));
    if (scheduledTime.isBefore(DateTime.now())) return;

    final isBirthday = event.type == CalendarEventType.birthday;
    final notificationId = ('ev_${event.id}').hashCode;

    await _localNotifications.zonedSchedule(
      notificationId,
      isBirthday
          ? '🎂 Birthday: ${event.title}'
          : '📅 Event soon: ${event.title}',
      minutes == 0
          ? 'Starting now'
          : 'In $minutes minutes',
      tz.TZDateTime.from(scheduledTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notificationChannelId,
          AppConstants.notificationChannelName,
          channelDescription: AppConstants.notificationChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          color: isBirthday
              ? const Color(0xFFEC4899)
              : const Color(0xFF14B8A6),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime,
      payload: event.id,
    );
  }

  Future<void> cancelEventReminder(String eventId) async {
    await _localNotifications.cancel(('ev_$eventId').hashCode);
  }

  // ── Immediate Notifications ────────────────────────────────────────────────

  Future<void> showTaskOverdueNotification(Task task) async {
    await _localNotifications.show(
      task.id.hashCode + 1000,
      '🚨 Overdue: ${task.title}',
      'This task was due ${task.deadline != null ? _formatAgo(task.deadline!) : ""}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notificationChannelId,
          AppConstants.notificationChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: task.id,
    );
  }

  // ── FCM Token ──────────────────────────────────────────────────────────────

  Future<String?> getFcmToken() => _messaging.getToken();

  // ── Handlers ──────────────────────────────────────────────────────────────

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notificationChannelId,
          AppConstants.notificationChannelName,
          importance: Importance.high,
        ),
      ),
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    // Navigate to task detail — handled via GoRouter
    // In production, use a global navigation key or event bus
  }

  String _formatAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}
