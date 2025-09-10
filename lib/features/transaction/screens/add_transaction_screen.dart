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
import '../../transfer/services/transfer_service.dart';
import '../../transfer/models/transfer_models.dart';

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
  final _feeController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  Category? _selectedCategory;
  Wallet? _selectedWallet;
  Wallet? _toWallet; // destination wallet when transfer
  Category? _feeCategory; // expense category for transfer fee
  bool _isTransfer = false;
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
  _feeController.dispose();
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

              // Transfer Toggle
              _buildTransferToggle(),
              const SizedBox(height: 6),

              ...(!_isTransfer
                  ? [
                      // Category Selection
                      _buildCategorySection(user.id),
                      const SizedBox(height: 6),
                      // Wallet Selection
                      _buildWalletSection(user.id),
                      const SizedBox(height: 6),
                    ]
                  : [
                      // Source wallet, destination wallet and optional fee for transfer
                      _buildWalletSection(user.id),
                      const SizedBox(height: 6),
                      _buildToWalletSection(user.id),
                      const SizedBox(height: 6),
                      _buildFeeSection(user.id),
                      const SizedBox(height: 6),
                    ]),

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

  Widget _buildDateSection() => _DateSection(
        date: _selectedDate,
        onTap: _selectDate,
      );

  Widget _buildAmountSection() => _AmountSection(
        controller: _amountController,
        focusNode: _amountFocusNode,
        onSubmitted: _unfocus,
        onTapOutside: _unfocus,
      );

  Widget _buildCategorySection(String userId) => _CategorySection(
        userId: userId,
        selected: _selectedCategory,
        onSelect: (c) => setState(() => _selectedCategory = c),
        openSheet: _selectCategory,
        ref: ref,
      );

  Widget _buildWalletSection(String userId) => _WalletSection(
        userId: userId,
        selected: _selectedWallet,
        onSelect: (w) => setState(() => _selectedWallet = w),
        openSheet: _selectWallet,
        ref: ref,
      );

  Widget _buildNotesSection() => _NotesSection(controller: _notesController);

  Widget _buildTransferToggle() => Card(
        child: SwitchListTile(
          title: const Text('Transfer antar wallet saya'),
          subtitle:
              const Text('Pindahkan saldo antar wallet (opsional biaya admin)'),
          value: _isTransfer,
          onChanged: (v) {
            setState(() {
              _isTransfer = v;
              if (v) {
                _selectedCategory = null; // hide category in transfer mode
              } else {
                _toWallet = null;
                _feeCategory = null;
                _feeController.clear();
              }
            });
          },
        ),
      );

  Widget _buildToWalletSection(String userId) => _WalletSection(
        userId: userId,
        selected: _toWallet,
        onSelect: (w) => setState(() => _toWallet = w),
        openSheet: _selectToWallet,
        ref: ref,
      );

  Widget _buildFeeSection(String userId) {
    final categoriesAsync = ref.watch(categoriesProvider(userId));
    final cats = categoriesAsync.value ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Biaya Admin (opsional)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            TextFormField(
              controller: _feeController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              decoration: const InputDecoration(hintText: '0.00'),
            ),
            const SizedBox(height: 6),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: Text(_feeCategory?.name ?? 'Kategori Biaya (Expense)'),
              subtitle: const Text('Diperlukan jika biaya > 0'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _selectFeeCategory(cats),
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

  void _selectToWallet(List<Wallet> wallets) {
    _unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => WalletSelectorSheet(
        wallets: wallets,
        onWalletSelected: (wallet) {
          setState(() {
            _toWallet = wallet;
          });
          Navigator.pop(context);
          refreshWalletProviders(ref);
        },
        rootContext: this.context,
      ),
    );
  }

  void _selectFeeCategory(List<Category> categories) {
    _unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CategorySelectorSheet(
        categories: categories,
        onCategorySelected: (category) {
          setState(() {
            _feeCategory = category;
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

  Future<void> _saveTransaction() async {
  _unfocus();
    if (!_formKey.currentState!.validate()) return;

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

      if (_isTransfer) {
        // Handle transfer flow
        if (_toWallet == null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Pilih wallet tujuan')));
          return;
        }
        if (_selectedWallet!.id == _toWallet!.id) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Wallet sumber & tujuan tidak boleh sama')));
          return;
        }
        final feeText = _feeController.text.trim();
        final fee = feeText.isEmpty ? 0.0 : double.tryParse(feeText) ?? 0.0;
        if (fee > 0 && (_feeCategory == null || _feeCategory!.type != CategoryType.expense)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Kategori biaya (Expense) diperlukan jika biaya > 0')));
          return;
        }
        final userId = ref.read(currentUserProvider).value!.id;
        final transferSvc = ref.read(transferServiceProvider);
        await transferSvc.transferBetweenWallets(
          userId,
          CreateWalletTransferRequest(
            fromWalletId: _selectedWallet!.id,
            toWalletId: _toWallet!.id,
            amount: finalAmount,
            fee: fee.abs(),
            notes: notes.isEmpty ? null : notes,
            date: _selectedDate,
            feeCategoryId: _feeCategory?.id,
          ),
        );
      } else if (widget.initialTransaction != null) {
        // Update existing transaction
        final request = UpdateTransactionRequest(
          walletId: _selectedWallet!.id,
          categoryId: _selectedCategory!.id,
          amount: finalAmount,
          notes: notes.isEmpty ? null : notes,
          date: _selectedDate,
        );

  final repo = ref.read(transactionRepositoryProvider);
  await repo.updateTransaction(
          widget.initialTransaction!.id,
          user.id,
          request,
        );
      } else {
        // Create new transaction
        if (_selectedCategory == null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Please select a category')));
          return;
        }
        final request = CreateTransactionRequest(
          walletId: _selectedWallet!.id,
          categoryId: _selectedCategory!.id,
          amount: finalAmount,
          notes: notes.isEmpty ? null : notes,
          date: _selectedDate,
        );

  final repo = ref.read(transactionRepositoryProvider);
  await repo.createTransaction(user.id, request);
      }

    // Refresh transactions list and wallet balances
  refreshTransactionProviders(ref);
  ref.invalidate(transactionsProvider(user.id));
  // filteredTransactionsProvider is a family; rely on refresh trigger to update all instances
  ref.invalidate(transactionsSummaryProvider((userId: user.id, startDate: null, endDate: null)));
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

}

// --- Extracted Section Widgets ---

class _DateSection extends StatelessWidget {
  final DateTime date; final VoidCallback onTap;
  const _DateSection({required this.date, required this.onTap});
  static String format(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) return 'Today';
    if (date.year == now.year && date.month == now.month && date.day == now.day - 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.calendar_today),
          title: const Text('Transaction Date'),
          subtitle: Text(format(date)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
        ),
      );
}

class _AmountSection extends StatelessWidget {
  final TextEditingController controller; final FocusNode focusNode; final VoidCallback onSubmitted; final VoidCallback onTapOutside;
  const _AmountSection({required this.controller, required this.focusNode, required this.onSubmitted, required this.onTapOutside});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Amount', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            TextFormField(
              focusNode: focusNode,
              controller: controller,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '0',
                hintStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.grey),
                prefixText: 'Rp ',
                prefixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmitted(),
              onTapOutside: (_) => onTapOutside(),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Please enter an amount';
                final amount = double.tryParse(value!); if (amount == null || amount <= 0) return 'Please enter a valid amount';
                return null;
              },
            ),
          ]),
        ),
      );
}

class _NotesSection extends StatelessWidget {
  final TextEditingController controller; const _NotesSection({required this.controller});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Notes (Optional)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(border: InputBorder.none, hintText: 'Add transaction details...'),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ]),
        ),
      );
}

class _CategorySection extends ConsumerWidget {
  final String userId; final Category? selected; final void Function(Category?) onSelect; final void Function(List<Category>) openSheet; final WidgetRef ref;
  const _CategorySection({required this.userId, required this.selected, required this.onSelect, required this.openSheet, required this.ref});
  @override
  Widget build(BuildContext context, WidgetRef ref2) {
    final categoriesAsync = ref.watch(categoriesProvider(userId));
    final cats = categoriesAsync.value ?? [];
    return Card(child: Column(children: [
      ListTile(
        leading: selected != null
            ? Icon(IconData(selected!.iconCodePoint ?? Icons.category.codePoint, fontFamily: 'MaterialIcons'), color: selected!.color != null ? Color(selected!.color!) : null)
            : const Icon(Icons.category),
        title: Text(selected?.name ?? 'Select Category'),
        subtitle: selected != null ? Text(selected!.type.name.toUpperCase()) : const Text('Choose transaction category'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => openSheet(cats),
      ),
      if ((selected == null) && (cats.isEmpty))
  const SizedBox.shrink(),
    ]));
  }
}

class _WalletSection extends ConsumerWidget {
  final String userId; final Wallet? selected; final void Function(Wallet?) onSelect; final void Function(List<Wallet>) openSheet; final WidgetRef ref;
  const _WalletSection({required this.userId, required this.selected, required this.onSelect, required this.openSheet, required this.ref});
  static IconData iconFor(String? icon) {
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
  @override
  Widget build(BuildContext context, WidgetRef ref2) {
    final walletsAsync = ref.watch(activeWalletsProvider(userId));
    final wallets = walletsAsync.value ?? [];
    return Card(child: Column(children: [
      ListTile(
        leading: selected != null
            ? Icon(iconFor(selected!.icon), color: Theme.of(context).primaryColor)
            : const Icon(Icons.account_balance_wallet),
        title: Text(selected?.name ?? 'Select Wallet'),
        subtitle: selected != null
            ? Text('Balance: ${CurrencyFormatter.format(selected!.balance, selected!.currency)}')
            : const Text('Choose wallet for transaction'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => openSheet(wallets),
      ),
      if ((selected == null) && wallets.isEmpty)
  const SizedBox.shrink(),
    ]));
  }
}
