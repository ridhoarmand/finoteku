import 'package:flutter/material.dart';
import '../../../utils/wallet_icon_helper.dart';
import '../../../widgets/amount_text.dart';
import '../../../theme/app_theme.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/transaction.dart';
import '../providers/transaction_providers.dart';
import '../../category/providers/category_providers.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/category_icon_helper.dart';
import 'add_edit_transaction_screen.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../models/category.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  bool _hasChanges = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return Scaffold(
        body: Center(child: Text(ref.tr(context, 'login_required_short'))),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (context.mounted) {
          Navigator.of(context).pop(_hasChanges);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(ref.tr(context, 'transaction_details_title')),
          leading: BackButton(
            onPressed: () {
              Navigator.of(context).pop(_hasChanges);
            },
          ),
        ),
        body: _buildTransactionBody(context, ref, user.id),
        bottomNavigationBar: switch (ref
            .watch(
              transactionProvider((
                transactionId: widget.transactionId,
                userId: user.id,
              )),
            )
            .value) {
          final tx? => _actions(context, ref, tx, user.id),
          _ => null,
        },
      ),
    );
  }

  Widget _buildTransactionBody(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) {
    final txAsync = ref.watch(
      transactionProvider((
        transactionId: widget.transactionId,
        userId: userId,
      )),
    );
    return txAsync.when(
      data: (tx) {
        if (tx == null) {
          return Center(child: Text(ref.tr(context, 'transaction_not_found')));
        }
        return _buildTransactionDetail(context, ref, tx, userId);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _errorWithRetry(
        context,
        ref,
        () => ref.invalidate(
          transactionProvider((
            transactionId: widget.transactionId,
            userId: userId,
          )),
        ),
      ),
    );
  }

  Widget _errorWithRetry(
    BuildContext context,
    WidgetRef ref,
    VoidCallback retry,
  ) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(PhRegular.warningCircle, size: 64, color: context.colors.muted),
        const SizedBox(height: 16),
        Text(
          ref
              .tr(context, 'error_loading_transactions')
              .replaceAll('{error}', ''),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: retry, child: Text(ref.tr(context, 'retry'))),
      ],
    ),
  );

  Widget _buildTransactionDetail(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
    String userId,
  ) {
    final theme = Theme.of(context);
    final muted = context.colors.muted;
    final categories =
        ref.watch(categoriesAllProvider(userId)).value ?? const <Category>[];
    final wallets = ref.watch(walletsProvider(userId)).value ?? const [];
    final category = categories
        .where((c) => c.id == transaction.categoryId)
        .firstOrNull;
    final parent = category?.parentId == null
        ? null
        : categories.where((c) => c.id == category!.parentId).firstOrNull;
    final wallet = wallets
        .where((w) => w.id == transaction.walletId)
        .firstOrNull;
    final isIncome = category?.type == CategoryType.income;
    final hasNotes = transaction.notes?.trim().isNotEmpty ?? false;
    final catName = category == null
        ? ref.tr(context, 'uncategorized')
        : (parent != null
              ? '${parent.name} › ${category.name}'
              : category.name);

    Widget row(
      IconData icon,
      String label,
      String value, {
      Widget? leading,
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: leading ?? Icon(icon, color: theme.colorScheme.onSurface),
            ),
          ),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // The amount is the focal point; what it was for sits right under it.
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: context.colors.sunken,
            borderRadius: BorderRadius.circular(AppTheme.rCard),
          ),
          child: Icon(
            CategoryIconHelper.iconFor(
              codePoint: category?.iconCodePoint,
              name: category?.name ?? '',
            ),
            size: 26,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          hasNotes ? transaction.notes!.trim() : catName,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        AmountText(
          transaction.amount.abs(),
          tone: isIncome ? AmountTone.income : AmountTone.expense,
          signed: true,
          style: theme.textTheme.displaySmall,
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              row(
                PhRegular.calendarBlank,
                ref.tr(context, 'date_label'),
                _formatDate(context, ref, transaction.date),
              ),
              const Divider(indent: 56),
              row(
                PhRegular.squaresFour,
                ref.tr(context, 'category_label'),
                catName,
                leading: Icon(
                  CategoryIconHelper.iconFor(
                    codePoint: category?.iconCodePoint,
                    name: category?.name ?? '',
                  ),
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Divider(indent: 56),
              row(
                PhRegular.wallet,
                ref.tr(context, 'wallet_label'),
                wallet?.name ?? ref.tr(context, 'wallet_unknown'),
                leading: wallet == null
                    ? null
                    : WalletIconHelper.buildIcon(wallet.icon, size: 24),
              ),
              if (hasNotes && category != null) ...[
                const Divider(indent: 56),
                row(
                  PhRegular.note,
                  ref.tr(context, 'notes'),
                  transaction.notes!.trim(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            [
              '${ref.tr(context, 'wallet_created_label')}: ${_formatDateTime(context, ref, transaction.createdAt)}',
              if (transaction.updatedAt != transaction.createdAt)
                '${ref.tr(context, 'wallet_updated_label')}: ${_formatDateTime(context, ref, transaction.updatedAt)}',
            ].join('\n'),
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }

  Widget _actions(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
    String userId,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _editTransaction(context, ref, transaction),
              icon: const Icon(PhRegular.pencilSimple),
              label: Text(ref.tr(context, 'edit')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () =>
                  _showDeleteDialog(context, ref, transaction, userId),
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

  void _editTransaction(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
  ) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            AddEditTransactionScreen(initialTransaction: transaction),
      ),
    );

    // If transaction was updated, refresh the data
    if (result == true && context.mounted) {
      setState(() {
        _hasChanges = true;
      });
      // Invalidate providers to ensure fresh data
      ref.invalidate(transactionProvider);
      refreshWalletProviders(ref);
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
    String userId,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(ref.tr(context, 'delete_transaction_title')),
          content: Text(ref.tr(context, 'delete_transaction_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(ref.tr(context, 'cancel')),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Close dialog first
                // Use the screen context, not dialog context
                await _deleteTransaction(context, ref, transaction.id, userId);
              },
              style: FilledButton.styleFrom(foregroundColor: Colors.white),
              child: Text(ref.tr(context, 'delete')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTransaction(
    BuildContext context,
    WidgetRef ref,
    String transactionId,
    String userId,
  ) async {
    try {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.deleteTransaction(transactionId, userId);

      // Invalidate related providers to refresh data
      refreshTransactionProviders(ref);
      // Family providers require params; rely on refresh trigger instead of raw invalidation
      // Also refresh wallet providers to update balances
      refreshWalletProviders(ref);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.tr(context, 'transaction_deleted_successfully')),
          ),
        );
        Navigator.of(context).pop(true); // Go back to previous screen
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref
                  .tr(context, 'error_deleting_transaction')
                  .replaceAll('{error}', '$e'),
            ),
          ),
        );
      }
    }
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

  String _formatDateTime(
    BuildContext context,
    WidgetRef ref,
    DateTime dateTime,
  ) {
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
    ][dateTime.month - 1];
    final monthName = ref.tr(context, monthKey);
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.day} $monthName ${dateTime.year} $hour:$minute';
  }
}
