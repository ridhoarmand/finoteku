import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../models/daily_notification.dart';
import '../../../services/user_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static const String _storageKey = 'daily_notifications';
  static List<DailyNotification> _notificationsList = [];
  static UserService? _userService;

  static Future<void> initialize({UserService? userService}) async {
    try {
      _userService = userService;
      
      // Initialize timezone
      tz.initializeTimeZones();
      
      // Get user timezone or use default
      String userTimezone = 'Asia/Jakarta'; // Default
      if (_userService != null) {
        try {
          userTimezone = await _userService!.getUserTimezone();
        } catch (e) {
          debugPrint('Failed to get user timezone, using default: $e');
        }
      }
      
      tz.setLocalLocation(tz.getLocation(userTimezone));
      debugPrint('Notification timezone set to: $userTimezone');

      // Initialize notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(initSettings);
      await _requestPermissions();
      await loadNotifications();
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
    }
  }

  static Future<void> _requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
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

  static Future<void> addNotification(String title, String body, TimeOfDay time) async {
    try {
      final notification = DailyNotification(
        id: const Uuid().v4(),
        title: title,
        body: body,
        time: time,
        isEnabled: true,
        createdAt: DateTime.now(),
      );

      _notificationsList.add(notification);
      await _saveNotifications();
      await _scheduleDailyNotification(notification);
    } catch (e) {
      debugPrint('Error adding notification: $e');
    }
  }

  static Future<void> updateNotification(DailyNotification notification) async {
    try {
      final index = _notificationsList.indexWhere((n) => n.id == notification.id);
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
        final updated = notification.copyWith(isEnabled: !notification.isEnabled);
        await updateNotification(updated);
      }
    } catch (e) {
      debugPrint('Error toggling notification: $e');
    }
  }

  static Future<void> _scheduleDailyNotification(DailyNotification notification) async {
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

      const androidDetails = AndroidNotificationDetails(
        'daily_notifications',
        'Daily Notifications',
        channelDescription: 'Daily notification reminders',
        importance: Importance.high,
        priority: Priority.high,
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

      debugPrint('Scheduled notification: ${notification.title} at $scheduledTime');
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
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
        999,
        'Test Notification',
        'This is a test notification from Finoteku',
        details,
      );
    } catch (e) {
      debugPrint('Error sending test notification: $e');
    }
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
}
