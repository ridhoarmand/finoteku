import 'package:flutter/foundation.dart';

/// Simple logger abstraction to centralize logging formatting & toggle.
class AppLogger {
  const AppLogger._();
  static void d(String message) {
    if (kDebugMode) {
      print('🐛 $message');
    }
  }

  static void i(String message) {
    if (kDebugMode) {
      print('ℹ️ $message');
    }
  }

  static void w(String message) {
    if (kDebugMode) {
      print('⚠️ $message');
    }
  }

  static void e(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      print('❌ $message');
      if (error != null) {
        print('   → $error');
      }
      if (stackTrace != null) {
        print(stackTrace);
      }
    }
  }
}
