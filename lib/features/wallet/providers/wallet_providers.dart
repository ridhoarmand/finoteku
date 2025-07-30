import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/wallet.dart';
import '../../../services/local_database_service.dart';
import '../services/wallet_service.dart';
import '../services/supabase_wallet_service.dart';

// Provider untuk WalletService
final walletServiceProvider = Provider<WalletService>((ref) {
  final localDb = ref.watch(localDatabaseServiceProvider);
  final supabaseWalletService = ref.watch(supabaseWalletServiceProvider);
  return WalletService(localDb, supabaseWalletService);
});

// Provider untuk daftar wallets berdasarkan user ID
final walletsProvider = FutureProvider.family<List<Wallet>, String>((ref, userId) async {
  final walletService = ref.watch(walletServiceProvider);
  return walletService.getWallets(userId);
});

// Provider untuk wallet by ID
final walletProvider = FutureProvider.family<Wallet?, ({String walletId, String userId})>((ref, params) async {
  final walletService = ref.watch(walletServiceProvider);
  return walletService.getWalletById(params.walletId, userId: params.userId);
});

// Provider untuk active wallets saja
final activeWalletsProvider = FutureProvider.family<List<Wallet>, String>((ref, userId) async {
  final walletService = ref.watch(walletServiceProvider);
  final wallets = await walletService.getWallets(userId);
  return wallets.where((wallet) => wallet.isActive).toList();
});

// Provider untuk total balance dari semua active wallets
final totalBalanceProvider = FutureProvider.family<double, String>((ref, userId) async {
  final activeWallets = await ref.watch(activeWalletsProvider(userId).future);
  double total = 0.0;
  for (final wallet in activeWallets) {
    total += wallet.balance;
  }
  return total;
});
