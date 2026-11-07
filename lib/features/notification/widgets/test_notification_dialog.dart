import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/notification_service.dart';

class TestNotificationDialog extends StatefulWidget {
  const TestNotificationDialog({super.key});

  @override
  State<TestNotificationDialog> createState() => _TestNotificationDialogState();
}

class _TestNotificationDialogState extends State<TestNotificationDialog> {
  // Debug State
  bool _isNotificationGranted = false;
  bool _isExactAlarmGranted = false;
  List<PendingNotificationRequest> _pendingNotifications = [];
  List<AndroidNotificationChannel> _channels = [];
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    if (kDebugMode) {
      _checkPendingNotifications();
      _loadChannels();
    }
  }

  Future<void> _checkPermissions() async {
    final notifStatus = await Permission.notification.status;

    // Check exact alarm logic
    bool exact = false;
    // Simple check for UI purposes
    if (await Permission.scheduleExactAlarm.status.isGranted) {
      exact = true;
    }
    // Android 11- (SDK < 31) implicit exact alarm
    // We assume true for simplicity in UI if not explicitly denied/restricted

    if (mounted) {
      setState(() {
        _isNotificationGranted = notifStatus.isGranted;
        _isExactAlarmGranted = exact;
      });
    }
  }

  Future<void> _checkPendingNotifications() async {
    final pending = await NotificationService.checkPendingNotifications();
    if (mounted) {
      setState(() {
        _pendingNotifications = pending;
        _pendingCount = pending.length;
      });
    }
  }

  Future<void> _loadChannels() async {
    // This method is for debugging channel registration on Android
    final channels = await NotificationService.getNotificationChannels();
    if (mounted) {
      setState(() {
        _channels = channels ?? [];
      });
    }
  }

  Future<void> _sendTest() async {
    await NotificationService.sendTestNotification();
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notifikasi dikirim!')));
    }
  }

  Future<void> _sendDelayedTest() async {
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Menunggu 5 detik...')));
    }
    await NotificationService.sendDelayedTestNotification();
  }

  Future<void> _sendScheduledTest() async {
    // Schedule notification
    await NotificationService.sendTestScheduledNotification();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifikasi dijadwalkan dalam 10 detik!')),
      );
      // Refresh pending list if looking at debug details
      if (kDebugMode) {
        _checkPendingNotifications();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(PhRegular.bellRinging, color: Colors.blue),
          SizedBox(width: 8),
          Text('Test Notifikasi'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih jenis tes notifikasi:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // ACTION BUTTONS (Always Visible)
            const Text(
              'Test Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionBtn(
                  icon: PhRegular.bell,
                  label: 'Instant',
                  onTap: _sendTest,
                  color: Colors.blue,
                ),
                _ActionBtn(
                  icon: PhRegular.timer,
                  label: 'Delay 5s',
                  onTap: _sendDelayedTest,
                  color: Colors.orange,
                ),
                _ActionBtn(
                  icon: PhRegular.clock,
                  label: 'Terjadwal',
                  onTap: _sendScheduledTest,
                  color: Colors.purple,
                ),
              ],
            ),

            // DEBUG SECTION (Conditional)
            if (kDebugMode) ...[
              const SizedBox(height: 24),
              const Divider(),
              const Center(
                child: Text(
                  '[DEBUG INFO]',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Permission Status
              _SectionHeader(title: 'Permission Status', icon: PhRegular.lock),
              _StatusRow(
                label: 'Notifications',
                isGranted: _isNotificationGranted,
              ),
              _StatusRow(label: 'Exact Alarm', isGranted: _isExactAlarmGranted),
              const Divider(),

              // Pending Schedules
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SectionHeader(
                    title: 'Pending Schedule ($_pendingCount)',
                    icon: PhRegular.listChecks,
                  ),
                  IconButton(
                    icon: const Icon(PhRegular.arrowClockwise, size: 20),
                    onPressed: _checkPendingNotifications,
                    tooltip: 'Refresh Pending',
                  ),
                ],
              ),
              if (_pendingNotifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'No pending notifications',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ..._pendingNotifications.map(
                  (n) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(n.title ?? 'No Title'),
                    subtitle: Text('ID: ${n.id} • ${n.body}'),
                    leading: const Icon(
                      PhRegular.clock,
                      color: Colors.purple,
                      size: 20,
                    ),
                  ),
                ),
              const Divider(),

              // Channels
              _SectionHeader(
                title: 'Active Android Channels',
                icon: PhRegular.list,
              ),
              if (_channels.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'No channels found',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ..._channels.map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(c.name),
                    subtitle: Text('ID: ${c.id} • Imp: ${c.importance}'),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}

// Helper Widgets
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                // Fix deprecated withOpacity -> withAlpha (0.1 * 255 ~= 25)
                color: color.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool isGranted;

  const _StatusRow({required this.label, required this.isGranted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              // Fix deprecated withOpacity -> withAlpha (0.1 * 255 ~= 25)
              color: isGranted
                  ? Colors.green.withAlpha(25)
                  : Colors.red.withAlpha(25),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isGranted ? Colors.green : Colors.red,
                width: 0.5,
              ),
            ),
            child: Text(
              isGranted ? 'GRANTED' : 'DENIED',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isGranted ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
