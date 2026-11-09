/// A monthly spending limit. [categoryId] null = the overall monthly limit.
/// A budget applies to every month until changed.
class Budget {
  final String id;
  final String? categoryId;
  final double amount;
  const Budget({required this.id, required this.categoryId, required this.amount});
}

enum BudgetState { ok, near, over }

/// A budget and what was spent against it in one month.
class BudgetProgress {
  final Budget budget;
  final double spent;
  const BudgetProgress(this.budget, this.spent);

  factory BudgetProgress.fromRpc(Map<String, dynamic> row) => BudgetProgress(
    Budget(
      id: row['budget_id'] as String,
      categoryId: row['category_id'] as String?,
      amount: (row['amount'] as num).toDouble(),
    ),
    (row['spent'] as num).toDouble(),
  );

  double get ratio => budget.amount <= 0 ? 0 : spent / budget.amount;
  double get remaining => budget.amount - spent;
  BudgetState get state => stateOf(ratio);

  static BudgetState stateOf(double ratio) =>
      ratio >= 1 ? BudgetState.over : (ratio >= 0.8 ? BudgetState.near : BudgetState.ok);
}

/// One month of budgets: the overall limit, or the sum of category limits when
/// no overall limit is set. [unbudgeted]: root expense categories with spending
/// this month but no budget (category id, spent), largest first.
class BudgetMonth {
  final List<BudgetProgress> items;
  final List<(String, double)> unbudgeted;
  const BudgetMonth(this.items, [this.unbudgeted = const []]);

  /// Rows of get_budget_progress: budget rows, and rows without budget_id for unbudgeted spending.
  factory BudgetMonth.fromRpc(List<Map<String, dynamic>> rows) => BudgetMonth(
    [
      for (final r in rows)
        if (r['budget_id'] != null) BudgetProgress.fromRpc(r),
    ],
    [
      for (final r in rows)
        if (r['budget_id'] == null) (r['category_id'] as String, (r['spent'] as num).toDouble()),
    ],
  );

  BudgetProgress? get overall => items.where((p) => p.budget.categoryId == null).firstOrNull;
  List<BudgetProgress> get categories => items.where((p) => p.budget.categoryId != null).toList();
  bool get isEmpty => items.isEmpty;

  /// (limit, spent) for the month total.
  (double, double) get total {
    final o = overall;
    if (o != null) return (o.budget.amount, o.spent);
    final c = categories;
    return (c.fold(0.0, (s, p) => s + p.budget.amount), c.fold(0.0, (s, p) => s + p.spent));
  }

  /// The category closest to (or furthest past) its limit, if any is near or over.
  BudgetProgress? get mostCritical {
    final c = categories.where((p) => p.state != BudgetState.ok).toList()..sort((a, b) => b.ratio.compareTo(a.ratio));
    return c.firstOrNull;
  }
}
