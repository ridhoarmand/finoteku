import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../services/connectivity_service.dart';
import '../../../services/supabase_service.dart';
import 'wallet_providers.dart';

/// State untuk status sync
enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}

/// State data untuk sync
class WalletSyncState {
  final SyncStatus status;
  final String? message;
  final DateTime? lastSyncTime;
  final int unsyncedCount;

  const WalletSyncState({
    this.status = SyncStatus.idle,
    this.message,
    this.lastSyncTime,
    this.unsyncedCount = 0,
  });

  WalletSyncState copyWith({
    SyncStatus? status,
    String? message,
    DateTime? lastSyncTime,
    int? unsyncedCount,
  }) {
    return WalletSyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      unsyncedCount: unsyncedCount ?? this.unsyncedCount,
    );
  }
}

/// Provider untuk sync state
final walletSyncStateProvider = StateNotifierProvider<WalletSyncNotifier, WalletSyncState>((ref) {
  return WalletSyncNotifier(ref);
});

/// Notifier untuk mengelola sync state
class WalletSyncNotifier extends StateNotifier<WalletSyncState> {
  final Ref _ref;

  WalletSyncNotifier(this._ref) : super(const WalletSyncState()) {
    // Listen to connectivity changes and auto sync when online
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    _ref.listen(connectionStatusProvider, (previous, next) {
      next.when(
        data: (isConnected) {
          // If we just came online and have unsynced items, auto sync
          if (isConnected && previous?.value == false && state.unsyncedCount > 0) {
            final currentUser = _ref.read(currentUserProvider);
            currentUser.whenData((user) {
              if (user != null) {
                syncWalletData(user.id);
              }
            });
          }
        },
        loading: () {},
        error: (_, _) {},
      );
    });
  }

  /// Sync semua data wallet untuk user
  Future<void> syncWalletData(String userId) async {
    // Prevent multiple concurrent syncs
    if (state.status == SyncStatus.syncing) {
      if (kDebugMode) {
        print('⚠️ Sync already in progress, skipping');
      }
      return;
    }

    state = state.copyWith(status: SyncStatus.syncing);

    try {
      final walletService = _ref.read(walletServiceProvider);
      final isConnected = await _ref.read(connectionStatusProvider.future);

      if (!isConnected) {
        state = state.copyWith(
          status: SyncStatus.idle,
          message: 'Offline - will sync when online',
        );
        if (kDebugMode) {
          print('📵 Offline - sync deferred');
        }
        return;
      }

      if (kDebugMode) {
        print('🔄 Starting wallet sync for user: $userId');
      }

      // Sync unsynced wallets
      await walletService.syncUnsyncedWallets(userId);
      
      // Refresh wallets provider untuk update UI
      _ref.invalidate(walletsProvider(userId));

      state = state.copyWith(
        status: SyncStatus.success,
        lastSyncTime: DateTime.now(),
        message: 'Sync completed successfully',
        unsyncedCount: 0,
      );

      if (kDebugMode) {
        print('✅ Wallet sync completed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Wallet sync failed: $e');
      }
      
      state = state.copyWith(
        status: SyncStatus.error,
        message: 'Sync failed: ${e.toString()}',
      );
    }
  }

  /// Update unsynced count
  void updateUnsyncedCount(int count) {
    state = state.copyWith(unsyncedCount: count);
  }

  /// Reset state ke idle
  void resetState() {
    state = const WalletSyncState();
  }

  /// Check dan update unsynced count
  Future<void> checkUnsyncedCount(String userId) async {
    try {
      final wallets = await _ref.read(walletsProvider(userId).future);
      final unsyncedCount = wallets.where((w) => w.needsSync).length;
      
      state = state.copyWith(unsyncedCount: unsyncedCount);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking unsynced count: $e');
      }
    }
  }
}

/// Provider untuk auto sync - digunakan di splash screen
final autoSyncProvider = FutureProvider.family<bool, String>((ref, userId) async {
  final syncNotifier = ref.read(walletSyncStateProvider.notifier);
  
  try {
    // Check if user is authenticated
    final currentUser = await ref.read(currentUserProvider.future);
    if (currentUser == null) return false;

    // Check connection
    final isConnected = await ref.read(connectionStatusProvider.future);
    if (!isConnected) {
      if (kDebugMode) {
        print('⚠️ Auto sync skipped - no internet connection');
      }
      return false;
    }

    // Perform sync
    await syncNotifier.syncWalletData(userId);
    return true;
  } catch (e) {
    if (kDebugMode) {
      print('❌ Auto sync failed: $e');
    }
    return false;
  }
});

/// Provider untuk trigger sync saat dibutuhkan
final manualSyncProvider = FutureProvider.family<bool, String>((ref, userId) async {
  final syncNotifier = ref.read(walletSyncStateProvider.notifier);
  await syncNotifier.syncWalletData(userId);
  return true;
});
