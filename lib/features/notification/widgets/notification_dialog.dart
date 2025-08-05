import 'package:flutter/material.dart';

import '../models/daily_notification.dart';

class NotificationDialog extends StatefulWidget {
  final DailyNotification? notification;
  final Function(String title, String body, TimeOfDay time) onSave;

  const NotificationDialog({
    super.key,
    this.notification,
    required this.onSave,
  });

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<NotificationDialog> {
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
          _buildTitleField(),
          const SizedBox(height: 16),
          _buildBodyField(),
          const SizedBox(height: 16),
          _buildTimeSelector(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: 'Judul',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildBodyField() {
    return TextField(
      controller: _bodyController,
      decoration: const InputDecoration(
        labelText: 'Pesan',
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
    );
  }

  Widget _buildTimeSelector() {
    return InkWell(
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
