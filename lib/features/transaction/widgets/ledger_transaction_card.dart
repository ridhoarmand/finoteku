import 'package:flutter/material.dart';
import '../../../models/ledger_entry.dart';
import '../../../models/category.dart';
import '../../../models/wallet.dart';
import '../../category/theme/category_theme.dart';

class LedgerTransactionCard extends StatelessWidget {
  final LedgerEntry entry;
  final Category? category;
  final Wallet? wallet;
  final ThemeData theme;
  final VoidCallback onTap;
  const LedgerTransactionCard({super.key, required this.entry, required this.category, required this.wallet, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPositive = entry.signedAmount >= 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: CategoryTheme.bySign(isPositive).withValues(alpha: 0.15),
                child: Icon(
                  () {
                    if (category?.iconCodePoint != null) {
                      return IconData(category!.iconCodePoint!, fontFamily: 'MaterialIcons');
                    }
                    return isPositive ? Icons.trending_up : Icons.trending_down;
                  }(),
                  color: CategoryTheme.bySign(isPositive),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category?.name ?? 'Uncategorized',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    if (entry.notes != null && entry.notes!.trim().isNotEmpty)
                      Text(
                        entry.notes!,
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
                  Text(
                    wallet?.name ?? 'Wallet',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatAmount(entry),
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

  String _formatAmount(LedgerEntry e) {
    final amount = e.amount.toStringAsFixed(0); // currency formatting delegated to list owner
    return e.signedAmount >= 0 ? amount : '-$amount';
  }
}
