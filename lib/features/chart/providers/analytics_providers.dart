import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/transaction.dart';
import '../../../models/category.dart';
import '../../transaction/providers/transaction_providers.dart';
import '../../category/providers/category_providers.dart';
import '../../auth/services/auth_service.dart';

/// Parameter umum untuk analitik rentang waktu
class AnalyticsRange {
  final DateTime start;
  final DateTime end;
  const AnalyticsRange(this.start, this.end);
}

/// Provider state (minggu/bulan/tahun)
final analyticsPeriodProvider = StateProvider<String>((ref) => 'month');

/// Hitung rentang berdasar period + now
final currentAnalyticsRangeProvider = Provider<AnalyticsRange>((ref) {
  final period = ref.watch(analyticsPeriodProvider);
  final now = DateTime.now();
  if (period == 'week') {
    final start = now.subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 6));
    return AnalyticsRange(DateTime(start.year, start.month, start.day), DateTime(end.year, end.month, end.day));
  } else if (period == 'year') {
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year, 12, 31);
    return AnalyticsRange(start, end);
  }
  // default month
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0);
  return AnalyticsRange(start, end);
});

/// Provider transaksi dalam rentang waktu
final rangeTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final authState = ref.watch(authStateProvider);
  final userId = authState.asData?.value.session?.user.id;
  if (userId == null) return [];
  final range = ref.watch(currentAnalyticsRangeProvider);
  return ref.watch(filteredTransactionsProvider((
    userId: userId,
    walletId: null,
    categoryId: null,
    startDate: range.start,
    endDate: range.end,
  )).future);
});

/// Total income, expense, net
class IncomeExpenseSummary {
  final double income;
  final double expense;
  const IncomeExpenseSummary({required this.income, required this.expense});
  double get net => income - expense;
}

final incomeExpenseSummaryProvider = FutureProvider<IncomeExpenseSummary>((ref) async {
  final txs = await ref.watch(rangeTransactionsProvider.future);
  final authState = ref.watch(authStateProvider);
  final userId = authState.asData?.value.session?.user.id;
  if (userId == null || txs.isEmpty) return const IncomeExpenseSummary(income: 0, expense: 0);
  // butuh kategori untuk menentukan tipe
  final categories = await ref.watch(categoriesProvider(userId).future);
  double income = 0, expense = 0;
  for (final t in txs) {
    if (t.categoryId == null) continue; // skip tanpa kategori
    final cat = categories.firstWhere((c) => c.id == t.categoryId, orElse: () => Category(
      id: '_', userId: userId, name: 'Unknown', type: CategoryType.expense,
      createdAt: DateTime.now(), updatedAt: DateTime.now(), isHidden: false, isActive: true,
    ));
    if (cat.type == CategoryType.income) {
      income += t.amount;
    } else {
      expense += t.amount;
    }
  }
  return IncomeExpenseSummary(income: income, expense: expense);
});

/// Aggregasi pengeluaran per kategori (expense only)
class CategorySpending {
  final String categoryId;
  final String name;
  final double total;
  final int? color;
  const CategorySpending({required this.categoryId, required this.name, required this.total, this.color});
}

final expenseByCategoryProvider = FutureProvider<List<CategorySpending>>((ref) async {
  final txs = await ref.watch(rangeTransactionsProvider.future);
  if (txs.isEmpty) return [];
  final authState = ref.watch(authStateProvider);
  final userId = authState.asData?.value.session?.user.id;
  if (userId == null) return [];
  final categories = await ref.watch(expenseCategoriesProvider(userId).future);
  final map = <String, double>{};
  for (final t in txs) {
    if (t.categoryId == null) continue;
    final cat = categories.firstWhere(
      (c) => c.id == t.categoryId,
      orElse: () => Category(
        id: '_', userId: userId, name: 'Unknown', type: CategoryType.expense,
        createdAt: DateTime.now(), updatedAt: DateTime.now(), isHidden: false, isActive: true,
      ),
    );
    if (cat.type != CategoryType.expense) continue;
    map[cat.id] = (map[cat.id] ?? 0) + t.amount;
  }
  final list = map.entries.map((e) {
    final cat = categories.firstWhere((c) => c.id == e.key, orElse: () => Category(
      id: '_', userId: userId, name: 'Unknown', type: CategoryType.expense,
      createdAt: DateTime.now(), updatedAt: DateTime.now(), isHidden: false, isActive: true,
    ));
    return CategorySpending(categoryId: e.key, name: cat.name, total: e.value, color: cat.color);
  }).toList();
  list.sort((a,b) => b.total.compareTo(a.total));
  return list;
});

/// Distribusi income per kategori income (opsional future)

/// Jumlah transaksi
final transactionCountProvider = FutureProvider<int>((ref) async {
  final txs = await ref.watch(rangeTransactionsProvider.future);
  return txs.length;
});
