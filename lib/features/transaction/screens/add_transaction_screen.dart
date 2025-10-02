import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/transaction.dart';
import '../../../models/category.dart';
import '../../../models/wallet.dart';
import '../providers/transaction_providers.dart';
import '../../category/providers/category_providers.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/category_icon_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../widgets/category_selector_sheet.dart';
import '../widgets/date_section.dart';
import '../widgets/amount_section.dart';
import '../widgets/notes_section.dart';
import '../../transfer/services/transfer_service.dart';
import '../../transfer/models/transfer_models.dart';
import '../../transfer/models/transfer.dart' as transfer_model;
import '../../transfer/screens/transfer_detail_screen.dart'; // Import untuk transferByIdProvider
import '../widgets/ledger_transfer_card.dart'; // Import untuk transferDataProvider

class AddTransactionScreen extends ConsumerStatefulWidget {
  final Transaction? initialTransaction;
  final transfer_model.Transfer? initialTransfer;

  const AddTransactionScreen({
    super.key,
    this.initialTransaction,
    this.initialTransfer,
  }) : assert(
         (initialTransaction != null) ^ (initialTransfer != null) ||
             (initialTransaction == null && initialTransfer == null),
         'Provide either initialTransaction or initialTransfer (or neither for create)',
       );

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
      _isTransfer = false;
      // Load category and wallet from IDs will be done in didChangeDependencies
      // after the provider is available
    }

    // If editing existing transfer, populate fields
    if (widget.initialTransfer != null) {
      final tr = widget.initialTransfer!;
      _isTransfer = true;
      _amountController.text = tr.amount.abs().toString();
      _feeController.text = tr.fee.abs().toString();
      _notesController.text = tr.notes ?? '';
      _selectedDate = tr.date;
      // Wallets will be assigned in didChangeDependencies
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

    // Load wallets for editing transfer
    if (widget.initialTransfer != null &&
        _selectedWallet == null &&
        _toWallet == null) {
      _loadInitialTransferData();
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

  Future<void> _loadInitialTransferData() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    final tr = widget.initialTransfer!;

    final walletsAsync = ref.read(activeWalletsProvider(user.id));
    final wallets = walletsAsync.value ?? [];
    Wallet? from;
    Wallet? to;
    try {
      from = wallets.firstWhere((w) => w.id == tr.fromWalletId);
    } catch (_) {}
    try {
      to = wallets.firstWhere((w) => w.id == tr.toWalletId);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _selectedWallet = from;
        _toWallet = to;
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
      return Scaffold(
        body: Center(child: Text(ref.tr(context, 'login_required_short'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialTransfer != null
              ? ref.tr(context, 'edit_transfer_title')
              : (widget.initialTransaction != null
                    ? ref.tr(context, 'edit_transaction_title')
                    : ref.tr(context, 'add_transaction_title')),
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
            padding: const EdgeInsets.all(2), // Reduced from 6 to 4
            children: [
              // Date Section
              _buildDateSection(),
              // Amount Section
              _buildAmountSection(),
              // Transfer Toggle
              _buildTransferToggle(),

              ...(!_isTransfer
                  ? [
                      // Category Selection
                      _buildCategorySection(user.id),
                      // Wallet Selection
                      _buildWalletSection(user.id),
                    ]
                  : [
                      // Source wallet, destination wallet and optional fee for transfer
                      _buildWalletSection(user.id),
                      _buildToWalletSection(user.id),
                      _buildFeeSection(user.id),
                    ]),

              // Notes Section
              _buildNotesSection(),
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
                        widget.initialTransfer != null
                            ? ref.tr(context, 'update_transfer_button')
                            : (widget.initialTransaction != null
                                  ? ref.tr(context, 'update_transaction_button')
                                  : ref.tr(context, 'add_transaction_button')),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSection() =>
      DateSection(date: _selectedDate, onTap: _selectDate);

  Widget _buildAmountSection() => AmountSection(
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

  Widget _buildNotesSection() => NotesSection(controller: _notesController);

  Widget _buildTransferToggle() => Card(
    child: SwitchListTile(
      title: Text(ref.tr(context, 'transfer_internal_title')),
      subtitle: Text(ref.tr(context, 'transfer_internal_subtitle')),
      value: _isTransfer,
      onChanged: widget.initialTransfer != null
          ? null // disabled when editing an existing transfer
          : (v) {
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
        padding: const EdgeInsets.all(10), // Reduced from 12 to 10
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.tr(context, 'fee_title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4), // Reduced from 6 to 4
            TextFormField(
              controller: _feeController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                hintText: ref.tr(context, 'fee_hint'),
              ),
            ),
            const SizedBox(height: 4), // Reduced from 6 to 4
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: Text(
                _feeCategory?.name ?? ref.tr(context, 'fee_category_title'),
              ),
              subtitle: Text(ref.tr(context, 'fee_category_subtitle')),
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
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    _unfocus();
    context
        .push(
          '/categories/select?userId=${user.id}&title=${Uri.encodeComponent(ref.tr(context, 'select_category_title'))}',
        )
        .then((result) {
          if (result != null && result is Category) {
            setState(() {
              _selectedCategory = result;
            });
            refreshCategoryProviders(ref);
          }
        });
  }

  void _selectWallet(List<Wallet> wallets) {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    _unfocus();
    context
        .push(
          '/wallets/select?userId=${user.id}&title=${Uri.encodeComponent(ref.tr(context, 'select_wallet_title'))}',
        )
        .then((result) {
          if (result != null && result is Wallet) {
            setState(() {
              _selectedWallet = result;
            });
            refreshWalletProviders(ref);
          }
        });
  }

  void _selectToWallet(List<Wallet> wallets) {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    _unfocus();
    context
        .push(
          '/wallets/select?userId=${user.id}&title=${Uri.encodeComponent(ref.tr(context, 'select_destination_wallet'))}',
        )
        .then((result) {
          if (result is Wallet) {
            setState(() {
              _toWallet = result;
            });
            refreshWalletProviders(ref);
          }
        });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.tr(context, 'please_select_wallet'))),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ref.tr(context, 'please_select_destination_wallet'),
              ),
            ),
          );
          return;
        }
        if (_selectedWallet!.id == _toWallet!.id) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ref.tr(context, 'source_destination_same_error')),
            ),
          );
          return;
        }
        final feeText = _feeController.text.trim();
        final fee = feeText.isEmpty ? 0.0 : double.tryParse(feeText) ?? 0.0;
        final userId = ref.read(currentUserProvider).value!.id;
        final transferSvc = ref.read(transferServiceProvider);
        if (widget.initialTransfer != null) {
          // Update existing transfer (no fee category change supported in update)
          await transferSvc.update(
            userId,
            widget.initialTransfer!.id,
            fromWalletId: _selectedWallet!.id,
            toWalletId: _toWallet!.id,
            amount: finalAmount,
            fee: fee.abs(),
            notes: notes.isEmpty ? null : notes,
            date: _selectedDate,
            // If previously no fee and user adds fee now, pass category
            feeCategoryId: (widget.initialTransfer!.fee == 0 && fee > 0)
                ? _feeCategory?.id
                : null,
          );
        } else {
          if (fee > 0 &&
              (_feeCategory == null ||
                  _feeCategory!.type != CategoryType.expense)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ref.tr(context, 'fee_category_required_error')),
              ),
            );
            return;
          }
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
        }
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ref.tr(context, 'please_select_category'))),
          );
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

      // For transfers, also invalidate the destination wallet and specific transfer provider
      if (_isTransfer && _toWallet != null) {
        ref.invalidate(
          walletProvider((walletId: _toWallet!.id, userId: user.id)),
        );

        // If updating existing transfer, invalidate its detail provider
        if (widget.initialTransfer != null) {
          ref.invalidate(
            transferByIdProvider((
              userId: user.id,
              transferId: widget.initialTransfer!.id,
            )),
          );
          // Also invalidate transferDataProvider used in LedgerTransferCard
          ref.invalidate(
            transferDataProvider((
              userId: user.id,
              transferId: widget.initialTransfer!.id,
            )),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.initialTransfer != null
                  ? ref.tr(context, 'transfer_updated_successfully')
                  : (widget.initialTransaction != null
                        ? ref.tr(context, 'transaction_updated_successfully')
                        : ref.tr(context, 'transaction_added_successfully')),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${ref.tr(context, 'error_saving_transaction')}: ${e.toString()}',
            ),
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

class _CategorySection extends ConsumerWidget {
  final String userId;
  final Category? selected;
  final void Function(Category?) onSelect;
  final void Function(List<Category>) openSheet;
  final WidgetRef ref;
  const _CategorySection({
    required this.userId,
    required this.selected,
    required this.onSelect,
    required this.openSheet,
    required this.ref,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref2) {
    final categoriesAsync = ref.watch(categoriesProvider(userId));
    final cats = categoriesAsync.value ?? [];
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: selected != null
                ? Icon(
                    CategoryIconHelper.getIconFromCodePoint(
                      selected!.iconCodePoint,
                    ),
                    color: selected!.color != null
                        ? Color(selected!.color!)
                        : null,
                  )
                : const Icon(Icons.category),
            title: Text(
              selected?.name ?? ref.tr(context, 'select_category_title'),
            ),
            subtitle: selected != null
                ? Text(selected!.type.name.toUpperCase())
                : Text(ref.tr(context, 'choose_transaction_category')),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => openSheet(cats),
          ),
          if ((selected == null) && (cats.isEmpty)) const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _WalletSection extends ConsumerWidget {
  final String userId;
  final Wallet? selected;
  final void Function(Wallet?) onSelect;
  final void Function(List<Wallet>) openSheet;
  final WidgetRef ref;
  const _WalletSection({
    required this.userId,
    required this.selected,
    required this.onSelect,
    required this.openSheet,
    required this.ref,
  });
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
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: selected != null
                ? Icon(
                    iconFor(selected!.icon),
                    color: Theme.of(context).primaryColor,
                  )
                : const Icon(Icons.account_balance_wallet),
            title: Text(
              selected?.name ?? ref.tr(context, 'select_wallet_title'),
            ),
            subtitle: selected != null
                ? Text(
                    '${ref.tr(context, 'wallet_balance_prefix')}${CurrencyFormatter.format(selected!.balance, selected!.currency)}',
                  )
                : Text(ref.tr(context, 'choose_wallet_subtitle')),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => openSheet(wallets),
          ),
          if ((selected == null) && wallets.isEmpty) const SizedBox.shrink(),
        ],
      ),
    );
  }
}
