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

/// Custom date range (override period). Null = gunakan period preset.
final customDateRangeProvider = StateProvider<AnalyticsRange?>((ref) => null);

/// Hitung rentang berdasar period + now
final currentAnalyticsRangeProvider = Provider<AnalyticsRange>((ref) {
  final custom = ref.watch(customDateRangeProvider);
  if (custom != null) return custom;
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
  // Ambil SEMUA kategori (termasuk yang hidden / non-aktif) agar tidak muncul Unknown jika user sudah mengubah status kategori.
  final categories = await ref.watch(categoriesProvider(userId).future);
  final catMap = {for (final c in categories) c.id: c};
  double income = 0, expense = 0;
  for (final t in txs) {
    if (t.categoryId == null) continue; // transaksi tanpa kategori di-skip dari perhitungan (netral)
    final cat = catMap[t.categoryId];
    if (cat == null) {
      // Jika kategori benar-benar hilang (misal hard delete), kita tidak bisa tahu tipe; lewati agar tidak salah klasifikasi.
      continue;
    }
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
  // Ambil semua kategori (bukan hanya yang aktif) agar transaksi lama tetap terklasifikasi.
  final allCategories = await ref.watch(categoriesProvider(userId).future);
  final expenseCats = allCategories.where((c) => c.type == CategoryType.expense).toList();
  final catMap = {for (final c in expenseCats) c.id: c};

  final map = <String, double>{};
  for (final t in txs) {
    final cid = t.categoryId;
    if (cid == null) continue; // skip transaksi tanpa kategori
    final cat = catMap[cid];
    if (cat == null) {
      // Kategori benar-benar hilang atau bukan expense -> skip agar tidak muncul Unknown misleading
      continue;
    }
    map[cid] = (map[cid] ?? 0) + t.amount;
  }

  final list = map.entries.map((e) {
    final cat = catMap[e.key]!; // pasti ada
    return CategorySpending(categoryId: e.key, name: cat.name, total: e.value, color: cat.color);
  }).toList();
  list.sort((a, b) => b.total.compareTo(a.total));
  return list;
});

/// Income by category (aktif & non-aktif) agar bisa breakdown income
final incomeByCategoryProvider = FutureProvider<List<CategorySpending>>((ref) async {
  final txs = await ref.watch(rangeTransactionsProvider.future);
  if (txs.isEmpty) return [];
  final authState = ref.watch(authStateProvider);
  final userId = authState.asData?.value.session?.user.id;
  if (userId == null) return [];
  final allCategories = await ref.watch(categoriesProvider(userId).future);
  final incomeCats = allCategories.where((c) => c.type == CategoryType.income).toList();
  final catMap = {for (final c in incomeCats) c.id: c};
  final map = <String, double>{};
  for (final t in txs) {
    final cid = t.categoryId;
    if (cid == null) continue;
    final cat = catMap[cid];
    if (cat == null) continue;
    map[cid] = (map[cid] ?? 0) + t.amount;
  }
  final list = map.entries.map((e) {
    final cat = catMap[e.key]!;
    return CategorySpending(categoryId: e.key, name: cat.name, total: e.value, color: cat.color);
  }).toList();
  list.sort((a,b)=> b.total.compareTo(a.total));
  return list;
});

/// Expense aggregated by parent category (rolling children into parent)
final expenseByParentCategoryProvider = FutureProvider<List<CategorySpending>>((ref) async {
  final txs = await ref.watch(rangeTransactionsProvider.future);
  if (txs.isEmpty) return [];
  final authState = ref.watch(authStateProvider);
  final userId = authState.asData?.value.session?.user.id;
  if (userId == null) return [];
  final allCategories = await ref.watch(categoriesProvider(userId).future);
  final expenseCats = allCategories.where((c) => c.type == CategoryType.expense).toList();
  final parentMap = {for (final c in expenseCats.where((c)=> c.parentId == null)) c.id: c};
  // Map child->parent id
  String? resolveParent(String id) {
    final cat = expenseCats.firstWhere((c) => c.id == id, orElse: () => Category(
      id: '_', userId: userId, name: 'Unknown', type: CategoryType.expense,
      createdAt: DateTime.now(), updatedAt: DateTime.now(), isHidden: false, isActive: true,
    ));
    if (cat.parentId == null) return cat.id;
    // Pastikan parent ada
    if (parentMap.containsKey(cat.parentId)) return cat.parentId;
    return cat.parentId; // fallback parentId meski mungkin tidak ada di parentMap
  }
  final agg = <String, double>{};
  for (final t in txs) {
    final cid = t.categoryId;
    if (cid == null) continue;
    final cat = expenseCats.firstWhere(
      (c) => c.id == cid,
      orElse: () => Category(
        id: '_missing', userId: userId, name: 'Unknown', type: CategoryType.expense,
        createdAt: DateTime.now(), updatedAt: DateTime.now(), isHidden: false, isActive: true,
      ),
    );
    if (cat.id.startsWith('_missing')) continue; // skip unknown missing
    final parentId = resolveParent(cat.id);
    if (parentId == null) continue;
    agg[parentId] = (agg[parentId] ?? 0) + t.amount;
  }
  final list = agg.entries.map((e) {
    final parent = expenseCats.firstWhere((c) => c.id == e.key, orElse: () => Category(
      id: e.key, userId: userId, name: 'Unknown', type: CategoryType.expense,
      createdAt: DateTime.now(), updatedAt: DateTime.now(), isHidden: false, isActive: true,
    ));
    return CategorySpending(categoryId: e.key, name: parent.name, total: e.value, color: parent.color);
  }).toList();
  list.sort((a,b)=> b.total.compareTo(a.total));
  return list;
});

/// Monthly trend (12 bulan terakhir dari akhir range end)
class MonthTrend {
  final String label; // e.g. Jan
  final double income;
  final double expense;
  const MonthTrend({required this.label, required this.income, required this.expense});
}

final monthlyTrendProvider = FutureProvider<List<MonthTrend>>((ref) async {
  final authState = ref.watch(authStateProvider);
  final userId = authState.asData?.value.session?.user.id;
  if (userId == null) return [];
  final endRange = ref.watch(currentAnalyticsRangeProvider).end;
  final List<MonthTrend> result = [];
  for (int i = 11; i >= 0; i--) {
    final monthDate = DateTime(endRange.year, endRange.month - i, 1);
    final start = DateTime(monthDate.year, monthDate.month, 1);
    final end = DateTime(monthDate.year, monthDate.month + 1, 0);
    final txs = await ref.watch(filteredTransactionsProvider((userId: userId, walletId: null, categoryId: null, startDate: start, endDate: end)).future);
    final categories = await ref.watch(categoriesProvider(userId).future);
    final catMap = {for (final c in categories) c.id: c};
    double inc = 0, exp = 0;
    for (final t in txs) {
      if (t.categoryId == null) continue;
      final cat = catMap[t.categoryId];
      if (cat == null) continue;
      if (cat.type == CategoryType.income) {
        inc += t.amount;
      } else {
        exp += t.amount;
      }
    }
    result.add(MonthTrend(label: _monthShort(monthDate.month), income: inc, expense: exp));
  }
  return result;
});

String _monthShort(int m) {
  const names = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
  return names[(m-1) % 12];
}

/// Distribusi income per kategori income (opsional future)

/// Jumlah transaksi
final transactionCountProvider = FutureProvider<int>((ref) async {
  final txs = await ref.watch(rangeTransactionsProvider.future);
  return txs.length;
});
