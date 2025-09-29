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
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: Colors.grey.shade200, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        leading: SizedBox(
          width: 40,
          height: 40,
          child: WalletIconHelper.buildIcon(wallet.icon, size: 40),
        ),
        title: Text(
          wallet.name,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: !wallet.isHidden ? null : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              CurrencyFormatter.format(wallet.balance, wallet.currency),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: wallet.balance >= 0
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
            Text(
              wallet.currency,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            if (wallet.isHidden) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.visibility_off,
                    size: 10,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    ref.tr(context, 'wallet_hidden'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: onAction,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(Icons.edit),
                  const SizedBox(width: 8),
                  Text(ref.tr(context, 'edit')),
                ],
              ),
            ),
            PopupMenuItem(
              value: !wallet.isHidden ? 'deactivate' : 'activate',
              child: Row(
                children: [
                  Icon(
                    !wallet.isHidden ? Icons.visibility_off : Icons.visibility,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    !wallet.isHidden
                        ? ref.tr(context, 'wallet_hide')
                        : ref.tr(context, 'wallet_unhide'),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    ref.tr(context, 'delete'),
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
