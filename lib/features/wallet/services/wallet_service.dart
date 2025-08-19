// Removed kDebugMode import (use AppLogger instead)
import '../../../core/errors/failure.dart';
import '../../../core/logging/logger.dart';
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
    } catch (e, st) {
      AppLogger.e('Gagal membuat wallet', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  Future<Wallet> updateWallet(String walletId, String userId, UpdateWalletRequest request) async {
    final existing = await _supabaseWalletService.getWallet(walletId, userId);
    if (existing == null) throw NotFoundFailure('Wallet tidak ditemukan');
    if (existing.userId != userId) throw PermissionFailure('Tidak berhak');
    try {
      return await _supabaseWalletService.updateWallet(walletId, userId, request);
    } catch (e, st) {
      AppLogger.e('Gagal update wallet', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  Future<void> deleteWallet(String walletId, String userId) async {
    try {
      await _supabaseWalletService.deleteWallet(walletId, userId);
    } catch (e, st) {
      AppLogger.e('Gagal hapus wallet', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  Future<void> safeDeleteWallet(String walletId, String userId, {String? transferToWalletId}) async {
    if (transferToWalletId != null) {
      throw ValidationFailure('Transfer transaksi antar wallet belum tersedia');
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
  if (wallet == null) throw NotFoundFailure('Wallet tidak ditemukan');
    return updateWalletBalance(walletId, userId, wallet.balance + amount);
  }
}
