import 'package:flutter/material.dart';
import '../../../models/ledger_entry.dart';
import '../../../models/category.dart';
import '../../../models/wallet.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/category_icon_helper.dart';
import '../../category/theme/category_theme.dart';

class LedgerTransactionCard extends StatelessWidget {
  final LedgerEntry entry;
  final Category? category;
  final Wallet? wallet;
  final ThemeData theme;
  final VoidCallback onTap;
  final String currency;

  const LedgerTransactionCard({
    super.key,
    required this.entry,
    required this.category,
    required this.wallet,
    required this.theme,
    required this.onTap,
    this.currency = 'IDR',
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = entry.signedAmount >= 0;
    final amountFormatted = CurrencyFormatter.format(entry.amount, currency);
    final displayAmount = isPositive ? amountFormatted : '-$amountFormatted';

    return Card(
      margin: const EdgeInsets.only(bottom: 4), // Kurangi margin bottom
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ), // Kurangi padding vertical
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: CategoryTheme.bySign(
                  isPositive,
                ).withValues(alpha: 0.12),
                child: Icon(() {
                  if (category?.iconCodePoint != null) {
                    return CategoryIconHelper.getIconFromCodePoint(
                      category!.iconCodePoint,
                    );
                  }
                  return isPositive ? Icons.trending_up : Icons.trending_down;
                }(), color: CategoryTheme.bySign(isPositive)),
              ),
              const SizedBox(width: 10), // Kurangi spacing horizontal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category?.name ?? 'Uncategorized',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1), // Kurangi spacing vertikal
                    if (entry.notes != null && entry.notes!.trim().isNotEmpty)
                      Text(
                        entry.notes!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10), // Kurangi spacing horizontal
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    wallet?.name ?? 'Wallet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 1), // Kurangi spacing vertikal
                  Text(
                    displayAmount,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: CategoryTheme.bySign(isPositive),
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
