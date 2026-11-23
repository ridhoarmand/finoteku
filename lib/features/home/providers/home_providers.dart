import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/home_widget_service.dart';
import '../../transaction/providers/transaction_providers.dart';
import '../../wallet/providers/wallet_providers.dart';

/// Notifier untuk menyimpan ID wallet yang dipilih di home screen
class SelectedHomeWallet extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? walletId) => state = walletId;
  void clear() => state = null;
}

/// Provider untuk selected wallet di home screen
/// null = semua wallet
final selectedHomeWalletProvider =
    NotifierProvider<SelectedHomeWallet, String?>(SelectedHomeWallet.new);

/// Numbers for the Android home-screen widget; reloads after every transaction change.
final widgetSnapshotProvider = FutureProvider.autoDispose.family<WidgetSnapshot, String>((ref, userId) async {
  ref.watch(transactionRefreshTriggerProvider);
  final wallets = await ref.watch(walletsProvider(userId).future);
  final repo = ref.watch(transactionRepositoryProvider);
  final now = DateTime.now();
  final entries = [
    ...await repo.getLedgerEntries(userId, startDate: DateTime(now.year, now.month, now.day)),
    ...await repo.getLedgerEntries(userId, limit: 1), // newest entry, for "last recorded"
  ];
  return widgetSnapshot(entries, wallets, now);
});
