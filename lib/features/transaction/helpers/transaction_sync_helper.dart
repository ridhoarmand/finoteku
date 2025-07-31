import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../models/transaction.dart';
import '../services/supabase_transaction_service.dart';
import '../../../services/local_database_service.dart';

/// Helper class untuk sync operations pada transaction
class TransactionSyncHelper {
  final LocalDatabaseService _localDb;
  final SupabaseTransactionService _supabaseTransactionService;

  TransactionSyncHelper(this._localDb, this._supabaseTransactionService);

  /// Sync unsynced transactions to server
  Future<void> syncUnsyncedTransactions(String userId) async {
    try {
      if (kDebugMode) {
        print('🔄 Starting sync unsynced transactions for user: $userId');
      }

      // Ambil transactions yang belum ter-sync
      final unsyncedTransactions = await _localDb.getUnsyncedTransactions(userId);
      
      if (unsyncedTransactions.isEmpty) {
        if (kDebugMode) {
          print('✅ No unsynced transactions found');
        }
        return;
      }

      if (kDebugMode) {
        print('📤 Found ${unsyncedTransactions.length} unsynced transactions');
      }

      int syncedCount = 0;
      for (final transaction in unsyncedTransactions) {
        try {
          // Sync ke server
          final syncedTransaction = await _supabaseTransactionService.syncTransaction(transaction);
          
          // Update local dengan data dari server dan tandai sudah sync
          final updatedTransaction = syncedTransaction.copyWith(needsSync: false);
          await _localDb.saveTransaction(updatedTransaction);
          
          syncedCount++;
          if (kDebugMode) {
            print('✅ Synced transaction: ${transaction.id}');
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Failed to sync transaction ${transaction.id}: $e');
          }
          // Continue dengan transaction lainnya
        }
      }

      if (kDebugMode) {
        print('🎉 Sync completed: $syncedCount/${unsyncedTransactions.length} transactions synced');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during sync unsynced transactions: $e');
      }
      throw Exception('Failed to sync transactions: $e');
    }
  }

  /// Try sync single transaction to server
  Future<void> trySyncTransaction(Transaction transaction) async {
    try {
      // Coba sync ke Supabase
      final syncedTransaction = await _supabaseTransactionService.syncTransaction(transaction);
      
      // Update local dengan data dari server dan tandai sudah sync
      final updatedTransaction = syncedTransaction.copyWith(needsSync: false);
      await _localDb.saveTransaction(updatedTransaction);
      
      if (kDebugMode) {
        print('✅ Transaction synced successfully: ${transaction.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Sync transaction error: $e');
        print('📝 Transaction will remain with needsSync=true until next sync attempt');
      }
      // Jangan throw error, biarkan tetap tersimpan local dengan needsSync = true
    }
  }

  /// Try sync transaction deletion to server
  Future<void> trySyncTransactionDeletion(String transactionId, String userId) async {
    try {
      // Coba sync penghapusan ke Supabase
      await _supabaseTransactionService.syncTransactionDeletion(transactionId, userId);
    } catch (e) {
      if (kDebugMode) {
        print('Sync transaction deletion error: $e');
      }
      // Jangan throw error
    }
  }

  /// Fetch and merge transactions from server
  Future<void> fetchAndMergeFromServer(String userId) async {
    try {
      // Ambil data transaction dari server dan merge dengan local
      final serverTransactions = await _supabaseTransactionService.getTransactions(userId);

      for (final serverTransaction in serverTransactions) {
        final localTransaction = await _localDb.getTransaction(serverTransaction.id, userId);

        if (localTransaction == null) {
          // Transaction baru dari server, simpan ke local
          await _localDb.saveTransaction(serverTransaction);
        } else if (serverTransaction.updatedAt.isAfter(localTransaction.updatedAt)) {
          // Server lebih baru, update local
          await _localDb.saveTransaction(serverTransaction);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Fetch transactions from server error: $e');
      }
    }
  }
}
