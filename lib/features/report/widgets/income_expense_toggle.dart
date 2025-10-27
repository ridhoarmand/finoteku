import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/report_providers.dart';
import '../models/report_models.dart';
import '../../../core/localization/app_localizations.dart';

class IncomeExpenseToggle extends ConsumerWidget {
  const IncomeExpenseToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportStateProvider);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (state.type != ReportType.expense) {
                  ref
                      .read(reportStateProvider.notifier)
                      .updateState(state.copyWith(type: ReportType.expense));
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: state.type == ReportType.expense
                      ? Colors.red[400]
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  ref.tr(context, 'expense'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: state.type == ReportType.expense
                        ? Colors.white
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: state.type == ReportType.expense
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (state.type != ReportType.income) {
                  ref
                      .read(reportStateProvider.notifier)
                      .updateState(state.copyWith(type: ReportType.income));
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: state.type == ReportType.income
                      ? Colors.green[400]
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  ref.tr(context, 'income'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: state.type == ReportType.income
                        ? Colors.white
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: state.type == ReportType.income
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
