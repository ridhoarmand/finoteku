import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../models/wallet.dart';
import '../../../services/local_database_service.dart';
import '../services/wallet_service.dart';
import '../services/supabase_wallet_service.dart';
import '../../../services/connectivity_service.dart';

// Provider untuk WalletService  
final walletServiceProvider = Provider<WalletService>((ref) {
  final localDb = ref.watch(localDatabaseServiceProvider);
  final supabaseWalletService = ref.watch(supabaseWalletServiceProvider);
  return WalletService(localDb, supabaseWalletService);
});

// StateProvider untuk trigger refresh wallets
final walletRefreshTriggerProvider = StateProvider<int>((ref) => 0);

// Provider untuk daftar wallets berdasarkan user ID dengan smart sync
final walletsProvider = FutureProvider.family<List<Wallet>, String>((ref, userId) async {
  try {
    // Watch refresh trigger untuk auto-refresh saat ada perubahan
    ref.watch(walletRefreshTriggerProvider);
    
    final walletService = ref.watch(walletServiceProvider);
    
    // Cleanup duplicate Cash wallets before fetching
    await walletService.cleanupDuplicateCashWallets(userId);
    
    final wallets = await walletService.getWallets(userId);
    
    // Check if any wallets need sync and trigger auto sync in background
    final unsyncedWallets = wallets.where((w) => w.needsSync).toList();
    if (unsyncedWallets.isNotEmpty) {
      // Trigger background sync without blocking the UI
      Future.microtask(() async {
        try {
          final isConnected = await ref.read(connectionStatusProvider.future);
          if (isConnected) {
            await walletService.syncUnsyncedWallets(userId);
            // Trigger refresh
            ref.read(walletRefreshTriggerProvider.notifier).state++;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Background sync failed: $e');
          }
        }
      });
    }
    
    return wallets;
  } catch (e) {
    if (kDebugMode) {
      print('❌ Error in walletsProvider for user $userId: $e');
    }
    // Return empty list instead of throwing to prevent crashes
    return <Wallet>[];
  }
});

// Provider untuk wallet by ID
final walletProvider = FutureProvider.family<Wallet?, ({String walletId, String userId})>((ref, params) async {
  final walletService = ref.watch(walletServiceProvider);
  return walletService.getWalletById(params.walletId, userId: params.userId);
});

// Provider untuk active wallets saja
final activeWalletsProvider = FutureProvider.family<List<Wallet>, String>((ref, userId) async {
  try {
    // Watch refresh trigger untuk auto-refresh saat ada perubahan
    ref.watch(walletRefreshTriggerProvider);
    
    final walletService = ref.watch(walletServiceProvider);
    final wallets = await walletService.getWallets(userId);
    return wallets.where((wallet) => wallet.isActive).toList();
  } catch (e) {
    if (kDebugMode) {
      print('❌ Error in activeWalletsProvider for user $userId: $e');
    }
    // Return empty list instead of throwing to prevent crashes
    return <Wallet>[];
  }
});

// Provider untuk total balance dari semua active wallets
final totalBalanceProvider = FutureProvider.family<double, String>((ref, userId) async {
  try {
    // Watch refresh trigger untuk auto-refresh saat ada perubahan
    ref.watch(walletRefreshTriggerProvider);
    
    final activeWallets = await ref.watch(activeWalletsProvider(userId).future);
    double total = 0.0;
    for (final wallet in activeWallets) {
      total += wallet.balance;
    }
    return total;
  } catch (e) {
    if (kDebugMode) {
      print('❌ Error in totalBalanceProvider for user $userId: $e');
    }
    // Return 0.0 instead of throwing to prevent crashes
    return 0.0;
  }
});

// Provider untuk cleanup duplicate wallets (one-time use)
final walletCleanupProvider = FutureProvider.family<bool, String>((ref, userId) async {
  try {
    final walletService = ref.read(walletServiceProvider);
    await walletService.cleanupDuplicateCashWallets(userId);
    return true;
  } catch (e) {
    if (kDebugMode) {
      print('❌ Error in walletCleanupProvider: $e');
    }
    return false;
  }
});

// Helper function untuk refresh semua wallet providers
void refreshWalletProviders(WidgetRef ref) {
  // Increment refresh trigger untuk memaksa semua wallet providers refresh
  ref.read(walletRefreshTriggerProvider.notifier).state++;
  
  if (kDebugMode) {
    print('🔄 Triggered refresh for all wallet providers');
  }
}
