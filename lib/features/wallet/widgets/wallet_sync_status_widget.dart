import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/supabase_service.dart';
import '../providers/wallet_providers.dart';
import '../providers/wallet_sync_provider.dart';

class WalletSyncStatusWidget extends ConsumerStatefulWidget {
  const WalletSyncStatusWidget({super.key});

  @override
  ConsumerState<WalletSyncStatusWidget> createState() => _WalletSyncStatusWidgetState();
}

class _WalletSyncStatusWidgetState extends ConsumerState<WalletSyncStatusWidget> {
  
  @override
  void initState() {
    super.initState();
    // Check unsynced count when widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUnsyncedCount();
    });
  }

  void _checkUnsyncedCount() {
    final currentUser = ref.read(currentUserProvider);
    currentUser.whenData((user) {
      if (user != null) {
        ref.read(walletSyncStateProvider.notifier).checkUnsyncedCount(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    
    return currentUser.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        
        final connectionAsync = ref.watch(connectionStatusProvider);
        final walletsAsync = ref.watch(walletsProvider(user.id));
        final syncState = ref.watch(walletSyncStateProvider);

        return connectionAsync.when(
          data: (isConnected) => walletsAsync.when(
            data: (wallets) {
              final unsyncedCount = wallets.where((wallet) => wallet.needsSync).length;
              
              // Update sync state with current unsynced count
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (syncState.unsyncedCount != unsyncedCount) {
                  ref.read(walletSyncStateProvider.notifier).updateUnsyncedCount(unsyncedCount);
                }
              });

              // Show sync status if syncing
              if (syncState.status == SyncStatus.syncing) {
                return _buildSyncingIndicator(context);
              }

              // Show error status if sync failed
              if (syncState.status == SyncStatus.error) {
                return _buildErrorIndicator(context, syncState.message, user.id);
              }
              
              if (unsyncedCount == 0) {
                return _buildSyncedIndicator(context, isConnected);
              } else {
                return _buildUnsyncedIndicator(context, unsyncedCount, isConnected, user.id);
              }
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildSyncingIndicator(BuildContext context) {
    return Tooltip(
      message: 'Syncing wallets...',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue[600],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Syncing',
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorIndicator(BuildContext context, String? message, String userId) {
    return Tooltip(
      message: message ?? 'Sync failed - tap to retry',
      child: GestureDetector(
        onTap: () => _retrySync(userId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sync_problem,
                color: Colors.red[600],
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'Retry',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncedIndicator(BuildContext context, bool isConnected) {
    return Tooltip(
      message: isConnected 
          ? 'All wallets synced' 
          : 'All wallets synced (offline)',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_done,
            color: Colors.green[600],
            size: 20,
          ),
          if (!isConnected) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.wifi_off,
              color: Colors.grey[600],
              size: 16,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnsyncedIndicator(
    BuildContext context, 
    int unsyncedCount, 
    bool isConnected,
    String userId,
  ) {
    final color = isConnected ? Colors.orange : Colors.grey;
    final message = isConnected 
        ? '$unsyncedCount wallets will sync automatically'
        : '$unsyncedCount wallets waiting for internet connection';

    return Tooltip(
      message: message,
      child: GestureDetector(
        onTap: isConnected ? () => _triggerSync(userId) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isConnected ? Icons.sync : Icons.sync_disabled,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '$unsyncedCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isConnected) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.wifi_off,
                  color: Colors.white,
                  size: 12,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _triggerSync(String userId) {
    ref.read(walletSyncStateProvider.notifier).syncWalletData(userId);
  }

  void _retrySync(String userId) {
    ref.read(walletSyncStateProvider.notifier).syncWalletData(userId);
  }
}
