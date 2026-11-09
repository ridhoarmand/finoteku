import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:finoteku/theme/app_theme.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import '../providers/notification_provider.dart';
import '../services/notification_service.dart';
import '../widgets/widgets.dart';
import '../../../core/localization/app_localizations.dart';

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
      // Sync happens automatically on provider build
      // ref.read(notificationListProvider.notifier).loadNotifications();
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
        title: Row(
          children: [
            Icon(PhRegular.bellRinging, color: Theme.of(context).colorScheme.primary),
            SizedBox(width: 8),
            Text(ref.tr(context, 'notif_permission_title')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ref.tr(context, 'notif_permission_body')),
            const SizedBox(height: 16),
            _buildPermissionItem(
              ref.tr(context, 'notif_perm_notifications'),
              ref.tr(context, 'notif_perm_notifications_desc'),
              hasNotif,
            ),
            const SizedBox(height: 8),
            _buildPermissionItem(
              ref.tr(context, 'notif_perm_exact_alarm'),
              ref.tr(context, 'notif_perm_exact_alarm_desc'),
              hasExactAlarm,
            ),
            const SizedBox(height: 16),
            if (!hasExactAlarm)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ref.tr(context, 'notif_permission_manual'),
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(ref.tr(context, 'later')),
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
            child: Text(ref.tr(context, 'notif_grant_permission')),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(String title, String subtitle, bool granted) {
    return Row(
      children: [
        Icon(
          granted ? PhFill.checkCircle : PhRegular.xCircle,
          color: granted ? context.colors.income : Theme.of(context).colorScheme.error,
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
                style: TextStyle(fontSize: 12, color: context.colors.muted),
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
        title: Text(ref.tr(context, 'notif_title')),
        actions: [
          IconButton(
            icon: const Icon(PhRegular.bellRinging),
            onPressed: _showTestNotificationDialog,
            tooltip: ref.tr(context, 'notif_test'),
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
              color: context.colors.sunken,
              child: Row(
                children: [
                  Icon(PhRegular.info, size: 18, color: Theme.of(context).colorScheme.onSurface),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ref.tr(context, 'notif_emulator_warning'),
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface),
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
        icon: const Icon(PhRegular.plus),
        label: Text(ref.tr(context, 'add')),
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
