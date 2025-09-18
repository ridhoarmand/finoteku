import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../utils/currency_formatter.dart';
import '../../category/providers/category_providers.dart';
import '../../transaction/providers/transaction_providers.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../../models/category.dart';
import '../../category/theme/category_theme.dart';
import '../../transaction/screens/transaction_detail_screen.dart';

class RecentTransactionsSection extends ConsumerWidget {
  final String userId;
  const RecentTransactionsSection({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentTransactionsProvider(userId));
    final categoriesAsync = ref.watch(categoriesProvider(userId));
    final walletsAsync = ref.watch(activeWalletsProvider(userId));

    final theme = Theme.of(context);

    return recentAsync.when(
      loading: () => const Center(
        child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, st) => Center(
        child: Text(
          ref.tr(context, 'error_loading_transactions').replaceAll('{error}', '$e'),
          style: theme.textTheme.bodyMedium,
        ),
      ),
      data: (txs) {
        if (txs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(ref.tr(context, 'home_transactions_empty'),
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
                const SizedBox(height: 8),
                Text(ref.tr(context, 'home_transactions_empty_sub'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500])),
              ],
            ),
          );
        }

        return categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, st) => const SizedBox.shrink(),
          data: (categories) {
            return walletsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (e, st) => const SizedBox.shrink(),
              data: (wallets) {
                final categoryMap = {for (final c in categories) c.id: c};
                final walletMap = {for (final w in wallets) w.id: w};

                bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
                String formatDateLabel(BuildContext context, WidgetRef ref, DateTime date) {
                  final now = DateTime.now();
                  if (isSameDay(date, now)) return ref.tr(context, 'day_today');
                  final yesterday = DateTime(now.year, now.month, now.day - 1);
                  if (isSameDay(date, yesterday)) return ref.tr(context, 'day_yesterday');

                  final weekdayKeys = [
                    'weekday_monday',
                    'weekday_tuesday',
                    'weekday_wednesday',
                    'weekday_thursday',
                    'weekday_friday',
                    'weekday_saturday',
                    'weekday_sunday',
                  ];
                  final monthKeys = [
                    'month_january',
                    'month_february',
                    'month_march',
                    'month_april',
                    'month_may',
                    'month_june',
                    'month_july',
                    'month_august',
                    'month_september',
                    'month_october',
                    'month_november',
                    'month_december',
                  ];
                  final weekdayName = ref.tr(context, weekdayKeys[date.weekday - 1]);
                  final monthName = ref.tr(context, monthKeys[date.month - 1]);
                  return '$weekdayName, ${date.day} $monthName ${date.year}';
                }

                final sorted = [...txs]..sort((a, b) => b.date.compareTo(a.date));
                final List<_HomeListItem> items = [];
                DateTime? lastHeader;
                for (final tx in sorted) {
                  final d = DateTime(tx.date.year, tx.date.month, tx.date.day);
                  if (lastHeader == null || !isSameDay(d, lastHeader)) {
                    items.add(_HomeListItem.header(d));
                    lastHeader = d;
                  }
                  items.add(_HomeListItem.transaction(tx));
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item.isHeader) {
                      final label = formatDateLabel(context, ref, item.date!);
                      return Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                label,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final tx = item.transaction;
                    final category = categoryMap[tx.categoryId];
                    final wallet = walletMap[tx.walletId];
                    final isIncome = category?.type == CategoryType.income;
                    final amountFormatted = CurrencyFormatter.format(tx.amount, 'IDR');
                    final displayAmount = isIncome == true ? amountFormatted : '-$amountFormatted';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => TransactionDetailScreen(transactionId: tx.id),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: (isIncome == true ? CategoryTheme.income : CategoryTheme.expense)
                                    .withValues(alpha: 0.12),
                                child: Icon(
                                  () {
                                    if (category?.iconCodePoint != null) {
                                      return IconData(category!.iconCodePoint!, fontFamily: 'MaterialIcons');
                                    }
                                    return isIncome == true ? Icons.trending_up : Icons.trending_down;
                                  }(),
                                  color: isIncome == true ? CategoryTheme.income : CategoryTheme.expense,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category?.name ?? ref.tr(context, 'uncategorized'),
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    if (tx.notes != null && tx.notes!.trim().isNotEmpty)
                                      Text(
                                        tx.notes!,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    wallet?.name ?? ref.tr(context, 'wallet_label'),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    displayAmount,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: isIncome == true ? CategoryTheme.income : CategoryTheme.expense,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _HomeListItem {
  final bool isHeader;
  final DateTime? date;
  final dynamic transaction;
  _HomeListItem._(this.isHeader, this.date, this.transaction);
  factory _HomeListItem.header(DateTime date) => _HomeListItem._(true, date, null);
  factory _HomeListItem.transaction(dynamic tx) => _HomeListItem._(false, null, tx);
}
