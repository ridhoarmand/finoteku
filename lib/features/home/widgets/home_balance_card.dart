import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/wallet.dart';
import '../../../utils/currency_formatter.dart';
import '../../../core/state/balance_visibility_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../providers/home_providers.dart';

class HomeBalanceCard extends ConsumerWidget {
  final AsyncValue<List<Wallet>> walletsAsync;

  const HomeBalanceCard({super.key, required this.walletsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.88),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with wallet selector
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  ref.tr(context, 'total_balance'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                _buildWalletSelector(context, ref, theme),
              ],
            ),
            const SizedBox(height: 12),

            // Balance Display
            _buildBalanceDisplay(context, ref, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletSelector(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    final selectedWalletId = ref.watch(selectedHomeWalletProvider);

    return walletsAsync.when(
      data: (wallets) {
        if (wallets.isEmpty) return const SizedBox.shrink();

        // Filter out hidden wallets
        final visibleWallets = wallets.where((w) => !w.isHidden).toList();

        final selectedWallet = selectedWalletId == null
            ? null
            : visibleWallets.firstWhere(
                (w) => w.id == selectedWalletId,
                orElse: () => visibleWallets.isNotEmpty
                    ? visibleWallets.first
                    : Wallet(
                        id: '',
                        name: 'N/A',
                        balance: 0,
                        userId: '',
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
              );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () =>
                _showWalletSelectionModal(context, ref, visibleWallets),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selectedWalletId == null
                        ? Icons.account_balance_wallet
                        : Icons.wallet,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selectedWalletId == null
                        ? ref.tr(context, 'all_wallets')
                        : (selectedWallet?.name ?? '').length > 8
                        ? '${(selectedWallet?.name ?? '').substring(0, 8)}...'
                        : (selectedWallet?.name ?? ''),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  void _showWalletSelectionModal(
    BuildContext context,
    WidgetRef ref,
    List<Wallet> wallets,
  ) {
    final selectedWalletId = ref.read(selectedHomeWalletProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    ref.tr(context, 'select_wallet'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Wallet options
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // All wallets option
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(ref.tr(context, 'all_wallets')),
                    subtitle: Text('${wallets.length} wallet'),
                    trailing: selectedWalletId == null
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      ref.read(selectedHomeWalletProvider.notifier).clear();
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(height: 1),

                  // Individual wallets
                  ...wallets.map(
                    (wallet) => ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.wallet,
                          color: Colors.blue,
                          size: 20,
                        ),
                      ),
                      title: Text(wallet.name),
                      subtitle: Text(
                        CurrencyFormatter.format(
                          wallet.balance,
                          wallet.currency,
                        ),
                      ),
                      trailing: selectedWalletId == wallet.id
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        ref
                            .read(selectedHomeWalletProvider.notifier)
                            .select(wallet.id);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Bottom padding
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceDisplay(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    final selectedWalletId = ref.watch(selectedHomeWalletProvider);

    return walletsAsync.when(
      data: (wallets) {
        double totalBalance = 0;
        if (selectedWalletId == null) {
          // Filter out hidden wallets
          totalBalance = wallets
              .where((w) => !w.isHidden)
              .fold(0.0, (sum, wallet) => sum + wallet.balance);
        } else {
          final selected = wallets.firstWhere(
            (w) => w.id == selectedWalletId,
            orElse: () => wallets.isNotEmpty
                ? wallets.first
                : Wallet(
                    id: '',
                    name: 'N/A',
                    balance: 0,
                    userId: '',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
          );
          totalBalance = selected.balance;
        }

        final isVisible = ref.watch(balanceVisibilityProvider);

        return Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  isVisible
                      ? CurrencyFormatter.format(totalBalance, 'IDR')
                      : '••••••••',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    fontSize: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                ref.read(balanceVisibilityProvider.notifier).toggle();
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isVisible ? Icons.visibility : Icons.visibility_off,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => Container(
        width: 200,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      error: (error, stack) => Text(
        ref.tr(context, 'error_loading_balance'),
        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
      ),
    );
  }
}
