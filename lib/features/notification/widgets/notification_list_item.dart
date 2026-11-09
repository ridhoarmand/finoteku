import 'package:flutter/material.dart';
import 'package:finoteku/theme/app_theme.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';

import '../models/daily_notification.dart';

class NotificationListItem extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          notification.isEnabled
              ? PhRegular.bellRinging
              : PhRegular.bellSlash,
          color: notification.isEnabled
              ? Theme.of(context).primaryColor
              : context.colors.muted,
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: notification.isEnabled ? null : context.colors.muted,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              style: TextStyle(
                color: notification.isEnabled ? null : context.colors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${notification.time.hour.toString().padLeft(2, '0')}:${notification.time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 12,
                color: notification.isEnabled
                    ? Theme.of(context).primaryColor
                    : context.colors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: notification.isEnabled, onChanged: (_) => onToggle()),
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
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(PhRegular.pencilSimple),
                      SizedBox(width: 8),
                      Text(ref.tr(context, 'edit')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(PhRegular.trash, color: Theme.of(context).colorScheme.error),
                      SizedBox(width: 8),
                      Text(
                        ref.tr(context, 'delete'),
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
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
