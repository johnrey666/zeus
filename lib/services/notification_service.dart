import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Manila')); // Adjust to your timezone

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    await _requestPermissions();

    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');
  }

  // Schedule workout reminder
  Future<void> scheduleWorkoutReminder({
    required int id,
    required DateTime scheduledTime,
    required String workoutName,
  }) async {
    await initialize();

    final androidDetails = AndroidNotificationDetails(
      'workout_reminders',
      'Workout Reminders',
      channelDescription: 'Notifications for scheduled workout reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.zonedSchedule(
        id,
        'Workout Reminder',
        'Time for your workout: $workoutName',
        tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'workout:$id',
      );
    } catch (e) {
      print('Error scheduling workout reminder: $e');
      // Fallback to inexact scheduling if exact alarms are not permitted
      try {
        await _notifications.zonedSchedule(
          id,
          'Workout Reminder',
          'Time for your workout: $workoutName',
          tz.TZDateTime.from(scheduledTime, tz.local),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'workout:$id',
        );
      } catch (e2) {
        print('Error scheduling workout reminder (fallback): $e2');
      }
    }
  }

  // Schedule hydration reminder (4 times: 8am, 12pm, 3pm, 8pm)
  Future<void> scheduleHydrationReminders() async {
    await initialize();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Schedule 4 reminders at specific times: 8am, 12pm, 3pm, 8pm
    final reminderTimes = [
      DateTime(today.year, today.month, today.day, 8, 0),   // 8:00 AM
      DateTime(today.year, today.month, today.day, 12, 0),  // 12:00 PM (noon)
      DateTime(today.year, today.month, today.day, 15, 0),  // 3:00 PM
      DateTime(today.year, today.month, today.day, 20, 0),  // 8:00 PM
    ];
    
    final glassNumbers = [1, 2, 3, 4];
    
    for (int i = 0; i < reminderTimes.length; i++) {
      final reminderTime = reminderTimes[i];
      
      // If time has passed today, schedule for tomorrow
      final scheduledTime = reminderTime.isBefore(now)
          ? reminderTime.add(const Duration(days: 1))
          : reminderTime;
      
      // Only schedule if time hasn't passed today (or schedule for tomorrow)
      if (scheduledTime.isAfter(now) || scheduledTime.day != now.day) {
        final androidDetails = AndroidNotificationDetails(
          'hydration_reminders',
          'Hydration Reminders',
          channelDescription: 'Reminders to drink water (8 glasses daily)',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        );

        const iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

        final notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        try {
          await _notifications.zonedSchedule(
            1000 + i, // Unique ID for each hydration reminder
            '💧 Hydration Reminder',
            'Time to drink water! Glass ${glassNumbers[i]} of 4',
            tz.TZDateTime.from(scheduledTime, tz.local),
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: 'hydration:${glassNumbers[i]}',
          );
        } catch (e) {
          print('Error scheduling hydration reminder ${i + 1}: $e');
          // Continue with other reminders even if one fails
        }
      }
    }
  }

  // Schedule daily steps reminder
  Future<void> scheduleStepsReminder() async {
    await initialize();

    final now = DateTime.now();
    final reminderTime = DateTime(now.year, now.month, now.day, 20, 0); // 8 PM

    // If 8 PM has passed today, schedule for tomorrow
    final scheduledTime = reminderTime.isBefore(now)
        ? reminderTime.add(const Duration(days: 1))
        : reminderTime;

    final androidDetails = AndroidNotificationDetails(
      'steps_reminders',
      'Daily Steps Reminders',
      channelDescription: 'Reminders to reach daily step goal (10,000 steps)',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.zonedSchedule(
        2000,
        '🚶 Daily Steps Goal',
        'Have you reached your 10,000 steps today?',
        tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'steps:10000',
      );
    } catch (e) {
      print('Error scheduling steps reminder: $e');
      // App continues even if notification scheduling fails
    }
  }

  // Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Cancel all workout reminders
  Future<void> cancelWorkoutReminders() async {
    // Cancel IDs 1-999 (workout reminders)
    for (int i = 1; i < 1000; i++) {
      await _notifications.cancel(i);
    }
  }

  // Cancel hydration reminders
  Future<void> cancelHydrationReminders() async {
    // Cancel IDs 1000-1999 (hydration reminders)
    for (int i = 1000; i < 2000; i++) {
      await _notifications.cancel(i);
    }
  }

  // Cancel steps reminder
  Future<void> cancelStepsReminder() async {
    await _notifications.cancel(2000);
  }
}

