import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase_service.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../services/transfer_service.dart';

class TransferDetailScreen extends ConsumerWidget {
  final String transferId;

  const TransferDetailScreen({super.key, required this.transferId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Transfer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to edit transfer form when implemented
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit transfer coming soon')),
              );
            },
          )
        ],
      ),
      body: user == null
          ? const Center(child: Text('Login diperlukan'))
          : FutureBuilder(
              future: ref.read(transferServiceProvider).getById(user.id, transferId),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final tr = snapshot.data;
                if (tr == null) {
                  return const Center(child: Text('Transfer tidak ditemukan'));
                }
                final walletsAsync = ref.watch(activeWalletsProvider(user.id));
                return walletsAsync.when(
                  data: (wallets) {
                    final walletMap = {for (final w in wallets) w.id: w};
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(child: Icon(Icons.swap_horiz)),
                              const SizedBox(width: 12),
                              Text(
                                'Transfer',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _kv(context, 'Tanggal', _fmt(tr.date)),
                          const SizedBox(height: 8),
                          _kv(context, 'Dari Wallet', walletMap[tr.fromWalletId]?.name ?? '-'),
                          const SizedBox(height: 8),
                          _kv(context, 'Ke Wallet', walletMap[tr.toWalletId]?.name ?? '-'),
                          const SizedBox(height: 8),
                          _kv(context, 'Jumlah', tr.amount.toStringAsFixed(0)),
                          const SizedBox(height: 8),
                          _kv(context, 'Biaya', tr.fee.toStringAsFixed(0)),
                          if ((tr.notes ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _kv(context, 'Catatan', tr.notes!),
                          ],
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Form edit transfer belum tersedia')),
                                );
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit Transfer'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Gagal memuat wallet: $e')),
                );
              },
            ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(k, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        const SizedBox(width: 12),
        Expanded(child: Text(v)),
      ],
    );
  }

  String _fmt(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
