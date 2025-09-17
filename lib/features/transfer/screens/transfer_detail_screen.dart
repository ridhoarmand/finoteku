import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase_service.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../services/transfer_service.dart';
import '../../../core/localization/app_localizations.dart';

class TransferDetailScreen extends ConsumerWidget {
  final String transferId;

  const TransferDetailScreen({super.key, required this.transferId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr(context, 'transfer_details_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to edit transfer form when implemented
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ref.tr(context, 'edit_transfer_coming_soon'))),
              );
            },
          )
        ],
      ),
      body: user == null
          ? Center(child: Text(ref.tr(context, 'login_required_short')))
          : FutureBuilder(
              future: ref.read(transferServiceProvider).getById(user.id, transferId),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final tr = snapshot.data;
                if (tr == null) {
                  return Center(child: Text(ref.tr(context, 'transfer_not_found')));
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
                                ref.tr(context, 'transfer'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _kv(context, ref.tr(context, 'date_label'), _fmt(context, ref, tr.date)),
                          const SizedBox(height: 8),
                          _kv(context, ref.tr(context, 'from_wallet'), walletMap[tr.fromWalletId]?.name ?? '-'),
                          const SizedBox(height: 8),
                          _kv(context, ref.tr(context, 'to_wallet'), walletMap[tr.toWalletId]?.name ?? '-'),
                          const SizedBox(height: 8),
                          _kv(context, ref.tr(context, 'amount'), tr.amount.toStringAsFixed(0)),
                          const SizedBox(height: 8),
                          _kv(context, ref.tr(context, 'fee'), tr.fee.toStringAsFixed(0)),
                          if ((tr.notes ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _kv(context, ref.tr(context, 'notes'), tr.notes!),
                          ],
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(ref.tr(context, 'form_edit_transfer_not_available'))),
                                );
                              },
                              icon: const Icon(Icons.edit),
                              label: Text(ref.tr(context, 'edit_transfer')),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text(ref.tr(context, 'wallet_loading_error'))),
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

  String _fmt(BuildContext context, WidgetRef ref, DateTime d) {
    // Use localized month names from core localization
    final monthKey = [
      'month_january',
      'month_february',
      'month_march',
      'month_april',
      'month_may',
      'month_june',
      'month_july',
      'month_august',
      'month_september',
      'month_october',
      'month_november',
      'month_december',
    ][d.month - 1];
    final monthName = ref.tr(context, monthKey);
    return '${d.day} $monthName ${d.year}';
  }
}
