import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analytics_providers.dart';
import '../../../utils/currency_formatter.dart';

class SummaryStatsRow extends ConsumerWidget {
  const SummaryStatsRow({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final txCountAsync = ref.watch(transactionCountProvider);
    final summaryAsync = ref.watch(incomeExpenseSummaryProvider);
    return Row(
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
                data: (s) => _StatTile(label: 'Net', value: CurrencyFormatter.format(s.net, 'IDR'), color: s.net >= 0 ? theme.colorScheme.secondary : theme.colorScheme.error),
                loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                error: (e, _) => _StatTile(label: 'Net', value: '-', color: theme.colorScheme.error),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label; final String value; final Color color; const _StatTile({required this.label, required this.value, required this.color});
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
