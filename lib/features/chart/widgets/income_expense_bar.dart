import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analytics_providers.dart';
import '../../../utils/format_currency.dart';

class IncomeExpenseBarCard extends ConsumerWidget {
  const IncomeExpenseBarCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(incomeExpenseSummaryProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Income vs Expense', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1.6,
              child: summaryAsync.when(
                data: (sum) {
                  if (sum.income == 0 && sum.expense == 0) {
                    return const _EmptyChartPlaceholder(icon: Icons.bar_chart, text: 'Belum ada data');
                  }
                  final maxY = [sum.income, sum.expense].reduce((a,b)=> a>b?a:b) * 1.15;
                  return BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceEvenly,
                      maxY: maxY == 0 ? 100 : maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final label = group.x == 0 ? 'Income' : 'Expense';
                            return BarTooltipItem(
                              '$label\n${formatCurrencyIDR(rod.toY)}',
                              TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600),
                            );
                          },
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 0, getTitlesWidget: (v, meta)=> const SizedBox() )),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              switch (value.toInt()) {
                                case 0: return const Padding(padding: EdgeInsets.only(top:4), child: Text('Income'));
                                case 1: return const Padding(padding: EdgeInsets.only(top:4), child: Text('Expense'));
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        BarChartGroupData(
                          x: 0,
                          groupVertically: true,
                          barRods: [
                            BarChartRodData(
                              toY: sum.income,
                              borderRadius: BorderRadius.circular(6),
                              gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.55)]),
                              width: 36,
                            ),
                          ],
                        ),
                        BarChartGroupData(
                          x: 1,
                          groupVertically: true,
                          barRods: [
                            BarChartRodData(
                              toY: sum.expense,
                              borderRadius: BorderRadius.circular(6),
                              gradient: LinearGradient(colors: [theme.colorScheme.error, theme.colorScheme.error.withValues(alpha: 0.55)]),
                              width: 36,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorWidget(msg: 'Gagal memuat: $e'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String msg; const _ErrorWidget({required this.msg});
  @override
  Widget build(BuildContext context) => Center(child: Text(msg));
}

class _EmptyChartPlaceholder extends StatelessWidget {
  final IconData icon; final String text; const _EmptyChartPlaceholder({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
