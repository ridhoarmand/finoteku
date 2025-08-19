import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analytics_providers.dart';
import '../widgets/period_selector.dart';
import '../widgets/income_expense_bar.dart';
import '../widgets/expense_category_pie.dart';
import '../widgets/summary_stats_row.dart';

/// Layar utama Analitik yang kini hanya merangkai widget modular.
class ChartScreen extends ConsumerWidget {
  const ChartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analitik'),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(rangeTransactionsProvider);
          ref.invalidate(incomeExpenseSummaryProvider);
          ref.invalidate(expenseByCategoryProvider);
          ref.invalidate(transactionCountProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PeriodSelector(),
              SizedBox(height: 16),
              IncomeExpenseBarCard(),
              SizedBox(height: 16),
              ExpenseCategoryPieCard(),
              SizedBox(height: 16),
              SummaryStatsRow(),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
