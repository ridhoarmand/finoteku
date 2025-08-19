import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/transaction.dart';
import '../../../services/supabase_service.dart';
import '../../../core/errors/failure.dart';
import '../../../core/logging/logger.dart';

// Provider untuk SupabaseTransactionService
final supabaseTransactionServiceProvider = Provider<SupabaseTransactionService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return SupabaseTransactionService(supabase);
});

class SupabaseTransactionService {
  final SupabaseClient _supabase;

  SupabaseTransactionService(this._supabase);

  // Ambil semua transaction user dari server
  Future<List<Transaction>> getTransactions(
    String userId, {
    String? walletId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase
          .from('transactions')
          .select('*')
          .eq('user_id', userId);

      if (walletId != null) query = query.eq('wallet_id', walletId);
      if (categoryId != null) query = query.eq('category_id', categoryId);
      if (startDate != null) {
        query = query.gte('date', startDate.toIso8601String().split('T')[0]);
      }
      if (endDate != null) {
        query = query.lte('date', endDate.toIso8601String().split('T')[0]);
      }

      final response = await query.order('date', ascending: false);
      if (response.isEmpty) return [];

      return (response as List)
          .map((item) => Transaction.fromJson(_convertFromSupabase(item)))
          .toList();
    } catch (e, st) {
      AppLogger.e('fetch transactions failed', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  // Ambil transaction by ID dari server
  Future<Transaction?> getTransaction(String transactionId, String userId) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select('*')
          .eq('id', transactionId)
          .eq('user_id', userId)
          .single();
      return Transaction.fromJson(_convertFromSupabase(response));
    } catch (e, st) {
      final msg = e.toString();
      if (msg.contains('No rows') || msg.contains('0 rows')) {
        return null;
      }
      AppLogger.e('fetch transaction failed', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  // Buat transaction baru di server
  Future<Transaction> createTransaction(
    String userId,
    CreateTransactionRequest request,
  ) async {
    try {
      if (request.categoryId == null || request.categoryId!.isEmpty) {
        throw const ValidationFailure('Category is required');
      }
      if (request.amount <= 0) {
        throw const ValidationFailure('Amount must be greater than 0');
      }
      final data = {
        'user_id': userId,
        'wallet_id': request.walletId,
        'category_id': request.categoryId,
        'amount': request.amount,
        'notes': request.notes,
        'date': request.date.toIso8601String().split('T')[0],
      };
      final response = await _supabase
          .from('transactions')
          .insert(data)
          .select()
          .single();
      return Transaction.fromJson(_convertFromSupabase(response));
    } catch (e, st) {
      AppLogger.e('create transaction failed', error: e, stackTrace: st);
      if (e is Failure) rethrow;
      throw mapException(e, st);
    }
  }

  // Update transaction di server
  Future<Transaction> updateTransaction(
    String transactionId,
    String userId,
    UpdateTransactionRequest request,
  ) async {
    try {
      final data = <String, dynamic>{};
      if (request.walletId != null) data['wallet_id'] = request.walletId;
      if (request.categoryId != null) data['category_id'] = request.categoryId;
      if (request.amount != null) data['amount'] = request.amount;
      if (request.notes != null) data['notes'] = request.notes;
      if (request.date != null) data['date'] = request.date!.toIso8601String().split('T')[0];

      if (data.isEmpty) {
        throw const ValidationFailure('No data to update');
      }
      if (data.containsKey('amount') && (data['amount'] as num) <= 0) {
        throw const ValidationFailure('Amount must be greater than 0');
      }

      final response = await _supabase
          .from('transactions')
          .update(data)
          .eq('id', transactionId)
          .eq('user_id', userId)
          .select()
          .single();
      return Transaction.fromJson(_convertFromSupabase(response));
    } catch (e, st) {
      AppLogger.e('update transaction failed', error: e, stackTrace: st);
      if (e is Failure) rethrow;
      throw mapException(e, st);
    }
  }

  // Hapus transaction di server
  Future<void> deleteTransaction(String transactionId, String userId) async {
    try {
      await _supabase
          .from('transactions')
          .delete()
          .eq('id', transactionId)
          .eq('user_id', userId);
    } catch (e, st) {
      AppLogger.e('delete transaction failed', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  // Legacy sync methods removed (online-only architecture)

  // Convert dari format Supabase ke format aplikasi
  Map<String, dynamic> _convertFromSupabase(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'user_id': data['user_id'],
      'wallet_id': data['wallet_id'],
      'category_id': data['category_id'],
      // Supabase bisa mengembalikan decimal sebagai String atau num
      'amount': _parseAmount(data['amount']),
      'notes': data['notes'],
      'date': data['date'],
      'created_at': data['created_at'],
      'updated_at': data['updated_at'],
  // Offline flags removed
    };
  }

  double _parseAmount(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

}
