import 'package:flutter/material.dart';

class DateSection extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const DateSection({super.key, required this.date, required this.onTap});

  static String format(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) return 'Today';
    if (date.year == now.year && date.month == now.month && date.day == now.day - 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.calendar_today),
          title: const Text('Transaction Date'),
          subtitle: Text(format(date)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
        ),
      );
}
