import 'package:flutter/material.dart';

import '../services/notification_service.dart';

class TestNotificationDialog extends StatelessWidget {
  const TestNotificationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kirim Notifikasi'),
      content: const Text('Apakah Anda yakin ingin mengirim notifikasi test?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => _sendTestNotification(context),
          child: const Text('Kirim'),
        ),
      ],
    );
  }

  void _sendTestNotification(BuildContext context) async {
    try {
      await NotificationService.sendTestNotification();

      if (context.mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notifikasi dikirim!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim notifikasi: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
