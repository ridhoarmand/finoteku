import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/refresh_token.dart';
import '../../../services/supabase_service.dart';
import '../../transaction/providers/transaction_providers.dart';
import '../models/budget.dart';
import '../services/budget_service.dart';

final budgetServiceProvider = Provider<BudgetService>((ref) => BudgetService(ref.watch(supabaseProvider)));

final budgetRefreshProvider = refreshTokenProvider();

typedef BudgetKey = ({String userId, DateTime month});

/// Key for [budgetMonthProvider]: the user (RLS scopes the data, the key keeps
/// caches apart after switching accounts) and the first day of the month.
BudgetKey budgetKey(String userId, DateTime d) => (userId: userId, month: DateTime(d.year, d.month));

/// Budgets with spending for a month. Reloads after budget edits and after any transaction change.
final budgetMonthProvider = FutureProvider.family<BudgetMonth, BudgetKey>((ref, key) {
  ref.watch(budgetRefreshProvider);
  ref.watch(transactionRefreshTriggerProvider);
  return ref.watch(budgetServiceProvider).getMonth(key.month);
  // no automatic retry: a missing table/RPC (migration not run) should show the
  // error state with its retry button, not spin forever
}, retry: (_, _) => null);
