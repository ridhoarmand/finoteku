import 'package:flutter/material.dart';

class TransactionScreen extends StatelessWidget {
  const TransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Navigate to add transaction
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add transaction feature coming soon')),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(
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
                            'Rp 0',
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
                          Icon(
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
                            'Rp 0',
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
            const SizedBox(height: 24),
            
            // Transaction List
            Expanded(
              child: Center(
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
                        // TODO: Navigate to add transaction
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Add transaction feature coming soon')),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Transaction'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add new transaction
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add transaction feature coming soon')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
