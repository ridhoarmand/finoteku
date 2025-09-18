import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../models/transaction.dart';
import '../../../models/transaction_summary.dart';
import '../../../models/ledger_entry.dart';
import '../services/supabase_transaction_service.dart';
import '../../../core/state/refresh_token.dart';

// Alias repository langsung
final transactionRepositoryProvider = Provider<SupabaseTransactionService>((ref) => ref.watch(supabaseTransactionServiceProvider));

// Unified refresh trigger
final transactionRefreshTriggerProvider = createRefreshTokenProvider();

// Provider untuk daftar transactions berdasarkan user ID
final transactionsProvider = FutureProvider.family<List<Transaction>, String>((ref, userId) async {
  // watch refresh token
  ref.watch(transactionRefreshTriggerProvider);
  try {
    final repo = ref.watch(transactionRepositoryProvider);
    return await repo.getTransactions(userId);
  } catch (e) {
    if (kDebugMode) {
      print('❌ Error in transactionsProvider for user $userId: $e');
    }
    return <Transaction>[];
  }
});

// Provider untuk transaction by ID
final transactionProvider = FutureProvider.family<Transaction?, ({String transactionId, String userId})>((ref, params) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getTransaction(params.transactionId, params.userId);
});

// Provider untuk transactions dengan filter
final filteredTransactionsProvider = FutureProvider.family<List<Transaction>, ({
  String userId,
  String? walletId,
  String? categoryId,
  DateTime? startDate,
  DateTime? endDate,
})>((ref, params) async {
  ref.watch(transactionRefreshTriggerProvider);
  try {
    final repo = ref.watch(transactionRepositoryProvider);
    return await repo.getTransactions(
      params.userId,
      walletId: params.walletId,
      categoryId: params.categoryId,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  } catch (e) {
    if (kDebugMode) {
      print('❌ Error in filteredTransactionsProvider for user ${params.userId}: $e');
    }
    return <Transaction>[];
  }
});

// Provider untuk transactions summary
final transactionsSummaryProvider = FutureProvider.family<TransactionSummary, ({
  String userId,
  DateTime? startDate,
  DateTime? endDate,
})>((ref, params) async {
  ref.watch(transactionRefreshTriggerProvider);
  try {
    final repo = ref.watch(transactionRepositoryProvider);
    final txs = await repo.getTransactions(
      params.userId,
      startDate: params.startDate,
      endDate: params.endDate,
    );
    return TransactionSummary.fromTransactions(txs.map((t) => t.amount));
  } catch (e) {
    if (kDebugMode) {
      print('❌ Error in transactionsSummaryProvider for user ${params.userId}: $e');
    }
    return const TransactionSummary(income: 0, expense: 0);
  }
});

// Provider untuk unified ledger entries (transactions + transfers)
final ledgerEntriesProvider = FutureProvider.family<List<LedgerEntry>, ({
  String userId,
  String? walletId,
  DateTime? startDate,
  DateTime? endDate,
})>((ref, params) async {
  ref.watch(transactionRefreshTriggerProvider);
  try {
    final repo = ref.watch(transactionRepositoryProvider);
    return await repo.getLedgerEntries(
      params.userId,
      walletId: params.walletId,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  } catch (e) {
    if (kDebugMode) {
      print('❌ Error in ledgerEntriesProvider for user ${params.userId}: $e');
    }
    return <LedgerEntry>[];
  }
});

// Provider untuk recent transactions (last 10)
final recentTransactionsProvider = FutureProvider.family<List<Transaction>, String>((ref, userId) async {
  ref.watch(transactionRefreshTriggerProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  final transactions = await repo.getTransactions(userId);
  return transactions.take(10).toList();
});

// Provider untuk recent activities (transactions + transfers combined)
final recentActivitiesProvider = FutureProvider.family<List<LedgerEntry>, String>((ref, userId) async {
  ref.watch(transactionRefreshTriggerProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  
  // Get recent ledger entries with a reasonable limit
  final entries = await repo.getLedgerEntries(
    userId,
    startDate: DateTime.now().subtract(const Duration(days: 30)), // Last 30 days
    endDate: DateTime.now(),
  );
  
  // Sort by date descending first
  final sorted = [...entries]..sort((a, b) => b.date.compareTo(a.date));
  
  // Deduplicate transfers - ambil hanya satu entry per transferId
  final deduplicatedEntries = <LedgerEntry>[];
  final processedTransferIds = <String>{};
  
  for (final entry in sorted) {
    if (entry.transferId != null) {
      // Ini adalah transfer entry
      if (!processedTransferIds.contains(entry.transferId)) {
        // Belum diproses, tambahkan entry ini
        deduplicatedEntries.add(entry);
        processedTransferIds.add(entry.transferId!);
      }
      // Skip jika transferId sudah diproses
    } else {
      // Ini adalah transaction biasa, selalu tambahkan
      deduplicatedEntries.add(entry);
    }
  }
  
  // Ambil 20 teratas setelah deduplication
  return deduplicatedEntries.take(20).toList();
});

// Provider untuk monthly transactions
final monthlyTransactionsProvider = FutureProvider.family<List<Transaction>, ({String userId, int year, int month})>((ref, params) async {
  ref.watch(transactionRefreshTriggerProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  final startDate = DateTime(params.year, params.month, 1);
  final endDate = DateTime(params.year, params.month + 1, 0);
  return repo.getTransactions(
    params.userId,
    startDate: startDate,
    endDate: endDate,
  );
});

// Provider untuk update transaction
final updateTransactionProvider = Provider<Future<Transaction> Function(String, String, UpdateTransactionRequest)>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.updateTransaction;
});

// Provider untuk delete transaction
final deleteTransactionProvider = Provider<Future<void> Function(String, String)>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.deleteTransaction;
});

// Helper to refresh all transaction related providers
void refreshTransactionProviders(WidgetRef ref) {
  ref.read(transactionRefreshTriggerProvider.notifier).bump();
}
