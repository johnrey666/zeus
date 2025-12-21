# 📱 Notification System Explanation

## How Notifications Work in Zeus Fitness App

### Overview
The app uses **local notifications** that are scheduled on your device. These notifications work even when the app is closed or in the background.

### Types of Notifications

#### 1. 💧 Hydration Reminders
- **When**: 4 times daily at specific times
  - 8:00 AM - "Time to drink water! Glass 1 of 4"
  - 12:00 PM (Noon) - "Time to drink water! Glass 2 of 4"
  - 3:00 PM - "Time to drink water! Glass 3 of 4"
  - 8:00 PM - "Time to drink water! Glass 4 of 4"
- **Purpose**: Remind you to drink water throughout the day
- **Location**: Scheduled automatically when app starts (`lib/main.dart`)
- **Service**: `lib/services/notification_service.dart` → `scheduleHydrationReminders()`

#### 2. 🚶 Daily Steps Reminder
- **When**: Every day at 8:00 PM
- **Message**: "Have you reached your 10,000 steps today?"
- **Purpose**: Remind you to check your daily step goal
- **Location**: Scheduled automatically when app starts (`lib/main.dart`)
- **Service**: `lib/services/notification_service.dart` → `scheduleStepsReminder()`

#### 3. 💪 Workout Reminders
- **When**: At the scheduled time of your workout (when you add a workout to calendar)
- **Message**: "Time for your workout: [Workout Name]"
- **Purpose**: Remind you about upcoming workouts
- **Location**: Scheduled when you add a workout (`lib/pages/member_pages/home_page.dart`)
- **Service**: `lib/services/notification_service.dart` → `scheduleWorkoutReminder()`

### How It Works Technically

1. **Initialization** (`lib/main.dart`):
   ```dart
   await NotificationService().initialize();
   await NotificationService().scheduleHydrationReminders();
   await NotificationService().scheduleStepsReminder();
   ```

2. **Notification Service** (`lib/services/notification_service.dart`):
   - Uses `flutter_local_notifications` package
   - Schedules notifications using timezone-aware scheduling
   - Works on both Android and iOS

3. **Background Execution**:
   - Notifications are scheduled in the device's notification system
   - They work even when the app is closed
   - Uses `AndroidScheduleMode.inexactAllowWhileIdle` for battery efficiency

### Notification IDs
- Hydration reminders: 1000-1003
- Steps reminder: 2000
- Workout reminders: Dynamic (based on workout ID hash)

### Permissions Required
- **Android**: Notification permission (requested automatically)
- **iOS**: Alert, Badge, and Sound permissions (requested automatically)

### Troubleshooting

**Notifications not showing?**
1. Check device notification settings for the app
2. Ensure notifications are enabled in device settings
3. Check if Do Not Disturb mode is enabled
4. Restart the app to reschedule notifications

**Want to test notifications?**
- Notifications are scheduled for future times
- To test immediately, you can modify the scheduled times in `notification_service.dart`

### Files Involved
- `lib/services/notification_service.dart` - Main notification service
- `lib/main.dart` - Initializes and schedules daily reminders
- `lib/pages/member_pages/home_page.dart` - Schedules workout reminders

