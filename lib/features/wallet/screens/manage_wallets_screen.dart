import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/wallet.dart';
import '../providers/wallet_providers.dart';
import '../../../services/supabase_service.dart';
import '../widgets/wallet_card.dart';
import '../widgets/wallet_empty_state.dart';
import '../widgets/wallet_form_dialog.dart';
import '../../../core/localization/app_localizations.dart';

class ManageWalletsScreen extends ConsumerWidget {
  const ManageWalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr(context, 'manage_wallets')),
        actions: [
          // Sync status indicator removed (online-only architecture)
          IconButton(
            tooltip: ref.tr(context, 'add'),
            icon: const Icon(PhRegular.plus),
            onPressed: () {
              // Check if user is authenticated before showing dialog
              final user = currentUser.value;
              if (user != null) {
                _showAddWalletDialog(context, ref);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ref.tr(context, 'login_required_continue')),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return Center(child: Text(ref.tr(context, 'login_required_short')));
          }

          final walletsAsync = ref.watch(walletsProvider(user.id));

          return walletsAsync.when(
            data: (wallets) {
              if (wallets.isEmpty) {
                return WalletEmptyState(
                  onAdd: () => _showAddWalletDialog(context, ref),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(walletsProvider(user.id)),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ), // Padding atas bawah lebih kecil
                  itemCount: wallets.length,
                  itemBuilder: (context, index) => WalletCard(
                    wallet: wallets[index],
                    onTap: () =>
                        _showWalletDetails(context, ref, wallets[index]),
                    onAction: (action) => _handleMenuAction(
                      context,
                      ref,
                      action,
                      wallets[index],
                      user.id,
                    ),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhRegular.warningCircle,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ref.tr(context, 'wallet_loading_error'),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(walletsProvider(user.id)),
                    child: Text(ref.tr(context, 'retry')),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhRegular.warningCircle,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                ref.tr(context, 'wallet_auth_error'),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(currentUserProvider),
                child: Text(ref.tr(context, 'retry')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Wallet card & empty state extracted to widgets folder

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    Wallet wallet,
    String userId,
  ) async {
    final repo = ref.read(walletRepositoryProvider);
    switch (action) {
      case 'edit':
        _showEditWalletDialog(context, ref, wallet, userId);
        break;
      case 'activate':
      case 'deactivate':
        try {
          await repo.updateWallet(
            wallet.id,
            userId,
            UpdateWalletRequest(isHidden: action == 'deactivate'),
          );
          refreshWalletProviders(ref);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  action == 'deactivate'
                      ? ref.tr(context, 'wallet_now_hidden')
                      : ref.tr(context, 'wallet_now_visible'),
                ),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        }
        break;
      case 'delete':
        _confirmDelete(context, ref, wallet, userId);
        break;
    }
  }

  void _showAddWalletDialog(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    showDialog(
      context: context,
      builder: (_) => WalletFormDialog(
        title: ref.tr(context, 'wallet_add'),
        onSave: (request) async {
          try {
            await ref
                .read(walletRepositoryProvider)
                .createWallet(user.id, request as CreateWalletRequest);
            refreshWalletProviders(ref);
          } catch (e) {
            rethrow;
          }
        },
      ),
    );
  }

  void _showEditWalletDialog(
    BuildContext context,
    WidgetRef ref,
    Wallet wallet,
    String userId,
  ) {
    showDialog(
      context: context,
      builder: (_) => WalletFormDialog(
        title: ref.tr(context, 'wallet_edit'),
        initialData: UpdateWalletRequest(
          name: wallet.name,
          balance: wallet.balance,
          currency: wallet.currency,
          icon: wallet.icon,
          isHidden: wallet.isHidden,
        ),
        onSave: (request) async {
          try {
            await ref
                .read(walletRepositoryProvider)
                .updateWallet(
                  wallet.id,
                  userId,
                  request as UpdateWalletRequest,
                );
            refreshWalletProviders(ref);
          } catch (e) {
            rethrow;
          }
        },
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Wallet wallet,
    String userId,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(ref.tr(context, 'wallet_delete_title')),
        content: Text(
          '${ref.tr(context, 'wallet_delete_confirm_prefix')} "${wallet.name}"? ${ref.tr(context, 'wallet_irreversible_action')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(ref.tr(context, 'cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ref
                    .read(walletRepositoryProvider)
                    .deleteWallet(wallet.id, userId);
                if (context.mounted) {
                  Navigator.pop(context); // close dialog
                }
                refreshWalletProviders(ref);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ref.tr(context, 'wallet_deleted'))),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(ref.tr(context, 'delete')),
          ),
        ],
      ),
    );
  }

  void _showWalletDetails(BuildContext context, WidgetRef ref, Wallet wallet) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(ref.tr(context, 'wallet_details_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(ref.tr(context, 'wallet_name_label'), wallet.name),
            _detailRow(
              ref.tr(context, 'wallet_balance_label'),
              wallet.balance.toStringAsFixed(2),
            ),
            _detailRow(
              ref.tr(context, 'wallet_currency_label'),
              wallet.currency,
            ),
            _detailRow(
              ref.tr(context, 'wallet_status_label'),
              !wallet.isHidden
                  ? ref.tr(context, 'wallet_visible')
                  : ref.tr(context, 'wallet_hidden'),
            ),
            _detailRow(
              ref.tr(context, 'wallet_created_label'),
              _formatSimpleDate(wallet.createdAt.toLocal()),
            ),
            _detailRow(
              ref.tr(context, 'wallet_updated_label'),
              _formatSimpleDate(wallet.updatedAt.toLocal()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(ref.tr(context, 'close')),
          ),
        ],
      ),
    );
  }

  /// Format date to simple format: "23 Des 2023"
  String _formatSimpleDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
