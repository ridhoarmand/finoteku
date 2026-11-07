import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../../core/localization/app_localizations.dart';
import '../../../core/state/balance_visibility_provider.dart';
import '../../../models/ledger_entry.dart';
import '../../../models/wallet.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/amount_text.dart';
import '../../../widgets/inline_error.dart';
import '../../../widgets/user_avatar_widget.dart';
import '../../category/providers/category_providers.dart';
import '../../transaction/providers/transaction_providers.dart';
import '../../transaction/screens/add_edit_transaction_screen.dart';
import '../../transaction/widgets/ledger_list.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../wallet/widgets/wallet_picker_sheet.dart';
import '../providers/home_providers.dart';

/// Beranda: the balance is the focal point, the month in one line, then the
/// latest activity grouped by day (DESIGN.md "Layout").
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _maxRows = 25;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = SupabaseService.currentUser;
    if (user == null) {
      return Scaffold(body: Center(child: Text(ref.tr(context, 'login_required_short'))));
    }
    final userId = user.id;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final from = today.subtract(const Duration(days: 30));
    final rangeStart = from.isBefore(monthStart) ? from : monthStart;

    final selectedWalletId = ref.watch(selectedHomeWalletProvider);
    final walletsAsync = ref.watch(walletsProvider(userId));
    final ledgerArgs = (userId: userId, walletId: selectedWalletId, startDate: rangeStart, endDate: today);
    final ledgerAsync = ref.watch(ledgerEntriesProvider(ledgerArgs));
    final categoriesAsync = ref.watch(categoriesAllProvider(userId));

    Future<void> refresh() async {
      ref.read(transactionRefreshTriggerProvider.notifier).bump();
      refreshWalletProviders(ref);
      await ref.read(ledgerEntriesProvider(ledgerArgs).future).catchError((_) => <LedgerEntry>[]);
    }

    Future<void> addTransaction() async {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddEditTransactionScreen()));
    }

    final wallets = walletsAsync.value ?? const <Wallet>[];
    final header = _HomeHeader(
      user: user,
      wallets: wallets,
      walletsAsync: walletsAsync,
      selectedWalletId: selectedWalletId,
      monthEntries: ledgerAsync.value?.where((e) => !e.date.isBefore(monthStart)).toList(),
    );

    Widget body;
    if (ledgerAsync.hasError || categoriesAsync.hasError) {
      body = ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [header, InlineError(onRetry: refresh)],
      );
    } else if (!ledgerAsync.hasValue || !categoriesAsync.hasValue) {
      body = ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [header, const SizedBox(height: 48), const Center(child: CircularProgressIndicator())],
      );
    } else {
      final entries = ledgerAsync.value!.take(_maxRows).toList();
      body = entries.isEmpty
          ? ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [header, _EmptyActivity(onAdd: addTransaction)],
            )
          : LedgerList(
              entries: entries,
              categories: categoriesAsync.value!,
              wallets: wallets,
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(ref.tr(context, 'recent_transactions'), style: Theme.of(context).textTheme.titleMedium),
                      ),
                      TextButton(onPressed: () => context.go('/transaction'), child: Text(ref.tr(context, 'see_all'))),
                    ],
                  ),
                ],
              ),
            );
    }

    return Scaffold(
      body: SafeArea(bottom: false, child: RefreshIndicator(onRefresh: refresh, child: body)),
      floatingActionButton: FloatingActionButton(
        tooltip: ref.tr(context, 'record_transaction'),
        onPressed: addTransaction,
        child: const Icon(PhBold.plus),
      ),
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  final User? user;
  final List<Wallet> wallets;
  final AsyncValue<List<Wallet>> walletsAsync;
  final String? selectedWalletId;
  final List<LedgerEntry>? monthEntries;

  const _HomeHeader({
    required this.user,
    required this.wallets,
    required this.walletsAsync,
    required this.selectedWalletId,
    required this.monthEntries,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = context.colors.muted;
    final visible = ref.watch(balanceVisibilityProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final selected = wallets.where((w) => w.id == selectedWalletId).firstOrNull;
    // hidden wallets are not part of "all wallets" (same as the wallet screen)
    final balance = selected?.balance ?? wallets.where((w) => !w.isHidden).fold<double>(0, (s, w) => s + w.balance);

    double sum(bool income) => (monthEntries ?? const <LedgerEntry>[])
        .where((e) => e.transferId == null && (e.signedAmount >= 0) == income)
        .fold<double>(0, (s, e) => s + e.amount);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEEE, d MMMM', locale).format(DateTime.now()),
                  style: theme.textTheme.labelLarge?.copyWith(color: muted),
                ),
              ),
              Semantics(
                button: true,
                label: ref.tr(context, 'nav_account'),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.go('/account'),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: UserAvatarWidget(user: user, radius: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // wallet scope of the number below
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.rControl),
            onTap: wallets.isEmpty
                ? null
                : () async {
                    final pick = await showWalletPicker(
                      context,
                      wallets: wallets.where((w) => !w.isHidden).toList(),
                      selectedId: selectedWalletId,
                    );
                    if (pick == null) return;
                    final n = ref.read(selectedHomeWalletProvider.notifier);
                    pick.walletId == null ? n.clear() : n.select(pick.walletId);
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selected?.name ?? ref.tr(context, 'total_balance'),
                    style: theme.textTheme.titleSmall?.copyWith(color: muted),
                  ),
                  const SizedBox(width: 4),
                  Icon(PhRegular.caretDown, size: 16, color: muted),
                ],
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: walletsAsync.isLoading && wallets.isEmpty
                    ? const SizedBox(height: 44, child: Align(alignment: Alignment.centerLeft, child: LinearProgressIndicator()))
                    : AmountText(balance, hidden: !visible, style: theme.textTheme.displaySmall),
              ),
              IconButton(
                tooltip: ref.tr(context, visible ? 'hide_balance' : 'show_balance'),
                onPressed: () => ref.read(balanceVisibilityProvider.notifier).toggle(),
                icon: Icon(visible ? PhRegular.eye : PhRegular.eyeSlash, color: muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (monthEntries != null)
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(ref.tr(context, 'this_month'), style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                AmountText(sum(true), tone: AmountTone.income, signed: true, hidden: !visible, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(ref.tr(context, 'home_in'), style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                Text('·', style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                AmountText(sum(false), tone: AmountTone.expense, signed: true, hidden: !visible, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(ref.tr(context, 'home_out'), style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
              ],
            ),
          const SizedBox(height: 16),
          const Divider(),
        ],
      ),
    );
  }
}

class _EmptyActivity extends ConsumerWidget {
  final VoidCallback onAdd;
  const _EmptyActivity({required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(PhRegular.receipt, size: 40, color: context.colors.muted),
          const SizedBox(height: 12),
          Text(ref.tr(context, 'home_empty_title'), style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            ref.tr(context, 'home_empty_body'),
            style: theme.textTheme.bodyMedium?.copyWith(color: context.colors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(PhBold.plus, size: 18),
            label: Text(ref.tr(context, 'record_transaction')),
          ),
        ],
      ),
    );
  }
}
