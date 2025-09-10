import 'package:flutter/material.dart';

class WalletEmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const WalletEmptyState({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 80, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 24),
            Text('No Wallets Yet', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Create your first wallet to start\nmanaging your finances',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Wallet'),
          ),
        ],
      ),
    );
  }
}
