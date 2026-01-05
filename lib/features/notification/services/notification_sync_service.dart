import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_service.dart';
import '../../../core/errors/failure.dart';
import '../../../core/logging/logger.dart';
import '../models/daily_notification.dart';

/// Provider for NotificationSyncService
final notificationSyncServiceProvider = Provider<NotificationSyncService>((
  ref,
) {
  final supabase = ref.watch(supabaseProvider);
  return NotificationSyncService(supabase);
});

/// Service for syncing notifications to Supabase
class NotificationSyncService {
  final SupabaseClient _supabase;

  NotificationSyncService(this._supabase);

  /// Fetch all notification reminders from Supabase
  Future<List<DailyNotification>> getReminders(String userId) async {
    try {
      final response = await _supabase
          .from('notification_reminders')
          .select('*')
          .eq('user_id', userId)
          .order('created_at');

      if (response.isEmpty) return [];

      return (response as List).map((json) {
        return DailyNotification(
          id: json['id'] as String,
          title: json['title'] as String,
          body: json['message'] as String,
          time: TimeOfDay(
            hour: json['hour'] as int,
            minute: json['minute'] as int,
          ),
          isEnabled: json['is_enabled'] as bool? ?? true,
          createdAt: DateTime.parse(json['created_at'] as String),
        );
      }).toList();
    } catch (e, st) {
      AppLogger.e('getReminders error', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  /// Create a new notification reminder in Supabase
  Future<DailyNotification> createReminder({
    required String userId,
    required String title,
    required String message,
    required TimeOfDay time,
  }) async {
    try {
      final data = {
        'user_id': userId,
        'title': title,
        'message': message,
        'hour': time.hour,
        'minute': time.minute,
        'is_enabled': true,
      };

      final response = await _supabase
          .from('notification_reminders')
          .insert(data)
          .select()
          .single();

      return DailyNotification(
        id: response['id'] as String,
        title: response['title'] as String,
        body: response['message'] as String,
        time: TimeOfDay(
          hour: response['hour'] as int,
          minute: response['minute'] as int,
        ),
        isEnabled: response['is_enabled'] as bool? ?? true,
        createdAt: DateTime.parse(response['created_at'] as String),
      );
    } catch (e, st) {
      AppLogger.e('createReminder error', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  /// Update an existing notification reminder
  Future<DailyNotification> updateReminder({
    required String reminderId,
    required String userId,
    String? title,
    String? message,
    TimeOfDay? time,
    bool? isEnabled,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (message != null) data['message'] = message;
      if (time != null) {
        data['hour'] = time.hour;
        data['minute'] = time.minute;
      }
      if (isEnabled != null) data['is_enabled'] = isEnabled;

      final response = await _supabase
          .from('notification_reminders')
          .update(data)
          .eq('id', reminderId)
          .eq('user_id', userId)
          .select()
          .single();

      return DailyNotification(
        id: response['id'] as String,
        title: response['title'] as String,
        body: response['message'] as String,
        time: TimeOfDay(
          hour: response['hour'] as int,
          minute: response['minute'] as int,
        ),
        isEnabled: response['is_enabled'] as bool? ?? true,
        createdAt: DateTime.parse(response['created_at'] as String),
      );
    } catch (e, st) {
      AppLogger.e('updateReminder error', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  /// Delete a notification reminder
  Future<void> deleteReminder(String reminderId, String userId) async {
    try {
      await _supabase
          .from('notification_reminders')
          .delete()
          .eq('id', reminderId)
          .eq('user_id', userId);
    } catch (e, st) {
      AppLogger.e('deleteReminder error', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  /// Toggle enabled state of a reminder
  Future<DailyNotification> toggleReminder(
    String reminderId,
    String userId,
    bool isEnabled,
  ) async {
    return updateReminder(
      reminderId: reminderId,
      userId: userId,
      isEnabled: isEnabled,
    );
  }
}
