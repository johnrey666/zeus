import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Stream for notification clicks
  final StreamController<String> _notificationClickStream =
      StreamController<String>.broadcast();
  Stream<String> get notificationClicks => _notificationClickStream.stream;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(
        tz.getLocation('Asia/Manila')); // Adjust to your timezone

    // Setup local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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

    // Create notification channels
    await _createNotificationChannels();

    _initialized = true;
    print('Notification service initialized successfully');
  }

  Future<void> _requestPermissions() async {
    // Request local notification permission
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> _createNotificationChannels() async {
    // Create notification channels for Android
    const AndroidNotificationChannel workoutChannel =
        AndroidNotificationChannel(
      'workout_reminders',
      'Workout Reminders',
      description: 'Notifications for scheduled workout reminders',
      importance: Importance.high,
      playSound: true,
    );

    const AndroidNotificationChannel hydrationChannel =
        AndroidNotificationChannel(
      'hydration_reminders',
      'Hydration Reminders',
      description: 'Reminders to drink water',
      importance: Importance.defaultImportance,
    );

    const AndroidNotificationChannel stepsChannel = AndroidNotificationChannel(
      'steps_reminders',
      'Daily Steps Reminders',
      description: 'Reminders to reach daily step goal',
      importance: Importance.defaultImportance,
    );

    // Create channels
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(workoutChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(hydrationChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(stepsChannel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    if (response.payload != null) {
      _notificationClickStream.add(response.payload!);
    }
  }

  // Show immediate notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'workout_reminders',
      'Workout Reminders',
      channelDescription: 'Notifications for scheduled workout reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
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

    await _notifications.show(
      0,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Schedule workout reminder
  Future<void> scheduleWorkoutReminder({
    required int id,
    required DateTime scheduledTime,
    required String workoutName,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'workout_reminders',
      'Workout Reminders',
      channelDescription: 'Notifications for scheduled workout reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
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
        payload: 'workout:$id:$workoutName',
      );
      print('Workout reminder scheduled: $workoutName at $scheduledTime');
    } catch (e) {
      print('Error scheduling workout reminder: $e');
      // Fallback to inexact scheduling
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
          payload: 'workout:$id:$workoutName',
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
      DateTime(today.year, today.month, today.day, 8, 0), // 8:00 AM
      DateTime(today.year, today.month, today.day, 12, 0), // 12:00 PM (noon)
      DateTime(today.year, today.month, today.day, 15, 0), // 3:00 PM
      DateTime(today.year, today.month, today.day, 20, 0), // 8:00 PM
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
          channelDescription: 'Reminders to drink water (4 glasses daily)',
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
          print('Hydration reminder scheduled for glass ${glassNumbers[i]}');
        } catch (e) {
          print('Error scheduling hydration reminder ${i + 1}: $e');
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
      print('Steps reminder scheduled');
    } catch (e) {
      print('Error scheduling steps reminder: $e');
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

  // Clean up
  void dispose() {
    _notificationClickStream.close();
  }
}
