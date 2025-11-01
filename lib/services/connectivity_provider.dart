import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connectivity_service.dart';

/// Provider untuk ConnectivityService singleton
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Provider untuk stream connection status
final connectionStatusProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.connectionStatus;
});

/// Provider untuk current connection state (synchronous)
final isOnlineProvider = Provider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.isOnline;
});

/// Notifier untuk manage connectivity state dengan retry logic
class ConnectivityNotifier extends Notifier<AsyncValue<bool>> {
  @override
  AsyncValue<bool> build() {
    // Initialize dengan loading state
    _checkConnectivity();
    return const AsyncValue.loading();
  }

  Future<void> _checkConnectivity() async {
    state = const AsyncValue.loading();

    try {
      final service = ref.read(connectivityServiceProvider);
      final isConnected = await service.checkConnectivity();
      state = AsyncValue.data(isConnected);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('❌ Connectivity check error: $error');
      }
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Retry connectivity check
  Future<void> retry() async {
    await _checkConnectivity();
  }

  /// Wait until online with retry mechanism
  Future<bool> waitUntilOnline({
    int maxRetries = 10,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    state = const AsyncValue.loading();

    try {
      final service = ref.read(connectivityServiceProvider);
      final isConnected = await service.waitUntilOnline(
        maxRetries: maxRetries,
        retryDelay: retryDelay,
      );

      state = AsyncValue.data(isConnected);
      return isConnected;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('❌ Wait until online error: $error');
      }
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }
}

/// Provider untuk ConnectivityNotifier
final connectivityNotifierProvider =
    NotifierProvider<ConnectivityNotifier, AsyncValue<bool>>(
      ConnectivityNotifier.new,
    );
