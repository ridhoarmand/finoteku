import 'package:flutter/material.dart';
import '../../../models/ledger_entry.dart';
import '../../../models/wallet.dart';
import '../../category/theme/category_theme.dart';
import '../../../utils/currency_formatter.dart';

class LedgerTransferCard extends StatelessWidget {
  final LedgerEntry a;
  final LedgerEntry? counterpart;
  final Map<String, Wallet> walletMap;
  final ThemeData theme;
  final void Function(String transferId) onTap;
  final String currency;

  const LedgerTransferCard({
    super.key,
    required this.a,
    required this.counterpart,
    required this.walletMap,
    required this.theme,
    required this.onTap,
    this.currency = 'IDR',
  });

  @override
  Widget build(BuildContext context) {
    LedgerEntry? outEntry = a.signedAmount < 0
        ? a
        : (counterpart != null && counterpart!.signedAmount < 0 ? counterpart : null);
    LedgerEntry? inEntry = a.signedAmount >= 0
        ? a
        : (counterpart != null && counterpart!.signedAmount >= 0 ? counterpart : null);
    final fromName = outEntry != null ? (walletMap[outEntry.walletId]?.name ?? '-') : null;
    final toName = inEntry != null ? (walletMap[inEntry.walletId]?.name ?? '-') : null;
    final amount = a.amount;
    final displayAmount = CurrencyFormatter.format(amount, currency);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(a.transferId!),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: CategoryTheme.transfer.withValues(alpha: 0.15),
                child: Icon(Icons.swap_horiz, color: CategoryTheme.transfer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (fromName != null && toName != null) ? '$fromName -> $toName' : 'Transfer',
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if ((a.notes ?? counterpart?.notes ?? '').trim().isNotEmpty)
                      Text(
                        (a.notes ?? counterpart?.notes)!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    displayAmount,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
