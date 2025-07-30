import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_database_service.dart';
import '../features/wallet/services/supabase_wallet_service.dart';
import '../features/category/services/supabase_category_service.dart';
import 'supabase_service.dart';

// Provider untuk SyncService
final syncServiceProvider = Provider<SyncService>((ref) {
  final localDb = ref.watch(localDatabaseServiceProvider);
  final supabaseWalletService = ref.watch(supabaseWalletServiceProvider);
  final supabaseCategoryService = ref.watch(supabaseCategoryServiceProvider);
  return SyncService(localDb, supabaseWalletService, supabaseCategoryService);
});

// Provider untuk sync status
final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}

class SyncService {
  final LocalDatabaseService _localDb;
  final SupabaseWalletService _supabaseWalletService;
  final SupabaseCategoryService _supabaseCategoryService;
  
  Timer? _syncTimer;

  SyncService(this._localDb, this._supabaseWalletService, this._supabaseCategoryService);

  // Start auto sync (setiap 5 menit ketika online)
  void startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (SupabaseService.isAuthenticated) {
        _performAutoSync();
      }
    });
  }

  // Stop auto sync
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  // Manual sync untuk user tertentu
  Future<SyncResult> syncUserData(String userId) async {
    if (!SupabaseService.isAuthenticated) {
      return SyncResult(
        success: false,
        error: 'User not authenticated',
      );
    }

    try {
      final walletResult = await syncWallets(userId);
      final categoryResult = await syncCategories(userId);

      return SyncResult(
        success: walletResult.success && categoryResult.success,
        walletsSync: walletResult,
        categoriesSync: categoryResult,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        error: 'Sync failed: $e',
      );
    }
  }

  // Sync wallets untuk user
  Future<SyncResult> syncWallets(String userId) async {
    try {
      // 1. Push local changes ke server
      final unsyncedWallets = await _localDb.getUnsyncedWallets(userId);
      int pushedCount = 0;
      
      for (final wallet in unsyncedWallets) {
        try {
          if (wallet.isDeleted) {
            await _supabaseWalletService.syncWalletDeletion(wallet.id, userId);
          } else {
            await _supabaseWalletService.syncWallet(wallet);
          }
          await _localDb.markWalletSynced(wallet.id, userId);
          pushedCount++;
        } catch (e) {
          if (kDebugMode) {
            print('Failed to sync wallet ${wallet.id}: $e');
          }
        }
      }

      // 2. Pull data terbaru dari server
      final serverWallets = await _supabaseWalletService.getWallets(userId);
      int pulledCount = 0;

      for (final serverWallet in serverWallets) {
        final localWallet = await _localDb.getWallet(serverWallet.id, userId);
        
        if (localWallet == null) {
          // Wallet baru dari server
          await _localDb.saveWallet(serverWallet);
          pulledCount++;
        } else if (serverWallet.updatedAt.isAfter(localWallet.updatedAt)) {
          // Server lebih baru, update local
          await _localDb.saveWallet(serverWallet);
          pulledCount++;
        }
      }

      return SyncResult(
        success: true,
        pushedCount: pushedCount,
        pulledCount: pulledCount,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        error: 'Wallet sync failed: $e',
      );
    }
  }

  // Sync categories untuk user
  Future<SyncResult> syncCategories(String userId) async {
    try {
      // 1. Push local changes ke server
      final unsyncedCategories = await _localDb.getUnsyncedCategories(userId);
      int pushedCount = 0;
      
      for (final category in unsyncedCategories) {
        try {
          if (category.isDeleted) {
            await _supabaseCategoryService.syncCategoryDeletion(category.id, userId);
          } else {
            await _supabaseCategoryService.syncCategory(category);
          }
          await _localDb.markCategorySynced(category.id, userId);
          pushedCount++;
        } catch (e) {
          if (kDebugMode) {
            print('Failed to sync category ${category.id}: $e');
          }
        }
      }

      // 2. Pull data terbaru dari server
      final serverCategories = await _supabaseCategoryService.getCategories(userId);
      int pulledCount = 0;

      for (final serverCategory in serverCategories) {
        final localCategory = await _localDb.getCategory(serverCategory.id, userId);
        
        if (localCategory == null) {
          // Category baru dari server
          await _localDb.saveCategory(serverCategory);
          pulledCount++;
        } else if (serverCategory.updatedAt.isAfter(localCategory.updatedAt)) {
          // Server lebih baru, update local
          await _localDb.saveCategory(serverCategory);
          pulledCount++;
        }
      }

      return SyncResult(
        success: true,
        pushedCount: pushedCount,
        pulledCount: pulledCount,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        error: 'Category sync failed: $e',
      );
    }
  }

  // Backup data ke server (one-way push)
  Future<SyncResult> backupUserData(String userId) async {
    if (!SupabaseService.isAuthenticated) {
      return SyncResult(
        success: false,
        error: 'User not authenticated',
      );
    }

    try {
      // Backup wallets
      final localWallets = await _localDb.getWallets(userId);
      int walletCount = 0;
      
      for (final wallet in localWallets) {
        try {
          await _supabaseWalletService.syncWallet(wallet);
          await _localDb.markWalletSynced(wallet.id, userId);
          walletCount++;
        } catch (e) {
          if (kDebugMode) {
            print('Failed to backup wallet ${wallet.id}: $e');
          }
        }
      }

      // Backup categories
      final localCategories = await _localDb.getCategories(userId);
      int categoryCount = 0;
      
      for (final category in localCategories) {
        try {
          await _supabaseCategoryService.syncCategory(category);
          await _localDb.markCategorySynced(category.id, userId);
          categoryCount++;
        } catch (e) {
          if (kDebugMode) {
            print('Failed to backup category ${category.id}: $e');
          }
        }
      }

      return SyncResult(
        success: true,
        pushedCount: walletCount + categoryCount,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        error: 'Backup failed: $e',
      );
    }
  }

  // Private method untuk auto sync
  Future<void> _performAutoSync() async {
    final userId = SupabaseService.currentUserId;
    if (userId != null) {
      try {
        await syncUserData(userId);
        if (kDebugMode) {
          print('Auto sync completed for user: $userId');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Auto sync failed: $e');
        }
      }
    }
  }
}

class SyncResult {
  final bool success;
  final String? error;
  final int pushedCount;
  final int pulledCount;
  final SyncResult? walletsSync;
  final SyncResult? categoriesSync;

  SyncResult({
    required this.success,
    this.error,
    this.pushedCount = 0,
    this.pulledCount = 0,
    this.walletsSync,
    this.categoriesSync,
  });

  @override
  String toString() {
    if (!success) {
      return 'Sync failed: ${error ?? "Unknown error"}';
    }
    return 'Sync success: pushed $pushedCount, pulled $pulledCount items';
  }
}
