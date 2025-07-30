import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Provider untuk ConnectivityService
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

// Provider untuk connection status
final connectionStatusProvider = StreamProvider<bool>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return connectivityService.connectionStream;
});

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  late StreamController<bool> _connectionController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _wasConnected = false;

  ConnectivityService() {
    _connectionController = StreamController<bool>.broadcast();
    _initConnectivity();
  }

  /// Stream untuk monitor koneksi internet
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Check koneksi internet saat ini
  Future<bool> get isConnected async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return _hasInternetConnection(connectivityResult);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking connectivity: $e');
      }
      // Fallback: assume connected untuk development
      return true;
    }
  }

  /// Initialize connectivity monitoring
  void _initConnectivity() async {
    // Check initial connectivity with better error handling
    try {
      final initialResult = await _connectivity.checkConnectivity();
      final isInitiallyConnected = _hasInternetConnection(initialResult);
      _wasConnected = isInitiallyConnected;
      _connectionController.add(isInitiallyConnected);
      
      if (kDebugMode) {
        print('🌐 Initial connectivity: ${isInitiallyConnected ? "Connected" : "Disconnected"}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking initial connectivity: $e');
        print('🔄 Using fallback connectivity (assuming connected for development)');
      }
      // Fallback untuk development - assume connected
      _wasConnected = true;
      _connectionController.add(true);
    }

    // Listen to connectivity changes with error handling
    try {
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          try {
            final isConnected = _hasInternetConnection(results);
            
            // Only emit if connection status changed
            if (_wasConnected != isConnected) {
              _wasConnected = isConnected;
              _connectionController.add(isConnected);
              
              if (kDebugMode) {
                print('🌐 Connectivity changed: ${isConnected ? "Connected" : "Disconnected"}');
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('❌ Error processing connectivity change: $e');
            }
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('❌ Connectivity stream error: $error');
          }
          // Don't change connection status on stream error
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error setting up connectivity listener: $e');
        print('🔄 Connectivity monitoring disabled, using manual checks only');
      }
    }
  }

  /// Check if any connectivity result indicates internet connection
  bool _hasInternetConnection(List<ConnectivityResult> results) {
    return results.any((result) => 
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet ||
      result == ConnectivityResult.vpn
    );
  }

  /// Manually trigger connectivity check
  Future<void> refreshConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final isConnected = _hasInternetConnection(result);
      
      if (_wasConnected != isConnected) {
        _wasConnected = isConnected;
        _connectionController.add(isConnected);
        
        if (kDebugMode) {
          print('🔄 Manual connectivity refresh: ${isConnected ? "Connected" : "Disconnected"}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error refreshing connectivity: $e');
        print('🔄 Keeping current connection status');
      }
      // Don't change current status on error
    }
  }

  /// Get current connection type as string
  Future<String> getConnectionType() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.isEmpty) return 'None';
      
      final primaryConnection = results.first;
      switch (primaryConnection) {
        case ConnectivityResult.wifi:
          return 'WiFi';
        case ConnectivityResult.mobile:
          return 'Mobile Data';
        case ConnectivityResult.ethernet:
          return 'Ethernet';
        case ConnectivityResult.vpn:
          return 'VPN';
        case ConnectivityResult.bluetooth:
          return 'Bluetooth';
        case ConnectivityResult.other:
          return 'Other';
        case ConnectivityResult.none:
          return 'None';
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting connection type: $e');
      }
      return 'Unknown';
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionController.close();
  }
}
