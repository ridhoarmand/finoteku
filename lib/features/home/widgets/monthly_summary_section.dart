import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../utils/currency_formatter.dart';
import '../../category/providers/category_providers.dart';
import '../../transaction/providers/transaction_providers.dart';
import '../../../models/category.dart';

class MonthlySummarySection extends ConsumerWidget {
  final String userId;
  const MonthlySummarySection({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final monthlyTxsAsync = ref.watch(
      monthlyTransactionsProvider((userId: userId, year: now.year, month: now.month)),
    );
    final categoriesAsync = ref.watch(categoriesProvider(userId));

    return monthlyTxsAsync.when(
      loading: () => _containerSkeleton(context),
      error: (e, st) => const SizedBox.shrink(),
      data: (txs) {
        return categoriesAsync.when(
          loading: () => _containerSkeleton(context),
          error: (e, st) => const SizedBox.shrink(),
          data: (categories) {
            double income = 0;
            double expense = 0;
            final map = {for (final c in categories) c.id: c};
            for (final t in txs) {
              final cat = map[t.categoryId];
              if (cat?.type == CategoryType.income) {
                income += t.amount.abs();
              } else {
                expense += t.amount.abs();
              }
            }

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref.tr(context, 'this_month'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryTile(
                          label: ref.tr(context, 'income'),
                          value: CurrencyFormatter.format(income, 'IDR'),
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryTile(
                          label: ref.tr(context, 'expense'),
                          value: CurrencyFormatter.format(expense, 'IDR'),
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _containerSkeleton(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: const SizedBox(
        height: 24,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color.withValues(alpha: 0.9),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}
