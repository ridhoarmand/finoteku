import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:uuid/uuid.dart';
import '../../../models/transaction.dart';
import '../../../services/local_database_service.dart';
import 'supabase_transaction_service.dart';
import '../helpers/transaction_sync_helper.dart';

class TransactionService {
  final LocalDatabaseService _localDb;
  final SupabaseTransactionService _supabaseTransactionService;
  late final TransactionSyncHelper _syncHelper;
  final _uuid = const Uuid();

  TransactionService(this._localDb, this._supabaseTransactionService) {
    _syncHelper = TransactionSyncHelper(_localDb, _supabaseTransactionService);
  }

  // Buat transaction baru
  Future<Transaction> createTransaction(String userId, CreateTransactionRequest request) async {
    final transaction = Transaction(
      id: _uuid.v4(),
      userId: userId,
      walletId: request.walletId,
      categoryId: request.categoryId,
      amount: request.amount,
      notes: request.notes,
      date: request.date,
      needsSync: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Simpan ke local database
    await _localDb.saveTransaction(transaction);

    // Coba sync ke server jika online
    await _syncHelper.trySyncTransaction(transaction);

    return transaction;
  }

  // Update transaction
  Future<Transaction> updateTransaction(String transactionId, String userId, UpdateTransactionRequest request) async {
    final existingTransaction = await _localDb.getTransaction(transactionId, userId);
    if (existingTransaction == null) {
      throw Exception('Transaction not found');
    }

    if (existingTransaction.userId != userId) {
      throw Exception('Unauthorized');
    }

    final updatedTransaction = existingTransaction.copyWith(
      walletId: request.walletId ?? existingTransaction.walletId,
      categoryId: request.categoryId ?? existingTransaction.categoryId,
      amount: request.amount ?? existingTransaction.amount,
      notes: request.notes ?? existingTransaction.notes,
      date: request.date ?? existingTransaction.date,
      needsSync: true,
      updatedAt: DateTime.now(),
    );

    await _localDb.saveTransaction(updatedTransaction);

    // Coba sync ke server jika online
    await _syncHelper.trySyncTransaction(updatedTransaction);

    return updatedTransaction;
  }

  // Hapus transaction
  Future<void> deleteTransaction(String transactionId, String userId) async {
    final transaction = await _localDb.getTransaction(transactionId, userId);
    if (transaction == null) {
      throw Exception('Transaction not found');
    }

    if (transaction.userId != userId) {
      throw Exception('Unauthorized');
    }

    // Hapus dari local database
    await _localDb.deleteTransaction(transactionId, userId);

    // Coba sync penghapusan ke server jika online
    await _syncHelper.trySyncTransactionDeletion(transactionId, userId);
  }

  // Ambil semua transactions user
  Future<List<Transaction>> getTransactions(String userId, {
    String? walletId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _localDb.getTransactions(
      userId,
      walletId: walletId,
      categoryId: categoryId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // Ambil transaction by ID (memerlukan userId untuk security)
  Future<Transaction?> getTransactionById(String transactionId, {String? userId}) async {
    if (userId != null) {
      return await _localDb.getTransaction(transactionId, userId);
    }
    
    // Jika tidak ada userId, tidak bisa mengambil transaction untuk security
    return null;
  }

  // Sync semua transactions ke server
  Future<void> syncTransactions(String userId) async {
    try {
      final localTransactions = await _localDb.getTransactions(userId);
      final transactionsNeedingSync = localTransactions.where((t) => t.needsSync).toList();

      for (final transaction in transactionsNeedingSync) {
        await _syncHelper.trySyncTransaction(transaction);
      }

      // Ambil data terbaru dari server
      await _syncHelper.fetchAndMergeFromServer(userId);
    } catch (e) {
      if (kDebugMode) {
        print('Sync error: $e');
      }
      // Jangan throw error, biarkan app tetap berfungsi offline
    }
  }

  // Public method untuk sync semua unsynced transactions
  Future<void> syncUnsyncedTransactions(String userId) async {
    try {
      if (kDebugMode) {
        print('🔄 Starting auto sync for unsynced transactions...');
      }

      final unsyncedTransactions = await _localDb.getUnsyncedTransactions(userId);
      if (unsyncedTransactions.isEmpty) {
        if (kDebugMode) {
          print('✅ No transactions need sync');
        }
        return;
      }

      if (kDebugMode) {
        print('📝 Found ${unsyncedTransactions.length} transactions to sync');
      }

      for (final transaction in unsyncedTransactions) {
        await _syncHelper.trySyncTransaction(transaction);
      }

      // Fetch and merge dari server
      await _syncHelper.fetchAndMergeFromServer(userId);

      if (kDebugMode) {
        print('✅ Auto sync completed for transactions');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Auto sync failed for transactions: $e');
      }
    }
  }

  // Force sync single transaction
  Future<void> forceSyncTransaction(String transactionId, String userId) async {
    final transaction = await _localDb.getTransaction(transactionId, userId);
    if (transaction == null) {
      throw Exception('Transaction not found');
    }

    // Force sync this specific transaction
    await _syncHelper.trySyncTransaction(transaction);
  }

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
