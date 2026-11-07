import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_notification.dart';
import '../services/notification_service.dart';
import '../services/notification_sync_service.dart';

// Note: We access the Supabase client through the NotificationSyncService to get currentUser

// Provider untuk list notifications
final notificationListProvider =
    NotifierProvider<NotificationListNotifier, List<DailyNotification>>(() {
      return NotificationListNotifier();
    });

class NotificationListNotifier extends Notifier<List<DailyNotification>> {
  @override
  List<DailyNotification> build() {
    // Initial fetch
    _syncNotifications();
    return [];
  }

  Future<void> _syncNotifications() async {
    try {
      final syncService = ref.read(notificationSyncServiceProvider);
      // Try to get userId from Auth Provider
      // We assume authServiceProvider exists based on conventions,
      // but to be safe/clean we can get it from Supabase auth directly if needed
      // or through the proper Auth provider.
      // Let's use the Supabase user ID directly from the sync service's client if possible,
      // or assume the caller is authenticated.
      // Better: Watch the auth state or user.

      // For now, let's fetch current user ID from Supabase Auth instance
      // We can get it via the sync service's supabase client if public, or ref.read(supabaseProvider).auth.currentUser.

      // Let's rely on finding the userId
      final user = ref.read(notificationSyncServiceProvider).currentUser;

      if (user == null) {
        // Fallback to local only or empty
        final local = NotificationService.getNotifications();
        state = local;
        return;
      }

      final remoteNotifications = await syncService.getReminders(user.id);

      // Update Local State
      state = remoteNotifications;

      // Reschedule Local Alarms to match Remote
      await NotificationService.scheduleFromList(remoteNotifications);
    } catch (e) {
      debugPrint('Sync notifications error: $e');
      // If offline, maybe load local?
      // NotificationService.getNotifications();
    }
  }

  Future<void> addNotification(
    String title,
    String body,
    TimeOfDay time,
  ) async {
    try {
      final user = ref.read(notificationSyncServiceProvider).currentUser;
      if (user != null) {
        final syncService = ref.read(notificationSyncServiceProvider);
        await syncService.createReminder(
          userId: user.id,
          title: title,
          message: body,
          time: time,
        );

        // Update State & Reschedule
        await _syncNotifications();
      } else {
        // Fallback local if needed (but we want sync)
        debugPrint('User not logged in, cannot add synced notification');
      }
    } catch (e) {
      debugPrint('Error adding notification: $e');
    }
  }

  Future<void> updateNotification(DailyNotification notification) async {
    try {
      final user = ref.read(notificationSyncServiceProvider).currentUser;
      if (user != null) {
        final syncService = ref.read(notificationSyncServiceProvider);
        await syncService.updateReminder(
          reminderId: notification.id,
          userId: user.id,
          title: notification.title,
          message: notification.body,
          time: notification.time,
          isEnabled: notification.isEnabled,
        );
        await _syncNotifications();
      }
    } catch (e) {
      debugPrint('Error updating notification: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      final user = ref.read(notificationSyncServiceProvider).currentUser;
      if (user != null) {
        final syncService = ref.read(notificationSyncServiceProvider);
        await syncService.deleteReminder(id, user.id);
        await _syncNotifications();
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> toggleNotification(String id) async {
    try {
      final notification = state.firstWhere((n) => n.id == id);
      final user = ref.read(notificationSyncServiceProvider).currentUser;

      if (user != null) {
        final syncService = ref.read(notificationSyncServiceProvider);
        await syncService.toggleReminder(id, user.id, !notification.isEnabled);
        await _syncNotifications();
      }
    } catch (e) {
      debugPrint('Error toggling notification: $e');
    }
  }
}
