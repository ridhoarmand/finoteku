import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/report_providers.dart';
import '../models/report_models.dart';
import '../../../core/localization/app_localizations.dart';

class ReportHeader extends ConsumerWidget {
  const ReportHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportStateProvider);
    final canGoToPrevious = ref.watch(canGoToPreviousPeriodProvider);
    final canGoToNext = ref.watch(canGoToNextPeriodProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          // Previous period button
          IconButton(
            onPressed: canGoToPrevious ? () => goToPreviousPeriod(ref) : null,
            icon: const Icon(Icons.chevron_left),
            iconSize: 24,
            tooltip: ref.tr(context, 'previous_period'),
          ),

          // Period display
          Expanded(
            child: Center(
              child: Text(
                _formatPeriod(context, state),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Next period button
          IconButton(
            onPressed: canGoToNext ? () => goToNextPeriod(ref) : null,
            icon: const Icon(Icons.chevron_right),
            iconSize: 24,
            tooltip: ref.tr(context, 'next_period'),
          ),

          const SizedBox(width: 16),

          // Period type dropdown (moved to right)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ReportPeriod>(
                value: state.period,
                isDense: true,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 14),
                items: ReportPeriod.values.map((period) {
                  return DropdownMenuItem(
                    value: period,
                    child: Text(_getPeriodName(context, ref, period)),
                  );
                }).toList(),
                onChanged: (ReportPeriod? newPeriod) {
                  if (newPeriod != null) {
                    changePeriodType(ref, newPeriod);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPeriod(BuildContext context, ReportState state) {
    switch (state.period) {
      case ReportPeriod.weekly:
        final weekStart = state.selectedMonth.subtract(
          Duration(days: state.selectedMonth.weekday - 1),
        );
        final weekEnd = weekStart.add(const Duration(days: 6));
        return '${_formatDate(weekStart)} - ${_formatDate(weekEnd)}';
      case ReportPeriod.monthly:
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'Mei',
          'Jun',
          'Jul',
          'Agu',
          'Sep',
          'Okt',
          'Nov',
          'Des',
        ];
        return '${months[state.selectedMonth.month - 1]} ${state.selectedMonth.year}';
      case ReportPeriod.yearly:
        return state.selectedMonth.year.toString();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}';
  }

  String _getPeriodName(
    BuildContext context,
    WidgetRef ref,
    ReportPeriod period,
  ) {
    switch (period) {
      case ReportPeriod.weekly:
        return ref.tr(context, 'period_weekly');
      case ReportPeriod.monthly:
        return ref.tr(context, 'period_monthly');
      case ReportPeriod.yearly:
        return ref.tr(context, 'period_yearly');
    }
  }
}
