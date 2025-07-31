import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'add_transaction_screen.dart';
import '../providers/transaction_providers.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/currency_formatter.dart';

class TransactionScreen extends ConsumerWidget {
  const TransactionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login first')),
      );
    }

    final transactionsSummaryAsync = ref.watch(transactionsSummaryProvider((
      userId: user.id,
      startDate: null,
      endDate: null,
    )));
    
    final transactionsAsync = ref.watch(transactionsProvider(user.id));
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Summary Cards
            transactionsSummaryAsync.when(
              data: (summary) => Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.trending_up,
                              color: Colors.green,
                              size: 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Income',
                              style: theme.textTheme.bodyMedium,
                            ),
                            Text(
                              CurrencyFormatter.format(summary['income'] ?? 0, 'IDR'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.trending_down,
                              color: Colors.red,
                              size: 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Expense',
                              style: theme.textTheme.bodyMedium,
                            ),
                            Text(
                              CurrencyFormatter.format(summary['expense'] ?? 0, 'IDR'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              loading: () => const Row(
                children: [
                  Expanded(child: Card(child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())))),
                  SizedBox(width: 8),
                  Expanded(child: Card(child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())))),
                ],
              ),
              error: (error, stack) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error loading summary: $error'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Transaction List
            Expanded(
              child: transactionsAsync.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return _buildEmptyState(context, theme);
                  }
                  return _buildTransactionList(transactions, theme);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('Error loading transactions: $error'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => ref.invalidate(transactionsProvider(user.id)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Transactions Yet',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by adding your first transaction',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AddTransactionScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Transaction'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<dynamic> transactions, ThemeData theme) {
    return RefreshIndicator(
      onRefresh: () async {
        // Implement refresh logic here if needed
      },
      child: ListView.builder(
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          
          // Determine if transaction is income or expense based on category type
          // For income categories, amount should be positive
          // For expense categories, amount should be negative
          final isIncome = transaction.amount > 0;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isIncome 
                    ? Colors.green.shade100 
                    : Colors.red.shade100,
                child: Icon(
                  isIncome 
                      ? Icons.trending_up 
                      : Icons.trending_down,
                  color: isIncome 
                      ? Colors.green 
                      : Colors.red,
                ),
              ),
              title: Text(transaction.notes ?? 'Transaction'),
              subtitle: Text(_formatDate(transaction.date)),
              trailing: Text(
                CurrencyFormatter.format(transaction.amount.abs(), 'IDR'),
                style: TextStyle(
                  color: isIncome 
                      ? Colors.green 
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                // TODO: Navigate to transaction detail
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
