import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';
import '../../../core/errors/failure.dart';
import '../../../core/logging/logger.dart';
import '../models/transfer_models.dart';
import '../models/transfer.dart';

final supabaseTransferServiceProvider = Provider<SupabaseTransferService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return SupabaseTransferService(supabase);
});

class SupabaseTransferService {
  final SupabaseClient _supabase;
  SupabaseTransferService(this._supabase);

  Future<String> createWalletTransfer(String userId, CreateWalletTransferRequest request) async {
    try {
      final payload = request.toJson(userId);
      final result = await _supabase.rpc('create_wallet_transfer', params: payload);
      // Supabase returns the scalar as dynamic
      final id = result as String;
      return id;
    } catch (e, st) {
      AppLogger.e('create wallet transfer failed', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  Future<Transfer?> getTransferById(String userId, String transferId) async {
    try {
      final res = await _supabase
          .from('transfers')
          .select()
          .eq('user_id', userId)
          .eq('id', transferId)
          .maybeSingle();
      if (res == null) return null;
  return Transfer.fromMap(res);
    } catch (e, st) {
      AppLogger.e('get transfer by id failed', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  Future<void> deleteTransfer(String userId, String transferId) async {
    try {
      await _supabase.rpc('delete_wallet_transfer', params: {
        'p_user_id': userId,
        'p_transfer_id': transferId,
      });
    } catch (e, st) {
      AppLogger.e('delete wallet transfer failed', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  Future<Transfer> updateTransfer(String userId, String transferId, {
    String? fromWalletId,
    String? toWalletId,
    double? amount,
    double? fee,
    String? notes,
    DateTime? date,
    String? feeCategoryId,
  }) async {
    // Use RPC to atomically update transfer and fee transaction, and handle balance movements correctly
    final resultId = await _supabase.rpc('update_wallet_transfer', params: {
      'p_user_id': userId,
      'p_transfer_id': transferId,
      'p_from_wallet_id': fromWalletId,
      'p_to_wallet_id': toWalletId,
      'p_amount': amount,
      'p_fee': fee,
      'p_notes': notes,
      'p_date': date?.toIso8601String().split('T')[0],
      'p_fee_category_id': feeCategoryId,
    }) as String;
    final res = await _supabase
        .from('transfers')
        .select()
        .eq('user_id', userId)
        .eq('id', resultId)
        .single();
    return Transfer.fromMap(res);
  }
}
