import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'add_transaction_screen.dart';
import 'transaction_detail_screen.dart';
import '../../transfer/screens/transfer_detail_screen.dart';
import '../../category/theme/category_theme.dart';
import '../../transfer/services/transfer_service.dart';
import '../providers/transaction_providers.dart';
import '../../../models/ledger_entry.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../category/providers/category_providers.dart';
import '../../../models/category.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/currency_formatter.dart';
import '../../../models/wallet.dart';
import '../../../core/state/balance_visibility_provider.dart';
import '../../../core/localization/app_localizations.dart';

class TransactionScreen extends ConsumerStatefulWidget {
  const TransactionScreen({super.key});

  @override
  ConsumerState<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends ConsumerState<TransactionScreen> {
  String? _selectedWalletId; // null means "All Wallets"
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(ref.tr(context, 'login_required_short')),
        ),
      );
    }

  final walletsAsync = ref.watch(activeWalletsProvider(user.id));
  final allWalletsAsync = ref.watch(walletsProvider(user.id));
    final categoriesAsync = ref.watch(categoriesProvider(user.id));

    // Gunakan ledger entries agar transfer juga tampil dalam daftar
    final ledgerAsync = ref.watch(
      ledgerEntriesProvider((
        userId: user.id,
        walletId: _selectedWalletId,
        startDate: null,
        endDate: null,
      )),
    );

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr(context, 'transactions_title')),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Compact top summary (balance + wallet selector side by side)
          _buildTopSummarySection(walletsAsync, theme),

          // Search Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSearchSection(theme),
          ),

          // Transaction List
          Expanded(
            child: Padding(
              // Slightly reduce horizontal padding to widen cards similar to Home
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ledgerAsync.when(
                data: (entries) {
                  return categoriesAsync.when(
                    data: (categories) {
                      final filtered = _filterLedgerBySearch(entries);
                      if (filtered.isEmpty) {
                        return _buildEmptyState(context, theme);
                      }
                      final wallets = allWalletsAsync.valueOrNull ?? walletsAsync.valueOrNull ?? [];
                      return _buildLedgerList(
                        filtered,
                        theme,
                        categories,
                        wallets,
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) =>
                        _buildErrorState(error, user.id, theme),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) =>
                    _buildErrorState(error, user.id, theme),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );

          // Refresh data if transaction was added successfully
          if (result == true) {
            final user = ref.read(currentUserProvider).value;
            if (user != null) {
              // filteredTransactionsProvider is a family; rely on refresh triggers
              refreshWalletProviders(ref);
            }
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBalanceSection(
    AsyncValue<List<Wallet>> walletsAsync,
    ThemeData theme,
  ) {
    return walletsAsync.when(
      data: (wallets) {
        double totalBalance = 0;
        Wallet? selected;
        if (_selectedWalletId == null) {
          totalBalance = wallets.fold(0, (sum, wallet) => sum + wallet.balance);
        } else {
          selected = wallets.firstWhere(
            (w) => w.id == _selectedWalletId,
            orElse: () => wallets.isNotEmpty
                ? wallets.first
                : Wallet(
                    id: '',
                    name: 'N/A',
                    balance: 0,
                    userId: '',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
          );
          totalBalance = selected.balance;
        }

  final isVisible = ref.watch(balanceVisibilityProvider);
  return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  ref.tr(context, 'total_balance'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    final current = ref.read(balanceVisibilityProvider);
                    ref.read(balanceVisibilityProvider.notifier).state = !current;
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isVisible ? Icons.visibility : Icons.visibility_off,
                      size: 18,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Responsive amount that scales down if too long
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                isVisible
                    ? CurrencyFormatter.format(totalBalance, 'IDR')
                    : '••••••••',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedWalletId == null
                  ? ref.tr(context, 'wallet_all_wallets')
                  : (selected?.name ?? ''),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
      loading: () => SizedBox(
        height: 80,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 110,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: 160,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
      error: (error, stack) => Text(
        ref.tr(context, 'error_loading_balance'),
        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
      ),
    );
  }

  // _buildWalletSelector removed (replaced by compact _buildTopSummarySection)

  Widget _buildWalletDropdown(
    AsyncValue<List<Wallet>> walletsAsync,
    ThemeData theme,
  ) {
    return walletsAsync.when(
      data: (wallets) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedWalletId,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 18,
              ),
              dropdownColor: theme.primaryColor,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
              onChanged: (val) => setState(() => _selectedWalletId = val),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    ref.tr(context, 'wallet_all_short'),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                ...wallets.map(
                  (w) => DropdownMenuItem<String?>(
                    value: w.id,
                    child: Text(
                      w.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      loading: () => const SizedBox(
        width: 120,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        ),
      ),
      error: (e, st) =>
          const Icon(Icons.error_outline, color: Colors.white70, size: 20),
    );
  }

  Widget _buildTopSummarySection(
    AsyncValue<List<Wallet>> walletsAsync,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildBalanceSection(walletsAsync, theme)),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: _buildWalletDropdown(walletsAsync, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection(ThemeData theme) {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: ref.tr(context, 'search_transactions'),
        prefixIcon: Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  List<LedgerEntry> _filterLedgerBySearch(List<LedgerEntry> entries) {
    if (_searchQuery.isEmpty) return entries;
    final q = _searchQuery.toLowerCase();
    return entries.where((e) {
      final notes = e.notes?.toLowerCase() ?? '';
      final amount = e.amount.toString();
      return notes.contains(q) || amount.contains(q);
    }).toList();
  }

  Widget _buildErrorState(Object error, String userId, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            ref
                .tr(context, 'error_loading_transactions')
                .replaceFirst('{error}', error.toString()),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.invalidate(
              filteredTransactionsProvider((
                userId: userId,
                walletId: _selectedWalletId,
                categoryId: null,
                startDate: null,
                endDate: null,
              )),
            ),
            child: Text(ref.tr(context, 'retry')),
          ),
        ],
      ),
    );
  }

  // _getWalletIcon removed (icons not shown in compact dropdown)

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            ref.tr(context, 'transactions_empty_title'),
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ref.tr(context, 'transactions_empty_sub'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AddTransactionScreen(),
                ),
              );

              // Refresh data if transaction was added successfully
              if (result == true) {
                final user = ref.read(currentUserProvider).value;
                if (user != null) {
                  // filteredTransactionsProvider is a family; rely on refresh triggers
                  refreshWalletProviders(ref);
                }
              }
            },
            icon: const Icon(Icons.add),
            label: Text(ref.tr(context, 'add_transaction')),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerList(
    List<LedgerEntry> entries,
    ThemeData theme,
    List<Category> categories,
    List<Wallet> wallets,
  ) {
    final categoryMap = {for (final c in categories) c.id: c};
    final walletMap = {for (final w in wallets) w.id: w};

    // Build flattened list with date headers
    final items = <_TxListItem>[];
    final processedTransferIds = <String>{};
    DateTime? currentDate;
    for (final e in entries) {
      final txDate = DateTime(e.date.year, e.date.month, e.date.day);
      if (currentDate == null || !_isSameDay(currentDate, txDate)) {
        currentDate = txDate;
        items.add(_TxListItem.header(txDate));
      }
      // Group transfer_in/out into a single visual item per transferId
      if ((e.kind == 'transfer_in' || e.kind == 'transfer_out') && e.transferId != null) {
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
        // Create a synthetic entry to render a single card; we reuse the existing entry but
        // mark via a wrapper item type to customize UI later in the builder.
        items.add(_TxListItem.transfer(e, counterpart != e ? counterpart : null));
      } else {
        items.add(_TxListItem.entry(e));
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh all transaction-related providers
        final user = ref.read(currentUserProvider).value;
        if (user != null) {
          // filteredTransactionsProvider is a family; rely on refresh trigger and specific invalidations
          ref.invalidate(transactionsProvider(user.id));
          refreshWalletProviders(ref);
          refreshCategoryProviders(ref);
        }
      },
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item.isHeader) {
            final label = _formatDate(item.date!);
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
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
            final a = item.entry!; // one side
            final b = item.counterpart; // other side (may be null when filtered)
            // Determine from/to wallets
            LedgerEntry? outEntry = a.signedAmount < 0 ? a : (b != null && b.signedAmount < 0 ? b : null);
            LedgerEntry? inEntry = a.signedAmount >= 0 ? a : (b != null && b.signedAmount >= 0 ? b : null);
            final fromName = outEntry != null ? (walletMap[outEntry.walletId]?.name ?? '-') : null;
            final toName = inEntry != null ? (walletMap[inEntry.walletId]?.name ?? '-') : null;
            final amount = (a.amount); // both sides share same absolute amount
            final amountFormatted = CurrencyFormatter.format(amount, 'IDR');
            final displayAmount = amountFormatted;
            final categoryColor = CategoryTheme.transfer; // neutral color for transfer
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  // Open transfer detail
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TransferDetailScreen(transferId: a.transferId!),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: categoryColor.withValues(alpha: 0.15),
                        child: Icon(
                          Icons.swap_horiz,
                          color: CategoryTheme.transfer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title: from -> to. If counterpart missing, resolve via a small fetch.
                            Builder(builder: (context) {
                              if (fromName != null && toName != null) {
                                return Text(
                                  '$fromName -> $toName',
                                  style: theme.textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              }
                              // counterpart not found (likely due to wallet filter), fetch transfer to resolve wallet names
                              final user = ref.read(currentUserProvider).value;
                              if (user == null) {
                                return Text(
                                  ref.tr(context, 'transfer'),
                                  style: theme.textTheme.titleMedium,
                                );
                              }
                              return FutureBuilder(
                                future: ref.read(transferServiceProvider).getById(user.id, a.transferId!),
                                builder: (context, snap) {
                                  if (snap.connectionState != ConnectionState.done) {
                                    return Text(
                                      ref.tr(context, 'transfer'),
                                      style: theme.textTheme.titleMedium,
                                    );
                                  }
                                  final tr = snap.data as dynamic; // Transfer
                                  if (tr == null) {
                                    return Text(
                                      ref.tr(context, 'transfer'),
                                      style: theme.textTheme.titleMedium,
                                    );
                                  }
                                  final from = walletMap[tr.fromWalletId]?.name ?? '-';
                                  final to = walletMap[tr.toWalletId]?.name ?? '-';
                                  return Text(
                                    '$from -> $to',
                                    style: theme.textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              );
                            }),
                            const SizedBox(height: 2),
                            // Subtitle: notes
                            if ((a.notes ?? b?.notes ?? '').trim().isNotEmpty)
                              Text(
                                (a.notes ?? b?.notes)!,
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
          final entry = item.entry!;
          final category = entry.categoryId != null ? categoryMap[entry.categoryId] : null;
          final wallet = walletMap[entry.walletId];
          final isPositive = entry.signedAmount >= 0;
          final amountFormatted = CurrencyFormatter.format(entry.amount, 'IDR');
          final displayAmount = isPositive ? amountFormatted : '-$amountFormatted';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (entry.kind == 'transaction') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TransactionDetailScreen(transactionId: entry.entryId),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
                          if (entry.kind == 'transfer_in') return Icons.call_received;
                          if (entry.kind == 'transfer_out') return Icons.call_made;
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
                            category?.name ?? _titleForEntry(entry),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          if (entry.notes != null && entry.notes!.trim().isNotEmpty) ...[
                            Text(
                              entry.notes!,
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          wallet?.name ?? ref.tr(context, 'wallet_label'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
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
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) {
      return ref.tr(context, 'day_today');
    }
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (_isSameDay(date, yesterday)) {
      return ref.tr(context, 'day_yesterday');
    }

    final weekdayKeys = [
      'weekday_monday',
      'weekday_tuesday',
      'weekday_wednesday',
      'weekday_thursday',
      'weekday_friday',
      'weekday_saturday',
      'weekday_sunday',
    ];
    final monthKeys = [
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
    ];
    final weekdayName = ref.tr(context, weekdayKeys[date.weekday - 1]);
    final monthName = ref.tr(context, monthKeys[date.month - 1]);
    return '$weekdayName, ${date.day} $monthName ${date.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _titleForEntry(LedgerEntry e) {
    switch (e.kind) {
      case 'transfer_in':
        return ref.tr(context, 'transfer_in');
      case 'transfer_out':
        return ref.tr(context, 'transfer_out');
      default:
        return ref.tr(context, 'uncategorized');
    }
  }
}

class _TxListItem {
  final bool isHeader;
  final DateTime? date;
  final LedgerEntry? entry;
  final bool isTransfer;
  final LedgerEntry? counterpart;

  _TxListItem._(this.isHeader, this.date, this.entry, this.isTransfer, this.counterpart);
  factory _TxListItem.header(DateTime date) => _TxListItem._(true, date, null, false, null);
  factory _TxListItem.entry(LedgerEntry e) => _TxListItem._(false, null, e, false, null);
  factory _TxListItem.transfer(LedgerEntry a, LedgerEntry? b) => _TxListItem._(false, null, a, true, b);
}
