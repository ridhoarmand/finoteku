import 'package:finoteku/features/budget/models/budget.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> row(String? id, String? cat, num? amount, num spent) =>
    {'budget_id': id, 'category_id': cat, 'amount': amount, 'spent': spent};

void main() {
  test('state switches at 80% and 100%', () {
    expect(BudgetProgress.stateOf(0.799), BudgetState.ok);
    expect(BudgetProgress.stateOf(0.8), BudgetState.near);
    expect(BudgetProgress.stateOf(0.999), BudgetState.near);
    expect(BudgetProgress.stateOf(1), BudgetState.over);
  });

  test('remaining goes negative when over', () {
    final p = BudgetProgress.fromRpc(row('b', 'c', 100, 130));
    expect(p.remaining, -30);
    expect(p.state, BudgetState.over);
  });

  test('total uses the overall limit, else the sum of category limits', () {
    final cats = BudgetMonth.fromRpc([row('b1', 'c1', 100, 50), row('b2', 'c2', 200, 190), row(null, 'c3', null, 40)]);
    expect(cats.total, (300.0, 240.0));
    expect(cats.unbudgeted, [('c3', 40.0)]);
    expect(cats.mostCritical?.budget.categoryId, 'c2'); // 95%

    final withOverall = BudgetMonth.fromRpc([row('b0', null, 1000, 280), ...[row('b1', 'c1', 100, 50)]]);
    expect(withOverall.total, (1000.0, 280.0));
    expect(withOverall.categories.length, 1);
    expect(withOverall.mostCritical, isNull);
  });
}
