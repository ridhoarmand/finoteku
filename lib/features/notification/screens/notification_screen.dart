import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notification_provider.dart';
import '../widgets/widgets.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: const NotificationListWidget(),
      floatingActionButton: _buildFloatingActionButton(context, ref),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Notifikasi'),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_active),
          onPressed: () => _showTestNotificationDialog(context),
          tooltip: 'Test Notifikasi',
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      onPressed: () => _showAddDialog(context, ref),
      child: const Icon(Icons.add),
    );
  }

  void _showTestNotificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const TestNotificationDialog(),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => NotificationDialog(
        onSave: (title, body, time) => _addNotification(ref, title, body, time),
      ),
    );
  }

  void _addNotification(WidgetRef ref, String title, String body, TimeOfDay time) {
    ref.read(notificationListProvider.notifier).addNotification(title, body, time);
  }
}
