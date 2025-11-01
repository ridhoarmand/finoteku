import 'package:flutter_riverpod/flutter_riverpod.dart';

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
