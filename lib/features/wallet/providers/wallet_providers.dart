import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/wallet.dart';
import '../services/wallet_service.dart';
import '../../../core/logging/logger.dart';
import '../../../core/state/refresh_token.dart';

// Alias repository: langsung gunakan WalletService (wrapper dihapus)
final walletRepositoryProvider = Provider<WalletService>(
  (ref) => ref.watch(walletServiceProvider),
);

// Unified refresh token for wallets
final walletRefreshTriggerProvider = refreshTokenProvider();

// Provider untuk daftar wallets berdasarkan user ID dengan smart sync
final walletsProvider = FutureProvider.family<List<Wallet>, String>((
  ref,
  userId,
) async {
  // Watch refresh trigger untuk auto-refresh saat ada perubahan
  ref.watch(walletRefreshTriggerProvider);

  final repo = ref.watch(walletRepositoryProvider);
  return await repo.getWallets(userId);
});

// Provider untuk wallet by ID
final walletProvider =
    FutureProvider.family<Wallet?, ({String walletId, String userId})>((
      ref,
      params,
    ) async {
      final repo = ref.watch(walletRepositoryProvider);
      return repo.getWalletById(params.walletId, userId: params.userId);
    });

// Provider untuk visible wallets (yang tidak hidden)
final activeWalletsProvider = FutureProvider.family<List<Wallet>, String>((
  ref,
  userId,
) async {
  // Watch refresh trigger untuk auto-refresh saat ada perubahan
  ref.watch(walletRefreshTriggerProvider);

  final repo = ref.watch(walletRepositoryProvider);
  final wallets = await repo.getWallets(userId);
  return wallets.where((wallet) => !wallet.isHidden).toList();
});

// Provider untuk hidden wallets saja
final hiddenWalletsProvider = FutureProvider.family<List<Wallet>, String>((
  ref,
  userId,
) async {
  // Watch refresh trigger untuk auto-refresh saat ada perubahan
  ref.watch(walletRefreshTriggerProvider);

  final repo = ref.watch(walletRepositoryProvider);
  final wallets = await repo.getWallets(userId);
  return wallets.where((wallet) => wallet.isHidden).toList();
});

// Helper function untuk refresh semua wallet providers
void refreshWalletProviders(WidgetRef ref) {
  // Increment refresh trigger untuk memaksa semua wallet providers refresh
  ref.read(walletRefreshTriggerProvider.notifier).bump();

  AppLogger.i('Wallet providers refreshed');
}
