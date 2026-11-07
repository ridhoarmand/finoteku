import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../theme/app_theme.dart';

class DateSection extends ConsumerWidget {
  final DateTime date;
  final VoidCallback onTap;
  const DateSection({super.key, required this.date, required this.onTap});

  static String format(DateTime date, BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    if (d == today) return ref.tr(context, 'date_today');
    if (d == today.subtract(const Duration(days: 1))) return ref.tr(context, 'date_yesterday');
    return DateFormat('EEEE, d MMMM yyyy', Localizations.localeOf(context).toLanguageTag()).format(date);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = context.colors.muted;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(PhRegular.calendarBlank, color: theme.colorScheme.onSurface),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ref.tr(context, 'field_date'), style: theme.textTheme.labelMedium?.copyWith(color: muted)),
                  const SizedBox(height: 2),
                  Text(format(date, context, ref), style: theme.textTheme.titleSmall),
                ],
              ),
            ),
            Icon(PhRegular.caretRight, size: 16, color: muted),
          ],
        ),
      ),
    );
  }
}
