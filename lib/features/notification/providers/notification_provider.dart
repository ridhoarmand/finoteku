import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_notification.dart';
import '../services/notification_service.dart';

// Provider untuk list notifications
final notificationListProvider = NotifierProvider<NotificationListNotifier, List<DailyNotification>>(
  NotificationListNotifier.new,
);

class NotificationListNotifier extends Notifier<List<DailyNotification>> {
  @override
  List<DailyNotification> build() {
    loadNotifications();
    return [];
  }

  Future<void> loadNotifications() async {
    try {
      final notifications = NotificationService.getNotifications();
      state = notifications;
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  Future<void> addNotification(String title, String body, TimeOfDay time) async {
    try {
      await NotificationService.addNotification(title, body, time);
      await loadNotifications();
    } catch (e) {
      debugPrint('Error adding notification: $e');
    }
  }

  Future<void> updateNotification(DailyNotification notification) async {
    try {
      await NotificationService.updateNotification(notification);
      await loadNotifications();
    } catch (e) {
      debugPrint('Error updating notification: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await NotificationService.deleteNotification(id);
      await loadNotifications();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> toggleNotification(String id) async {
    try {
      await NotificationService.toggleNotification(id);
      await loadNotifications();
    } catch (e) {
      debugPrint('Error toggling notification: $e');
    }
  }
}

// Provider untuk sending test notification
final testNotificationProvider = FutureProvider.autoDispose.family<void, void>((ref, _) async {
  await NotificationService.sendTestNotification();
});
