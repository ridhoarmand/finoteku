import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/wallet.dart';
import '../../../services/supabase_service.dart';
import '../../../core/errors/failure.dart';
import '../../../core/logging/logger.dart';

// Provider untuk SupabaseWalletService
final supabaseWalletServiceProvider = Provider<SupabaseWalletService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return SupabaseWalletService(supabase);
});

class SupabaseWalletService {
  final SupabaseClient _supabase;

  SupabaseWalletService(this._supabase);

  // Ambil semua wallet user dari server
  Future<List<Wallet>> getWallets(String userId) async {
    try {
      final response = await _supabase
          .from('wallets')
          .select('*')
          .eq('user_id', userId);

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
  Future<Wallet?> getWallet(String walletId, String userId) async {
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

  // Buat wallet baru di server
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

  // Update wallet di server
  Future<Wallet> updateWallet(
    String walletId,
    String userId,
    UpdateWalletRequest request,
  ) async {
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

  // Hapus wallet di server
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

  // Sync wallet ke server
  // Legacy sync methods removed (online-only)

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
