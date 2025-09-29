import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/wallet.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/wallet_icon_helper.dart';
import '../../../core/localization/app_localizations.dart';

class WalletSelectorSheet extends ConsumerWidget {
  final String userId;
  final List<Wallet> wallets;
  final Function(Wallet) onWalletSelected;
  final BuildContext rootContext; // context dari screen induk

  const WalletSelectorSheet({
    super.key,
    required this.userId,
    required this.wallets,
    required this.onWalletSelected,
    required this.rootContext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        height:
            MediaQuery.of(context).size.height * 0.8, // 80% of screen height
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header with Add Wallet FAB
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ref.tr(context, 'select_wallet_title'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  FloatingActionButton.small(
                    onPressed: _addNewWallet,
                    tooltip: ref.tr(context, 'add_new_wallet'),
                    child: const Icon(Icons.add, size: 20),
                  ),
                ],
              ),
            ),

            // Wallet List
            Expanded(child: _buildWalletList(context, theme, ref)),
          ],
        ),
      ),
    );
  }

  void _addNewWallet() {
    final router = GoRouter.of(rootContext);
    Navigator.pop(rootContext);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        router.push('/wallets/manage');
      } catch (_) {}
    });
  }

  Widget _buildWalletList(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
  ) {
    final walletItems = <Widget>[];

    // Add existing wallets
    for (final wallet in wallets) {
      walletItems.add(_buildWalletItem(context, theme, wallet));
    }

    if (wallets.isEmpty) {
      // Show empty state when no wallets available
      return ListView(
        padding: const EdgeInsets.all(4),
        children: [
          const SizedBox(height: 4),
          Center(
            child: Text(
              ref.tr(context, 'no_wallets_yet'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      );
    }

    return ListView(padding: const EdgeInsets.all(12), children: walletItems);
  }

  Widget _buildWalletItem(
    BuildContext context,
    ThemeData theme,
    Wallet wallet,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 1,
      child: ListTile(
        dense: true,
        leading: SizedBox(
          width: 36,
          height: 36,
          child: WalletIconHelper.buildIcon(
            wallet.icon,
            size: 36, // Icon seukuran container penuh
          ),
        ),
        title: Text(
          wallet.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          CurrencyFormatter.format(wallet.balance, wallet.currency),
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: wallet.balance >= 0
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: () => onWalletSelected(wallet),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}
