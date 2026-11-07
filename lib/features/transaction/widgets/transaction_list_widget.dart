import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/ledger_entry.dart';
import '../../../models/category.dart';
import '../../../models/wallet.dart';
import '../utils/transaction_screen_helpers.dart';
import '../widgets/ledger_transfer_card.dart';
import '../widgets/ledger_transaction_card.dart';

import '../../../core/localization/app_localizations.dart';
import '../screens/transaction_detail_screen.dart';
import '../../transfer/screens/transfer_detail_screen.dart';

class TransactionListWidget extends ConsumerWidget {
  final List<LedgerEntry> entries;
  final List<Category> categories;
  final List<Wallet> wallets;
  final String userId;
  final ScrollController scrollController;
  final bool isLoadingMore;

  const TransactionListWidget({
    super.key,
    required this.entries,
    required this.categories,
    required this.wallets,
    required this.userId,
    required this.scrollController,
    required this.isLoadingMore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categoryMap = {for (final c in categories) c.id: c};
    final walletMap = {for (final w in wallets) w.id: w};

    // Build flattened list with date headers
    final items = _buildTransactionItems(entries);

    return ListView.builder(
      controller: scrollController,
      // room for the floating + button over the last item
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: items.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the end
        if (index == items.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final item = items[index];
        if (item.isHeader) {
          final label = TransactionScreenHelpers.formatDate(
            item.date!,
            (key) => ref.tr(context, key),
          );
          return Padding(
            padding: const EdgeInsets.all(1), // Kurangi padding date header
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
                letterSpacing: 0.3,
              ),
            ),
          );
        }

        // Handle unified transfer card separately
        if (item.isTransfer) {
          final a = item.entry!;
          final b = item.counterpart;
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 1,
              horizontal: 1,
            ), // Kurangi padding transfer card
            child: LedgerTransferCard(
              a: a,
              counterpart: b,
              walletMap: walletMap,
              theme: theme,
              userId: userId,
              onTap: (id) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TransferDetailScreen(transferId: id),
                  ),
                );
              },
              currency: 'IDR',
            ),
          );
        }

        final entry = item.entry!;
        final category = entry.categoryId != null
            ? categoryMap[entry.categoryId]
            : null;
        final wallet = walletMap[entry.walletId];

        return Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 1,
            horizontal: 1,
          ), // Kurangi padding transaction card
          child: LedgerTransactionCard(
            entry: entry,
            category: category,
            wallet: wallet,
            theme: theme,
            onTap: () {
              if (entry.kind == 'transaction') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        TransactionDetailScreen(transactionId: entry.entryId),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  List<TxListItem> _buildTransactionItems(List<LedgerEntry> entries) {
    final items = <TxListItem>[];
    final processedTransferIds = <String>{};
    DateTime? currentDate;

    for (final e in entries) {
      final txDate = DateTime(e.date.year, e.date.month, e.date.day);
      if (currentDate == null ||
          !TransactionScreenHelpers.isSameDay(currentDate, txDate)) {
        currentDate = txDate;
        items.add(TxListItem.header(txDate));
      }

      // Group transfer_in/out into a single visual item per transferId
      if ((e.kind == 'transfer_in' || e.kind == 'transfer_out') &&
          e.transferId != null) {
        if (processedTransferIds.contains(e.transferId)) {
          // already added a card for this transfer
          continue;
        }
        // Try to find counterpart in current list (may be missing if filtered by wallet)
        final counterpart = entries.firstWhere(
          (x) => x.transferId == e.transferId && x.entryId != e.entryId,
          orElse: () => e,
        );
        // Mark as processed
        processedTransferIds.add(e.transferId!);
        // Create a synthetic entry to render a single card
        items.add(
          TxListItem.transfer(e, counterpart != e ? counterpart : null),
        );
      } else {
        items.add(TxListItem.entry(e));
      }
    }

    return items;
  }
}
