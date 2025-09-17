import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';

class WalletEmptyState extends ConsumerWidget {
  final VoidCallback onAdd;
  const WalletEmptyState({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 80, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 24),
            Text(ref.tr(context, 'wallet_no_wallets_title'), style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            ref.tr(context, 'wallet_no_wallets_sub'),
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(ref.tr(context, 'wallet_add')),
          ),
        ],
      ),
    );
  }
}
