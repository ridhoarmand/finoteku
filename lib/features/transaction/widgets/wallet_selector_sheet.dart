import 'package:flutter/material.dart';
import '../../../models/wallet.dart';
import '../../../utils/currency_formatter.dart';

class WalletSelectorSheet extends StatelessWidget {
  final List<Wallet> wallets;
  final Function(Wallet) onWalletSelected;

  const WalletSelectorSheet({
    super.key,
    required this.wallets,
    required this.onWalletSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8, // 80% of screen height
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Select Wallet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Wallet List
          Expanded(
            child: _buildWalletList(context, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletList(BuildContext context, ThemeData theme) {
    final walletItems = <Widget>[];

    // Add "Add New Wallet" option at the top
    walletItems.add(_buildAddNewWalletItem(context, theme));

    // Add existing wallets
    for (final wallet in wallets) {
      walletItems.add(_buildWalletItem(context, theme, wallet));
    }

    if (wallets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No wallets available',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add wallets in settings',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: walletItems,
    );
  }

  Widget _buildAddNewWalletItem(BuildContext context, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.primary,
          width: 1.5,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            Icons.add,
            color: theme.colorScheme.primary,
            size: 16,
          ),
        ),
        title: Text(
          'Add New Wallet',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          'Create a new wallet',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: theme.colorScheme.primary,
        ),
        onTap: () {
          Navigator.pop(context);
          Navigator.of(context).pushNamed('/wallets/manage');
        },
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 2,
        ),
      ),
    );
  }

  Widget _buildWalletItem(BuildContext context, ThemeData theme, Wallet wallet) {
    return Card(
      margin: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            _getWalletIcon(wallet.icon),
            color: theme.colorScheme.primary,
            size: 16,
          ),
        ),
        title: Text(
          wallet.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          'Balance: ${CurrencyFormatter.format(wallet.balance, wallet.currency)}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => onWalletSelected(wallet),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 2,
        ),
      ),
    );
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
