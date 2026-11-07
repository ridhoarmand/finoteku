// Removed kDebugMode import (use AppLogger instead)
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../core/logging/logger.dart';
import '../../../models/wallet.dart';
import '../../../services/supabase_service.dart';

class WalletService {
  final SupabaseClient _supabase;

  WalletService(this._supabase);

  // Ambil semua wallet user dari server
  Future<List<Wallet>> getWallets(String userId) async {
    try {
      final response = await _supabase
          .from('wallets')
          .select('*')
          .eq('user_id', userId)
          .order('updated_at', ascending: false); // Urutkan dari yang terbaru

      // Handle empty result
      if (response.isEmpty) return [];

      return (response as List)
          .map((item) => Wallet.fromJson(_convertFromSupabase(item)))
          .toList();
    } catch (e, st) {
      AppLogger.e('fetch wallets failed', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  // Ambil wallet by ID dari server
  Future<Wallet?> getWalletById(String walletId, {String? userId}) async {
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('wallets')
          .select('*')
          .eq('id', walletId)
          .eq('user_id', userId)
          .single();

      return Wallet.fromJson(_convertFromSupabase(response));
    } catch (e, st) {
      final msg = e.toString();
      if (msg.contains('No rows') || msg.contains('0 rows')) {
        return null;
      }
      AppLogger.e('fetch wallet failed', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  Future<Wallet> createWallet(
    String userId,
    CreateWalletRequest request,
  ) async {
    try {
      final data = {
        'user_id': userId,
        'name': request.name,
        'balance': request.initialBalance,
        'currency': request.currency,
        'icon': request.icon,
        'is_hidden': false,
      };

      final response = await _supabase
          .from('wallets')
          .insert(data)
          .select()
          .single();

      return Wallet.fromJson(_convertFromSupabase(response));
    } catch (e, st) {
      AppLogger.e('create wallet failed', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  Future<Wallet> updateWallet(
    String walletId,
    String userId,
    UpdateWalletRequest request,
  ) async {
    final existing = await getWalletById(walletId, userId: userId);
    if (existing == null) throw NotFoundFailure('Wallet tidak ditemukan');
    if (existing.userId != userId) throw PermissionFailure('Tidak berhak');

    try {
      final data = <String, dynamic>{};
      if (request.name != null) data['name'] = request.name;
      if (request.balance != null) data['balance'] = request.balance;
      if (request.currency != null) data['currency'] = request.currency;
      if (request.icon != null) data['icon'] = request.icon;
      if (request.isHidden != null) data['is_hidden'] = request.isHidden;

      if (data.isEmpty) {
        throw Exception('No data to update');
      }

      final response = await _supabase
          .from('wallets')
          .update(data)
          .eq('id', walletId)
          .eq('user_id', userId)
          .select()
          .single();

      return Wallet.fromJson(_convertFromSupabase(response));
    } catch (e, st) {
      AppLogger.e('update wallet failed', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  Future<void> deleteWallet(String walletId, String userId) async {
    try {
      await _supabase
          .from('wallets')
          .delete()
          .eq('id', walletId)
          .eq('user_id', userId);
    } catch (e, st) {
      AppLogger.e('delete wallet failed', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  // Legacy offline sync methods removed.

  // Convert dari format Supabase ke format aplikasi
  Map<String, dynamic> _convertFromSupabase(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'user_id': data['user_id'],
      'name': data['name'],
      'balance': data['balance'],
      'currency': data['currency'],
      'icon': data['icon'],
      'is_hidden': data['is_hidden'],
      'created_at': data['created_at'],
      'updated_at': data['updated_at'],
    };
  }
}

// Provider untuk WalletService
final walletServiceProvider = Provider<WalletService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return WalletService(supabase);
});
