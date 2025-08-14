import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../models/wallet.dart';
import 'supabase_wallet_service.dart';

/// Layanan Wallet (ONLINE-ONLY)
/// Semua operasi langsung berkomunikasi dengan Supabase.
class WalletService {
  final SupabaseWalletService _supabaseWalletService;
  WalletService(this._supabaseWalletService);

  Future<Wallet> createWallet(String userId, CreateWalletRequest request) async {
    try {
      return await _supabaseWalletService.createWallet(userId, request);
    } catch (e) {
      if (kDebugMode) print('❌ Gagal membuat wallet: $e');
      rethrow;
    }
  }

  Future<Wallet> updateWallet(String walletId, String userId, UpdateWalletRequest request) async {
    final existing = await _supabaseWalletService.getWallet(walletId, userId);
    if (existing == null) throw Exception('Wallet tidak ditemukan');
    if (existing.userId != userId) throw Exception('Tidak berhak');
    return _supabaseWalletService.updateWallet(walletId, userId, request);
  }

  Future<void> deleteWallet(String walletId, String userId) async {
    try {
      await _supabaseWalletService.deleteWallet(walletId, userId);
    } catch (e) {
      if (kDebugMode) print('❌ Gagal hapus wallet: $e');
      rethrow;
    }
  }

  Future<void> safeDeleteWallet(String walletId, String userId, {String? transferToWalletId}) async {
    if (transferToWalletId != null) {
      throw Exception('Transfer transaksi antar wallet belum tersedia');
    }
    await deleteWallet(walletId, userId);
  }

  Future<bool> canDeleteWallet(String walletId, String userId) async => true;
  Future<int> getWalletTransactionCount(String walletId, String userId) async => 0;
  Future<int> transferTransactionsToWallet(String fromWalletId, String toWalletId, String userId) async => throw Exception('Belum didukung');
  Future<void> recalculateWalletBalance(String walletId, String userId) async {}

  Future<List<Wallet>> getWallets(String userId) async => _supabaseWalletService.getWallets(userId);
  Future<Wallet?> getWalletById(String walletId, {String? userId}) async => userId == null ? null : _supabaseWalletService.getWallet(walletId, userId);

  // Legacy offline sync methods removed.

  Future<Wallet> updateWalletBalance(String walletId, String userId, double newBalance) async {
    return updateWallet(walletId, userId, UpdateWalletRequest(balance: newBalance));
  }

  Future<Wallet> adjustWalletBalance(String walletId, String userId, double amount) async {
    final wallet = await getWalletById(walletId, userId: userId);
    if (wallet == null) throw Exception('Wallet tidak ditemukan');
    return updateWalletBalance(walletId, userId, wallet.balance + amount);
  }
}
