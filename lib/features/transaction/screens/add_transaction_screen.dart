import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/transaction.dart';
import '../../../models/category.dart';
import '../../../models/wallet.dart';
import '../providers/transaction_providers.dart';
import '../../category/providers/category_providers.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/currency_formatter.dart';
import '../widgets/category_selector_sheet.dart';
import '../widgets/wallet_selector_sheet.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final Transaction? initialTransaction;

  const AddTransactionScreen({super.key, this.initialTransaction});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _amountFocusNode = FocusNode();

  DateTime _selectedDate = DateTime.now();
  Category? _selectedCategory;
  Wallet? _selectedWallet;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // If editing existing transaction, populate fields
    if (widget.initialTransaction != null) {
      final transaction = widget.initialTransaction!;
      _amountController.text = transaction.amount.abs().toString();
      _notesController.text = transaction.notes ?? '';
      _selectedDate = transaction.date;

      // Load category and wallet from IDs will be done in didChangeDependencies
      // after the provider is available
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Load category and wallet when editing existing transaction
    if (widget.initialTransaction != null &&
        _selectedCategory == null &&
        _selectedWallet == null) {
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final transaction = widget.initialTransaction!;

    // Load categories and find the selected one
    final categoriesAsync = ref.read(categoriesProvider(user.id));
    final categories = categoriesAsync.value ?? [];
    Category? category;
    try {
      category = categories.firstWhere((c) => c.id == transaction.categoryId);
    } catch (e) {
      // Category not found, keep as null
    }

    // Load wallets and find the selected one
    final walletsAsync = ref.read(activeWalletsProvider(user.id));
    final wallets = walletsAsync.value ?? [];
    Wallet? wallet;
    try {
      wallet = wallets.firstWhere((w) => w.id == transaction.walletId);
    } catch (e) {
      // Wallet not found, keep as null
    }

    if (mounted) {
      setState(() {
        _selectedCategory = category;
        _selectedWallet = wallet;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
  _amountFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login first')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialTransaction != null
              ? 'Edit Transaction'
              : 'Add Transaction',
        ),
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside
          FocusScope.of(context).unfocus();
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(6),
            children: [
              // Date Section
              _buildDateSection(),
              const SizedBox(height: 6),

              // Amount Section
              _buildAmountSection(),
              const SizedBox(height: 6),

              // Category Selection
              _buildCategorySection(user.id),
              const SizedBox(height: 6),

              // Wallet Selection
              _buildWalletSection(user.id),
              const SizedBox(height: 6),

              // Notes Section
              _buildNotesSection(),
              const SizedBox(height: 12),

              // Save Button
              FilledButton(
                onPressed: _isLoading ? null : _saveTransaction,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        widget.initialTransaction != null
                            ? 'Update Transaction'
                            : 'Add Transaction',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSection() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today),
        title: const Text('Transaction Date'),
        subtitle: Text(_formatDate(_selectedDate)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _selectDate,
      ),
    );
  }

  Widget _buildAmountSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16), // Reduced from 20
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4), // Reduced from 8
            TextFormField(
              focusNode: _amountFocusNode,
              controller: _amountController,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '0',
                hintStyle: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
                prefixText: 'Rp ',
                prefixStyle: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _unfocus(),
              onTapOutside: (_) => _unfocus(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value!);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(String userId) {
    final categoriesAsync = ref.watch(categoriesProvider(userId));

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: _selectedCategory != null
                ? Icon(
                    IconData(
                      _selectedCategory!.iconCodePoint ?? Icons.category.codePoint,
                      fontFamily: 'MaterialIcons',
                    ),
                    color: _selectedCategory!.color != null
                        ? Color(_selectedCategory!.color!)
                        : null,
                  )
                : const Icon(Icons.category),
            title: Text(_selectedCategory?.name ?? 'Select Category'),
            subtitle: _selectedCategory != null
                ? Text(_selectedCategory!.type.name.toUpperCase())
                : const Text('Choose transaction category'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _selectCategory(categoriesAsync.value ?? []),
          ),
          if ((_selectedCategory == null) && (categoriesAsync.value?.isEmpty ?? true))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    if (!mounted) return;
                    Navigator.of(context).pushNamed('/categories/manage').then((value) {
                      if (!mounted) return;
                      if (value == true) {
                        final user = ref.read(currentUserProvider).value;
                        if (user != null) {
                          ref.invalidate(categoriesProvider(user.id));
                        }
                      }
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Category'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWalletSection(String userId) {
    final walletsAsync = ref.watch(activeWalletsProvider(userId));

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: _selectedWallet != null
                ? Icon(
                    _getWalletIcon(_selectedWallet!.icon),
                    color: Theme.of(context).primaryColor,
                  )
                : const Icon(Icons.account_balance_wallet),
            title: Text(_selectedWallet?.name ?? 'Select Wallet'),
            subtitle: _selectedWallet != null
                ? Text(
                    'Balance: ${CurrencyFormatter.format(_selectedWallet!.balance, _selectedWallet!.currency)}',
                  )
                : const Text('Choose wallet for transaction'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _selectWallet(walletsAsync.value ?? []),
          ),
          if ((_selectedWallet == null) && (walletsAsync.value?.isEmpty ?? true))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    if (!mounted) return;
                    Navigator.of(context).pushNamed('/wallets/manage').then((value) {
                      if (!mounted) return;
                      if (value == true) {
                        final user = ref.read(currentUserProvider).value;
                        if (user != null) {
                          refreshWalletProviders(ref);
                        }
                      }
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Wallet'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12), // Reduced from 16
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes (Optional)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4), // Reduced from 8
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Add transaction details...',
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
  _unfocus();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  void _selectCategory(List<Category> categories) {
  _unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CategorySelectorSheet(
        categories: categories,
        onCategorySelected: (category) {
          setState(() {
            _selectedCategory = category;
          });
          Navigator.pop(context);
          final user = ref.read(currentUserProvider).value;
          if (user != null) {
            ref.invalidate(categoriesProvider(user.id));
          }
        },
  rootContext: this.context,
      ),
    );
  }

  void _selectWallet(List<Wallet> wallets) {
  _unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => WalletSelectorSheet(
        wallets: wallets,
        onWalletSelected: (wallet) {
          setState(() {
            _selectedWallet = wallet;
          });
          Navigator.pop(context);
          refreshWalletProviders(ref);
        },
  rootContext: this.context,
      ),
    );
  }

  Future<void> _saveTransaction() async {
  _unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    if (_selectedWallet == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a wallet')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = ref.read(currentUserProvider).value!;
      final amount = double.parse(_amountController.text);
      final notes = _notesController.text.trim();

  // Amount always stored as positive; category.type determines sign in analytics & wallet triggers
  final finalAmount = amount.abs();

      if (widget.initialTransaction != null) {
        // Update existing transaction
        final request = UpdateTransactionRequest(
          walletId: _selectedWallet!.id,
          categoryId: _selectedCategory!.id,
          amount: finalAmount,
          notes: notes.isEmpty ? null : notes,
          date: _selectedDate,
        );

        final transactionService = ref.read(transactionServiceProvider);
        await transactionService.updateTransaction(
          widget.initialTransaction!.id,
          user.id,
          request,
        );
      } else {
        // Create new transaction
        final request = CreateTransactionRequest(
          walletId: _selectedWallet!.id,
          categoryId: _selectedCategory!.id,
          amount: finalAmount,
          notes: notes.isEmpty ? null : notes,
          date: _selectedDate,
        );

        final transactionService = ref.read(transactionServiceProvider);
        await transactionService.createTransaction(user.id, request);
      }

      // Refresh transactions list and wallet balances
      ref.invalidate(transactionsProvider(user.id));
      ref.invalidate(
        filteredTransactionsProvider,
      ); // Fix: Invalidate filtered transactions
      ref.invalidate(
        transactionsSummaryProvider((
          userId: user.id,
          startDate: null,
          endDate: null,
        )),
      );
      // Refresh wallet data to show updated balance
      refreshWalletProviders(ref);
      if (_selectedWallet != null) {
        ref.invalidate(
          walletProvider((walletId: _selectedWallet!.id, userId: user.id)),
        );
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.initialTransaction != null
                  ? 'Transaction updated successfully'
                  : 'Transaction added successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _unfocus() {
  // Always try to unfocus to dismiss keyboard
  FocusManager.instance.primaryFocus?.unfocus();
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

  IconData _getWalletIcon(String? icon) {
    switch (icon) {
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
}
