import 'package:flutter/material.dart';
import '../../../models/wallet.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/wallet_icon_helper.dart';

class WalletCard extends StatelessWidget {
  final Wallet wallet;
  final VoidCallback onTap;
  final void Function(String action) onAction;

  const WalletCard({
    super.key,
    required this.wallet,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: wallet.isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.outline.withValues(alpha: 0.1),
          child: WalletIconHelper.buildIcon(
            wallet.icon,
            size: 36,
            color: wallet.icon == null || wallet.icon!.isEmpty
                ? (wallet.isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant)
                : null,
          ),
        ),
        title: Text(
          wallet.name,
          style: theme.textTheme.titleMedium?.copyWith(
            color: wallet.isActive ? null : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              CurrencyFormatter.format(wallet.balance, wallet.currency),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: wallet.balance >= 0
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
            Text('Currency: ${wallet.currency}', style: theme.textTheme.bodySmall),
            if (!wallet.isActive)
              Text('Inactive', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: onAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')]),
            ),
            PopupMenuItem(
              value: wallet.isActive ? 'deactivate' : 'activate',
              child: Row(
                children: [
                  Icon(wallet.isActive ? Icons.visibility_off : Icons.visibility),
                  const SizedBox(width: 8),
                  Text(wallet.isActive ? 'Deactivate' : 'Activate'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
