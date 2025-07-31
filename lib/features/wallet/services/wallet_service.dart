import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:uuid/uuid.dart';
import '../../../models/wallet.dart';
import '../../../services/local_database_service.dart';
import 'supabase_wallet_service.dart';
import '../helpers/wallet_sync_helper.dart';

class WalletService {
  final LocalDatabaseService _localDb;
  final SupabaseWalletService _supabaseWalletService;
  late final WalletSyncHelper _syncHelper;
  final _uuid = const Uuid();

  WalletService(this._localDb, this._supabaseWalletService) {
    _syncHelper = WalletSyncHelper(_localDb, _supabaseWalletService);
  }

  // Buat wallet baru
  Future<Wallet> createWallet(String userId, CreateWalletRequest request) async {
    final wallet = Wallet(
      id: _uuid.v4(),
      userId: userId,
      name: request.name,
      balance: request.initialBalance,
      currency: request.currency,
      icon: request.icon,
      isActive: true,
      needsSync: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Simpan ke local database
    await _localDb.saveWallet(wallet);

    // Coba sync ke server jika online
    await _syncHelper.trySyncWallet(wallet);

    return wallet;
  }

  // Update wallet
  Future<Wallet> updateWallet(String walletId, String userId, UpdateWalletRequest request) async {
    final existingWallet = await _localDb.getWallet(walletId, userId);
    if (existingWallet == null) {
      throw Exception('Wallet not found');
    }

    if (existingWallet.userId != userId) {
      throw Exception('Unauthorized');
    }

    final updatedWallet = existingWallet.copyWith(
      name: request.name ?? existingWallet.name,
      balance: request.balance ?? existingWallet.balance,
      currency: request.currency ?? existingWallet.currency,
      icon: request.icon ?? existingWallet.icon,
      isActive: request.isActive ?? existingWallet.isActive,
      needsSync: true,
      updatedAt: DateTime.now(),
    );

    await _localDb.saveWallet(updatedWallet);

    // Coba sync ke server jika online
    await _syncHelper.trySyncWallet(updatedWallet);

    return updatedWallet;
  }

  // Hapus wallet
  Future<void> deleteWallet(String walletId, String userId) async {
    final wallet = await _localDb.getWallet(walletId, userId);
    if (wallet == null) {
      throw Exception('Wallet not found');
    }

    if (wallet.userId != userId) {
      throw Exception('Unauthorized');
    }

    // Check if wallet has transactions
    final hasTransactions = await _localDb.walletHasTransactions(walletId, userId);
    if (hasTransactions) {
      throw Exception('Cannot delete wallet that has transactions. Please transfer transactions to another wallet first.');
    }

    // Hapus dari local database
    await _localDb.deleteWallet(walletId, userId);

    // Coba sync penghapusan ke server jika online
    await _syncHelper.trySyncWalletDeletion(walletId, userId);
  }

  // Safe delete wallet with transaction transfer
  Future<void> safeDeleteWallet(String walletId, String userId, {String? transferToWalletId}) async {
    final wallet = await _localDb.getWallet(walletId, userId);
    if (wallet == null) {
      throw Exception('Wallet not found');
    }

    if (wallet.userId != userId) {
      throw Exception('Unauthorized');
    }

    // Use the safe delete method from local database
    await _localDb.safeDeleteWallet(walletId, userId, transferToWalletId: transferToWalletId);

    // Coba sync penghapusan ke server jika online
    await _syncHelper.trySyncWalletDeletion(walletId, userId);
  }

  // Check if wallet can be deleted
  Future<bool> canDeleteWallet(String walletId, String userId) async {
    return !(await _localDb.walletHasTransactions(walletId, userId));
  }

  // Get transaction count for wallet
  Future<int> getWalletTransactionCount(String walletId, String userId) async {
    final transactions = await _localDb.getTransactions(userId, walletId: walletId);
    return transactions.length;
  }

  // Transfer transactions between wallets
  Future<int> transferTransactionsToWallet(String fromWalletId, String toWalletId, String userId) async {
    // Validate both wallets exist and belong to user
    final fromWallet = await _localDb.getWallet(fromWalletId, userId);
    final toWallet = await _localDb.getWallet(toWalletId, userId);
    
    if (fromWallet == null || toWallet == null) {
      throw Exception('Wallet not found');
    }

    if (fromWallet.userId != userId || toWallet.userId != userId) {
      throw Exception('Unauthorized');
    }

    return await _localDb.transferTransactionsToWallet(fromWalletId, toWalletId, userId);
  }

  // Recalculate wallet balance
  Future<void> recalculateWalletBalance(String walletId, String userId) async {
    await _localDb.recalculateWalletBalance(walletId, userId);
  }

  // Ambil semua wallets user
  Future<List<Wallet>> getWallets(String userId) async {
    try {
      final wallets = await _localDb.getWallets(userId);
      
      // Jika belum ada wallet, buat default wallet
      if (wallets.isEmpty) {
        if (kDebugMode) {
          print('🏦 No wallets found for user $userId, creating default wallet');
        }
        await _createDefaultWallet(userId);
        return _localDb.getWallets(userId);
      }
      
      return wallets;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting wallets for user $userId: $e');
      }
      // Return empty list on error to prevent crashes
      return [];
    }
  }

  // Ambil wallet by ID (memerlukan userId untuk security)
  Future<Wallet?> getWalletById(String walletId, {String? userId}) async {
    if (userId != null) {
      return await _localDb.getWallet(walletId, userId);
    }
    
    // Jika tidak ada userId, tidak bisa mengambil wallet untuk security
    return null;
  }

  // Sync semua wallets ke server
  Future<void> syncWallets(String userId) async {
    try {
      final localWallets = await _localDb.getWallets(userId);
      final walletsNeedingSync = localWallets.where((w) => w.needsSync).toList();

      for (final wallet in walletsNeedingSync) {
        await _syncHelper.trySyncWallet(wallet);
      }

      // Ambil data terbaru dari server
      await _syncHelper.fetchAndMergeFromServer(userId);
    } catch (e) {
      if (kDebugMode) {
        print('Sync error: $e');
      }
      // Jangan throw error, biarkan app tetap berfungsi offline
    }
  }

  // Public method untuk sync semua unsynced wallets
  Future<void> syncUnsyncedWallets(String userId) async {
    try {
      if (kDebugMode) {
        print('🔄 Starting auto sync for unsynced wallets...');
      }

      final unsyncedWallets = await _localDb.getUnsyncedWallets(userId);
      if (unsyncedWallets.isEmpty) {
        if (kDebugMode) {
          print('✅ No wallets need sync');
        }
        return;
      }

      if (kDebugMode) {
        print('📝 Found ${unsyncedWallets.length} wallets to sync');
      }

      for (final wallet in unsyncedWallets) {
        await _syncHelper.trySyncWallet(wallet);
      }

      // Fetch and merge dari server
      await _syncHelper.fetchAndMergeFromServer(userId);

      if (kDebugMode) {
        print('✅ Auto sync completed for wallets');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Auto sync failed for wallets: $e');
      }
    }
  }

  // Update balance wallet
  Future<Wallet> updateWalletBalance(String walletId, String userId, double newBalance) async {
    return updateWallet(walletId, userId, UpdateWalletRequest(balance: newBalance));
  }

  // Add/subtract dari balance wallet
  Future<Wallet> adjustWalletBalance(String walletId, String userId, double amount) async {
    final wallet = await getWalletById(walletId);
    if (wallet == null) {
      throw Exception('Wallet not found');
    }

    final newBalance = wallet.balance + amount;
    return updateWalletBalance(walletId, userId, newBalance);
  }

  // Private methods

  Future<void> _createDefaultWallet(String userId) async {
    try {
      if (kDebugMode) {
        print('🏦 Creating default wallet for user: $userId');
      }

      final defaultWallet = Wallet(
        id: _uuid.v4(),
        userId: userId,
        name: 'Cash',
        balance: 0.0,
        currency: 'IDR',
        icon: 'cash', // Icon untuk default cash wallet
        isActive: true,
        needsSync: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _localDb.saveWallet(defaultWallet);
      
      // Try sync to server but don't fail if it doesn't work
      try {
        await _syncHelper.trySyncWallet(defaultWallet);
      } catch (syncError) {
        if (kDebugMode) {
          print('⚠️ Failed to sync default wallet to server: $syncError');
        }
        // Continue anyway - wallet is saved locally
      }

      if (kDebugMode) {
        print('✅ Default wallet created successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating default wallet: $e');
      }
      throw Exception('Failed to create default wallet: $e');
    }
  }

  // Force sync single wallet
  Future<void> forceSyncWallet(String walletId, String userId) async {
    final wallet = await _localDb.getWallet(walletId, userId);
    if (wallet == null) {
      throw Exception('Wallet not found');
    }

    // Force sync this specific wallet
    await _syncHelper.trySyncWallet(wallet);
  }
}
