import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/wallet.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../wallet/widgets/wallet_form_dialog.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../theme/app_theme.dart';
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
          icon: const Icon(PhRegular.x),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddWalletDialog(),
        tooltip: ref.tr(context, 'wallet_add'),
        child: const Icon(PhRegular.plus),
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

        // One card, one-line rows split by dividers (like the ledger list)
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), // room for the FAB
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < walletsToShow.length; i++) ...[
                    if (i > 0) const Divider(indent: 62),
                    _buildWalletTile(walletsToShow[i]),
                  ],
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(error.toString()),
    );
  }

  Widget _buildWalletTile(Wallet wallet) {
    final isSelected = widget.selectedWallet?.id == wallet.id;
    final theme = Theme.of(context);
    final muted = context.colors.muted;

    return ListTile(
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer,
      selectedColor: theme.colorScheme.onPrimaryContainer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: WalletIconHelper.buildIcon(wallet.icon, size: 32),
      title: Text(wallet.name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (wallet.isHidden) ...[
            Icon(PhRegular.eyeSlash, size: 16, color: muted, semanticLabel: ref.tr(context, 'wallet_hidden')),
            const SizedBox(width: 8),
          ],
          Text(
            CurrencyFormatter.format(wallet.balance, wallet.currency),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: tabularFigures,
              color: wallet.balance < 0 ? theme.colorScheme.error : muted,
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 8),
            Icon(PhFill.checkCircle, color: theme.colorScheme.primary, size: 20),
          ],
        ],
      ),
      onTap: () => _selectWallet(wallet),
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
                PhRegular.wallet,
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
                PhRegular.warningCircle,
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
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
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
    ));
  }
}
