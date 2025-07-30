import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_database_service.dart';
import '../features/wallet/services/supabase_wallet_service.dart';
import '../features/wallet/services/wallet_service.dart';
import '../features/category/services/supabase_category_service.dart';
import '../features/category/services/category_service.dart';
import 'supabase_service.dart';
import 'connectivity_service.dart';

// Provider untuk SyncService
final syncServiceProvider = Provider<SyncService>((ref) {
  final localDb = ref.watch(localDatabaseServiceProvider);
  final supabaseWalletService = ref.watch(supabaseWalletServiceProvider);
  final supabaseCategoryService = ref.watch(supabaseCategoryServiceProvider);
  final walletService = ref.watch(walletServiceProvider);
  final categoryService = ref.watch(categoryServiceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  return SyncService(
    localDb, 
    supabaseWalletService, 
    supabaseCategoryService,
    walletService,
    categoryService,
    connectivityService,
  );
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
  final WalletService _walletService;
  final CategoryService _categoryService;
  final ConnectivityService _connectivityService;

  Timer? _syncTimer;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isConnected = false;

  SyncService(
    this._localDb, 
    this._supabaseWalletService, 
    this._supabaseCategoryService,
    this._walletService,
    this._categoryService,
    this._connectivityService,
  ) {
    _initConnectivityListener();
  }  // Start auto sync (setiap 5 menit ketika online)
  void startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (SupabaseService.isAuthenticated && _isConnected) {
        _performAutoSync();
      }
    });
  }

  // Stop auto sync
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  // Initialize connectivity listener untuk auto sync ketika internet kembali
  void _initConnectivityListener() async {
    // Check initial connectivity
    _isConnected = await _connectivityService.isConnected;
    
    // Listen to connectivity changes
    _connectivitySubscription = _connectivityService.connectionStream.listen(
      (bool isConnected) async {
        final wasConnected = _isConnected;
        _isConnected = isConnected;
        
        if (kDebugMode) {
          print('🌐 Connectivity changed: ${isConnected ? "Connected" : "Disconnected"}');
        }
        
        // Jika baru saja terkoneksi setelah disconnect dan ada pending sync
        if (!wasConnected && isConnected && SupabaseService.isAuthenticated) {
          if (kDebugMode) {
            print('🔄 Internet reconnected, checking for pending sync...');
          }
          
          // Tunggu sebentar untuk memastikan koneksi stabil
          await Future.delayed(const Duration(seconds: 2));
          
          // Cek apakah ada data yang perlu di-sync
          final hasPendingData = await _checkForPendingSync();
          if (hasPendingData) {
            if (kDebugMode) {
              print('✅ Found pending data, starting auto sync...');
            }
            await _performAutoSync();
          }
        }
      },
    );
  }

  // Check apakah ada data yang pending sync
  Future<bool> _checkForPendingSync() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return false;

      // Check unsynced wallets
      final unsyncedWallets = await _localDb.getUnsyncedWallets(userId);
      if (unsyncedWallets.isNotEmpty) {
        if (kDebugMode) {
          print('📝 Found ${unsyncedWallets.length} unsynced wallets');
        }
        return true;
      }

      // Check unsynced categories
      final unsyncedCategories = await _localDb.getUnsyncedCategories(userId);
      if (unsyncedCategories.isNotEmpty) {
        if (kDebugMode) {
          print('📝 Found ${unsyncedCategories.length} unsynced categories');
        }
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking pending sync: $e');
      }
      return false;
    }
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
    if (userId != null && _isConnected) {
      try {
        if (kDebugMode) {
          print('🔄 Starting auto sync for user: $userId');
        }
        
        // Use the simpler auto sync methods for better efficiency
        await _performSimpleAutoSync(userId);
        
        if (kDebugMode) {
          print('✅ Auto sync completed for user: $userId');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Auto sync failed: $e');
        }
      }
    }
  }

  // Private method untuk simple auto sync (hanya sync unsynced items)
  Future<void> _performSimpleAutoSync(String userId) async {
    try {
      // Auto sync unsynced wallets
      await _walletService.syncUnsyncedWallets(userId);
      
      // Auto sync unsynced categories  
      await _categoryService.syncUnsyncedCategories(userId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Simple auto sync failed: $e');
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
