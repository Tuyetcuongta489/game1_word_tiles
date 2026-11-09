import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service for managing local notifications for user retention & re-engagement.
///
/// Automatically schedules retention notifications when the user exits or backgrounds the app,
/// and cancels pending notifications when the user resumes playing.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // Notification IDs
  static const int idReminderImmediate = 1000;
  static const int idReminder1h = 1001;
  static const int idReminder24h = 1002;
  static const int idReminder48h = 1003;
  static const int idReminder72h = 1004;

  // Notification Channel
  static const String channelId = 'wordnect_retention_channel';
  static const String channelName = 'Game Reminders & Rewards';
  static const String channelDescription =
      'Notifications for daily rewards, game streak alerts, and new puzzle challenges.';

  /// Initialize notification plugin, timezone database, and request permissions.
  static Future<void> init() async {
    if (_isInitialized) return;

    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest || kIsWeb) {
      _isInitialized = true;
      return;
    }

    try {
      tz.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings('ic_notification');
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

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('[NotificationService] Notification tapped: ${response.payload}');
        },
      );

      // Request runtime permissions on Android 13+ (API 33+)
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidImpl?.requestNotificationsPermission();
      }

      _isInitialized = true;
      debugPrint('[NotificationService] Initialized successfully.');
    } catch (e) {
      debugPrint('[NotificationService] Init error: $e');
    }
  }

  /// Cancels all pending reminders when the user resumes the app.
  static Future<void> cancelAllReminders() async {
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest || kIsWeb) return;

    try {
      await _notificationsPlugin.cancelAll();
      debugPrint('[NotificationService] Cancelled all pending retention reminders.');
    } catch (e) {
      debugPrint('[NotificationService] Cancel error: $e');
    }
  }

  /// Schedules re-engagement reminders when the user leaves or backgrounds the app.
  /// 0. Immediate (~10s right after out/kill app)
  /// 1. 1 Hour Later (Short Break)
  /// 2. 24 Hours Later (Daily Login Streak)
  /// 3. 48 Hours Later (Level Challenge)
  /// 4. 72 Hours Later (Win-back Reward)
  static Future<void> scheduleRetentionReminders({int? currentLevel}) async {
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest || kIsWeb) return;

    try {
      if (!_isInitialized) {
        await init();
      }

      await cancelAllReminders();

      final now = tz.TZDateTime.now(tz.local);

      // 0. Immediate Reminder: 10s after leaving/killing app
      final puzzleText = currentLevel != null && currentLevel > 0
          ? 'Level $currentLevel is waiting for you!'
          : 'Your puzzle is waiting!';
      await _scheduleNotification(
        id: idReminderImmediate,
        title: "Wait, Don't Go! 🎁",
        body: '$puzzleText Come back now to keep your streak and claim bonus coins!',
        scheduledDate: now.add(const Duration(seconds: 10)),
      );

      // 1. Reminder 1: 1 Hour Later (Short Break)
      await _scheduleNotification(
        id: idReminder1h,
        title: 'Brain Break Time! 🧠',
        body: 'A fresh word puzzle is waiting. Take 2 minutes to relax and solve!',
        scheduledDate: now.add(const Duration(hours: 1)),
      );

      // 2. Reminder 2: 24 Hours Later (Daily Login Streak)
      await _scheduleNotification(
        id: idReminder24h,
        title: 'Daily Reward Ready! 🎁',
        body: "Don't break your streak! Claim your daily bonus coins and boosters now.",
        scheduledDate: now.add(const Duration(hours: 24)),
      );

      // 3. Reminder 3: 48 Hours Later (Level Challenge)
      final levelText = currentLevel != null && currentLevel > 0
          ? 'Level $currentLevel is waiting for your brilliant move!'
          : 'Can you solve today\'s challenge?';
      await _scheduleNotification(
        id: idReminder48h,
        title: 'Word Master Challenge! 🏆',
        body: '$levelText Jump in to test your vocabulary!',
        scheduledDate: now.add(const Duration(hours: 48)),
      );

      // 4. Reminder 4: 72 Hours Later (Win-back Reward)
      await _scheduleNotification(
        id: idReminder72h,
        title: 'We Miss You! ✨',
        body: 'Come back to Wordnect and claim your special welcome-back reward!',
        scheduledDate: now.add(const Duration(hours: 72)),
      );

      debugPrint('[NotificationService] Scheduled retention reminders (10s immediate, 1h, 24h, 48h, 72h).');
    } catch (e) {
      debugPrint('[NotificationService] Scheduling error: $e');
    }
  }

  /// Sends an immediate test notification for QA / Cheat Menu testing.
  static Future<void> showTestNotification() async {
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest || kIsWeb) return;

    if (!_isInitialized) await init();

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
      icon: 'ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('app_icon'),
      color: Color(0xFF3B82F6),
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notificationsPlugin.show(
      id: 9999,
      title: 'Notification Test 🔔',
      body: 'Wordnect notifications are running perfectly on your Android device!',
      notificationDetails: notificationDetails,
    );
    debugPrint('[NotificationService] Fired instant test notification.');
  }

  /// Schedules a test notification with a custom short delay (e.g. 5 seconds)
  /// so developers and QA can minimize or kill the app and verify background receipt.
  static Future<void> scheduleTestNotification({int seconds = 5}) async {
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest || kIsWeb) return;

    if (!_isInitialized) await init();

    final now = tz.TZDateTime.now(tz.local);
    await _scheduleNotification(
      id: 9998,
      title: 'Background Test Alert (${seconds}s) ⏳',
      body: 'Your test notification arrived on time while the app was in background!',
      scheduledDate: now.add(Duration(seconds: seconds)),
    );
    debugPrint('[NotificationService] Scheduled QA test notification in ${seconds}s.');
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
      icon: 'ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('app_icon'),
      color: Color(0xFF3B82F6),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
