import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:convert';

import 'package:go_router/go_router.dart';

import '../models/daily_notification.dart';
import '../../../services/user_service.dart';
import '../../../core/services/permission_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static const String _storageKey = 'daily_notifications';
  static List<DailyNotification> _notificationsList = [];
  static UserService? _userService;

  static GlobalKey<NavigatorState>? _navigatorKey;

  static Future<void> initialize({
    UserService? userService,
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    try {
      _userService = userService;
      _navigatorKey = navigatorKey;

      // Initialize timezone
      try {
        tz.initializeTimeZones();
        debugPrint('🌍 Timezones initialized successfully');
      } catch (e) {
        debugPrint('❌ Failed to initialize timezones: $e');
      }

      // Get user timezone or use default
      String userTimezone = 'Asia/Jakarta'; // Default
      if (_userService != null) {
        try {
          userTimezone = await _userService!.getUserTimezone();
          debugPrint('👤 User timezone from service: $userTimezone');
        } catch (e) {
          debugPrint('⚠️ Failed to get user timezone, using default: $e');
        }
      }

      try {
        final location = tz.getLocation(userTimezone);
        tz.setLocalLocation(location);
        debugPrint(
          '✅ Notification timezone set to: $userTimezone (Offset: ${location.currentTimeZone})',
        );
      } catch (e) {
        debugPrint('❌ Failed to set location for $userTimezone: $e');
        // Fallback to UTC if Jakarta fails? Or try 'UTC'
        try {
          tz.setLocalLocation(tz.getLocation('UTC'));
          debugPrint('⚠️ Fallback to UTC timezone');
        } catch (z) {
          debugPrint('❌ Fatal: Could not set any timezone: $z');
        }
      }

      // Initialize notifications with proper notification icon
      const androidSettings = AndroidInitializationSettings(
        '@drawable/ic_stat_notification',
      );
      const iosSettings = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      // Add Linux Settings
      final linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );

      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        linux: linuxSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint(
            '🔔 Notification clicked with payload: ${response.payload}',
          );
          if (response.payload == 'transaction_add' && _navigatorKey != null) {
            // Navigate to add transaction screen
            // Using GoRouter logic if navigatorKey context is available
            final context = _navigatorKey!.currentContext;
            if (context != null) {
              // Gunakan GoRouter untuk navigasi
              context.push('/transaction/add');
            }
          }
        },
      );

      // Create the notification channel explicitly
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'daily_notifications', // id
          'Daily Notifications', // title
          description: 'Daily notification reminders',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );

        await androidPlugin.createNotificationChannel(channel);

        // Setup also for test channel
        const AndroidNotificationChannel testChannel =
            AndroidNotificationChannel(
              'test_channel',
              'Test Notifications',
              description: 'Test notification channel',
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            );
        await androidPlugin.createNotificationChannel(testChannel);
      }

      await requestPermissions();
      await loadNotifications();
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
    }
  }

  static Future<void> requestPermissions() async {
    // Gunakan PermissionService untuk handle permission logic yang kompleks
    await PermissionService().requestNotificationPermissions();

    // Fallback/Legacy check using FLN plugin just in case
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final canScheduleExact = await androidPlugin
          .canScheduleExactNotifications();
      debugPrint(
        '📅 Can schedule exact notifications (FLN check): $canScheduleExact',
      );
    }
  }

  /// Check and log current permission status
  static Future<Map<String, bool>> checkPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      bool areNotificationsEnabled;
      if (sdkInt >= 33) {
        final status = await Permission.notification.status;
        areNotificationsEnabled = status.isGranted;
      } else {
        areNotificationsEnabled = true; // Implied on Android < 13
      }

      bool canScheduleExact;
      if (sdkInt >= 31) {
        // Android 12+
        final status = await Permission.scheduleExactAlarm.status;
        canScheduleExact = status.isGranted;
      } else {
        canScheduleExact = true; // Implied on Android < 12
      }

      debugPrint('=== Permission Status (Android SDK $sdkInt) ===');
      debugPrint('Notifications: $areNotificationsEnabled');
      debugPrint('Exact Alarm: $canScheduleExact');

      return {
        'notifications': areNotificationsEnabled,
        'exactAlarm': canScheduleExact,
      };
    }
    return {'notifications': false, 'exactAlarm': false};
  }

  /// Request exact alarm permission specifically
  static Future<void> requestExactAlarmPermission() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestExactAlarmsPermission();
      debugPrint('⏰ Exact alarm permission request result: $granted');
    }
  }

  static Future<void> loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList(_storageKey) ?? [];

      _notificationsList = notificationsJson
          .map((json) => DailyNotification.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      _notificationsList = [];
    }
  }

  static Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = _notificationsList
          .map((notification) => jsonEncode(notification.toJson()))
          .toList();

      await prefs.setStringList(_storageKey, notificationsJson);
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }

  static List<DailyNotification> getNotifications() {
    return List.from(_notificationsList);
  }

  // Modified to be a pure scheduler, mostly called by Provider now
  static Future<void> scheduleFromList(
    List<DailyNotification> notifications,
  ) async {
    try {
      await _notifications.cancelAll();
      for (final n in notifications) {
        if (n.isEnabled) {
          await _scheduleDailyNotification(n);
        }
      }
      _notificationsList = notifications; // Keep in memory for UI if needed
    } catch (e) {
      debugPrint('Error scheduling from list: $e');
    }
  }

  static Future<void> addNotification(
    String title,
    String body,
    TimeOfDay time,
  ) async {
    // Legacy or local-only fallback
    // In new flow, Provider calls API then calls scheduleFromList
  }

  static Future<void> updateNotification(DailyNotification notification) async {
    try {
      final index = _notificationsList.indexWhere(
        (n) => n.id == notification.id,
      );
      if (index != -1) {
        _notificationsList[index] = notification;
        await _saveNotifications();

        // Cancel old notification and schedule new one
        await _notifications.cancel(notification.notificationId);
        if (notification.isEnabled) {
          await _scheduleDailyNotification(notification);
        }
      }
    } catch (e) {
      debugPrint('Error updating notification: $e');
    }
  }

  static Future<void> deleteNotification(String id) async {
    try {
      final notification = _notificationsList.firstWhere((n) => n.id == id);
      await _notifications.cancel(notification.notificationId);

      _notificationsList.removeWhere((n) => n.id == id);
      await _saveNotifications();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  static Future<void> toggleNotification(String id) async {
    try {
      final index = _notificationsList.indexWhere((n) => n.id == id);
      if (index != -1) {
        final notification = _notificationsList[index];
        final updated = notification.copyWith(
          isEnabled: !notification.isEnabled,
        );
        await updateNotification(updated);
      }
    } catch (e) {
      debugPrint('Error toggling notification: $e');
    }
  }

  static Future<void> _scheduleDailyNotification(
    DailyNotification notification,
  ) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        notification.time.hour,
        notification.time.minute,
      );

      // If the time has passed today, schedule for tomorrow
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      debugPrint('Current time: $now');
      debugPrint('Scheduling notification for: $scheduledTime');

      const androidDetails = AndroidNotificationDetails(
        'daily_notifications',
        'Daily Notifications',
        channelDescription: 'Daily notification reminders',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        icon: '@drawable/ic_stat_notification',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        notification.notificationId,
        notification.title,
        notification.body,
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint(
        '✅ Successfully scheduled notification: ${notification.title} at $scheduledTime (ID: ${notification.notificationId})',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error scheduling notification: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  static Future<void> sendTestNotification() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'test_channel',
        'Test Notifications',
        channelDescription: 'Test notification channel',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_stat_notification',
        color: Color(0xFF7F3DFF), // Finoteku Purple Branding
        largeIcon: DrawableResourceAndroidBitmap(
          '@mipmap/ic_launcher',
        ), // Full Color Icon
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        0,
        'Test Notification',
        'Coba klik notifikasi ini untuk input transaksi!',
        details,
        payload: 'transaction_add',
      );
      debugPrint('✅ Test notification sent');
    } catch (e) {
      debugPrint('❌ Error sending test notification: $e');
    }
  }

  /// Test scheduled notification - fires in 10 seconds
  /// Uses zonedSchedule with fallback to inexact mode
  static Future<void> sendTestScheduledNotification() async {
    // 1. Ensure Timezone is ready
    try {
      try {
        final now = tz.TZDateTime.now(tz.local);
        debugPrint('Timezone Valid: ${now.location.name} - $now');
      } catch (e) {
        debugPrint('⚠️ Timezone not ready, re-initializing to Asia/Jakarta...');
        tz.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      }

      final scheduledTime = tz.TZDateTime.now(
        tz.local,
      ).add(const Duration(seconds: 10));

      debugPrint('📅 Scheduling test notification for: $scheduledTime');

      const androidDetails = AndroidNotificationDetails(
        'test_channel',
        'Test Notifications',
        channelDescription: 'Test notification channel',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        icon: '@drawable/ic_stat_notification',
        color: Color(0xFF7F3DFF), // Finoteku Purple Branding
        largeIcon: DrawableResourceAndroidBitmap(
          '@mipmap/ic_launcher',
        ), // Full Color Icon
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Try exact scheduling first
      try {
        await _notifications.zonedSchedule(
          998,
          'Test Scheduled',
          'Notifikasi terjadwal berhasil! (10 detik)',
          scheduledTime,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          // Removed uiLocalNotificationDateInterpretation due to compilation error
          // The plugin version resolved may treat this as optional or implicit
          payload: 'transaction_add',
        );
        debugPrint('✅ Scheduled with EXACT mode');
      } catch (exactError) {
        debugPrint('⚠️ Exact scheduling failed: $exactError');
        debugPrint('Trying inexact mode...');

        // Fallback to inexact
        await _notifications.zonedSchedule(
          998,
          'Test Scheduled (Inexact)',
          'Klik untuk input transaksi!',
          scheduledTime,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'transaction_add',
        );
        debugPrint('✅ Scheduled with INEXACT mode');
      }

      debugPrint('✅ Test notification command completed');
    } catch (e, stackTrace) {
      debugPrint('❌ Error scheduling test notification: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Alternative test using Future.delayed - useful for diagnosing emulator issues
  static Future<void> sendDelayedTestNotification() async {
    debugPrint('⏰ Starting delayed notification test (10 seconds)...');

    await Future.delayed(const Duration(seconds: 10));

    debugPrint('⏰ Delay complete, sending notification now...');
    await sendTestNotification();
  }

  static Future<void> rescheduleAllNotifications() async {
    try {
      await _notifications.cancelAll();

      for (final notification in _notificationsList) {
        if (notification.isEnabled) {
          await _scheduleDailyNotification(notification);
        }
      }
    } catch (e) {
      debugPrint('Error rescheduling notifications: $e');
    }
  }

  /// Update timezone and reschedule all notifications
  static Future<void> updateTimezone() async {
    try {
      if (_userService != null) {
        final userTimezone = await _userService!.getUserTimezone();
        tz.setLocalLocation(tz.getLocation(userTimezone));
        debugPrint('Notification timezone updated to: $userTimezone');

        // Reschedule all active notifications with new timezone
        await rescheduleAllNotifications();
      }
    } catch (e) {
      debugPrint('Error updating timezone: $e');
    }
  }

  /// Get list of active notification channels (Android Only)
  static Future<List<AndroidNotificationChannel>?>
  getNotificationChannels() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      return await androidPlugin.getNotificationChannels();
    }
    return null;
  }

  /// Check pending notifications (Debug)
  static Future<List<PendingNotificationRequest>>
  checkPendingNotifications() async {
    final pending = await _notifications.pendingNotificationRequests();
    debugPrint('=== Pending Notifications: ${pending.length} ===');
    for (var p in pending) {
      debugPrint(
        'ID: ${p.id}, Title: ${p.title}, Body: ${p.body}, Payload: ${p.payload}',
      );
    }
    return pending;
  }
}
