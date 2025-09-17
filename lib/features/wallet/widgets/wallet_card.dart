import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/wallet.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/wallet_icon_helper.dart';
import '../../../core/localization/app_localizations.dart';

class WalletCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
            Text('${ref.tr(context, 'wallet_currency_label')}: ${wallet.currency}', style: theme.textTheme.bodySmall),
            if (!wallet.isActive)
              Text(ref.tr(context, 'wallet_hidden'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: onAction,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(children: [const Icon(Icons.edit), const SizedBox(width: 8), Text(ref.tr(context, 'edit'))]),
            ),
            PopupMenuItem(
              value: wallet.isActive ? 'deactivate' : 'activate',
              child: Row(
                children: [
                  Icon(wallet.isActive ? Icons.visibility_off : Icons.visibility),
                  const SizedBox(width: 8),
                  Text(wallet.isActive ? ref.tr(context, 'wallet_hide') : ref.tr(context, 'wallet_unhide')),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [const Icon(Icons.delete, color: Colors.red), const SizedBox(width: 8), Text(ref.tr(context, 'delete'), style: const TextStyle(color: Colors.red))]),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
