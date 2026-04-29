import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/wallet.dart';
import '../../../utils/wallet_icon_helper.dart';
import '../../../utils/currency_formatter.dart';
import '../../../core/localization/app_localizations.dart';

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: ref.tr(context, 'wallet_name_label'),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? ref.tr(context, 'wallet_name_required')
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _balanceController,
                decoration: InputDecoration(
                  labelText: ref.tr(context, 'wallet_balance_label'),
                  border: const OutlineInputBorder(),
                  prefixText: 'Rp ',
                  hintText: '0',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d\.]')),
                  _ThousandSeparatorFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return ref.tr(context, 'wallet_balance_required');
                  }
                  final parsed = CurrencyFormatter.parse(value);
                  if (parsed == null) {
                    return ref.tr(context, 'wallet_number_invalid');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedCurrency,
                decoration: InputDecoration(
                  labelText: ref.tr(context, 'wallet_currency_label'),
                  border: const OutlineInputBorder(),
                ),
                items: _currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedCurrency = value ?? 'IDR'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ref.tr(context, 'wallet_selected_icon'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: WalletIconHelper.buildIcon(_selectedIcon, size: 24),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _showIconSelectionDialog,
                    child: Text(ref.tr(context, 'wallet_select_icon')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(ref.tr(context, 'cancel')),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleSave,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(ref.tr(context, 'save')),
        ),
      ],
    );
  }

  void _showIconSelectionDialog() {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxDialogHeight = screenHeight * 0.7;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: maxDialogHeight,
            maxWidth: 500,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ref.tr(context, 'wallet_select_icon_title'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: WalletIconHelper.buildIconSelectionGrid(
                    selectedIcon: _selectedIcon,
                    onIconSelected: (iconPath) {
                      setState(() => _selectedIcon = iconPath);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedIcon = null);
                        Navigator.of(context).pop();
                      },
                      child: Text(ref.tr(context, 'wallet_use_default')),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(ref.tr(context, 'cancel')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final balance = CurrencyFormatter.parse(_balanceController.text) ?? 0;
      if (widget.initialData != null) {
        final request = UpdateWalletRequest(
          name: _nameController.text.trim(),
          balance: balance,
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
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

/// TextInputFormatter for adding thousand separators as user types
/// Preserves cursor position for better editing experience
class _ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Get cursor position from new value (where user wants cursor to be)
    final newCursorPos = newValue.selection.baseOffset;

    // Remove existing separators
    final cleanNew = newValue.text.replaceAll('.', '');

    // Parse to number
    final number = int.tryParse(cleanNew);
    if (number == null && cleanNew.isNotEmpty) {
      return oldValue;
    }

    if (number == null) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Format with thousand separators
    final formatted = _formatWithThousandSeparator(number);

    // Calculate how many separators were before cursor in new (unformatted) value
    final separatorsBeforeCursorInNew = newValue.text
        .substring(0, newCursorPos.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'[^.]'), '')
        .length;

    // Calculate digits before cursor (excluding separators)
    final digitsBeforeCursor = newCursorPos - separatorsBeforeCursorInNew;

    // Now count how many characters (including new separators) to reach that many digits
    int finalCursorPos = 0;
    int digitsSeen = 0;
    for (
      int i = 0;
      i < formatted.length && digitsSeen < digitsBeforeCursor;
      i++
    ) {
      finalCursorPos++;
      if (formatted[i] != '.') {
        digitsSeen++;
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: finalCursorPos.clamp(0, formatted.length),
      ),
    );
  }

  String _formatWithThousandSeparator(int number) {
    final text = number.toString();
    final buffer = StringBuffer();
    int count = 0;

    for (int i = text.length - 1; i >= 0; i--) {
      buffer.write(text[i]);
      count++;
      if (count == 3 && i > 0) {
        buffer.write('.');
        count = 0;
      }
    }

    return buffer.toString().split('').reversed.join();
  }
}
