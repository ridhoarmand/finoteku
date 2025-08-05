import 'package:flutter/material.dart';

import '../models/daily_notification.dart';

class NotificationListItem extends StatelessWidget {
  final DailyNotification notification;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const NotificationListItem({
    super.key,
    required this.notification,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          notification.isEnabled
              ? Icons.notifications_active
              : Icons.notifications_off,
          color: notification.isEnabled
              ? Theme.of(context).primaryColor
              : Colors.grey,
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: notification.isEnabled ? null : Colors.grey,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              style: TextStyle(
                color: notification.isEnabled ? null : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${notification.time.hour.toString().padLeft(2, '0')}:${notification.time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 12,
                color: notification.isEnabled
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: notification.isEnabled,
              onChanged: (_) => onToggle(),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Hapus',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
