import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/ledger_entry.dart';
import '../../../models/wallet.dart';
import '../../category/theme/category_theme.dart';
import '../../../utils/currency_formatter.dart';
import '../../../core/localization/app_localizations.dart';
import '../../transfer/models/transfer.dart';
import '../../transfer/services/transfer_service.dart';

// Provider untuk mendapatkan transfer data berdasarkan transferId
final transferDataProvider =
    FutureProvider.family<Transfer?, ({String userId, String transferId})>((
      ref,
      params,
    ) async {
      return ref
          .watch(transferServiceProvider)
          .getById(params.userId, params.transferId);
    });

class LedgerTransferCard extends ConsumerWidget {
  final LedgerEntry a;
  final LedgerEntry? counterpart;
  final Map<String, Wallet> walletMap;
  final ThemeData theme;
  final void Function(String transferId) onTap;
  final String currency;
  final String userId; // Tambahkan userId untuk mengakses transfer data

  const LedgerTransferCard({
    super.key,
    required this.a,
    required this.counterpart,
    required this.walletMap,
    required this.theme,
    required this.onTap,
    required this.userId, // Required userId
    this.currency = 'IDR',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (a.transferId == null) {
      // Fallback jika tidak ada transferId
      return _buildFallbackCard();
    }

    // Ambil data transfer asli untuk mendapatkan fromWalletId dan toWalletId yang benar
    final transferAsync = ref.watch(
      transferDataProvider((userId: userId, transferId: a.transferId!)),
    );

    return transferAsync.when(
      loading: () => _buildLoadingCard(),
      error: (error, stackTrace) => _buildFallbackCard(),
      data: (transfer) {
        if (transfer == null) {
          return _buildFallbackCard();
        }
        return _buildTransferCard(context, ref, transfer);
      },
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 4), // Kurangi margin
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ), // Kurangi padding
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: CategoryTheme.transfer.withValues(alpha: 0.12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CategoryTheme.transfer,
                ),
              ),
            ),
            const SizedBox(width: 10), // Kurangi spacing
            Expanded(
              child: Text(
                'Loading transfer...',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCard() {
    // Gunakan logika lama sebagai fallback
    LedgerEntry? outEntry = a.signedAmount < 0
        ? a
        : (counterpart != null && counterpart!.signedAmount < 0
              ? counterpart
              : null);
    LedgerEntry? inEntry = a.signedAmount >= 0
        ? a
        : (counterpart != null && counterpart!.signedAmount >= 0
              ? counterpart
              : null);

    final fromWallet = outEntry != null ? walletMap[outEntry.walletId] : null;
    final toWallet = inEntry != null ? walletMap[inEntry.walletId] : null;
    final fromName = fromWallet?.name ?? 'Unknown Wallet';
    final toName = toWallet?.name ?? 'Unknown Wallet';

    return _buildCardUI(fromName, toName, a.notes ?? counterpart?.notes ?? '');
  }

  Widget _buildTransferCard(
    BuildContext context,
    WidgetRef ref,
    Transfer transfer,
  ) {
    // Gunakan data transfer asli untuk mendapatkan wallet yang benar
    final fromWallet = walletMap[transfer.fromWalletId];
    final toWallet = walletMap[transfer.toWalletId];
    final fromName = fromWallet?.name ?? ref.tr(context, 'wallet_unknown');
    final toName = toWallet?.name ?? ref.tr(context, 'wallet_unknown');

    return _buildCardUI(fromName, toName, transfer.notes ?? '');
  }

  Widget _buildCardUI(String fromName, String toName, String notes) {
    final amount = a.amount;
    final displayAmount = CurrencyFormatter.format(amount, currency);

    return Card(
      margin: const EdgeInsets.only(bottom: 4), // Kurangi margin
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(a.transferId!),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ), // Kurangi padding
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: CategoryTheme.transfer.withValues(alpha: 0.12),
                child: Icon(Icons.swap_horiz, color: CategoryTheme.transfer),
              ),
              const SizedBox(width: 10), // Kurangi spacing
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transfer',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1), // Kurangi spacing
                    if (notes.trim().isNotEmpty)
                      Text(
                        notes,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10), // Kurangi spacing
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$fromName → $toName',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1), // Kurangi spacing
                  Text(
                    displayAmount,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: CategoryTheme.transfer,
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
