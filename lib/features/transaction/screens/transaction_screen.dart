import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'add_transaction_screen.dart';
import 'transaction_detail_screen.dart';
import '../providers/transaction_providers.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../category/providers/category_providers.dart';
import '../../../models/category.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/currency_formatter.dart';
import '../../../models/wallet.dart';
import '../../../core/state/balance_visibility_provider.dart';

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
      return const Scaffold(body: Center(child: Text('Please login first')));
    }

    final walletsAsync = ref.watch(activeWalletsProvider(user.id));
    final categoriesAsync = ref.watch(categoriesProvider(user.id));

    // Get filtered transactions based on selected wallet
    final transactionsAsync = ref.watch(
      filteredTransactionsProvider((
        userId: user.id,
        walletId: _selectedWalletId,
        categoryId: null,
        startDate: null,
        endDate: null,
      )),
    );

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: transactionsAsync.when(
                data: (transactions) {
                  return categoriesAsync.when(
                    data: (categories) {
                      final filteredTransactions = _filterTransactionsBySearch(
                        transactions,
                      );
                      if (filteredTransactions.isEmpty) {
                        return _buildEmptyState(context, theme);
                      }
                      final wallets = walletsAsync.valueOrNull ?? [];
                      return _buildTransactionList(
                        filteredTransactions,
                        theme,
                        categories,
                        wallets,
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
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
              ref.invalidate(filteredTransactionsProvider);
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
                  'Total Balance',
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
                  ? 'Semua Dompet'
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
        'Error loading balance',
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
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'Semua',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white),
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
        hintText: 'Search transactions...',
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

  List<dynamic> _filterTransactionsBySearch(List<dynamic> transactions) {
    if (_searchQuery.isEmpty) return transactions;

    return transactions.where((transaction) {
      final notes = transaction.notes?.toLowerCase() ?? '';
      final amount = transaction.amount.toString();
      final query = _searchQuery.toLowerCase();

      return notes.contains(query) || amount.contains(query);
    }).toList();
  }

  Widget _buildErrorState(Object error, String userId, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Error loading transactions: $error'),
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
            child: const Text('Retry'),
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
            'No Transactions Yet',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by adding your first transaction',
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
                  ref.invalidate(filteredTransactionsProvider);
                  refreshWalletProviders(ref);
                }
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Transaction'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(
    List<dynamic> transactions,
    ThemeData theme,
    List<Category> categories,
    List<Wallet> wallets,
  ) {
    final categoryMap = {for (final c in categories) c.id: c};
    final walletMap = {for (final w in wallets) w.id: w};

    // Build flattened list with date headers
    final items = <_TxListItem>[];
    DateTime? currentDate;
    for (final tx in transactions) {
      final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (currentDate == null || !_isSameDay(currentDate, txDate)) {
        currentDate = txDate;
        items.add(_TxListItem.header(txDate));
      }
      items.add(_TxListItem.transaction(tx));
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh all transaction-related providers
        final user = ref.read(currentUserProvider).value;
        if (user != null) {
          ref.invalidate(filteredTransactionsProvider);
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
          final transaction = item.transaction!;
          final category = categoryMap[transaction.categoryId];
          final wallet = walletMap[transaction.walletId];
          final isIncome = category?.type == CategoryType.income;
          final amountFormatted = CurrencyFormatter.format(
            transaction.amount,
            'IDR',
          );
          final displayAmount = isIncome
              ? amountFormatted
              : '-$amountFormatted';
          return Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        TransactionDetailScreen(transactionId: transaction.id),
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
                      backgroundColor: () {
                        final baseColor = category?.color != null
                            ? Color(category!.color!)
                            : (isIncome ? Colors.green : Colors.red);
                        return baseColor.withValues(alpha: 0.15);
                      }(),
                      child: Icon(
                        () {
                          if (category?.iconCodePoint != null) {
                            return IconData(
                              category!.iconCodePoint!,
                              fontFamily: 'MaterialIcons',
                            );
                          }
                          return isIncome
                              ? Icons.trending_up
                              : Icons.trending_down;
                        }(),
                        color: category?.color != null
                            ? Color(category!.color!)
                            : (isIncome ? Colors.green : Colors.red),
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
                          if (transaction.notes != null &&
                              transaction.notes!.trim().isNotEmpty) ...[
                            Text(
                              transaction.notes!,
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
                          wallet?.name ?? 'Wallet',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayAmount,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: isIncome ? Colors.green : Colors.red,
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
      return 'Hari ini';
    }
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (_isSameDay(date, yesterday)) {
      return 'Kemarin';
    }
    const hari = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const bulan = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    // Dart weekday: Monday=1 ... Sunday=7
    final weekdayName = hari[date.weekday - 1];
    final monthName = bulan[date.month - 1];
    return '$weekdayName, ${date.day} $monthName ${date.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _TxListItem {
  final bool isHeader;
  final DateTime? date;
  final dynamic transaction; // Transaction

  _TxListItem._(this.isHeader, this.date, this.transaction);
  factory _TxListItem.header(DateTime date) => _TxListItem._(true, date, null);
  factory _TxListItem.transaction(dynamic tx) => _TxListItem._(false, null, tx);
}
