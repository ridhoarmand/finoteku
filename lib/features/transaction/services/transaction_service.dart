import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../models/transaction.dart';
import 'supabase_transaction_service.dart';

/// Service transaksi online-only (langsung Supabase)
class TransactionService {
  final SupabaseTransactionService _supabase;

  TransactionService(this._supabase);

  // Buat transaction baru
  Future<Transaction> createTransaction(String userId, CreateTransactionRequest request) async {
    try {
      if (request.categoryId == null || request.categoryId!.isEmpty) {
        throw Exception('Category is required');
      }
      if (request.amount <= 0) {
        throw Exception('Amount must be greater than 0');
      }
      return await _supabase.createTransaction(userId, request);
    } catch (e) {
      if (kDebugMode) print('❌ Gagal membuat transaksi: $e');
      rethrow;
    }
  }

  // Update transaction
  Future<Transaction> updateTransaction(String transactionId, String userId, UpdateTransactionRequest request) async {
  final existingTransaction = await _supabase.getTransaction(transactionId, userId);
    if (existingTransaction == null) {
      throw Exception('Transaction not found');
    }

    if (existingTransaction.userId != userId) {
      throw Exception('Unauthorized');
    }

    try {
      if (request.amount != null && request.amount! <= 0) {
        throw Exception('Amount must be greater than 0');
      }
      return await _supabase.updateTransaction(transactionId, userId, request);
    } catch (e) {
      if (kDebugMode) print('❌ Gagal update transaksi: $e');
      rethrow;
    }
  }

  // Hapus transaction
  Future<void> deleteTransaction(String transactionId, String userId) async {
  final transaction = await _supabase.getTransaction(transactionId, userId);
    if (transaction == null) {
      throw Exception('Transaction not found');
    }

    if (transaction.userId != userId) {
      throw Exception('Unauthorized');
    }

  await _supabase.deleteTransaction(transactionId, userId);
  }

  // Ambil semua transactions user
  Future<List<Transaction>> getTransactions(String userId, {
    String? walletId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _supabase.getTransactions(
      userId,
      walletId: walletId,
      categoryId: categoryId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // Ambil transaction by ID (memerlukan userId untuk security)
  Future<Transaction?> getTransactionById(String transactionId, {String? userId}) async {
  if (userId == null) return null;
  return _supabase.getTransaction(transactionId, userId);
  }

  // Legacy sync methods removed (online-only)

  // Get transactions summary (income, expense totals)
  Future<Map<String, double>> getTransactionsSummary(String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final transactions = await getTransactions(
      userId,
      startDate: startDate,
      endDate: endDate,
    );

    double totalIncome = 0;
    double totalExpense = 0;

    for (final transaction in transactions) {
      // Perlu load category untuk menentukan apakah income atau expense
      // Untuk sementara, anggap positive amount = income, negative = expense
      if (transaction.amount > 0) {
        totalIncome += transaction.amount;
      } else {
        totalExpense += transaction.amount.abs();
      }
    }

    return {
      'income': totalIncome,
      'expense': totalExpense,
      'balance': totalIncome - totalExpense,
    };
  }
}
