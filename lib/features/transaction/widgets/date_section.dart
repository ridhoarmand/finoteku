import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';

class DateSection extends ConsumerWidget {
  final DateTime date;
  final VoidCallback onTap;
  const DateSection({super.key, required this.date, required this.onTap});

  static String format(DateTime date, BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return ref.tr(context, 'date_today');
    }
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      return ref.tr(context, 'date_yesterday');
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      leading: const Icon(Icons.calendar_today),
      title: Text(ref.tr(context, 'transaction_date_title')),
      subtitle: Text(format(date, context, ref)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    ),
  );
}
