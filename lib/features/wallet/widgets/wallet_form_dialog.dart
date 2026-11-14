import 'package:flutter/material.dart';
import 'package:finoteku/theme/app_theme.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/wallet.dart';
import '../../../utils/wallet_icon_helper.dart';
import '../../../utils/currency_formatter.dart';
import '../../../core/localization/app_localizations.dart';
import '../../transaction/widgets/amount_section.dart';

class WalletFormDialog extends ConsumerStatefulWidget {
  final String title;
  final UpdateWalletRequest? initialData;
  final Future<void> Function(dynamic request)
  onSave; // accepts CreateWalletRequest or UpdateWalletRequest

  const WalletFormDialog({
    super.key,
    required this.title,
    this.initialData,
    required this.onSave,
  });

  @override
  ConsumerState<WalletFormDialog> createState() => _WalletFormDialogState();
}

class _WalletFormDialogState extends ConsumerState<WalletFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _balanceFocus = FocusNode();
  String? _autoName; // name last filled in from a logo
  String _selectedCurrency = 'IDR';
  String? _selectedIcon;
  bool _isHidden = false;
  bool _isLoading = false;

  final List<String> _currencies = const [
    'IDR',
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'SGD',
    'MYR',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!.name ?? '';
      if (widget.initialData!.balance != null) {
        // Format balance with thousand separators
        _balanceController.text = CurrencyFormatter.formatForInput(
          widget.initialData!.balance!,
        );
      }
      _selectedCurrency = widget.initialData!.currency ?? 'IDR';
      _selectedIcon = widget.initialData!.icon;
      _isHidden = widget.initialData!.isHidden ?? false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _balanceFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // Logo first: picking one also names the wallet
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.rBlock),
                onTap: _pickIcon,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: WalletIconHelper.buildIcon(_selectedIcon, size: 64, color: context.colors.muted),
                ),
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: _pickIcon,
                icon: const Icon(PhRegular.pencilSimple, size: 16),
                label: Text(ref.tr(context, 'wallet_select_icon')),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: ref.tr(context, 'wallet_name_label')),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? ref.tr(context, 'wallet_name_required')
                  : null,
            ),
            const SizedBox(height: 24),
            AmountSection(
              controller: _balanceController,
              focusNode: _balanceFocus,
              onSubmitted: _unfocus,
              onTapOutside: _unfocus,
              labelKey: 'wallet_balance_label',
              prefix: _selectedCurrency == 'IDR' ? 'Rp' : _selectedCurrency,
              allowZero: true,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCurrency,
              decoration: InputDecoration(labelText: ref.tr(context, 'wallet_currency_label')),
              items: _currencies
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _selectedCurrency = value ?? 'IDR'),
            ),
          ],
        ),
      ),
      // Save stays reachable above the keyboard, same as the transaction form
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            textStyle: theme.textTheme.titleMedium,
          ),
          onPressed: _isLoading ? null : _handleSave,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(ref.tr(context, 'save')),
        ),
      ),
    );
  }

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  /// Logo sheet (search + bank / e-wallet chips). '' = back to the default icon.
  Future<void> _pickIcon() async {
    _unfocus();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8 + MediaQuery.viewInsetsOf(sheet).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ref.tr(context, 'wallet_select_icon_title'),
                        style: Theme.of(sheet).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheet, ''),
                      child: Text(ref.tr(context, 'wallet_use_default')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: WalletIconHelper.buildIconSelectionGrid(
                    selectedIcon: _selectedIcon,
                    onIconSelected: (path) => Navigator.pop(sheet, path),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedIcon = picked.isEmpty ? null : picked;
      // the name follows the logo until the user types one of their own
      final name = _nameController.text.trim();
      final logoName = picked == WalletIconHelper.cashIcon ? 'Tunai' : WalletIconHelper.logoFor(picked)?.name;
      if (logoName != null && (name.isEmpty || name == _autoName)) {
        _nameController.text = _autoName = logoName;
      }
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final balance = CurrencyFormatter.parse(_balanceController.text) ?? 0;
      if (widget.initialData != null) {
        final request = UpdateWalletRequest(
          name: _nameController.text.trim(),
          // Only on a real edit: the shown value may be stale, and writing it back
          // would erase transactions recorded meanwhile (e.g. by the bot).
          balance: balance != widget.initialData!.balance ? balance : null,
          currency: _selectedCurrency,
          icon: _selectedIcon,
          isHidden: _isHidden,
        );
        await widget.onSave(request);
      } else {
        final request = CreateWalletRequest(
          name: _nameController.text.trim(),
          initialBalance: balance,
          currency: _selectedCurrency,
          icon: _selectedIcon,
        );
        await widget.onSave(request);
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.initialData != null
                  ? ref.tr(context, 'wallet_updated_success')
                  : ref.tr(context, 'wallet_created_success'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ref.tr(context, 'error_saving')}: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
