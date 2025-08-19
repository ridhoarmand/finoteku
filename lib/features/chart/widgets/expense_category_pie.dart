import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analytics_providers.dart';

class ExpenseCategoryPieCard extends ConsumerWidget {
  const ExpenseCategoryPieCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expenseByCatAsync = ref.watch(expenseByCategoryProvider);
    return Card(
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
                  return const SizedBox(height: 180, child: Center(child: _EmptyChartPlaceholder(icon: Icons.pie_chart, text: 'Belum ada data')));
                }
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
    );
  }
}

class _ErrorWidget extends StatelessWidget { final String msg; const _ErrorWidget({required this.msg}); @override Widget build(BuildContext context)=> Center(child: Text(msg)); }

class _EmptyChartPlaceholder extends StatelessWidget {
  final IconData icon; final String text; const _EmptyChartPlaceholder({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(icon, size: 48, color: Colors.grey[400]), const SizedBox(height: 8), Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]))],
        ),
      ),
    );
  }
}

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
  final String label; final double pct; final Color color; const _LegendChip({required this.label, required this.pct, required this.color});
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
          Text(label.length > 14 ? '${label.substring(0, 12)}…' : label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
