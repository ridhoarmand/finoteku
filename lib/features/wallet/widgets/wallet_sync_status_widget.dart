import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/supabase_service.dart';
import '../providers/wallet_providers.dart';

class WalletSyncStatusWidget extends ConsumerWidget {
  const WalletSyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    
    return currentUser.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        
        final connectionAsync = ref.watch(connectionStatusProvider);
        final walletsAsync = ref.watch(walletsProvider(user.id));

        return connectionAsync.when(
          data: (isConnected) => walletsAsync.when(
            data: (wallets) {
              final unsyncedCount = wallets.where((wallet) => wallet.needsSync).length;
              
              if (unsyncedCount == 0) {
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
              } else {
                return Tooltip(
                  message: isConnected 
                      ? '$unsyncedCount wallets will sync automatically'
                      : '$unsyncedCount wallets waiting for internet connection',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isConnected ? Colors.orange : Colors.grey,
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
                );
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
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
