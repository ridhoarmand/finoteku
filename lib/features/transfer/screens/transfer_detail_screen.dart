import 'package:flutter/material.dart';
import '../../../models/wallet.dart';
import '../../../utils/wallet_icon_helper.dart';
import '../../../widgets/amount_text.dart';
import '../../../theme/app_theme.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../services/supabase_service.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../transaction/providers/transaction_providers.dart'; // Tambahkan untuk refreshTransactionProviders
import '../models/transfer.dart';
import '../services/transfer_service.dart';
import '../../transaction/screens/add_edit_transaction_screen.dart';

// Provider for transfer details
final transferByIdProvider =
    FutureProvider.family<Transfer?, ({String userId, String transferId})>((
      ref,
      params,
    ) async {
      return ref
          .watch(transferServiceProvider)
          .getById(params.userId, params.transferId);
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

    final transferAsync = ref.watch(
      transferByIdProvider((userId: user.id, transferId: transferId)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(ref.tr(context, 'transfer_details_title'))),
      bottomNavigationBar: switch (transferAsync.value) {
        final t? => _actions(context, ref, t, user.id),
        _ => null,
      },
      body: transferAsync.when(
        data: (transfer) {
          if (transfer == null) {
            return Center(child: Text(ref.tr(context, 'transfer_not_found')));
          }
          return _buildTransferDetail(context, ref, transfer, user.id);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _buildErrorWidget(context, ref, () {
          ref.invalidate(
            transferByIdProvider((userId: user.id, transferId: transferId)),
          );
        }),
      ),
    );
  }

  Widget _buildErrorWidget(
    BuildContext context,
    WidgetRef ref,
    VoidCallback retry,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhRegular.warningCircle, size: 64, color: context.colors.muted),
          const SizedBox(height: 16),
          Text(ref.tr(context, 'error_loading_transfers')),
          const SizedBox(height: 16),
          FilledButton(onPressed: retry, child: Text(ref.tr(context, 'retry'))),
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
    final muted = context.colors.muted;
    final wallets = ref.watch(walletsProvider(userId)).value ?? const [];
    final from = wallets
        .where((w) => w.id == transfer.fromWalletId)
        .firstOrNull;
    final to = wallets.where((w) => w.id == transfer.toWalletId).firstOrNull;
    final unknown = ref.tr(context, 'wallet_unknown');
    final hasNotes = transfer.notes?.trim().isNotEmpty ?? false;

    Widget row(String label, String value, Widget leading) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 24, height: 24, child: Center(child: leading)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(color: muted),
                ),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
    Widget walletIcon(Wallet? w) => w == null
        ? Icon(PhRegular.wallet, color: theme.colorScheme.onSurface)
        : WalletIconHelper.buildIcon(w.icon, size: 24);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: context.colors.sunken,
            borderRadius: BorderRadius.circular(AppTheme.rCard),
          ),
          child: Icon(
            PhRegular.arrowsLeftRight,
            size: 26,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          hasNotes ? transfer.notes!.trim() : ref.tr(context, 'transfer'),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        AmountText(
          transfer.amount,
          tone: AmountTone.transfer,
          style: theme.textTheme.displaySmall,
        ),
        const SizedBox(height: 4),
        Text(
          '${from?.name ?? unknown} → ${to?.name ?? unknown}',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              row(
                ref.tr(context, 'date_label'),
                _formatDate(context, ref, transfer.date),
                Icon(
                  PhRegular.calendarBlank,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Divider(indent: 56),
              row(
                ref.tr(context, 'from_wallet'),
                from?.name ?? unknown,
                walletIcon(from),
              ),
              const Divider(indent: 56),
              row(
                ref.tr(context, 'to_wallet'),
                to?.name ?? unknown,
                walletIcon(to),
              ),
              if (hasNotes) ...[
                const Divider(indent: 56),
                row(
                  ref.tr(context, 'notes'),
                  transfer.notes!.trim(),
                  Icon(PhRegular.note, color: theme.colorScheme.onSurface),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _actions(
    BuildContext context,
    WidgetRef ref,
    Transfer transfer,
    String userId,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _editTransfer(context, ref, transfer),
              icon: const Icon(PhRegular.pencilSimple),
              label: Text(ref.tr(context, 'edit')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () =>
                  _confirmDeleteTransfer(context, ref, transfer, userId),
              icon: const Icon(PhRegular.trash),
              label: Text(ref.tr(context, 'delete')),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.errorContainer,
                foregroundColor: scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editTransfer(
    BuildContext context,
    WidgetRef ref,
    Transfer transfer,
  ) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            AddEditTransactionScreen(initialTransfer: transfer),
      ),
    );

    if (result == true && context.mounted) {
      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        ref.invalidate(
          transferByIdProvider((userId: user.id, transferId: transfer.id)),
        );
        refreshWalletProviders(ref);
        // Refresh transaction providers untuk update ledger entries
        refreshTransactionProviders(ref);
      }
    }
  }

  void _confirmDeleteTransfer(
    BuildContext context,
    WidgetRef ref,
    Transfer transfer,
    String userId,
  ) {
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
                await ref
                    .read(transferServiceProvider)
                    .delete(userId, transfer.id);

                if (!outerContext.mounted) return;

                // Close dialog first
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }

                // Refresh wallet providers
                refreshWalletProviders(ref);
                // Refresh transaction providers untuk update ledger entries
                refreshTransactionProviders(ref);

                // Pop detail screen
                if (Navigator.of(outerContext).canPop()) {
                  Navigator.of(outerContext).pop();
                }

                // Show success message
                ScaffoldMessenger.of(outerContext).showSnackBar(
                  SnackBar(
                    content: Text(ref.tr(outerContext, 'transfer_deleted')),
                  ),
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
                      content: Text(
                        ref
                            .tr(outerContext, 'error_deleting_transfer')
                            .replaceAll('{error}', '$e'),
                      ),
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
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
