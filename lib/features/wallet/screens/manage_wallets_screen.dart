import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/wallet.dart';
import '../providers/wallet_providers.dart';
import '../../../services/supabase_service.dart';
import '../widgets/wallet_card.dart';
import '../widgets/wallet_empty_state.dart';
import '../widgets/wallet_form_dialog.dart';

class ManageWalletsScreen extends ConsumerWidget {
  const ManageWalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Wallets'),
        actions: [
          // Sync status indicator removed (online-only architecture)
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Check if user is authenticated before showing dialog
              final user = currentUser.valueOrNull;
              if (user != null) {
                _showAddWalletDialog(context, ref);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please wait for authentication to complete'),
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
            return const Center(child: Text('Please login first'));
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
                  padding: const EdgeInsets.all(16),
                  itemCount: wallets.length,
                  itemBuilder: (context, index) => WalletCard(
                    wallet: wallets[index],
                    onTap: () => _showWalletDetails(context, wallets[index]),
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
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading wallets',
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
                    child: const Text('Retry'),
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
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text('Authentication Error', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(currentUserProvider),
                child: const Text('Retry'),
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
        final toggled = !wallet.isActive;
        try {
          await repo.updateWallet(
            wallet.id,
            userId,
            UpdateWalletRequest(isActive: toggled),
          );
          refreshWalletProviders(ref);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  toggled ? 'Wallet activated' : 'Wallet deactivated',
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
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    showDialog(
      context: context,
      builder: (_) => WalletFormDialog(
        title: 'Add Wallet',
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
        title: 'Edit Wallet',
        initialData: UpdateWalletRequest(
          name: wallet.name,
          balance: wallet.balance,
          currency: wallet.currency,
          icon: wallet.icon,
          isActive: wallet.isActive,
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
        title: const Text('Delete Wallet'),
        content: Text(
          'Are you sure you want to delete "${wallet.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
                    const SnackBar(content: Text('Wallet deleted')),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showWalletDetails(BuildContext context, Wallet wallet) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Wallet Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Name', wallet.name),
            _detailRow('Balance', wallet.balance.toStringAsFixed(2)),
            _detailRow('Currency', wallet.currency),
            _detailRow('Status', wallet.isActive ? 'Active' : 'Inactive'),
            _detailRow('Created', wallet.createdAt.toLocal().toString()),
            _detailRow('Updated', wallet.updatedAt.toLocal().toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
