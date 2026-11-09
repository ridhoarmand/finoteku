import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure.dart';
import '../../../core/logging/logger.dart';
import '../models/budget.dart';

class BudgetService {
  final SupabaseClient _supabase;
  BudgetService(this._supabase);

  /// All budgets of the signed-in user with what was spent in [month] (one RPC call).
  Future<BudgetMonth> getMonth(DateTime month) async {
    try {
      final day = '${month.year}-${month.month.toString().padLeft(2, '0')}-01';
      final rows = await _supabase.rpc('get_budget_progress', params: {'p_month': day}) as List;
      return BudgetMonth.fromRpc(rows.cast<Map<String, dynamic>>());
    } catch (e, st) {
      AppLogger.e('fetch budgets failed', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  /// Create or change the limit of a category ([categoryId] null = overall limit).
  Future<void> upsert({required String userId, String? categoryId, required double amount}) async {
    try {
      await _supabase.from('budgets').upsert({
        'user_id': userId,
        'category_id': categoryId,
        'amount': amount,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,category_id');
    } catch (e, st) {
      AppLogger.e('save budget failed', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _supabase.from('budgets').delete().eq('id', id);
    } catch (e, st) {
      AppLogger.e('delete budget failed', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }
}
