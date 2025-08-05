import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_notification.dart';
import '../providers/notification_provider.dart';
import 'notification_empty_state.dart';
import 'notification_list_item.dart';
import 'notification_dialog.dart';

class NotificationListWidget extends ConsumerWidget {
  const NotificationListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationListProvider);

    if (notifications.isEmpty) {
      return const NotificationEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return NotificationListItem(
          notification: notification,
          onToggle: () => _toggleNotification(ref, notification.id),
          onEdit: () => _showEditDialog(context, ref, notification),
          onDelete: () => _deleteNotification(ref, notification.id),
        );
      },
    );
  }

  void _toggleNotification(WidgetRef ref, String id) {
    ref.read(notificationListProvider.notifier).toggleNotification(id);
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, DailyNotification notification) {
    showDialog(
      context: context,
      builder: (context) => NotificationDialog(
        notification: notification,
        onSave: (title, body, time) => _updateNotification(
          ref,
          notification,
          title,
          body,
          time,
        ),
      ),
    );
  }

  void _updateNotification(
    WidgetRef ref,
    DailyNotification notification,
    String title,
    String body,
    TimeOfDay time,
  ) {
    final updated = notification.copyWith(
      title: title,
      body: body,
      time: time,
    );
    ref.read(notificationListProvider.notifier).updateNotification(updated);
  }

  void _deleteNotification(WidgetRef ref, String id) {
    ref.read(notificationListProvider.notifier).deleteNotification(id);
  }
}
