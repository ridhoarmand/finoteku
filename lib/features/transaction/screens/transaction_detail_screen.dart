import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/transaction.dart';
import '../providers/transaction_providers.dart';
import '../../category/providers/category_providers.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/currency_formatter.dart';
import 'add_transaction_screen.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login first')),
      );
    }

    final transactionAsync = ref.watch(
      transactionProvider((
        transactionId: transactionId,
        userId: user.id,
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => transactionAsync.whenData((transaction) {
              if (transaction != null) {
                _editTransaction(context, ref, transaction);
              }
            }),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => transactionAsync.whenData((transaction) {
              if (transaction != null) {
                _showDeleteDialog(context, ref, transaction, user.id);
              }
            }),
          ),
        ],
      ),
      body: transactionAsync.when(
        data: (transaction) {
          if (transaction == null) {
            return const Center(
              child: Text('Transaction not found'),
            );
          }
          return _buildTransactionDetail(context, ref, transaction, user.id);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('Error loading transaction: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(
                  transactionProvider((
                    transactionId: transactionId,
                    userId: user.id,
                  )),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionDetail(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
    String userId,
  ) {
    final theme = Theme.of(context);
    final isIncome = transaction.amount > 0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amount Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: isIncome
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    child: Icon(
                      isIncome ? Icons.trending_up : Icons.trending_down,
                      color: isIncome ? Colors.green : Colors.red,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIncome ? 'Income' : 'Expense',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(transaction.amount.abs(), 'IDR'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: isIncome ? Colors.green : Colors.red,
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

          const SizedBox(height: 16),

          // Details Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  _buildDetailRow(
                    'Notes',
                    transaction.notes ?? 'No notes',
                    Icons.note,
                  ),

                  const Divider(),

                  // Date
                  _buildDetailRow(
                    'Date',
                    _formatDate(transaction.date),
                    Icons.calendar_today,
                  ),

                  const Divider(),

                  // Category
                  if (transaction.categoryId != null)
                    ref.watch(categoryProvider((
                      categoryId: transaction.categoryId!,
                      userId: userId,
                    ))).when(
                      data: (category) => Column(
                        children: [
                          _buildDetailRow(
                            'Category',
                            category?.name ?? 'Unknown Category',
                            _getCategoryIcon(category?.iconCodePoint),
                          ),
                          const Divider(),
                        ],
                      ),
                      loading: () => Column(
                        children: [
                          _buildDetailRow(
                            'Category',
                            'Loading...',
                            Icons.category,
                          ),
                          const Divider(),
                        ],
                      ),
                      error: (error, stack) => Column(
                        children: [
                          _buildDetailRow(
                            'Category',
                            'Error loading category',
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
                          'Category',
                          'No category',
                          Icons.category,
                        ),
                        const Divider(),
                      ],
                    ),

                  // Wallet
                  ref.watch(walletProvider((
                    walletId: transaction.walletId,
                    userId: userId,
                  ))).when(
                    data: (wallet) => Column(
                      children: [
                        _buildDetailRow(
                          'Wallet',
                          wallet?.name ?? 'Unknown Wallet',
                          _getWalletIcon(wallet?.icon),
                        ),
                        const Divider(),
                      ],
                    ),
                    loading: () => Column(
                      children: [
                        _buildDetailRow(
                          'Wallet',
                          'Loading...',
                          Icons.account_balance_wallet,
                        ),
                        const Divider(),
                      ],
                    ),
                    error: (error, stack) => Column(
                      children: [
                        _buildDetailRow(
                          'Wallet',
                          'Error loading wallet',
                          Icons.account_balance_wallet,
                        ),
                        const Divider(),
                      ],
                    ),
                  ),

                  // Created Date
                  _buildDetailRow(
                    'Created',
                    _formatDateTime(transaction.createdAt),
                    Icons.access_time,
                  ),

                  if (transaction.updatedAt != transaction.createdAt) ...[
                    const Divider(),
                    _buildDetailRow(
                      'Last Updated',
                      _formatDateTime(transaction.updatedAt),
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
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showDeleteDialog(context, ref, transaction, userId),
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
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

  void _editTransaction(BuildContext context, WidgetRef ref, Transaction transaction) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          initialTransaction: transaction,
        ),
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
          title: const Text('Delete Transaction'),
          content: const Text(
            'Are you sure you want to delete this transaction? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
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
              child: const Text('Delete'),
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
      final transactionService = ref.read(transactionServiceProvider);
      await transactionService.deleteTransaction(transactionId, userId);

      // Invalidate related providers to refresh data
      ref.invalidate(filteredTransactionsProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(transactionProvider);
      
      // Also invalidate wallet providers to update balances
      refreshWalletProviders(ref);
      ref.invalidate(walletProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Go back to transaction list
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting transaction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  IconData _getCategoryIcon(int? iconCodePoint) {
    if (iconCodePoint != null) {
      return IconData(iconCodePoint, fontFamily: 'MaterialIcons');
    }
    return Icons.category;
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
