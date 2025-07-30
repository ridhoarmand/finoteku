import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../models/wallet.dart';
import '../services/supabase_wallet_service.dart';
import '../../../services/local_database_service.dart';

/// Helper class untuk sync operations pada wallet
class WalletSyncHelper {
  final LocalDatabaseService _localDb;
  final SupabaseWalletService _supabaseWalletService;

  WalletSyncHelper(this._localDb, this._supabaseWalletService);

  /// Sync unsynced wallets to server
  Future<void> syncUnsyncedWallets(String userId) async {
    try {
      if (kDebugMode) {
        print('🔄 Starting sync unsynced wallets for user: $userId');
      }

      // Ambil wallets yang belum ter-sync
      final unsyncedWallets = await _localDb.getUnsyncedWallets(userId);
      
      if (unsyncedWallets.isEmpty) {
        if (kDebugMode) {
          print('✅ No unsynced wallets found');
        }
        return;
      }

      if (kDebugMode) {
        print('📤 Found ${unsyncedWallets.length} unsynced wallets');
      }

      int syncedCount = 0;
      for (final wallet in unsyncedWallets) {
        try {
          // Sync ke server
          final syncedWallet = await _supabaseWalletService.syncWallet(wallet);
          
          // Update local dengan data dari server dan tandai sudah sync
          final updatedWallet = syncedWallet.copyWith(needsSync: false);
          await _localDb.saveWallet(updatedWallet);
          
          syncedCount++;
          if (kDebugMode) {
            print('✅ Synced wallet: ${wallet.name}');
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Failed to sync wallet ${wallet.name}: $e');
          }
          // Continue dengan wallet lainnya
        }
      }

      if (kDebugMode) {
        print('🎉 Sync completed: $syncedCount/${unsyncedWallets.length} wallets synced');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during sync unsynced wallets: $e');
      }
      throw Exception('Failed to sync wallets: $e');
    }
  }

  /// Try sync single wallet to server
  Future<void> trySyncWallet(Wallet wallet) async {
    try {
      // Coba sync ke Supabase
      final syncedWallet = await _supabaseWalletService.syncWallet(wallet);
      
      // Update local dengan data dari server dan tandai sudah sync
      final updatedWallet = syncedWallet.copyWith(needsSync: false);
      await _localDb.saveWallet(updatedWallet);
      
      if (kDebugMode) {
        print('✅ Wallet synced successfully: ${wallet.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Sync wallet error: $e');
        print('📝 Wallet will remain with needsSync=true until next sync attempt');
      }
      // Jangan throw error, biarkan tetap tersimpan local dengan needsSync = true
    }
  }

  /// Try sync wallet deletion to server
  Future<void> trySyncWalletDeletion(String walletId, String userId) async {
    try {
      // Coba sync penghapusan ke Supabase
      await _supabaseWalletService.syncWalletDeletion(walletId, userId);
    } catch (e) {
      if (kDebugMode) {
        print('Sync wallet deletion error: $e');
      }
      // Jangan throw error
    }
  }

  /// Fetch and merge wallets from server
  Future<void> fetchAndMergeFromServer(String userId) async {
    try {
      // Ambil data wallet dari server dan merge dengan local
      final serverWallets = await _supabaseWalletService.getWallets(userId);

      for (final serverWallet in serverWallets) {
        final localWallet = await _localDb.getWallet(serverWallet.id, userId);

        if (localWallet == null) {
          // Wallet baru dari server, simpan ke local
          await _localDb.saveWallet(serverWallet);
        } else if (serverWallet.updatedAt.isAfter(localWallet.updatedAt)) {
          // Server lebih baru, update local
          await _localDb.saveWallet(serverWallet);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Fetch wallets from server error: $e');
      }
    }
  }
}
