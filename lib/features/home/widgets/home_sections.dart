import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../utils/currency_formatter.dart';
import '../../transaction/providers/transaction_providers.dart';

class MonthlySummarySection extends ConsumerWidget {
  final String userId;
  const MonthlySummarySection({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final summaryAsync = ref.watch(transactionsSummaryProvider((
      userId: userId,
      startDate: DateTime(now.year, now.month, 1),
      endDate: DateTime(now.year, now.month + 1, 0),
    )));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ref.tr(context, 'this_month'),
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        summaryAsync.when(
          data: (s) => Row(
            children: [
              _pill(context, Colors.green, Icons.trending_up,
                  ref.tr(context, 'income'), CurrencyFormatter.format(s.income, 'IDR')),
              const SizedBox(width: 12),
              _pill(context, Colors.red, Icons.trending_down,
                  ref.tr(context, 'expense'), CurrencyFormatter.format(s.expense, 'IDR')),
            ],
          ),
          loading: () => const Row(
            children: [
              _LoadingPill(),
              SizedBox(width: 12),
              _LoadingPill(),
            ],
          ),
          error: (e, st) => Text(
            '—',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _pill(BuildContext context, Color color, IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingPill extends StatelessWidget {
  const _LoadingPill();
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class RecentTransactionsSection extends ConsumerWidget {
  final String userId;
  const RecentTransactionsSection({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(recentTransactionsProvider(userId));
  return txsAsync.when(
      data: (txs) {
        if (txs.isEmpty) {
          return const SizedBox.shrink();
        }
    final na = ref.tr(context, 'not_available');
        return Column(
          children: [
      ...txs.take(5).map((t) => _tile(context, na, t.amount, t.notes, t.date)),
          ],
        );
      },
      loading: () => const _RecentLoadingList(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }

  Widget _tile(BuildContext context, String notAvailable, double amount, String? notes, DateTime date) {
    final isIncome = amount > 0;
    final color = isIncome ? Colors.green : Colors.red;
    final sign = isIncome ? '+' : '-';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(isIncome ? Icons.trending_up : Icons.trending_down, color: color, size: 18),
      ),
  title: Text(notes ?? notAvailable),
      trailing: Text(
        '$sign${CurrencyFormatter.format(amount.abs(), 'IDR')}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
      subtitle: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
    );
  }
}

class _RecentLoadingList extends StatelessWidget {
  const _RecentLoadingList();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.black12,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 12, width: 160, color: Colors.black12),
                    const SizedBox(height: 6),
                    Container(height: 10, width: 100, color: Colors.black12),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(height: 12, width: 80, color: Colors.black12),
            ],
          ),
        ),
      ),
    );
  }
}
