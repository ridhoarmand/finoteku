import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/agent_training_model.dart';
import '../../services/agent_training_service.dart';
import '../../services/supabase_service.dart';
import '../category/providers/category_providers.dart';
import '../wallet/providers/wallet_providers.dart';

/// Screen for managing AI Training (Instruksi & Contoh Chat)
class AgentTrainingScreen extends ConsumerStatefulWidget {
  const AgentTrainingScreen({super.key});

  @override
  ConsumerState<AgentTrainingScreen> createState() => _AgentTrainingScreenState();
}

class _AgentTrainingScreenState extends ConsumerState<AgentTrainingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _instructionController = TextEditingController();
  bool _isSubmittingInstruction = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trainingAsync = ref.watch(agentTrainingListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instruksi & Contoh Chat'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.psychology), text: 'Instruksi AI'),
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Contoh Chat'),
          ],
        ),
      ),
      body: trainingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading data: $e')),
        data: (trainingList) {
          final instructions = trainingList.where((item) => item.isInstruction).toList();
          final examples = trainingList.where((item) => item.isFewShot).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildInstructionsTab(context, theme, instructions),
              _buildExamplesTab(context, theme, examples),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExampleDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Contoh Chat'),
      ),
    );
  }

  Widget _buildInstructionsTab(
    BuildContext context,
    ThemeData theme,
    List<AgentTraining> instructions,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Petunjuk Penggunaan',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tuliskan instruksi bebas untuk mengarahkan gaya kerja AI Finoteku. Contoh:\n'
                  '• "Setiap jajan kopi selalu masukkan ke kategori Minuman"\n'
                  '• "Jika nominal tidak disebutkan, tanyakan terlebih dahulu"',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _instructionController,
                decoration: const InputDecoration(
                  labelText: 'Tambah Instruksi Khusus Baru...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isSubmittingInstruction ? null : _saveInstruction,
              icon: _isSubmittingInstruction
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Daftar Instruksi Aktif (${instructions.length})',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (instructions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Belum ada instruksi khusus. Tambahkan di atas!',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...instructions.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                  title: Text(item.instructionText ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: item.isActive,
                        onChanged: (val) => _toggleActive(item.id, val),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteItem(item.id),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildExamplesTab(
    BuildContext context,
    ThemeData theme,
    List<AgentTraining> examples,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: Colors.blue.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Semakin banyak contoh chat yang Anda buat, AI akan semakin akurat mengenali format pesan Anda.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Daftar Contoh Chat (${examples.length})',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (examples.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Belum ada contoh chat. Tekan tombol "+" untuk menambah contoh!',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...examples.map((item) {
            final output = item.expectedOutput ?? {};
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '"${item.sampleInput ?? ''}"',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Switch(
                          value: item.isActive,
                          onChanged: (val) => _toggleActive(item.id, val),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () => _deleteItem(item.id),
                        ),
                      ],
                    ),
                    const Divider(),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (output['amount'] != null)
                          Chip(
                            avatar: const Icon(Icons.payments, size: 14),
                            label: Text('Rp ${output['amount']}'),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (output['category'] != null)
                          Chip(
                            avatar: const Icon(Icons.category, size: 14),
                            label: Text('${output['category']}'),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (output['wallet'] != null)
                          Chip(
                            avatar: const Icon(Icons.account_balance_wallet, size: 14),
                            label: Text('${output['wallet']}'),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (output['notes'] != null)
                          Chip(
                            avatar: const Icon(Icons.notes, size: 14),
                            label: Text('${output['notes']}'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 80), // Padding for FAB
      ],
    );
  }

  Future<void> _saveInstruction() async {
    final text = _instructionController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmittingInstruction = true);
    try {
      final service = ref.read(agentTrainingServiceProvider);
      await service.addSystemInstruction(text);
      _instructionController.clear();
      ref.invalidate(agentTrainingListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambah instruksi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingInstruction = false);
    }
  }

  Future<void> _toggleActive(String id, bool isActive) async {
    final service = ref.read(agentTrainingServiceProvider);
    await service.toggleActive(id, isActive);
    ref.invalidate(agentTrainingListProvider);
  }

  Future<void> _deleteItem(String id) async {
    final service = ref.read(agentTrainingServiceProvider);
    await service.deleteTrainingItem(id);
    ref.invalidate(agentTrainingListProvider);
  }

  void _showAddExampleDialog(BuildContext context) {
    final user = ref.read(currentUserProvider).value;
    final userId = user?.id ?? '';
    final categories = ref.read(categoriesProvider(userId)).value ?? [];
    final wallets = ref.read(activeWalletsProvider(userId)).value ?? [];

    final sampleInputController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    String transactionType = 'expense';
    String? selectedCategory = categories.isNotEmpty ? categories.first.name : null;
    String? selectedWallet = wallets.isNotEmpty ? wallets.first.name : null;
    String? selectedToWallet = wallets.length > 1 ? wallets[1].name : null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Tambah Contoh Chat AI'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tuliskan contoh pesan chat dan tentukan nilai field sistem yang diharapkan:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: sampleInputController,
                      decoration: const InputDecoration(
                        labelText: 'Pesan Contoh Chat',
                        hintText: 'Misal: "jajan batagor 5k cash"',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: transactionType,
                      decoration: const InputDecoration(
                        labelText: 'Jenis Transaksi',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'expense', child: Text('Pengeluaran')),
                        DropdownMenuItem(value: 'income', child: Text('Pemasukan')),
                        DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => transactionType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Nominal Rp',
                        hintText: 'Misal: 5000',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (transactionType != 'transfer') ...[
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Kategori Sistem',
                          border: OutlineInputBorder(),
                        ),
                        items: categories.map((cat) {
                          return DropdownMenuItem(
                            value: cat.name,
                            child: Text(cat.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() => selectedCategory = val);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: selectedWallet,
                      decoration: InputDecoration(
                        labelText: transactionType == 'transfer' ? 'Dari Dompet' : 'Dompet / Wallet',
                        border: const OutlineInputBorder(),
                      ),
                      items: wallets.map((w) {
                        return DropdownMenuItem(
                          value: w.name,
                          child: Text(w.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedWallet = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (transactionType == 'transfer') ...[
                      DropdownButtonFormField<String>(
                        initialValue: selectedToWallet,
                        decoration: const InputDecoration(
                          labelText: 'Ke Dompet',
                          border: OutlineInputBorder(),
                        ),
                        items: wallets.map((w) {
                          return DropdownMenuItem(
                            value: w.name,
                            child: Text(w.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() => selectedToWallet = val);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Catatan / Keterangan (Opsional)',
                        hintText: 'Misal: Batagor',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () async {
                    final input = sampleInputController.text.trim();
                    final amountText = amountController.text.trim();
                    final notes = notesController.text.trim();

                    if (input.isEmpty || amountText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pesan contoh dan nominal wajib diisi')),
                      );
                      return;
                    }

                    final amount = double.tryParse(amountText) ?? 0;
                    final expectedOutput = <String, dynamic>{
                      'type': transactionType,
                      'amount': amount,
                      if (transactionType != 'transfer' && selectedCategory != null)
                        'category': selectedCategory!,
                      if (selectedWallet != null) 'wallet': selectedWallet!,
                      if (transactionType == 'transfer' && selectedToWallet != null)
                        'toWallet': selectedToWallet!,
                      if (notes.isNotEmpty) 'notes': notes,
                    };

                    final service = ref.read(agentTrainingServiceProvider);
                    await service.addFewShotExample(
                      sampleInput: input,
                      expectedOutput: expectedOutput,
                    );

                    ref.invalidate(agentTrainingListProvider);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Simpan Contoh'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
