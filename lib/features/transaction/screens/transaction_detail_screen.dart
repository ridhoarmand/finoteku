import 'package:flutter/material.dart';
import '../../category/theme/category_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/transaction.dart';
import '../providers/transaction_providers.dart';
import '../../category/providers/category_providers.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/category_icon_helper.dart';
import 'add_transaction_screen.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../models/category.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return Scaffold(
        body: Center(child: Text(ref.tr(context, 'login_required_short'))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(ref.tr(context, 'transaction_details_title'))),
      body: _buildTransactionBody(context, ref, user.id),
    );
  }

  Widget _buildTransactionBody(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) {
    final txAsync = ref.watch(
      transactionProvider((transactionId: transactionId, userId: userId)),
    );
    return txAsync.when(
      data: (tx) {
        if (tx == null)
          return Center(child: Text(ref.tr(context, 'transaction_not_found')));
        return _buildTransactionDetail(context, ref, tx, userId);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _errorWithRetry(
        context,
        ref,
        () => ref.invalidate(
          transactionProvider((transactionId: transactionId, userId: userId)),
        ),
      ),
    );
  }

  Widget _errorWithRetry(
    BuildContext context,
    WidgetRef ref,
    VoidCallback retry,
  ) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(
          ref
              .tr(context, 'error_loading_transactions')
              .replaceAll('{error}', ''),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: retry, child: Text(ref.tr(context, 'retry'))),
      ],
    ),
  );

  Widget _buildTransactionDetail(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
    String userId,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amount Card
          Consumer(
            builder: (context, ref, _) {
              final categoryAsync = transaction.categoryId != null
                  ? ref.watch(
                      categoryProvider((
                        categoryId: transaction.categoryId!,
                        userId: userId,
                      )),
                    )
                  : const AsyncValue.data(null);
              return categoryAsync.when(
                data: (category) {
                  final isIncome = category?.type == CategoryType.income;
                  final color = isIncome
                      ? CategoryTheme.income
                      : CategoryTheme.expense;
                  final icon = category?.iconCodePoint != null
                      ? CategoryIconHelper.getIconFromCodePoint(
                          category!.iconCodePoint,
                        )
                      : (isIncome ? Icons.trending_up : Icons.trending_down);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: color.withValues(alpha: 0.2),
                            child: Icon(icon, color: color, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isIncome
                                      ? ref.tr(context, 'income')
                                      : ref.tr(context, 'expense'),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(
                                    transaction.amount.abs(),
                                    'IDR',
                                  ),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          child: Icon(
                            Icons.category,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 16,
                                width: 80,
                                color: Colors.black12,
                              ),
                              Container(
                                height: 20,
                                width: 120,
                                color: Colors.black12,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                error: (e, st) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          child: Icon(
                            Icons.category,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ref.tr(context, 'details_title'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(
                                  transaction.amount.abs(),
                                  'IDR',
                                ),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Details Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref.tr(context, 'details_title'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  _buildDetailRow(
                    ref.tr(context, 'notes'),
                    transaction.notes ?? ref.tr(context, 'no_notes'),
                    Icons.note,
                  ),

                  const Divider(),

                  // Date
                  _buildDetailRow(
                    ref.tr(context, 'date_label'),
                    _formatDate(context, ref, transaction.date),
                    Icons.calendar_today,
                  ),

                  const Divider(),

                  // Category
                  if (transaction.categoryId != null)
                    ref
                        .watch(
                          categoryProvider((
                            categoryId: transaction.categoryId!,
                            userId: userId,
                          )),
                        )
                        .when(
                          data: (category) => Column(
                            children: [
                              _buildDetailRow(
                                ref.tr(context, 'category_label'),
                                category?.name ??
                                    ref.tr(context, 'uncategorized'),
                                _getCategoryIcon(category?.iconCodePoint),
                              ),
                              const Divider(),
                            ],
                          ),
                          loading: () => Column(
                            children: [
                              _buildDetailRow(
                                ref.tr(context, 'category_label'),
                                ref.tr(context, 'loading_ellipsis'),
                                Icons.category,
                              ),
                              const Divider(),
                            ],
                          ),
                          error: (error, stack) => Column(
                            children: [
                              _buildDetailRow(
                                ref.tr(context, 'category_label'),
                                ref.tr(context, 'error_loading_category'),
                                Icons.category,
                              ),
                              const Divider(),
                            ],
                          ),
                        )
                  else
                    Column(
                      children: [
                        _buildDetailRow(
                          ref.tr(context, 'category_label'),
                          ref.tr(context, 'no_category'),
                          Icons.category,
                        ),
                        const Divider(),
                      ],
                    ),

                  // Wallet
                  ref
                      .watch(
                        walletProvider((
                          walletId: transaction.walletId,
                          userId: userId,
                        )),
                      )
                      .when(
                        data: (wallet) => Column(
                          children: [
                            _buildDetailRow(
                              ref.tr(context, 'wallet_label'),
                              wallet?.name ?? ref.tr(context, 'wallet_unknown'),
                              _getWalletIcon(wallet?.icon),
                            ),
                            const Divider(),
                          ],
                        ),
                        loading: () => Column(
                          children: [
                            _buildDetailRow(
                              ref.tr(context, 'wallet_label'),
                              ref.tr(context, 'loading_ellipsis'),
                              Icons.account_balance_wallet,
                            ),
                            const Divider(),
                          ],
                        ),
                        error: (error, stack) => Column(
                          children: [
                            _buildDetailRow(
                              ref.tr(context, 'wallet_label'),
                              ref.tr(context, 'wallet_loading_error'),
                              Icons.account_balance_wallet,
                            ),
                            const Divider(),
                          ],
                        ),
                      ),

                  // Created Date
                  _buildDetailRow(
                    ref.tr(context, 'wallet_created_label'),
                    _formatDateTime(context, ref, transaction.createdAt),
                    Icons.access_time,
                  ),

                  if (transaction.updatedAt != transaction.createdAt) ...[
                    const Divider(),
                    _buildDetailRow(
                      ref.tr(context, 'wallet_updated_label'),
                      _formatDateTime(context, ref, transaction.updatedAt),
                      Icons.update,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const Spacer(),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editTransaction(context, ref, transaction),
                  icon: const Icon(Icons.edit),
                  label: Text(ref.tr(context, 'edit')),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      _showDeleteDialog(context, ref, transaction, userId),
                  icon: const Icon(Icons.delete),
                  label: Text(ref.tr(context, 'delete')),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  void _editTransaction(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
  ) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            AddTransactionScreen(initialTransaction: transaction),
      ),
    );

    // If transaction was updated, refresh the data
    if (result == true && context.mounted) {
      // Invalidate providers to ensure fresh data
      ref.invalidate(transactionProvider);
      ref.invalidate(filteredTransactionsProvider);
      refreshWalletProviders(ref);
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
    String userId,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(ref.tr(context, 'delete_transaction_title')),
          content: Text(ref.tr(context, 'delete_transaction_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(ref.tr(context, 'cancel')),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog
                await _deleteTransaction(context, ref, transaction.id, userId);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(ref.tr(context, 'delete')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTransaction(
    BuildContext context,
    WidgetRef ref,
    String transactionId,
    String userId,
  ) async {
    try {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.deleteTransaction(transactionId, userId);

      // Invalidate related providers to refresh data
      refreshTransactionProviders(ref); // bumps all transaction lists
      // Family providers require params; rely on refresh trigger instead of raw invalidation

      // Also refresh wallet providers to update balances
      refreshWalletProviders(ref);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.tr(context, 'transaction_deleted_successfully')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Go back to transaction list
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref
                  .tr(context, 'error_deleting_transaction')
                  .replaceAll('{error}', '$e'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(BuildContext context, WidgetRef ref, DateTime date) {
    final monthKey = [
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
    ][date.month - 1];
    final monthName = ref.tr(context, monthKey);
    return '${date.day} $monthName ${date.year}';
  }

  String _formatDateTime(
    BuildContext context,
    WidgetRef ref,
    DateTime dateTime,
  ) {
    final monthKey = [
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
    ][dateTime.month - 1];
    final monthName = ref.tr(context, monthKey);
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.day} $monthName ${dateTime.year} $hour:$minute';
  }

  IconData _getCategoryIcon(int? iconCodePoint) {
    return CategoryIconHelper.getIconFromCodePoint(iconCodePoint);
  }

  IconData _getWalletIcon(String? icon) {
    switch (icon?.toLowerCase()) {
      case 'bca':
      case 'bni':
      case 'bri':
      case 'mandiri':
      case 'btn':
      case 'bsi':
        return Icons.account_balance;
      case 'dana':
      case 'gopay':
      case 'ovo':
      case 'linkaja':
      case 'doku':
      case 'sopay':
        return Icons.phone_android;
      default:
        return Icons.account_balance_wallet;
    }
  }
}
