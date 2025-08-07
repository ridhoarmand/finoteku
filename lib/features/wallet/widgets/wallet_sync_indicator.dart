import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/supabase_service.dart';
import '../providers/wallet_sync_provider.dart';

/// Widget untuk menampilkan status sync yang sederhana dan informatif
class WalletSyncIndicator extends ConsumerWidget {
  const WalletSyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    
    return currentUser.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        
        final syncState = ref.watch(walletSyncStateProvider);
        final connectionAsync = ref.watch(connectionStatusProvider);

        return connectionAsync.when(
          data: (isConnected) => _buildSyncIndicator(
            context, 
            syncState, 
            isConnected,
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildSyncIndicator(
    BuildContext context,
    WalletSyncState syncState,
    bool isConnected,
  ) {
    switch (syncState.status) {
      case SyncStatus.syncing:
        return _buildSyncingIndicator(context);
        
      case SyncStatus.success:
        return _buildSuccessIndicator(context, isConnected);
        
      case SyncStatus.error:
        return _buildErrorIndicator(context, syncState.message);
        
      case SyncStatus.idle:
        if (syncState.unsyncedCount > 0) {
          return _buildUnsyncedIndicator(
            context, 
            syncState.unsyncedCount, 
            isConnected,
          );
        }
        return _buildIdleIndicator(context, isConnected);
    }
  }

  Widget _buildSyncingIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue[100],
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
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Syncing...',
            style: TextStyle(
              color: Colors.blue[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessIndicator(BuildContext context, bool isConnected) {
    return Tooltip(
      message: isConnected 
          ? 'All data synced successfully' 
          : 'All data synced (offline)',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_done,
            color: Colors.green[600],
            size: 18,
          ),
          if (!isConnected) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.wifi_off,
              color: Colors.grey[600],
              size: 14,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorIndicator(BuildContext context, String? message) {
    return Tooltip(
      message: message ?? 'Sync failed',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sync_problem,
              color: Colors.red[700],
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              'Error',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnsyncedIndicator(
    BuildContext context, 
    int unsyncedCount, 
    bool isConnected,
  ) {
    final color = isConnected ? Colors.orange : Colors.grey;
    final message = isConnected 
        ? '$unsyncedCount items will sync automatically'
        : '$unsyncedCount items waiting for connection';

    return Tooltip(
      message: message,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isConnected ? Icons.sync : Icons.sync_disabled,
              color: color[700],
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              '$unsyncedCount',
              style: TextStyle(
                color: color[700],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!isConnected) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.wifi_off,
                color: color[700],
                size: 12,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIdleIndicator(BuildContext context, bool isConnected) {
    if (!isConnected) {
      return Tooltip(
        message: 'Offline mode',
        child: Icon(
          Icons.wifi_off,
          color: Colors.grey[600],
          size: 16,
        ),
      );
    }
    
    return Tooltip(
      message: 'All data synced',
      child: Icon(
        Icons.cloud_done,
        color: Colors.green[600],
        size: 18,
      ),
    );
  }
}

/// Widget untuk manual sync button
class ManualSyncButton extends ConsumerWidget {
  const ManualSyncButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final syncState = ref.watch(walletSyncStateProvider);
    
    return currentUser.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        
        return IconButton(
          onPressed: syncState.status == SyncStatus.syncing 
              ? null 
              : () => _performManualSync(ref, user.id),
          icon: syncState.status == SyncStatus.syncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          tooltip: syncState.status == SyncStatus.syncing 
              ? 'Syncing...' 
              : 'Sync data',
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  void _performManualSync(WidgetRef ref, String userId) {
    ref.read(walletSyncStateProvider.notifier).syncWalletData(userId);
  }
}
