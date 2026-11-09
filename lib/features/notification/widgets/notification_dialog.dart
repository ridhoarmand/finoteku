import 'package:flutter/material.dart';
import 'package:finoteku/theme/app_theme.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';

import '../models/daily_notification.dart';

class NotificationDialog extends ConsumerStatefulWidget {
  final DailyNotification? notification;
  final Function(String title, String body, TimeOfDay time) onSave;

  const NotificationDialog({
    super.key,
    this.notification,
    required this.onSave,
  });

  @override
  ConsumerState<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends ConsumerState<NotificationDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.notification?.title ?? 'Pengingat Harian',
    );
    _bodyController = TextEditingController(
      text:
          widget.notification?.body ?? 'Jangan lupa catat pengeluaran kamu! ',
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
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTitleField(),
            const SizedBox(height: 16),
            _buildBodyField(),
            const SizedBox(height: 16),
            _buildTimeSelector(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(ref.tr(context, 'cancel')),
        ),
        FilledButton(onPressed: _save, child: Text(ref.tr(context, 'save'))),
      ],
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      decoration: InputDecoration(
        labelText: ref.tr(context, 'notif_field_title'),
        hintText: ref.tr(context, 'notif_field_title_hint'),
        border: OutlineInputBorder(),
        prefixIcon: Icon(PhRegular.textT),
      ),
    );
  }

  Widget _buildBodyField() {
    return TextField(
      controller: _bodyController,
      decoration: InputDecoration(
        labelText: ref.tr(context, 'notif_field_message'),
        hintText: ref.tr(context, 'notif_field_message_hint'),
        border: OutlineInputBorder(),
        prefixIcon: Icon(PhRegular.chatText),
      ),
      maxLines: 2,
    );
  }

  Widget _buildTimeSelector() {
    return InkWell(
      onTap: _selectTime,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.muted),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(PhRegular.clock, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.tr(context, 'notif_time'),
                  style: TextStyle(fontSize: 12, color: context.colors.muted),
                ),
                Text(
                  '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(PhRegular.pencilSimple, size: 18, color: context.colors.muted),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        // Force 24-hour format
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (!mounted) return;

    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  void _save() {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.tr(context, 'notif_required_fields')),
        ),
      );
      return;
    }

    widget.onSave(title, body, _selectedTime);
    Navigator.of(context).pop();
  }
}
