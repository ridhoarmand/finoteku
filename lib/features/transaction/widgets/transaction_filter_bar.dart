import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:finoteku/theme/ph_icons.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../models/category.dart';
import '../../../models/wallet.dart';
import '../../../utils/category_icon_helper.dart';
import '../../../utils/monday_first_date_picker.dart';
import '../../../widgets/filter_chip_button.dart';
import '../../wallet/widgets/wallet_picker_sheet.dart';
import '../providers/transaction_filter.dart';

/// Chips under the Transaksi header: period · type · category · wallet (+ reset).
class TransactionFilterBar extends ConsumerWidget {
  final List<Category> categories;
  final List<Wallet> wallets;

  const TransactionFilterBar({super.key, required this.categories, required this.wallets});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(transactionFilterProvider);
    final n = ref.read(transactionFilterProvider.notifier);
    String tr(String k) => ref.tr(context, k);
    String clear(String name) => tr('tx_clear_filter').replaceAll('{name}', name.toLowerCase());

    final category = categories.where((c) => c.id == f.categoryId).firstOrNull;
    final wallet = wallets.where((w) => w.id == f.walletId).firstOrNull;

    final chips = <Widget>[
      FilterChipButton(
        icon: PhRegular.calendarBlank,
        label: _periodLabel(context, ref, f),
        active: f.period != TxPeriod.thisMonth,
        onTap: () => _pickPeriod(context, ref, f),
        onClear: () => n.update((x) => x.copyWith(period: TxPeriod.thisMonth, custom: null)),
        clearTooltip: clear(tr('tx_period')),
      ),
      FilterChipButton(
        label: f.kind == null ? tr('tx_kind_all') : tr(_kindKey(f.kind!)),
        active: f.kind != null,
        onTap: () => _pickKind(context, ref, f),
        onClear: () => n.update((x) => x.copyWith(kind: null)),
        clearTooltip: clear(tr('tx_kind')),
      ),
      FilterChipButton(
        label: category?.name ?? tr('tx_category_any'),
        active: category != null,
        onTap: () => _pickCategory(context, ref, f),
        onClear: () => n.update((x) => x.copyWith(categoryId: null)),
        clearTooltip: clear(tr('tx_category_any')),
      ),
      FilterChipButton(
        label: wallet?.name ?? tr('tx_wallet_any'),
        active: wallet != null,
        onTap: () async {
          final pick = await showWalletPicker(context, wallets: wallets, selectedId: f.walletId);
          if (pick != null) n.update((x) => x.copyWith(walletId: pick.walletId));
        },
        onClear: () => n.update((x) => x.copyWith(walletId: null)),
        clearTooltip: clear(tr('tx_wallet_any')),
      ),
      if (f.activeCount > 1) TextButton(onPressed: n.reset, child: Text(tr('reset'))),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  static String _kindKey(TxKind k) => switch (k) {
    TxKind.expense => 'tx_kind_expense',
    TxKind.income => 'tx_kind_income',
    TxKind.transfer => 'tx_kind_transfer',
  };

  static const _periodKeys = {
    TxPeriod.thisMonth: 'tx_period_this_month',
    TxPeriod.lastMonth: 'tx_period_last_month',
    TxPeriod.last7Days: 'tx_period_last7',
    TxPeriod.today: 'tx_period_today',
    TxPeriod.all: 'tx_period_all',
    TxPeriod.custom: 'tx_period_custom',
  };

  String _periodLabel(BuildContext context, WidgetRef ref, TxFilter f) {
    if (f.period == TxPeriod.custom && f.custom != null) {
      final fmt = DateFormat('d MMM', Localizations.localeOf(context).toLanguageTag());
      return '${fmt.format(f.custom!.start)} – ${fmt.format(f.custom!.end)}';
    }
    return ref.tr(context, _periodKeys[f.period]!);
  }

  Future<void> _pickPeriod(BuildContext context, WidgetRef ref, TxFilter f) async {
    final picked = await _optionSheet<TxPeriod>(
      context,
      title: ref.tr(context, 'tx_period'),
      options: [for (final p in TxPeriod.values) (p, ref.tr(context, _periodKeys[p]!))],
      selected: f.period,
    );
    if (picked == null || !context.mounted) return;
    final n = ref.read(transactionFilterProvider.notifier);
    if (picked != TxPeriod.custom) return n.update((x) => x.copyWith(period: picked, custom: null));
    final now = DateTime.now();
    final range = await showMondayFirstDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: f.custom,
      locale: Localizations.localeOf(context),
    );
    if (range != null) n.update((x) => x.copyWith(period: TxPeriod.custom, custom: range));
  }

  Future<void> _pickKind(BuildContext context, WidgetRef ref, TxFilter f) async {
    // null option = all types
    final picked = await _optionSheet<TxKind?>(
      context,
      title: ref.tr(context, 'tx_kind'),
      options: [
        (null, ref.tr(context, 'tx_kind_all')),
        for (final k in TxKind.values) (k, ref.tr(context, _kindKey(k))),
      ],
      selected: f.kind,
      wrapNull: true,
    );
    if (picked == null) return;
    // picked is a _Choice so that choosing "all types" (null) differs from dismissing
    ref.read(transactionFilterProvider.notifier).update((x) => x.copyWith(kind: (picked as _Choice<TxKind?>).value));
  }

  Future<void> _pickCategory(BuildContext context, WidgetRef ref, TxFilter f) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategorySheet(categories: categories),
    );
  }
}

/// Wraps a nullable choice so "picked null" differs from "dismissed".
class _Choice<T> {
  final T value;
  const _Choice(this.value);
}

Future<dynamic> _optionSheet<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  required T selected,
  bool wrapNull = false,
}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<dynamic>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
          for (final (value, label) in options)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Text(label),
              trailing: value == selected
                  ? Icon(PhFill.checkCircle, color: theme.colorScheme.primary)
                  : null,
              onTap: () => Navigator.pop(ctx, wrapNull ? _Choice<T>(value) : value),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

class _CategorySheet extends ConsumerStatefulWidget {
  final List<Category> categories;
  const _CategorySheet({required this.categories});

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = ref.watch(transactionFilterProvider);
    final n = ref.read(transactionFilterProvider.notifier);
    final q = _q.trim().toLowerCase();

    // parents with their children; when searching, any match (and its parent) shows
    final parents = widget.categories.where((c) => c.parentId == null).toList()
      ..sort((a, b) => a.type == b.type ? a.name.compareTo(b.name) : a.type.index.compareTo(b.type.index));
    List<Category> childrenOf(Category p) =>
        widget.categories.where((c) => c.parentId == p.id).toList()..sort((a, b) => a.name.compareTo(b.name));
    bool hit(Category c) => q.isEmpty || c.name.toLowerCase().contains(q);

    void pick(String? id) {
      n.update((x) => x.copyWith(categoryId: id));
      Navigator.pop(context);
    }

    Widget tile(Category c, {bool child = false}) => ListTile(
      contentPadding: EdgeInsets.only(left: child ? 52 : 20, right: 20),
      leading: Icon(
        CategoryIconHelper.iconFor(codePoint: c.iconCodePoint, name: c.name),
        color: theme.colorScheme.onSurface,
      ),
      title: Text(c.name),
      trailing: f.categoryId == c.id ? Icon(PhFill.checkCircle, color: theme.colorScheme.primary) : null,
      onTap: () => pick(c.id),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(ref.tr(context, 'filter_pick_category'), style: theme.textTheme.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: ref.tr(context, 'tx_category_search'),
                    prefixIcon: const Icon(PhRegular.magnifyingGlass),
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(ref.tr(context, 'tx_include_sub')),
                value: f.includeSubcategories,
                onChanged: (v) => n.update((x) => x.copyWith(includeSubcategories: v)),
              ),
              const Divider(),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    if (q.isEmpty)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        leading: Icon(PhRegular.squaresFour, color: theme.colorScheme.onSurface),
                        title: Text(ref.tr(context, 'all_categories')),
                        trailing: f.categoryId == null
                            ? Icon(PhFill.checkCircle, color: theme.colorScheme.primary)
                            : null,
                        onTap: () => pick(null),
                      ),
                    for (final p in parents)
                      if (hit(p) || childrenOf(p).any(hit)) ...[
                        tile(p),
                        for (final c in childrenOf(p))
                          if (hit(c) || hit(p)) tile(c, child: true),
                      ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
