import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finoteku/theme/ph_icons.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../models/ledger_entry.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/amount_text.dart';
import '../../../widgets/inline_error.dart';
import '../../../services/supabase_service.dart';
import '../../category/providers/category_providers.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../providers/transaction_filter.dart';
import '../providers/transaction_providers.dart';
import '../widgets/ledger_list.dart';
import '../widgets/transaction_filter_bar.dart';

/// Transaksi: filter chips (period · type · category · wallet), a one-line summary
/// of what the filters return, then the day-grouped list.
class TransactionScreen extends ConsumerStatefulWidget {
  const TransactionScreen({super.key});

  @override
  ConsumerState<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends ConsumerState<TransactionScreen> {
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _closeSearch() {
    _search.clear();
    ref.read(transactionFilterProvider.notifier).update((x) => x.copyWith(query: ''));
    setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return Scaffold(body: Center(child: Text(ref.tr(context, 'login_required_short'))));
    }
    final theme = Theme.of(context);
    final f = ref.watch(transactionFilterProvider);
    final range = f.range(DateTime.now());
    // no end date: the day balances walk back from today, so they need every later entry too
    final args = (userId: user.id, walletId: f.walletId, startDate: range.start, endDate: null);
    final ledgerAsync = ref.watch(ledgerEntriesProvider(args));
    final categoriesAsync = ref.watch(categoriesAllProvider(user.id));
    final walletsAsync = ref.watch(walletsProvider(user.id));
    final categories = categoriesAsync.value ?? const [];
    final wallets = walletsAsync.value ?? const [];

    Future<void> refresh() async {
      ref.read(transactionRefreshTriggerProvider.notifier).bump();
      await ref.read(ledgerEntriesProvider(args).future).catchError((_) => <LedgerEntry>[]);
    }

    Widget body;
    if (ledgerAsync.hasError || categoriesAsync.hasError) {
      body = Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: InlineError(onRetry: refresh));
    } else if (!ledgerAsync.hasValue || !categoriesAsync.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final end = range.end;
      final all = end == null ? ledgerAsync.value! : ledgerAsync.value!.where((e) => !e.date.isAfter(end)).toList();
      final shown = applyTxFilter(all, f, categories, wallets);
      body = shown.isEmpty
          ? _Empty(filtered: all.isNotEmpty || f.activeCount > 0 || f.query.isNotEmpty)
          : LedgerList(
              entries: shown,
              categories: categories,
              wallets: wallets,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              header: _Summary(entries: shown),
              balances: walletsAsync.hasValue ? dayBalances(ledgerAsync.value!, wallets, f.walletId) : null,
            );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (v) => ref.read(transactionFilterProvider.notifier).update((x) => x.copyWith(query: v)),
                decoration: InputDecoration(
                  hintText: ref.tr(context, 'search_transactions'),
                  prefixIcon: const Icon(PhRegular.magnifyingGlass),
                  isDense: true,
                ),
              )
            : Text(ref.tr(context, 'transactions_title'), style: theme.textTheme.headlineSmall),
        actions: [
          IconButton(
            tooltip: ref.tr(context, _searching ? 'tx_search_close' : 'search_transactions'),
            onPressed: _searching ? _closeSearch : () => setState(() => _searching = true),
            icon: Icon(_searching ? PhRegular.x : PhRegular.magnifyingGlass),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          TransactionFilterBar(categories: categories, wallets: wallets),
          Expanded(child: RefreshIndicator(onRefresh: refresh, child: body)),
        ],
      ),
    );
  }
}

/// "42 transaksi · −Rp 1.290.000 · +Rp 8.500.000" for exactly what the list shows.
class _Summary extends ConsumerWidget {
  final List<LedgerEntry> entries;
  const _Summary({required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = context.colors.muted;
    final txs = entries.where((e) => e.transferId == null);
    final out = txs.where((e) => e.signedAmount < 0).fold<double>(0, (s, e) => s + e.amount);
    final inc = txs.where((e) => e.signedAmount >= 0).fold<double>(0, (s, e) => s + e.amount);
    final count = ledgerItems(entries).length;
    final style = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(ref.tr(context, 'tx_count').replaceAll('{n}', '$count'), style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
          if (out > 0) AmountText(out, tone: AmountTone.expense, signed: true, style: style),
          if (inc > 0) AmountText(inc, tone: AmountTone.income, signed: true, style: style),
        ],
      ),
    );
  }
}

class _Empty extends ConsumerWidget {
  /// true: the period has data but filters/search hide it; false: nothing in the period.
  final bool filtered;
  const _Empty({required this.filtered});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
      children: [
        Icon(filtered ? PhRegular.funnelSimple : PhRegular.receipt, size: 40, color: context.colors.muted),
        const SizedBox(height: 12),
        Text(
          ref.tr(context, filtered ? 'tx_empty_filtered_title' : 'tx_empty_period_title'),
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          ref.tr(context, filtered ? 'tx_empty_filtered_body' : 'tx_empty_period_body'),
          style: theme.textTheme.bodyMedium?.copyWith(color: context.colors.muted),
          textAlign: TextAlign.center,
        ),
        if (filtered) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: () => ref.read(transactionFilterProvider.notifier).update((_) => const TxFilter()),
              child: Text(ref.tr(context, 'reset')),
            ),
          ),
        ],
      ],
    );
  }
}
