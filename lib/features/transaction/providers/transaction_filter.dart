import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/category.dart';
import '../../../models/ledger_entry.dart';
import '../../../models/wallet.dart';

enum TxPeriod { thisMonth, lastMonth, last7Days, today, all, custom }

enum TxKind { expense, income, transfer }

/// Everything the Transaksi list is filtered by. One object, so the list, the
/// summary line and the chips always agree.
class TxFilter {
  final TxPeriod period;
  final DateTimeRange? custom;
  final TxKind? kind;
  final String? categoryId;
  final bool includeSubcategories;
  final String? walletId;
  final String query;

  const TxFilter({
    this.period = TxPeriod.thisMonth,
    this.custom,
    this.kind,
    this.categoryId,
    this.includeSubcategories = true,
    this.walletId,
    this.query = '',
  });

  static const _keep = Object();

  TxFilter copyWith({
    TxPeriod? period,
    Object? custom = _keep,
    Object? kind = _keep,
    Object? categoryId = _keep,
    bool? includeSubcategories,
    Object? walletId = _keep,
    String? query,
  }) =>
      TxFilter(
        period: period ?? this.period,
        custom: custom == _keep ? this.custom : custom as DateTimeRange?,
        kind: kind == _keep ? this.kind : kind as TxKind?,
        categoryId: categoryId == _keep ? this.categoryId : categoryId as String?,
        includeSubcategories: includeSubcategories ?? this.includeSubcategories,
        walletId: walletId == _keep ? this.walletId : walletId as String?,
        query: query ?? this.query,
      );

  /// Chips other than the default period that narrow the list.
  int get activeCount =>
      (period != TxPeriod.thisMonth ? 1 : 0) +
      (kind != null ? 1 : 0) +
      (categoryId != null ? 1 : 0) +
      (walletId != null ? 1 : 0);

  /// Inclusive day range for the server query; null ends mean "open".
  ({DateTime? start, DateTime? end}) range(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      TxPeriod.today => (start: today, end: today),
      TxPeriod.last7Days => (start: today.subtract(const Duration(days: 6)), end: today),
      TxPeriod.thisMonth => (start: DateTime(now.year, now.month, 1), end: today),
      TxPeriod.lastMonth => (
          start: DateTime(now.year, now.month - 1, 1),
          end: DateTime(now.year, now.month, 0),
        ),
      TxPeriod.all => (start: null, end: null),
      TxPeriod.custom => (start: custom?.start, end: custom?.end),
    };
  }
}

class TxFilterNotifier extends Notifier<TxFilter> {
  @override
  TxFilter build() => const TxFilter();

  void update(TxFilter Function(TxFilter f) change) => state = change(state);
  void reset() => state = TxFilter(query: state.query);
}

final transactionFilterProvider = NotifierProvider<TxFilterNotifier, TxFilter>(TxFilterNotifier.new);

Set<String> descendantIds(List<Category> categories, String rootId) {
  final out = <String>{};
  var frontier = {rootId};
  while (frontier.isNotEmpty) {
    final next = categories.where((c) => frontier.contains(c.parentId) && out.add(c.id)).map((c) => c.id).toSet();
    frontier = next;
  }
  return out;
}

/// Applies kind, category and search locally (wallet and dates are applied by the query).
List<LedgerEntry> applyTxFilter(
  List<LedgerEntry> entries,
  TxFilter f,
  List<Category> categories,
  List<Wallet> wallets,
) {
  final byId = {for (final c in categories) c.id: c};
  final walletName = {for (final w in wallets) w.id: w.name.toLowerCase()};
  final allowed = f.categoryId == null
      ? null
      : {f.categoryId!, if (f.includeSubcategories) ...descendantIds(categories, f.categoryId!)};
  final q = f.query.trim().toLowerCase();

  bool matches(LedgerEntry e) {
    final isTransfer = e.transferId != null;
    switch (f.kind) {
      case TxKind.transfer:
        if (!isTransfer) return false;
      case TxKind.income:
        if (isTransfer || e.signedAmount < 0) return false;
      case TxKind.expense:
        if (isTransfer || e.signedAmount >= 0) return false;
      case null:
        break;
    }
    if (allowed != null && !allowed.contains(e.categoryId)) return false;
    if (q.isEmpty) return true;
    final cat = byId[e.categoryId];
    final parent = byId[cat?.parentId];
    final haystack = [
      e.notes ?? '',
      cat?.name ?? '',
      parent?.name ?? '',
      walletName[e.walletId] ?? '',
      e.amount.toStringAsFixed(0),
    ].join(' ').toLowerCase();
    // every word must appear somewhere: "kopi gopay" finds coffee paid with Gopay
    return q.split(RegExp(r'\s+')).every(haystack.contains);
  }

  return entries.where(matches).toList();
}
