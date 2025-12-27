import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

/// Service untuk handle connectivity checking
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  bool _isOnline = false;
  bool get isOnline => _isOnline;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial connectivity
    await checkConnectivity();

    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      if (kDebugMode) {
        print('🌐 Connectivity changed: $results');
      }
      await checkConnectivity();
    });
  }

  /// Check if device has internet connectivity
  Future<bool> checkConnectivity() async {
    try {
      // Web: skip plugin + HTTP checks to avoid CORS/unsupported issues.
      if (kIsWeb) {
        _updateConnectionStatus(true);
        return true;
      }

      final connectivityResult = await _connectivity.checkConnectivity();

      // If no connectivity at all
      if (connectivityResult.contains(ConnectivityResult.none)) {
        _updateConnectionStatus(false);
        return false;
      }

      // Even if connected to WiFi/Mobile, verify actual internet access
      final hasInternet = await _checkActualInternetConnection();
      _updateConnectionStatus(hasInternet);
      return hasInternet;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking connectivity: $e');
      }
      _updateConnectionStatus(false);
      return false;
    }
  }

  /// Verify actual internet connection by pinging a reliable server
  Future<bool> _checkActualInternetConnection() async {
    try {
      // Try to reach Google DNS (very reliable) with short timeout
      final response = await http
          .get(Uri.parse('https://clients3.google.com/generate_204'))
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => http.Response('Timeout', 408),
          );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Internet connection check failed: $e');
      }
      return false;
    }
  }

  /// Wait until online with retry mechanism
  Future<bool> waitUntilOnline({
    int maxRetries = 10,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      final isConnected = await checkConnectivity();

      if (isConnected) {
        if (kDebugMode) {
          print('✅ Connected to internet!');
        }
        return true;
      }

      if (i < maxRetries - 1) {
        await Future.delayed(retryDelay);
      }
    }

    if (kDebugMode) {
      print('❌ Failed to connect after $maxRetries attempts');
    }
    return false;
  }

  /// Update connection status and notify listeners
  void _updateConnectionStatus(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      _connectionStatusController.add(isOnline);

      if (kDebugMode) {
        print(
          isOnline
              ? '✅ Internet connection available'
              : '❌ No internet connection',
        );
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _connectionStatusController.close();
  }
}
