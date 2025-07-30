import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/wallet.dart';
import '../../../services/local_database_service.dart';
import 'supabase_wallet_service.dart';

// Provider untuk WalletService
final walletServiceProvider = Provider<WalletService>((ref) {
  final localDb = ref.watch(localDatabaseServiceProvider);
  final supabaseWalletService = ref.watch(supabaseWalletServiceProvider);
  return WalletService(localDb, supabaseWalletService);
});

// Provider untuk daftar wallets berdasarkan user ID
final walletsProvider = FutureProvider.family<List<Wallet>, String>((ref, userId) async {
  final walletService = ref.watch(walletServiceProvider);
  return walletService.getWallets(userId);
});

// Provider untuk wallet by ID
final walletProvider = FutureProvider.family<Wallet?, String>((ref, walletId) async {
  final walletService = ref.watch(walletServiceProvider);
  return walletService.getWalletById(walletId);
});

// Provider untuk active wallets saja
final activeWalletsProvider = FutureProvider.family<List<Wallet>, String>((ref, userId) async {
  final walletService = ref.watch(walletServiceProvider);
  final wallets = await walletService.getWallets(userId);
  return wallets.where((wallet) => wallet.isActive).toList();
});

// Provider untuk total balance dari semua active wallets
final totalBalanceProvider = FutureProvider.family<double, String>((ref, userId) async {
  final activeWallets = await ref.watch(activeWalletsProvider(userId).future);
  double total = 0.0;
  for (final wallet in activeWallets) {
    total += wallet.balance;
  }
  return total;
});

class WalletService {
  final LocalDatabaseService _localDb;
  final SupabaseWalletService _supabaseWalletService;
  final _uuid = const Uuid();

  WalletService(this._localDb, this._supabaseWalletService);

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
    await _trySyncWallet(wallet);

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
    await _trySyncWallet(updatedWallet);

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

    // Hapus dari local database
    await _localDb.deleteWallet(walletId, userId);

    // Coba sync penghapusan ke server jika online
    await _trySyncWalletDeletion(walletId, userId);
  }

  // Ambil semua wallets user
  Future<List<Wallet>> getWallets(String userId) async {
    final wallets = await _localDb.getWallets(userId);
    
    // Jika belum ada wallet, buat default wallet
    if (wallets.isEmpty) {
      await _createDefaultWallet(userId);
      return _localDb.getWallets(userId);
    }
    
    return wallets;
  }

  // Ambil wallet by ID
  Future<Wallet?> getWalletById(String walletId) async {
    // Karena method getWallet memerlukan userId, kita perlu cara lain
    // Untuk saat ini, return null jika tidak bisa mengambil tanpa userId
    return null; // TODO: Implement proper getWalletById
  }

  // Sync semua wallets ke server
  Future<void> syncWallets(String userId) async {
    try {
      final localWallets = await _localDb.getWallets(userId);
      final walletsNeedingSync = localWallets.where((w) => w.needsSync).toList();

      for (final wallet in walletsNeedingSync) {
        await _trySyncWallet(wallet);
      }

      // Ambil data terbaru dari server
      await _fetchAndMergeFromServer(userId);
    } catch (e) {
      if (kDebugMode) {
        print('Sync error: $e');
      }
      // Jangan throw error, biarkan app tetap berfungsi offline
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
    final defaultWallet = Wallet(
      id: _uuid.v4(),
      userId: userId,
      name: 'Main Wallet',
      balance: 0.0,
      currency: 'IDR',
      isActive: true,
      needsSync: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _localDb.saveWallet(defaultWallet);
    await _trySyncWallet(defaultWallet);
  }

  Future<void> _trySyncWallet(Wallet wallet) async {
    try {
      // Coba sync ke Supabase jika online dan authenticated
      await _supabaseWalletService.syncWallet(wallet);
      
      // Mark as synced jika berhasil
      final syncedWallet = wallet.copyWith(needsSync: false);
      await _localDb.saveWallet(syncedWallet);
    } catch (e) {
      if (kDebugMode) {
        print('Sync wallet error: $e');
      }
      // Jangan throw error, biarkan tetap tersimpan local dengan needsSync = true
    }
  }

  Future<void> _trySyncWalletDeletion(String walletId, String userId) async {
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

  Future<void> _fetchAndMergeFromServer(String userId) async {
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
        print('Fetch from server error: $e');
      }
    }
  }
}
