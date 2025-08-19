import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/analytics_providers.dart';
import '../../../utils/format_currency.dart';

class ChartScreen extends ConsumerWidget {
  const ChartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final period = ref.watch(analyticsPeriodProvider);
    final summaryAsync = ref.watch(incomeExpenseSummaryProvider);
    final expenseByCatAsync = ref.watch(expenseByCategoryProvider);
    final txCountAsync = ref.watch(transactionCountProvider);

    void setPeriod(String p) => ref.read(analyticsPeriodProvider.notifier).state = p;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analitik'),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // simple invalidate
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
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'week', label: Text('Minggu')),
                  ButtonSegment(value: 'month', label: Text('Bulan')),
                  ButtonSegment(value: 'year', label: Text('Tahun')),
                ],
                selected: {period},
                onSelectionChanged: (s) => setPeriod(s.first),
              ),
              const SizedBox(height: 16),

              // Income vs Expense Bar Chart
              Card(
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
                              return _EmptyChartPlaceholder(icon: Icons.bar_chart, text: 'Belum ada data');
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
              ),
              const SizedBox(height: 16),

              // Expense Category Pie Chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Proporsi Pengeluaran per Kategori', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      expenseByCatAsync.when(
                        data: (raw) {
                          if (raw.isEmpty) {
                            return const SizedBox(height: 180, child: _EmptyChartPlaceholder(icon: Icons.pie_chart, text: 'Belum ada data'));
                          }
                          // Ambil top 7 lalu gabungkan sisanya jadi "Lainnya" untuk kurangi overcrowd
                          final sorted = [...raw]..sort((a,b)=> b.total.compareTo(a.total));
                          List list = sorted.take(7).toList();
                          if (sorted.length > 7) {
                            final othersTotal = sorted.skip(7).fold<double>(0, (s,e)=> s + e.total);
                            list = [...list, CategorySpending(categoryId: '_others', name: 'Lainnya', total: othersTotal, color: null)];
                          }
                          final total = list.fold<double>(0, (sum, e) => sum + e.total);
                          return Column(
                            children: [
                              SizedBox(
                                height: 220,
                                child: PieChart(
                                  PieChartData(
                                    sectionsSpace: 1,
                                    centerSpaceRadius: 38,
                                    startDegreeOffset: -90,
                                    sections: list.map((e) {
                                      final pct = total == 0 ? 0 : e.total / total * 100;
                                      final color = e.color != null ? Color(e.color!) : _colorForKey(e.categoryId, theme);
                                      return PieChartSectionData(
                                        value: e.total,
                                        title: pct < 7 ? '' : '${pct.toStringAsFixed(0)}%',
                                        color: color,
                                        radius: 68,
                                        titleStyle: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  for (final e in list)
                                    _LegendChip(
                                      label: e.name,
                                      pct: total == 0 ? 0 : e.total / total * 100,
                                      color: e.color != null ? Color(e.color!) : _colorForKey(e.categoryId, theme),
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                        loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
                        error: (e, _) => _ErrorWidget(msg: 'Gagal memuat: $e'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Summary Stats
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: txCountAsync.when(
                          data: (c) => _StatTile(label: 'Transaksi', value: c.toString(), color: theme.colorScheme.primary),
                          loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                          error: (e, _) => _StatTile(label: 'Transaksi', value: '-', color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: summaryAsync.when(
                          data: (s) => _StatTile(label: 'Net', value: formatCurrencyIDR(s.net), color: s.net >= 0 ? theme.colorScheme.secondary : theme.colorScheme.error),
                          loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                          error: (e, _) => _StatTile(label: 'Net', value: '-', color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChartPlaceholder extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyChartPlaceholder({required this.icon, required this.text});
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

class _ErrorWidget extends StatelessWidget {
  final String msg;
  const _ErrorWidget({required this.msg});
  @override
  Widget build(BuildContext context) => Center(child: Text(msg));
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

// Simple deterministic color generator for legend fallback
Color _colorForKey(String key, ThemeData theme) {
  final palette = [
    theme.colorScheme.primary,
    theme.colorScheme.secondary,
    theme.colorScheme.tertiary,
    theme.colorScheme.error,
    theme.colorScheme.primaryContainer,
    theme.colorScheme.secondaryContainer,
    theme.colorScheme.tertiaryContainer,
  ];
  if (key == '_others') return theme.colorScheme.outline;
  final hash = key.codeUnits.fold<int>(0, (p, c) => p + c);
  return palette[hash % palette.length];
}

class _LegendChip extends StatelessWidget {
  final String label;
  final double pct;
  final Color color;
  const _LegendChip({required this.label, required this.pct, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
            Text(
              label.length > 14 ? '${label.substring(0, 12)}…' : label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          const SizedBox(width: 6),
          Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
