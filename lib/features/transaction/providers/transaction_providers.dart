import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/transaction.dart';
import '../services/transaction_service.dart';
import '../services/supabase_transaction_service.dart';

// Provider untuk TransactionService
final transactionServiceProvider = Provider<TransactionService>((ref) {
  final supabaseTransactionService = ref.watch(supabaseTransactionServiceProvider);
  return TransactionService(supabaseTransactionService);
});

// Provider untuk daftar transactions berdasarkan user ID
final transactionsProvider = FutureProvider.family<List<Transaction>, String>((ref, userId) async {
  final transactionService = ref.watch(transactionServiceProvider);
  return transactionService.getTransactions(userId);
});

// Provider untuk transaction by ID
final transactionProvider = FutureProvider.family<Transaction?, ({String transactionId, String userId})>((ref, params) async {
  final transactionService = ref.watch(transactionServiceProvider);
  return transactionService.getTransactionById(params.transactionId, userId: params.userId);
});

// Provider untuk transactions dengan filter
final filteredTransactionsProvider = FutureProvider.family<List<Transaction>, ({
  String userId,
  String? walletId,
  String? categoryId,
  DateTime? startDate,
  DateTime? endDate,
})>((ref, params) async {
  final transactionService = ref.watch(transactionServiceProvider);
  return transactionService.getTransactions(
    params.userId,
    walletId: params.walletId,
    categoryId: params.categoryId,
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

// Provider untuk transactions summary
final transactionsSummaryProvider = FutureProvider.family<Map<String, double>, ({
  String userId,
  DateTime? startDate,
  DateTime? endDate,
})>((ref, params) async {
  final transactionService = ref.watch(transactionServiceProvider);
  return transactionService.getTransactionsSummary(
    params.userId,
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

// Provider untuk recent transactions (last 10)
final recentTransactionsProvider = FutureProvider.family<List<Transaction>, String>((ref, userId) async {
  final transactionService = ref.watch(transactionServiceProvider);
  final transactions = await transactionService.getTransactions(userId);
  return transactions.take(10).toList();
});

// Provider untuk monthly transactions
final monthlyTransactionsProvider = FutureProvider.family<List<Transaction>, ({String userId, int year, int month})>((ref, params) async {
  final transactionService = ref.watch(transactionServiceProvider);
  final startDate = DateTime(params.year, params.month, 1);
  final endDate = DateTime(params.year, params.month + 1, 0);
  
  return transactionService.getTransactions(
    params.userId,
    startDate: startDate,
    endDate: endDate,
  );
});

// Provider untuk update transaction
final updateTransactionProvider = Provider<Future<Transaction> Function(String, String, UpdateTransactionRequest)>((ref) {
  final transactionService = ref.watch(transactionServiceProvider);
  return transactionService.updateTransaction;
});

// Provider untuk delete transaction
final deleteTransactionProvider = Provider<Future<void> Function(String, String)>((ref) {
  final transactionService = ref.watch(transactionServiceProvider);
  return transactionService.deleteTransaction;
});
