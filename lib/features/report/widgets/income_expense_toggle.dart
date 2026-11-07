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
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ReportType>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: ReportType.expense, label: Text(ref.tr(context, 'expense'))),
          ButtonSegment(value: ReportType.income, label: Text(ref.tr(context, 'income'))),
        ],
        selected: {state.type},
        onSelectionChanged: (s) =>
            ref.read(reportStateProvider.notifier).updateState(state.copyWith(type: s.first)),
      ),
    );
  }
}
