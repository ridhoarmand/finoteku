import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/transaction.dart';
import '../../../services/supabase_service.dart';

// Provider untuk SupabaseTransactionService
final supabaseTransactionServiceProvider = Provider<SupabaseTransactionService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return SupabaseTransactionService(supabase);
});

class SupabaseTransactionService {
  final SupabaseClient _supabase;

  SupabaseTransactionService(this._supabase);

  // Ambil semua transaction user dari server
  Future<List<Transaction>> getTransactions(String userId, {
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

      // Apply filters
      if (walletId != null) {
        query = query.eq('wallet_id', walletId);
      }
      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }
      if (startDate != null) {
        query = query.gte('date', startDate.toIso8601String().split('T')[0]);
      }
      if (endDate != null) {
        query = query.lte('date', endDate.toIso8601String().split('T')[0]);
      }

      final response = await query.order('date', ascending: false);

      // Handle empty result
      if (response.isEmpty) {
        if (kDebugMode) {
          print('ℹ️ No transactions found in server for user: $userId');
        }
        return [];
      }

      return (response as List)
          .map((item) => Transaction.fromJson(_convertFromSupabase(item)))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching transactions from server: $e');
      }
      throw Exception('Failed to fetch transactions: $e');
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
    } catch (e) {
      if (e.toString().contains('No rows found') ||
          e.toString().contains('multiple (or no) rows returned') ||
          e.toString().contains('0 rows')) {
        if (kDebugMode) {
          print('ℹ️ Transaction not found in server: $transactionId');
        }
        return null;
      }
      if (kDebugMode) {
        print('❌ Error fetching transaction from server: $e');
      }
      throw Exception('Failed to fetch transaction: $e');
    }
  }

  // Buat transaction baru di server
  Future<Transaction> createTransaction(
    String userId,
    CreateTransactionRequest request,
  ) async {
    try {
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
    } catch (e) {
      throw Exception('Failed to create transaction: $e');
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
        throw Exception('No data to update');
      }

      final response = await _supabase
          .from('transactions')
          .update(data)
          .eq('id', transactionId)
          .eq('user_id', userId)
          .select()
          .single();

      return Transaction.fromJson(_convertFromSupabase(response));
    } catch (e) {
      throw Exception('Failed to update transaction: $e');
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
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }

  // Sync transaction ke server
  Future<Transaction> syncTransaction(Transaction transaction) async {
    try {
      if (kDebugMode) {
        print('🔄 Syncing transaction: ${transaction.id} for user: ${transaction.userId}');
      }

      // Cek apakah transaction sudah ada di server
      final checkResponse = await _supabase
          .from('transactions')
          .select('*')
          .eq('id', transaction.id)
          .eq('user_id', transaction.userId);

      if (checkResponse.isEmpty) {
        // Buat baru di server
        if (kDebugMode) {
          print('📝 Creating new transaction in server: ${transaction.id}');
        }

        final data = {
          'id': transaction.id, // Gunakan ID yang sama dari local
          'user_id': transaction.userId,
          'wallet_id': transaction.walletId,
          'category_id': transaction.categoryId,
          'amount': transaction.amount,
          'notes': transaction.notes,
          'date': transaction.date.toIso8601String().split('T')[0],
          'created_at': transaction.createdAt.toIso8601String(),
        };

        final response = await _supabase
            .from('transactions')
            .insert(data)
            .select()
            .single();

        if (kDebugMode) {
          print('✅ Transaction created successfully in server');
        }
        return Transaction.fromJson(_convertFromSupabase(response));
      } else {
        // Update yang sudah ada
        if (kDebugMode) {
          print('🔄 Updating existing transaction in server: ${transaction.id}');
        }
        final updateRequest = UpdateTransactionRequest(
          walletId: transaction.walletId,
          categoryId: transaction.categoryId,
          amount: transaction.amount,
          notes: transaction.notes,
          date: transaction.date,
        );
        final updatedTransaction = await updateTransaction(
          transaction.id,
          transaction.userId,
          updateRequest,
        );
        if (kDebugMode) {
          print('✅ Transaction updated successfully in server');
        }
        return updatedTransaction;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to sync transaction ${transaction.id}: $e');
      }
      throw Exception('Failed to sync transaction: $e');
    }
  }

  // Sync penghapusan transaction
  Future<void> syncTransactionDeletion(String transactionId, String userId) async {
    try {
      await deleteTransaction(transactionId, userId);
    } catch (e) {
      // Jika transaction tidak ditemukan di server, anggap sudah dihapus
      if (!e.toString().contains('No rows found')) {
        throw Exception('Failed to sync transaction deletion: $e');
      }
    }
  }

  // Convert dari format Supabase ke format aplikasi
  Map<String, dynamic> _convertFromSupabase(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'user_id': data['user_id'],
      'wallet_id': data['wallet_id'],
      'category_id': data['category_id'],
      'amount': data['amount'],
      'notes': data['notes'],
      'date': data['date'],
      'created_at': data['created_at'],
      'updated_at': data['updated_at'],
      'is_deleted': false, // Supabase tidak menyimpan soft delete
      'needs_sync': false, // Data dari server sudah ter-sync
    };
  }
}
