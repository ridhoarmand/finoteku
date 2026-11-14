import 'package:flutter/material.dart';
import 'package:finoteku/features/category/theme/category_theme.dart';
import 'package:finoteku/widgets/icon_tile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finoteku/theme/ph_icons.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/state/balance_visibility_provider.dart';
import '../../../models/category.dart';
import '../../../models/ledger_entry.dart';
import '../../../models/wallet.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/category_icon_helper.dart';
import '../../../widgets/amount_text.dart';
import '../../transfer/screens/transfer_detail_screen.dart';
import '../screens/transaction_detail_screen.dart';
import '../utils/transaction_screen_helpers.dart';

/// One row of the money list: a transaction, or a transfer shown once with both wallets.
class LedgerItem {
  final LedgerEntry entry;
  final String? fromWalletId; // transfers only
  final String? toWalletId;
  const LedgerItem(this.entry, {this.fromWalletId, this.toWalletId});
  bool get isTransfer => entry.transferId != null;
}

/// Transfers come as two ledger rows (out + in): keep one. Each row names the other
/// wallet itself, so both are known even when the list is filtered to one wallet.
List<LedgerItem> ledgerItems(List<LedgerEntry> entries) {
  final seen = <String>{};
  return [
    for (final e in entries)
      if (e.transferId == null)
        LedgerItem(e)
      else if (seen.add(e.transferId!))
        LedgerItem(
          e,
          fromWalletId: e.kind == 'transfer_out' ? e.walletId : e.counterpartWalletId,
          toWalletId: e.kind == 'transfer_in' ? e.walletId : e.counterpartWalletId,
        ),
  ];
}

/// Balance at the end of each day, walking back from the balance now.
/// Scope: [walletId], or every visible wallet (same total as Beranda). [entries] must
/// hold every entry from the oldest day shown up to now, before any category/type/search
/// filter, so filtering the list never changes these numbers.
/// shortcut: a wallet's opening balance or a manual balance edit is not a ledger entry,
/// so days before it show today's offset; add those as entries if it ever matters.
Map<DateTime, double> dayBalances(List<LedgerEntry> entries, List<Wallet> wallets, String? walletId) {
  final scope = walletId != null ? {walletId} : {for (final w in wallets) if (!w.isHidden) w.id};
  final net = <DateTime, double>{};
  for (final e in entries) {
    if (!scope.contains(e.walletId)) continue;
    final d = DateTime(e.date.year, e.date.month, e.date.day);
    net[d] = (net[d] ?? 0) + e.signedAmount;
  }
  var running = wallets.where((w) => scope.contains(w.id)).fold<double>(0, (s, w) => s + w.balance);
  final out = <DateTime, double>{};
  for (final d in net.keys.toList()..sort((a, b) => b.compareTo(a))) {
    out[d] = running;
    running -= net[d]!;
  }
  return out;
}

/// Entries grouped by day: a quiet date label with the day's net total, then the
/// rows in one card. Used by Beranda and Transaksi so money reads the same everywhere.
class LedgerList extends ConsumerWidget {
  final List<LedgerEntry> entries;
  final List<Category> categories;
  final List<Wallet> wallets;
  final ScrollController? controller;
  final EdgeInsets padding;
  final Widget? header;
  final Map<DateTime, double>? balances; // end-of-day balance, see [dayBalances]

  const LedgerList({
    super.key,
    required this.entries,
    required this.categories,
    required this.wallets,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 96), // room for the FAB
    this.header,
    this.balances,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryMap = {for (final c in categories) c.id: c};
    final walletMap = {for (final w in wallets) w.id: w};
    final days = <DateTime, List<LedgerItem>>{};
    for (final item in ledgerItems(entries)) {
      final d = item.entry.date;
      days.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(item);
    }
    final keys = days.keys.toList()..sort((a, b) => b.compareTo(a));
    final visible = ref.watch(balanceVisibilityProvider);

    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: keys.length + (header == null ? 0 : 1),
      itemBuilder: (context, i) {
        if (header != null) {
          if (i == 0) return header!;
          i -= 1;
        }
        final day = keys[i];
        final items = days[day]!;
        // transfers move money between own wallets: not part of the day's net
        final net = items.where((it) => !it.isTransfer).fold<double>(0, (s, it) => s + it.entry.signedAmount);
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TransactionScreenHelpers.formatDate(day, (k) => ref.tr(context, k)),
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.colors.muted),
                          ),
                          if (balances?[day] case final b?)
                            Row(
                              children: [
                                Text(
                                  '${ref.tr(context, 'day_balance')} ',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.muted),
                                ),
                                Flexible(
                                  child: AmountText(
                                    b,
                                    hidden: !visible,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: b < 0 ? Theme.of(context).colorScheme.error : context.colors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (net != 0)
                      AmountText(
                        net,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.colors.muted),
                      ),
                  ],
                ),
              ),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var j = 0; j < items.length; j++) ...[
                      if (j > 0) const Divider(indent: 68),
                      LedgerRow(item: items[j], categoryMap: categoryMap, walletMap: walletMap),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class LedgerRow extends ConsumerWidget {
  final LedgerItem item;
  final Map<String, Category> categoryMap;
  final Map<String, Wallet> walletMap;

  const LedgerRow({super.key, required this.item, required this.categoryMap, required this.walletMap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final e = item.entry;
    final String title;
    final String subtitle;
    final IconData icon;
    final AmountTone tone;
    final Color tint;

    if (item.isTransfer) {
      final from = walletMap[item.fromWalletId]?.name;
      final to = walletMap[item.toWalletId]?.name;
      icon = PhRegular.arrowsLeftRight;
      tint = theme.colorScheme.primary;
      tone = AmountTone.transfer;
      title = (e.notes?.trim().isNotEmpty ?? false) ? e.notes!.trim() : ref.tr(context, 'transfer');
      subtitle = '${from ?? '?'} → ${to ?? '?'}';
    } else {
      final cat = categoryMap[e.categoryId];
      final income = e.signedAmount >= 0;
      tint = CategoryTheme.forCategory(context, cat?.parentId ?? cat?.id);
      icon = CategoryIconHelper.iconFor(codePoint: cat?.iconCodePoint, name: cat?.name ?? '');
      tone = income ? AmountTone.income : AmountTone.expense;
      final catName = cat?.name ?? ref.tr(context, 'uncategorized');
      final hasNotes = e.notes?.trim().isNotEmpty ?? false;
      title = hasNotes ? e.notes!.trim() : catName;
      subtitle = [if (hasNotes) catName, walletMap[e.walletId]?.name ?? ''].where((s) => s.isNotEmpty).join(' · ');
    }

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => item.isTransfer
                ? TransferDetailScreen(transferId: e.transferId!)
                : TransactionDetailScreen(transactionId: e.entryId),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            IconTile(icon, color: tint),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AmountText(e.amount, tone: tone, signed: tone != AmountTone.transfer, style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}
