import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../transaction/widgets/wallet_selector_sheet.dart';
import '../../transaction/widgets/category_selector_sheet.dart';
import '../../../models/wallet.dart';
import '../../../models/category.dart';
import '../../../services/supabase_service.dart';
import '../../category/providers/category_providers.dart';
import '../services/transfer_service.dart';
import '../models/transfer_models.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  Wallet? _from;
  Wallet? _to;
  Category? _feeCat; // expense optional
  DateTime _date = DateTime.now();
  bool _loading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _feeCtrl.dispose();
    _notesCtrl.dispose();
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

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer Saldo')),
      body: walletsAsync.when(
        data: (wallets) => categoriesAsync.when(
          data: (categories) => _buildForm(context, wallets, categories),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<Wallet> wallets, List<Category> categories) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(_from?.name ?? 'Pilih Wallet Sumber'),
              subtitle: const Text('Wallet yang akan dikurangi'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _openWalletSheet(wallets, isSource: true),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: Text(_to?.name ?? 'Pilih Wallet Tujuan'),
              subtitle: const Text('Wallet yang akan bertambah'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _openWalletSheet(wallets, isSource: false),
            ),
          ),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jumlah Transfer', style: Theme.of(context).textTheme.titleMedium),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: const InputDecoration(hintText: '0.00'),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      if (n == null || n <= 0) return 'Masukkan jumlah valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('Biaya Admin (opsional)', style: Theme.of(context).textTheme.titleMedium),
                  TextFormField(
                    controller: _feeCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: const InputDecoration(hintText: '0.00'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
      // No income/expense categories for transfer entries
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long),
              title: Text(_feeCat?.name ?? 'Kategori Biaya (opsional, Expense)'),
              subtitle: const Text('Biaya admin di wallet sumber'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _openCategorySheet(categories),
            ),
          ),
          const SizedBox(height: 6),
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Tanggal Transfer'),
              subtitle: Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _pickDate,
            ),
          ),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)'
                ),
                maxLines: 2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('Transfer'),
          ),
        ],
      ),
    );
  }

  void _openWalletSheet(List<Wallet> wallets, {required bool isSource}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => WalletSelectorSheet(
        wallets: wallets,
        onWalletSelected: (w) {
          setState(() {
            if (isSource) {
              _from = w;
            } else {
              _to = w;
            }
          });
          Navigator.pop(context);
        },
        rootContext: context,
      ),
    );
  }

  void _openCategorySheet(List<Category> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategorySelectorSheet(
        categories: categories,
        onCategorySelected: (c) {
          setState(() {
            _feeCat = c;
          });
          Navigator.pop(context);
        },
        rootContext: context,
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    if (_from == null || _to == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih wallet sumber & tujuan')));
      return;
    }
    if (_from!.id == _to!.id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallet sumber & tujuan tidak boleh sama')));
      return;
    }
  // No income/expense category required for transfer; only optional fee category

    final amount = double.parse(_amountCtrl.text.trim());
    final fee = _feeCtrl.text.trim().isEmpty ? 0.0 : double.parse(_feeCtrl.text.trim());
  if (fee > 0 && _feeCat != null && _feeCat!.type != CategoryType.expense) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kategori biaya harus Expense')));
      return;
    }

    setState(() => _loading = true);
    try {
      final service = ref.read(transferServiceProvider);
      await service.transferBetweenWallets(
        user.id,
        CreateWalletTransferRequest(
          fromWalletId: _from!.id,
          toWalletId: _to!.id,
          amount: amount.abs(),
          fee: fee.abs(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          date: _date,
          feeCategoryId: _feeCat?.id,
        ),
      );
      // Refresh wallets to reflect new balances
      refreshWalletProviders(ref);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer berhasil')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
