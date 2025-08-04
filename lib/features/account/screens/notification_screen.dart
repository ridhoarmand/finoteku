import 'package:flutter/material.dart';
import '../../../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<DailyNotification> notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    setState(() {
      notifications = NotificationService.getNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            // Popup konfirmasi sebelum mengirim notifikasi
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Kirim Notifikasi'),
                    content: const Text(
                      'Apakah Anda yakin ingin mengirim notifikasi?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () {
                          _sendTestNotification();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Kirim'),
                      ),
                    ],
                  );
                },
              );
            },
            tooltip: 'Test Notifikasi',
          ),
        ],
      ),
      body: Column(
        children: [
          // Notifications list
          Expanded(
            child: notifications.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Belum ada notifikasi',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tambahkan notifikasi harian untuk mengingati aktivitas keuangan Anda',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
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
                              color: notification.isEnabled
                                  ? null
                                  : Colors.grey,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.body,
                                style: TextStyle(
                                  color: notification.isEnabled
                                      ? null
                                      : Colors.grey,
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
                                onChanged: (value) =>
                                    _toggleNotification(notification.id),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'edit':
                                      _showEditDialog(notification);
                                      break;
                                    case 'delete':
                                      _deleteNotification(notification.id);
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
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => _NotificationDialog(onSave: _addNotification),
    );
  }

  void _showEditDialog(DailyNotification notification) {
    showDialog(
      context: context,
      builder: (context) => _NotificationDialog(
        notification: notification,
        onSave: (title, body, time) =>
            _updateNotification(notification, title, body, time),
      ),
    );
  }

  void _addNotification(String title, String body, TimeOfDay time) async {
    await NotificationService.addNotification(title, body, time);
    _loadNotifications();
  }

  void _updateNotification(
    DailyNotification notification,
    String title,
    String body,
    TimeOfDay time,
  ) async {
    final updated = notification.copyWith(title: title, body: body, time: time);
    await NotificationService.updateNotification(updated);
    _loadNotifications();
  }

  void _deleteNotification(String id) async {
    await NotificationService.deleteNotification(id);
    _loadNotifications();
  }

  void _toggleNotification(String id) async {
    await NotificationService.toggleNotification(id);
    _loadNotifications();
  }

  void _sendTestNotification() async {
    // Popup konfirmasi sebelum mengirim notifikasi

    await NotificationService.sendTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notifikasi dikirim!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

class _NotificationDialog extends StatefulWidget {
  final DailyNotification? notification;
  final Function(String title, String body, TimeOfDay time) onSave;

  const _NotificationDialog({this.notification, required this.onSave});

  @override
  State<_NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<_NotificationDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.notification?.title ?? '',
    );
    _bodyController = TextEditingController(
      text: widget.notification?.body ?? '',
    );
    _selectedTime =
        widget.notification?.time ?? const TimeOfDay(hour: 19, minute: 0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.notification == null ? 'Tambah Notifikasi' : 'Edit Notifikasi',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Judul',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bodyController,
            decoration: const InputDecoration(
              labelText: 'Pesan',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _selectTime,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time),
                  const SizedBox(width: 8),
                  Text(
                    'Waktu: ${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }

  void _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  void _save() {
    if (_titleController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Judul dan pesan tidak boleh kosong'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onSave(
      _titleController.text.trim(),
      _bodyController.text.trim(),
      _selectedTime,
    );
    Navigator.of(context).pop();
  }
}
