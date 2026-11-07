import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/wallet.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../wallet/widgets/wallet_form_dialog.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/wallet_icon_helper.dart';

class WalletSelectionScreen extends ConsumerStatefulWidget {
  final String userId;
  final Wallet? selectedWallet;
  final String title;

  const WalletSelectionScreen({
    super.key,
    required this.userId,
    this.selectedWallet,
    this.title = 'Select Wallet',
  });

  @override
  ConsumerState<WalletSelectionScreen> createState() =>
      _WalletSelectionScreenState();
}

class _WalletSelectionScreenState extends ConsumerState<WalletSelectionScreen> {
  bool _showHiddenWallets = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddWalletDialog(),
        tooltip: ref.tr(context, 'wallet_add'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Simple toggle button untuk hidden wallets
          if (ref
                  .watch(hiddenWalletsProvider(widget.userId))
                  .value
                  ?.isNotEmpty ??
              false)
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Text(
                    ref.tr(context, 'wallet_show_hidden'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Switch.adaptive(
                    value: _showHiddenWallets,
                    onChanged: (value) {
                      setState(() {
                        _showHiddenWallets = value;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Wallet List (menggabungkan hidden dan visible)
          Expanded(child: _buildCombinedWalletsList()),
        ],
      ),
    );
  }

  Widget _buildCombinedWalletsList() {
    final walletsAsync = ref.watch(walletsProvider(widget.userId));

    return walletsAsync.when(
      data: (allWallets) {
        if (allWallets.isEmpty) {
          return _buildEmptyState(ref.tr(context, 'no_wallets_yet'));
        }

        // Sort all wallets by updatedAt (newest first)
        final allWalletsSorted = allWallets.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        // Filter berdasarkan toggle hidden
        final walletsToShow = _showHiddenWallets
            ? allWalletsSorted // Tampilkan semua
            : allWalletsSorted
                  .where((w) => !w.isHidden)
                  .toList(); // Hanya visible

        if (walletsToShow.isEmpty) {
          return _buildEmptyState(ref.tr(context, 'no_wallets_yet'));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: walletsToShow.length,
          itemBuilder: (context, index) {
            final wallet = walletsToShow[index];
            return _buildWalletTile(wallet);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(error.toString()),
    );
  }

  Widget _buildWalletTile(Wallet wallet) {
    final isSelected = widget.selectedWallet?.id == wallet.id;
    final isHidden = wallet.isHidden;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: isSelected ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        dense: true, // Membuat ListTile lebih compact
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 2, // Lebih kecil lagi
        ),
        leading: SizedBox(
          width: 32, // Lebih kecil lagi
          height: 32, // Lebih kecil lagi
          child: WalletIconHelper.buildIcon(
            wallet.icon,
            size: 32, // Icon lebih kecil lagi
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                wallet.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isHidden)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility_off,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      ref.tr(context, 'wallet_hidden'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 20,
              ),
          ],
        ),
        subtitle: Text(
          CurrencyFormatter.format(wallet.balance, wallet.currency),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: wallet.balance >= 0
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
          ),
        ),
        onTap: () => _selectWallet(wallet),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 48,
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              ref.tr(context, 'create_new_wallet'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              ref.tr(context, 'error_loading_wallets'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _selectWallet(Wallet wallet) {
    // Return selected wallet to previous screen
    context.pop(wallet);
  }

  void _showAddWalletDialog() {
    showDialog(
      context: context,
      builder: (_) => WalletFormDialog(
        title: ref.tr(context, 'wallet_add'),
        onSave: (request) async {
          try {
            await ref
                .read(walletRepositoryProvider)
                .createWallet(widget.userId, request as CreateWalletRequest);
            refreshWalletProviders(ref);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ref.tr(context, 'wallet_created_success')),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ref.tr(context, 'error_saving')),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
            rethrow;
          }
        },
      ),
    );
  }
}
