import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../models/wallet.dart';
import '../services/supabase_wallet_service.dart';
import '../../../core/logging/logger.dart';
import '../../../core/state/refresh_token.dart';

// Alias repository: langsung gunakan SupabaseWalletService (wrapper dihapus)
final walletRepositoryProvider = Provider<SupabaseWalletService>((ref) => ref.watch(supabaseWalletServiceProvider));

// Unified refresh token for wallets
final walletRefreshTriggerProvider = createRefreshTokenProvider();

// Provider untuk daftar wallets berdasarkan user ID dengan smart sync
final walletsProvider = FutureProvider.family<List<Wallet>, String>((ref, userId) async {
  try {
    // Watch refresh trigger untuk auto-refresh saat ada perubahan
  ref.watch(walletRefreshTriggerProvider);
    
  final repo = ref.watch(walletRepositoryProvider);
  return await repo.getWallets(userId);
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
  final repo = ref.watch(walletRepositoryProvider);
  return repo.getWallet(params.walletId, params.userId);
});

// Provider untuk active wallets saja
final activeWalletsProvider = FutureProvider.family<List<Wallet>, String>((ref, userId) async {
  try {
    // Watch refresh trigger untuk auto-refresh saat ada perubahan
  ref.watch(walletRefreshTriggerProvider);
    
  final repo = ref.watch(walletRepositoryProvider);
  final wallets = await repo.getWallets(userId);
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


// Helper function untuk refresh semua wallet providers
void refreshWalletProviders(WidgetRef ref) {
  // Increment refresh trigger untuk memaksa semua wallet providers refresh
  ref.read(walletRefreshTriggerProvider.notifier).bump();
  
  AppLogger.i('Wallet providers refreshed');
}
