import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';
import '../../../core/errors/failure.dart';
import '../../../core/logging/logger.dart';
import '../models/transfer_models.dart';

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
}
