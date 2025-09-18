import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/currency_formatter.dart';
import '../../category/theme/category_theme.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../models/transfer.dart';
import '../services/transfer_service.dart';
import '../../transaction/screens/add_transaction_screen.dart';

// Provider for transfer details
final transferByIdProvider = FutureProvider.family<Transfer?, ({String userId, String transferId})>((ref, params) async {
  return ref.watch(transferServiceProvider).getById(params.userId, params.transferId);
});

class TransferDetailScreen extends ConsumerWidget {
  final String transferId;

  const TransferDetailScreen({super.key, required this.transferId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return Scaffold(
        body: Center(child: Text(ref.tr(context, 'login_required_short'))),
      );
    }

    final transferAsync = ref.watch(transferByIdProvider((userId: user.id, transferId: transferId)));

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr(context, 'transfer_details_title')),
      ),
      body: transferAsync.when(
        data: (transfer) {
          if (transfer == null) {
            return Center(child: Text(ref.tr(context, 'transfer_not_found')));
          }
          return _buildTransferDetail(context, ref, transfer, user.id);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _buildErrorWidget(context, ref, () {
          ref.invalidate(transferByIdProvider((userId: user.id, transferId: transferId)));
        }),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, WidgetRef ref, VoidCallback retry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(ref.tr(context, 'error_loading_transfers')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: retry,
            child: Text(ref.tr(context, 'retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferDetail(
    BuildContext context,
    WidgetRef ref,
    Transfer transfer,
    String userId,
  ) {
    final theme = Theme.of(context);
    final walletsAsync = ref.watch(activeWalletsProvider(userId));

    return walletsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text(ref.tr(context, 'wallet_loading_error'))),
      data: (wallets) {
        final walletMap = {for (final w in wallets) w.id: w};
        
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transfer Amount Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: CategoryTheme.transfer.withValues(alpha: 0.15),
                        child: Icon(Icons.swap_horiz, color: CategoryTheme.transfer, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ref.tr(context, 'transfer'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(transfer.amount, 'IDR'),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: CategoryTheme.transfer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Transfer Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.tr(context, 'details_title'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildDetailRow(
                        ref.tr(context, 'date_label'),
                        _formatDate(context, ref, transfer.date),
                        Icons.calendar_today,
                      ),
                      const Divider(),

                      _buildDetailRow(
                        ref.tr(context, 'from_wallet'),
                        walletMap[transfer.fromWalletId]?.name ?? '-',
                        Icons.call_made,
                      ),
                      const Divider(),

                      _buildDetailRow(
                        ref.tr(context, 'to_wallet'),
                        walletMap[transfer.toWalletId]?.name ?? '-',
                        Icons.call_received,
                      ),
                      const Divider(),

                      _buildDetailRow(
                        ref.tr(context, 'amount'),
                        CurrencyFormatter.format(transfer.amount, 'IDR'),
                        Icons.currency_exchange,
                      ),
                      const Divider(),

                      _buildDetailRow(
                        ref.tr(context, 'fee'),
                        CurrencyFormatter.format(transfer.fee, 'IDR'),
                        Icons.receipt_long,
                      ),

                      if ((transfer.notes ?? '').trim().isNotEmpty) ...[
                        const Divider(),
                        _buildDetailRow(
                          ref.tr(context, 'notes'),
                          transfer.notes!,
                          Icons.note,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editTransfer(context, ref, transfer),
                      icon: const Icon(Icons.edit),
                      label: Text(ref.tr(context, 'edit')),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _confirmDeleteTransfer(context, ref, transfer, userId),
                      icon: const Icon(Icons.delete),
                      label: Text(ref.tr(context, 'delete')),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  void _editTransfer(BuildContext context, WidgetRef ref, Transfer transfer) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(initialTransfer: transfer),
      ),
    );

    if (result == true && context.mounted) {
      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        ref.invalidate(transferByIdProvider((userId: user.id, transferId: transfer.id)));
        refreshWalletProviders(ref);
      }
    }
  }

  void _confirmDeleteTransfer(BuildContext context, WidgetRef ref, Transfer transfer, String userId) {
    final outerContext = context;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ref.tr(dialogContext, 'transfer_delete_title')),
        content: Text(ref.tr(dialogContext, 'wallet_irreversible_action')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(ref.tr(dialogContext, 'cancel')),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(transferServiceProvider).delete(userId, transfer.id);
                
                if (!outerContext.mounted) return;
                
                // Close dialog first
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
                
                // Refresh wallet providers
                refreshWalletProviders(ref);
                
                // Pop detail screen
                if (Navigator.of(outerContext).canPop()) {
                  Navigator.of(outerContext).pop();
                }
                
                // Show success message
                ScaffoldMessenger.of(outerContext).showSnackBar(
                  SnackBar(content: Text(ref.tr(outerContext, 'transfer_deleted'))),
                );
              } catch (e) {
                // Close dialog
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
                
                // Show error
                if (outerContext.mounted) {
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    SnackBar(
                      content: Text(ref.tr(outerContext, 'error_deleting_transfer').replaceAll('{error}', '$e')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(ref.tr(dialogContext, 'delete')),
          ),
        ],
      ),
    );
  }

  String _formatDate(BuildContext context, WidgetRef ref, DateTime date) {
    final monthKey = [
      'month_january',
      'month_february',
      'month_march',
      'month_april',
      'month_may',
      'month_june',
      'month_july',
      'month_august',
      'month_september',
      'month_october',
      'month_november',
      'month_december',
    ][date.month - 1];
    final monthName = ref.tr(context, monthKey);
    return '${date.day} $monthName ${date.year}';
  }
}