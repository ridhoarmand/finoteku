import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/transaction.dart';
import '../../../models/ledger_entry.dart';
import '../services/transaction_service.dart';
import '../../../services/supabase_service.dart';
import '../../../core/state/refresh_token.dart';

// Provider untuk TransactionService (unified)
final transactionServiceProvider = Provider<TransactionService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return TransactionService(supabase);
});

// Alias repository langsung
final transactionRepositoryProvider = Provider<TransactionService>(
  (ref) => ref.watch(transactionServiceProvider),
);

// Unified refresh trigger
final transactionRefreshTriggerProvider = refreshTokenProvider();

// Provider untuk daftar transactions berdasarkan user ID
final transactionsProvider = FutureProvider.family<List<Transaction>, String>((
  ref,
  userId,
) async {
  // watch refresh token
  ref.watch(transactionRefreshTriggerProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  return await repo.getTransactions(userId);
});

// Provider untuk transaction by ID
final transactionProvider =
    FutureProvider.family<
      Transaction?,
      ({String transactionId, String userId})
    >((ref, params) async {
      final repo = ref.watch(transactionRepositoryProvider);
      return repo.getTransaction(params.transactionId, params.userId);
    });

// Provider untuk unified ledger entries (transactions + transfers)
final ledgerEntriesProvider = FutureProvider.family
    .autoDispose<
      List<LedgerEntry>,
      ({
        String userId,
        String? walletId,
        DateTime? startDate,
        DateTime? endDate,
      })
    >((ref, params) async {
      ref.watch(transactionRefreshTriggerProvider);
      final repo = ref.watch(transactionRepositoryProvider);
      final result = await repo.getLedgerEntries(
        params.userId,
        walletId: params.walletId,
        startDate: params.startDate,
        endDate: params.endDate,
      );
      return result;
    });

// Helper to refresh all transaction related providers
void refreshTransactionProviders(WidgetRef ref) {
  ref.read(transactionRefreshTriggerProvider.notifier).bump();
}
