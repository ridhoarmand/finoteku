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
  bool _includeChildren =
      true; // default include children when category selected
  String _searchQuery = '';
  bool _showFilters = false;
  DateTime? _startDate;
  DateTime? _endDate;
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
    // The selected wallet may have been hidden elsewhere: fall back to "all wallets"
    // instead of showing another wallet's balance next to the hidden one's list.
    final activeWallets = walletsAsync.value;
    final selectedGone = _selectedWalletId != null &&
        activeWallets != null &&
        !activeWallets.any((w) => w.id == _selectedWalletId);
    if (selectedGone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedWalletId = null);
      });
    }
    final selectedWalletId = selectedGone ? null : _selectedWalletId;
    final allWalletsAsync = ref.watch(walletsProvider(user.id));
    final categoriesAsync = ref.watch(categoriesAllProvider(user.id));

    // Gunakan ledger entries agar transfer juga tampil dalam daftar
    final ledgerAsync = ref.watch(
      ledgerEntriesProvider((
        userId: user.id,
        walletId: selectedWalletId,
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
      body: RefreshIndicator(
        onRefresh: () async {
          // Invalidate all relevant providers to reload data
          ref.invalidate(
            ledgerEntriesProvider((
              userId: user.id,
              walletId: selectedWalletId,
              startDate: _startDate,
              endDate: _endDate,
            )),
          );
          ref.invalidate(activeWalletsProvider(user.id));
          ref.invalidate(walletsProvider(user.id));
          ref.invalidate(categoriesAllProvider(user.id));
          // Also trigger the global refresh
          ref.read(transactionRefreshTriggerProvider.notifier).bump();
        },
        child: Column(
          children: [
            // Balance Section - Fixed at top
            TransactionBalanceSection(
              walletsAsync: walletsAsync,
              selectedWalletId: selectedWalletId,
              onWalletChanged: (val) => setState(() => _selectedWalletId = val),
            ),

            // Search and Filter Section - Fixed below balance
            TransactionSearchFilter(
              searchController: _searchController,
              searchQuery: _searchQuery,
              showFilters: _showFilters,
              selectedCategoryId: _selectedCategoryId,
              includeChildren: _includeChildren,
              startDate: _startDate,
              endDate: _endDate,
              userId: user.id,
              categoriesAsync: categoriesAsync,
              onSearchChanged: (value) => setState(() => _searchQuery = value),
              onToggleFilters: () =>
                  setState(() => _showFilters = !_showFilters),
              onCategoryChanged: (categoryId) {
                setState(() {
                  _selectedCategoryId = categoryId;
                  // Default include children when category selected
                  if (categoryId != null) {
                    _includeChildren = true;
                  }
                });
              },
              onIncludeChildrenChanged: (value) =>
                  setState(() => _includeChildren = value),
              onStartDateChanged: (date) => setState(() => _startDate = date),
              onEndDateChanged: (date) => setState(() => _endDate = date),
              onClearSearch: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              onResetFilters: () {
                setState(() {
                  _selectedCategoryId = null;
                  _includeChildren = true;
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) =>
                      _buildErrorState(error, user.id, theme),
                ),
              ),
            ),
          ],
        ),
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
      if (_includeChildren) {
        final allowedIds = {
          _selectedCategoryId!,
          ..._getDescendantCategoryIds(categories, _selectedCategoryId!),
        };
        filtered = filtered
            .where(
              (e) => e.categoryId != null && allowedIds.contains(e.categoryId),
            )
            .toList();
      } else {
        // Exact match only
        filtered = filtered
            .where((e) => e.categoryId == _selectedCategoryId)
            .toList();
      }
    }

    // Filter by date range if provided
    if (_startDate != null) {
      filtered = filtered.where((e) => e.date.isAfter(_startDate!)).toList();
    }
    if (_endDate != null) {
      final endOfDay = _endDate!.add(const Duration(days: 1));
      filtered = filtered.where((e) => e.date.isBefore(endOfDay)).toList();
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
      final categoryName = category == null
          ? ''
          : _buildCategoryPath(category, categoryMap).toLowerCase();

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

  Set<String> _getDescendantCategoryIds(
    List<Category> categories,
    String parentId,
  ) {
    final descendants = <String>{};

    void collect(String currentParentId) {
      for (final category in categories) {
        if (category.parentId == currentParentId &&
            descendants.add(category.id)) {
          collect(category.id);
        }
      }
    }

    collect(parentId);
    return descendants;
  }

  String _buildCategoryPath(
    Category category,
    Map<String, Category> categoryMap,
  ) {
    final parts = <String>[category.name];
    var current = category;

    while (current.parentId != null) {
      final parent = categoryMap[current.parentId!];
      if (parent == null) break;
      parts.add(parent.name);
      current = parent;
    }

    return parts.reversed.join(' > ');
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
            // the list watches ledgerEntriesProvider, which listens to this token
            onPressed: () =>
                ref.read(transactionRefreshTriggerProvider.notifier).bump(),
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
