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

// Provider untuk recent activities (transactions + transfers combined)
final recentActivitiesProvider = FutureProvider.family
    .autoDispose<List<LedgerEntry>, String>((ref, userId) async {
      ref.watch(transactionRefreshTriggerProvider);
      final repo = ref.watch(transactionRepositoryProvider);

      // Get recent ledger entries with a reasonable limit
      final entries = await repo.getLedgerEntries(
        userId,
        startDate: DateTime.now().subtract(
          const Duration(days: 30),
        ), // Last 30 days
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
      final result = deduplicatedEntries.take(20).toList();
      return result;
    });

// Provider untuk monthly transactions
final monthlyTransactionsProvider =
    FutureProvider.family<
      List<Transaction>,
      ({String userId, int year, int month})
    >((ref, params) async {
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

// Helper to refresh all transaction related providers
void refreshTransactionProviders(WidgetRef ref) {
  ref.read(transactionRefreshTriggerProvider.notifier).bump();
}
