import 'package:flutter/material.dart';
import '../../../utils/wallet_icon_helper.dart';
import '../../../theme/app_theme.dart';
import 'package:finoteku/theme/ph_icons.dart';
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
import '../../../utils/monday_first_date_picker.dart';
import '../../../core/localization/app_localizations.dart';
import '../widgets/date_section.dart';
import '../widgets/amount_section.dart';
import '../widgets/notes_section.dart';
import '../../transfer/services/transfer_service.dart';
import '../../transfer/models/transfer_models.dart';
import '../../transfer/models/transfer.dart' as transfer_model;
import '../../transfer/screens/transfer_detail_screen.dart'; // Import untuk transferByIdProvider
import '../utils/transaction_screen_helpers.dart';

class AddEditTransactionScreen extends ConsumerStatefulWidget {
  final Transaction? initialTransaction;
  final transfer_model.Transfer? initialTransfer;

  const AddEditTransactionScreen({
    super.key,
    this.initialTransaction,
    this.initialTransfer,
  }) : assert(
         (initialTransaction != null) ^ (initialTransfer != null) ||
             (initialTransaction == null && initialTransfer == null),
         'Provide either initialTransaction or initialTransfer (or neither for create)',
       );

  @override
  ConsumerState<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState
    extends ConsumerState<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _amountFocusNode = FocusNode();

  DateTime _selectedDate = DateTime.now();
  Category? _selectedCategory;
  Wallet? _selectedWallet;
  Wallet? _toWallet; // destination wallet when transfer
  bool _isTransfer = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // If editing existing transaction, populate fields
    if (widget.initialTransaction != null) {
      final transaction = widget.initialTransaction!;
      final double amount = transaction.amount.abs();
      // Format dengan menghilangkan desimal jika .00
      final String amountStr = amount == amount.toInt()
          ? amount.toInt().toString()
          : amount.toString();
      _amountController.text = _formatWithThousandSeparator(
        amountStr.replaceAll('.', ''),
      );
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
      final double amount = tr.amount.abs();
      // Format dengan menghilangkan desimal jika .00
      final String amountStr = amount == amount.toInt()
          ? amount.toInt().toString()
          : amount.toString();
      _amountController.text = _formatWithThousandSeparator(
        amountStr.replaceAll('.', ''),
      );

      _notesController.text = tr.notes ?? '';
      _selectedDate = tr.date;
      // Wallets will be assigned in didChangeDependencies
    }
  }

  /// Helper method to format numbers with thousand separators
  String _formatWithThousandSeparator(String digitsOnly) {
    if (digitsOnly.isEmpty) return '';

    final buffer = StringBuffer();
    final int length = digitsOnly.length;

    for (int i = 0; i < length; i++) {
      // Add separator every 3 digits from the right
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digitsOnly[i]);
    }

    return buffer.toString();
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

  // Look up in the lists *including hidden* wallets/categories, and wait for them:
  // a transaction may belong to a wallet or category the user hid later.
  Future<void> _loadInitialData() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final transaction = widget.initialTransaction!;
    final categories = await ref.read(categoriesAllProvider(user.id).future);
    final wallets = await ref.read(walletsProvider(user.id).future);

    if (mounted) {
      setState(() {
        _selectedCategory ??= categories
            .where((c) => c.id == transaction.categoryId)
            .firstOrNull;
        _selectedWallet ??= wallets
            .where((w) => w.id == transaction.walletId)
            .firstOrNull;
      });
    }
  }

  Future<void> _loadInitialTransferData() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    final tr = widget.initialTransfer!;
    final wallets = await ref.read(walletsProvider(user.id).future);

    if (mounted) {
      setState(() {
        _selectedWallet ??= wallets
            .where((w) => w.id == tr.fromWalletId)
            .firstOrNull;
        _toWallet ??= wallets.where((w) => w.id == tr.toWalletId).firstOrNull;
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
      return Scaffold(
        body: Center(child: Text(ref.tr(context, 'login_required_short'))),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final hasChanges = _hasChanges;
        if (!hasChanges) {
          if (context.mounted) Navigator.pop(context);
          return;
        }

        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(ref.tr(context, 'discard_changes_title')),
            content: Text(ref.tr(context, 'discard_changes_content')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(ref.tr(context, 'cancel_button')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: Text(ref.tr(context, 'discard_button')),
              ),
            ],
          ),
        );

        if (shouldPop == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.initialTransfer != null
                ? ref.tr(context, 'edit_transfer_title')
                : (widget.initialTransaction != null
                      ? ref.tr(context, 'edit_transaction_title')
                      : ref.tr(context, 'add_transaction_title')),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (widget.initialTransfer == null && widget.initialTransaction == null) ...[
                _buildModeSwitch(),
                const SizedBox(height: 20),
              ],
              // The amount is the focal point of this screen (DESIGN.md motif)
              _buildAmountSection(),
              const SizedBox(height: 20),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _buildWalletSection(user.id),
                    const Divider(indent: 56),
                    if (_isTransfer)
                      _buildToWalletSection(user.id)
                    else
                      _buildCategorySection(user.id),
                    const Divider(indent: 56),
                    _buildDateSection(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildNotesSection(),
            ],
          ),
        ),
        // Save stays reachable above the keyboard and at the end of long forms
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      textStyle: Theme.of(context).textTheme.titleMedium,
                    ),
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
                                      ? ref.tr(
                                          context,
                                          'update_transaction_button',
                                        )
                                      : ref.tr(
                                          context,
                                          'add_transaction_button',
                                        )),
                          ),
                  ),
        ),
      ),
    );
  }

  bool get _hasChanges {
    // 1. Check basic text fields first (fastest)
    final currentAmountText = _amountController.text.trim().replaceAll('.', '');
    final currentNotes = _notesController.text.trim();

    // Initial State Check for New Entry
    if (widget.initialTransaction == null && widget.initialTransfer == null) {
      if (currentAmountText.isNotEmpty) return true;
      if (currentNotes.isNotEmpty) return true;
      if (_selectedDate.difference(DateTime.now()).inMinutes.abs() > 1) {
        return true; // Date changed significantly
      }
      if (_selectedCategory != null) return true;
      // Note: _selectedWallet may be auto-selected, so usually we don't count it as a change unless user explicitly picked it?
      // strict: if (_selectedWallet != null) return true;
      // loose: ignore wallet for now as it might be default

      if (_isTransfer) {
        if (_toWallet != null) return true;
      }

      return false;
    }

    // 2. Check Editing Existing Transaction
    if (widget.initialTransaction != null) {
      final initial = widget.initialTransaction!;
      final initialAmount = initial.amount.abs();
      final currentAmount = double.tryParse(currentAmountText) ?? 0.0;

      if ((initialAmount - currentAmount).abs() > 0.01) return true;
      if (currentNotes != (initial.notes ?? '')) return true;
      if (!TransactionScreenHelpers.isSameDay(_selectedDate, initial.date)) {
        return true;
      }
      if (_selectedCategory?.id != initial.categoryId) return true;
      if (_selectedWallet?.id != initial.walletId) return true;

      return false;
    }

    // 3. Check Editing Existing Transfer
    if (widget.initialTransfer != null) {
      final initial = widget.initialTransfer!;
      final initialAmount = initial.amount.abs();
      final currentAmount = double.tryParse(currentAmountText) ?? 0.0;

      if ((initialAmount - currentAmount).abs() > 0.01) return true;
      if (currentNotes != (initial.notes ?? '')) return true;
      if (!TransactionScreenHelpers.isSameDay(_selectedDate, initial.date)) {
        return true;
      }
      if (_selectedWallet?.id != initial.fromWalletId) return true;
      if (_toWallet?.id != initial.toWalletId) return true;

      return false;
    }

    return false;
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
    labelKey: _isTransfer ? 'field_from_wallet' : 'field_wallet',
    userId: userId,
    selected: _selectedWallet,
    onSelect: (w) => setState(() => _selectedWallet = w),
    openSheet: _selectWallet,
    ref: ref,
  );

  Widget _buildNotesSection() =>
      NotesSection(controller: _notesController, onTapOutside: _unfocus);

  Widget _buildModeSwitch() => SegmentedButton<bool>(
    showSelectedIcon: false,
    segments: [
      ButtonSegment(value: false, label: Text(ref.tr(context, 'tx_mode_transaction')), icon: const Icon(PhRegular.receipt)),
      ButtonSegment(value: true, label: Text(ref.tr(context, 'tx_mode_transfer')), icon: const Icon(PhRegular.arrowsLeftRight)),
    ],
    selected: {_isTransfer},
    onSelectionChanged: (sel) {
      final v = sel.first;
      setState(() {
                _isTransfer = v;
                if (v) {
                  _selectedCategory = null; // hide category in transfer mode
                } else {
                  _toWallet = null;
                }
              });
    },
  );

  Widget _buildToWalletSection(String userId) => _WalletSection(
    labelKey: 'field_to_wallet',
    userId: userId,
    selected: _toWallet,
    onSelect: (w) => setState(() => _toWallet = w),
    openSheet: _selectToWallet,
    ref: ref,
  );

  Future<void> _selectDate() async {
    _unfocus();
    final date = await showMondayFirstDatePicker(
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
      final amountText = _amountController.text.trim().replaceAll('.', '');
      final amount = double.parse(amountText);
      final notes = _notesController.text.trim();

      // Amount always stored as positive; category.type determines sign in analytics & wallet triggers
      final finalAmount = amount.abs();

      // Validasi saldo untuk expense dan transfer
      if (!_isTransfer &&
          _selectedCategory != null &&
          _selectedCategory!.type == CategoryType.expense) {
        // Cek apakah saldo wallet cukup untuk pengeluaran
        double effectiveBalance = _selectedWallet!.balance;

        if (widget.initialTransaction != null &&
            widget.initialTransaction!.walletId == _selectedWallet!.id) {
          final categories =
              ref.read(categoriesAllProvider(user.id)).value ?? [];
          bool isOldTransactionExpense = false;

          // Try to determine based on category
          if (widget.initialTransaction!.categoryId == _selectedCategory!.id) {
            isOldTransactionExpense =
                _selectedCategory!.type == CategoryType.expense;
          } else {
            try {
              final oldCat = categories.firstWhere(
                (c) => c.id == widget.initialTransaction!.categoryId,
              );
              isOldTransactionExpense = oldCat.type == CategoryType.expense;
            } catch (_) {
              // Fallback: Check sign. If negative, likely expense.
              isOldTransactionExpense = widget.initialTransaction!.amount < 0;
            }
          }

          if (isOldTransactionExpense) {
            // Refund Expense: Add back the absolute amount
            effectiveBalance += widget.initialTransaction!.amount.abs();
          } else {
            // Refund Income: Remove the absolute amount
            effectiveBalance -= widget.initialTransaction!.amount.abs();
          }
        }

        final newBalance = effectiveBalance - finalAmount;

        // Toleransi floating point error
        if (newBalance < -0.01) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ref.tr(context, 'insufficient_balance_error')),
              ),
            );
          }
          return;
        }
      }

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
        // Validasi saldo wallet sumber untuk transfer
        final currentBalance = _selectedWallet!.balance;
        final newBalance = currentBalance - finalAmount;

        if (newBalance < 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ref.tr(context, 'insufficient_balance_for_transfer'),
                ),
              ),
            );
          }
          return;
        }
        final userId = ref.read(currentUserProvider).value!.id;
        final transferSvc = ref.read(transferServiceProvider);
        if (widget.initialTransfer != null) {
          // Update existing transfer
          await transferSvc.update(
            userId,
            widget.initialTransfer!.id,
            fromWalletId: _selectedWallet!.id,
            toWalletId: _toWallet!.id,
            amount: finalAmount,
            notes: notes.isEmpty ? null : notes,
            date: _selectedDate,
          );
        } else {
          await transferSvc.transferBetweenWallets(
            userId,
            CreateWalletTransferRequest(
              fromWalletId: _selectedWallet!.id,
              toWalletId: _toWallet!.id,
              amount: finalAmount,
              notes: notes.isEmpty ? null : notes,
              date: _selectedDate,
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
        }
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isTransfer
                  ? (widget.initialTransfer != null
                        ? ref.tr(context, 'transfer_updated_successfully')
                        : ref.tr(context, 'transfer_added_successfully'))
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

/// One row of the details card: icon, small label, value (or a muted "Pilih").
class _FieldRow extends ConsumerWidget {
  final Widget leading;
  final String label;
  final String? value;
  final String? detail;
  final VoidCallback onTap;

  const _FieldRow({required this.leading, required this.label, required this.value, this.detail, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = context.colors.muted;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 24, height: 24, child: Center(child: leading)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelMedium?.copyWith(color: muted)),
                  const SizedBox(height: 2),
                  Text(
                    value ?? ref.tr(context, 'field_choose'),
                    style: theme.textTheme.titleSmall?.copyWith(color: value == null ? muted : null),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (detail != null) ...[
              const SizedBox(width: 8),
              Text(detail!, style: theme.textTheme.bodySmall?.copyWith(color: muted, fontFeatures: tabularFigures)),
            ],
            const SizedBox(width: 4),
            Icon(PhRegular.caretRight, size: 16, color: muted),
          ],
        ),
      ),
    );
  }
}

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
    final cats = ref.watch(categoriesProvider(userId)).value ?? [];
    final all = ref.watch(categoriesAllProvider(userId)).value ?? cats;
    final c = selected;
    final parent = c?.parentId == null ? null : all.where((x) => x.id == c!.parentId).firstOrNull;
    return _FieldRow(
      leading: Icon(
        c == null ? PhRegular.squaresFour : CategoryIconHelper.iconFor(codePoint: c.iconCodePoint, name: c.name),
        color: Theme.of(context).colorScheme.onSurface,
      ),
      label: ref.tr(context, 'field_category'),
      value: c == null ? null : (parent != null ? '${parent.name} › ${c.name}' : c.name),
      onTap: () => openSheet(cats),
    );
  }
}

class _WalletSection extends ConsumerWidget {
  final String userId;
  final Wallet? selected;
  final void Function(Wallet?) onSelect;
  final void Function(List<Wallet>) openSheet;
  final WidgetRef ref;
  final String labelKey;
  const _WalletSection({
    required this.userId,
    required this.selected,
    required this.onSelect,
    required this.openSheet,
    required this.ref,
    this.labelKey = 'field_wallet',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref2) {
    final walletsAsync = ref.watch(activeWalletsProvider(userId));
    // Keep a hidden wallet pickable while it is the selected one (editing old data).
    final wallets = [
      if (selected != null && selected!.isHidden) selected!,
      ...?walletsAsync.value,
    ];
    final w = selected;
    return _FieldRow(
      leading: w == null
          ? Icon(PhRegular.wallet, color: Theme.of(context).colorScheme.onSurface)
          : WalletIconHelper.buildIcon(w.icon, size: 24),
      label: ref.tr(context, labelKey),
      value: w?.name,
      detail: w == null ? null : CurrencyFormatter.format(w.balance, w.currency),
      onTap: () => openSheet(wallets),
    );
  }
}
