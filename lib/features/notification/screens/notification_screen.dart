import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import '../providers/notification_provider.dart';
import '../services/notification_service.dart';
import '../widgets/widgets.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Refresh notification list to ensure we have latest data
      ref.read(notificationListProvider.notifier).loadNotifications();
      _checkAndRequestPermissions();
    });
  }

  Future<void> _checkAndRequestPermissions() async {
    if (!Platform.isAndroid) return;

    // Check status first
    final permissions = await NotificationService.checkPermissions();
    final hasNotificationPermission = permissions['notifications'] ?? false;
    final hasExactAlarmPermission = permissions['exactAlarm'] ?? false;

    if (!mounted) return;

    // If permissions are missing, try to request them immediately (system dialog)
    if (!hasNotificationPermission || !hasExactAlarmPermission) {
      await NotificationService.requestPermissions();

      // Check again after request
      if (!mounted) return;
      final newPermissions = await NotificationService.checkPermissions();
      final newHasNotif = newPermissions['notifications'] ?? false;
      final newHasExact = newPermissions['exactAlarm'] ?? false;

      // If still missing (user denied or permanently denied), show custom dialog
      if (!newHasNotif || !newHasExact) {
        _showPermissionDialog(newHasNotif, newHasExact);
      }
    }
  }

  void _showPermissionDialog(bool hasNotif, bool hasExactAlarm) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.orange),
            SizedBox(width: 8),
            Text('Izin Diperlukan'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Untuk notifikasi dapat berjalan dengan baik, aplikasi memerlukan izin berikut:',
            ),
            const SizedBox(height: 16),
            _buildPermissionItem(
              'Notifikasi',
              'Menampilkan pengingat',
              hasNotif,
            ),
            const SizedBox(height: 8),
            _buildPermissionItem(
              'Alarm Presisi',
              'Mengirim tepat waktu',
              hasExactAlarm,
            ),
            const SizedBox(height: 16),
            if (!hasExactAlarm)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Jika izin tidak muncul otomatis, buka:\nSettings → Apps → Finoteku → Alarms & reminders → Allow',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              navigator.pop();
              // Request both permissions
              await NotificationService.requestPermissions();
              // Await a bit for system dialogs
              await Future.delayed(const Duration(milliseconds: 1000));
              if (mounted) {
                await _checkAndRequestPermissions();
              }
            },
            child: const Text('Berikan Izin'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(String title, String subtitle, bool granted) {
    return Row(
      children: [
        Icon(
          granted ? Icons.check_circle : Icons.cancel,
          color: granted ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            onPressed: _showTestNotificationDialog,
            tooltip: 'Test Notifikasi',
          ),
        ],
      ),
      body: Column(
        children: [
          // Emulator warning only in debug mode
          if (kDebugMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange[100],
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.orange[800]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notifikasi terjadwal mungkin tidak berfungsi di emulator.',
                      style: TextStyle(fontSize: 11, color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
            ),
          const Expanded(child: NotificationListWidget()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    );
  }

  void _showTestNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => const TestNotificationDialog(),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => NotificationDialog(
        onSave: (title, body, time) {
          ref
              .read(notificationListProvider.notifier)
              .addNotification(title, body, time);
        },
      ),
    );
  }
}
