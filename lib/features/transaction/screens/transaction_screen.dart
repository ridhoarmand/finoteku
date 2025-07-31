import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'add_transaction_screen.dart';
import 'transaction_detail_screen.dart';
import '../providers/transaction_providers.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/currency_formatter.dart';
import '../../../models/wallet.dart';

class TransactionScreen extends ConsumerStatefulWidget {
  const TransactionScreen({super.key});

  @override
  ConsumerState<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends ConsumerState<TransactionScreen> {
  String? _selectedWalletId; // null means "All Wallets"
  bool _isBalanceVisible = true;
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
          // Balance and Wallet Selection Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Total Balance Section
                _buildBalanceSection(walletsAsync, theme),
                const SizedBox(height: 16),

                // Wallet Selector
                _buildWalletSelector(walletsAsync, theme),
              ],
            ),
          ),

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
                  final filteredTransactions = _filterTransactionsBySearch(
                    transactions,
                  );
                  if (filteredTransactions.isEmpty) {
                    return _buildEmptyState(context, theme);
                  }
                  return _buildTransactionList(filteredTransactions, theme);
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
              ref.invalidate(activeWalletsProvider(user.id));
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
        if (_selectedWalletId == null) {
          // All wallets
          totalBalance = wallets.fold(0, (sum, wallet) => sum + wallet.balance);
        } else {
          // Specific wallet
          final selectedWallet = wallets.firstWhere(
            (wallet) => wallet.id == _selectedWalletId,
            orElse: () => wallets.first,
          );
          totalBalance = selectedWallet.balance;
        }

        return Column(
          children: [
            Text(
              'Total Balance',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isBalanceVisible
                      ? CurrencyFormatter.format(totalBalance, 'IDR')
                      : '••••••••',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isBalanceVisible = !_isBalanceVisible;
                    });
                  },
                  icon: Icon(
                    _isBalanceVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => Column(
        children: [
          Text(
            'Total Balance',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          const CircularProgressIndicator(color: Colors.white),
        ],
      ),
      error: (error, stack) => Column(
        children: [
          Text(
            'Total Balance',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            'Error loading balance',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletSelector(
    AsyncValue<List<Wallet>> walletsAsync,
    ThemeData theme,
  ) {
    return walletsAsync.when(
      data: (wallets) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedWalletId,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedWalletId = newValue;
                });
              },
              dropdownColor: theme.primaryColor,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.wallet, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'All Wallets',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                ...wallets.map((Wallet wallet) {
                  return DropdownMenuItem<String?>(
                    value: wallet.id,
                    child: Row(
                      children: [
                        Icon(
                          _getWalletIcon(wallet.icon),
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          wallet.name,
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
      loading: () => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Text('Loading wallets...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
      error: (error, stack) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Error loading wallets',
          style: TextStyle(color: Colors.white70),
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

  IconData _getWalletIcon(String? icon) {
    switch (icon?.toLowerCase()) {
      case 'bca':
      case 'bni':
      case 'bri':
      case 'mandiri':
      case 'btn':
      case 'bsi':
        return Icons.account_balance;
      case 'dana':
      case 'gopay':
      case 'ovo':
      case 'linkaja':
      case 'doku':
      case 'sopay':
        return Icons.phone_android;
      default:
        return Icons.account_balance_wallet;
    }
  }

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
                  ref.invalidate(activeWalletsProvider(user.id));
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

  Widget _buildTransactionList(List<dynamic> transactions, ThemeData theme) {
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh all transaction-related providers
        final user = ref.read(currentUserProvider).value;
        if (user != null) {
          ref.invalidate(filteredTransactionsProvider);
          ref.invalidate(transactionsProvider(user.id));
          ref.invalidate(activeWalletsProvider(user.id));
        }
      },
      child: ListView.builder(
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index];

          // Determine if transaction is income or expense based on category type
          // For income categories, amount should be positive
          // For expense categories, amount should be negative
          final isIncome = transaction.amount > 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isIncome
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                child: Icon(
                  isIncome ? Icons.trending_up : Icons.trending_down,
                  color: isIncome ? Colors.green : Colors.red,
                ),
              ),
              title: Text(transaction.notes ?? 'Transaction'),
              subtitle: Text(_formatDate(transaction.date)),
              trailing: Text(
                CurrencyFormatter.format(transaction.amount.abs(), 'IDR'),
                style: TextStyle(
                  color: isIncome ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TransactionDetailScreen(
                      transactionId: transaction.id,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
