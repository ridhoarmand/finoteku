import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'add_edit_transaction_screen.dart';
import '../providers/transaction_providers.dart';
import '../../../models/ledger_entry.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../category/providers/category_providers.dart';
import '../../../models/category.dart';
import '../../../services/supabase_service.dart';
import '../../../models/wallet.dart';
import '../../../core/localization/app_localizations.dart';
import '../widgets/transaction_balance_section.dart';
import '../widgets/transaction_search_filter.dart';
import '../widgets/transaction_list_widget.dart';

class TransactionScreen extends ConsumerStatefulWidget {
  const TransactionScreen({super.key});

  @override
  ConsumerState<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends ConsumerState<TransactionScreen> {
  String? _selectedWalletId; // null means "All Wallets"
  String? _selectedCategoryId; // null means "All Categories"
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';
  bool _showFilters = false;
  bool _isLoadingMore = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Load more when user scrolls close to bottom
      _loadMoreData();
    }
  }

  void _loadMoreData() {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });
    // Trigger provider refresh for more data
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        _isLoadingMore = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return Scaffold(
        body: Center(child: Text(ref.tr(context, 'login_required_short'))),
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
        startDate: _startDate,
        endDate: _endDate,
      )),
    );

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr(context, 'transactions_title')),
        automaticallyImplyLeading: false,
      ),
      resizeToAvoidBottomInset: false, // Mencegah overflow saat keyboard muncul
      body: Column(
        children: [
          // Balance Section - Fixed at top
          TransactionBalanceSection(
            walletsAsync: walletsAsync,
            selectedWalletId: _selectedWalletId,
            onWalletChanged: (val) => setState(() => _selectedWalletId = val),
          ),

          // Search and Filter Section - Fixed below balance
          TransactionSearchFilter(
            searchController: _searchController,
            searchQuery: _searchQuery,
            showFilters: _showFilters,
            selectedCategoryId: _selectedCategoryId,
            startDate: _startDate,
            endDate: _endDate,
            categoriesAsync: categoriesAsync,
            onSearchChanged: (value) => setState(() => _searchQuery = value),
            onToggleFilters: () => setState(() => _showFilters = !_showFilters),
            onCategoryChanged: (categoryId) =>
                setState(() => _selectedCategoryId = categoryId),
            onStartDateChanged: (date) => setState(() => _startDate = date),
            onEndDateChanged: (date) => setState(() => _endDate = date),
            onClearSearch: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            onResetFilters: () {
              setState(() {
                _selectedCategoryId = null;
                _startDate = null;
                _endDate = null;
              });
            },
          ),

          // Transaction List - Scrollable
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ledgerAsync.when(
                data: (entries) {
                  return allWalletsAsync.when(
                    data: (allWallets) {
                      return categoriesAsync.when(
                        data: (categories) {
                          final filtered = _filterLedgerBySearch(
                            entries,
                            categories,
                            allWallets,
                          );
                          if (filtered.isEmpty) {
                            return _buildEmptyState(context, theme);
                          }
                          return TransactionListWidget(
                            entries: filtered,
                            categories: categories,
                            wallets: allWallets,
                            userId: user.id,
                            scrollController: _scrollController,
                            isLoadingMore: _isLoadingMore,
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stack) =>
                            _buildErrorState(error, user.id, theme),
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
              builder: (context) => const AddEditTransactionScreen(),
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

  List<LedgerEntry> _filterLedgerBySearch(
    List<LedgerEntry> entries,
    List<Category> categories,
    List<Wallet> wallets,
  ) {
    var filtered = entries;

    // Filter by category first if selected
    if (_selectedCategoryId != null) {
      filtered = filtered
          .where((e) => e.categoryId == _selectedCategoryId)
          .toList();
    }

    // Filter by date range if selected
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((e) {
        final entryDate = e.date;
        // Memastikan date comparison menggunakan hari penuh
        final startDateMidnight = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
        );
        final endDateMidnight = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          23,
          59,
          59,
          999,
        );

        return entryDate.isAfter(
              startDateMidnight.subtract(const Duration(seconds: 1)),
            ) &&
            entryDate.isBefore(endDateMidnight.add(const Duration(seconds: 1)));
      }).toList();
    }

    // Then filter by search query
    if (_searchQuery.isEmpty) return filtered;

    final q = _searchQuery.toLowerCase();

    // Buat map untuk akses cepat kategori dan wallet
    final categoryMap = {for (var c in categories) c.id: c};
    final walletMap = {for (var w in wallets) w.id: w};

    return filtered.where((e) {
      // Pencarian dalam notes
      final notes = e.notes?.toLowerCase() ?? '';

      // Pencarian dalam amount (exact match dan sebagian)
      final amount = e.amount.toString();
      final formattedAmount = e.amount.abs().toStringAsFixed(
        0,
      ); // Tanpa desimal untuk pencarian yang lebih mudah

      // Pencarian dalam nama kategori
      final category = e.categoryId != null ? categoryMap[e.categoryId] : null;
      final categoryName = category?.name.toLowerCase() ?? '';

      // Pencarian dalam nama wallet
      final wallet = walletMap[e.walletId];
      final walletName = wallet?.name.toLowerCase() ?? '';

      return notes.contains(q) ||
          amount.contains(q) ||
          formattedAmount.contains(q) ||
          categoryName.contains(q) ||
          walletName.contains(q);
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
                  builder: (context) => const AddEditTransactionScreen(),
                ),
              );

              // Refresh data if transaction was added successfully
              if (result == true) {
                final user = ref.read(currentUserProvider).value;
                if (user != null) {
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
}
