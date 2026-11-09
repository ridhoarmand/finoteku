import 'package:flutter/foundation.dart';

/// Environment configuration loader for Finoteku
/// Handles loading configuration from compile-time variables
class Environment {
  /// Initialize environment variables (no-op since using compile-time definitions)
  static Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('✅ Compile-time environment variables loaded');
    }
  }

  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project-id.supabase.co',
  );

  // new publishable key (sb_publishable_...), or the legacy anon key from older .env files
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'your-anon-key-here'),
  );

  // Bots: defaults are the official Finoteku bots; self-hosters set their own in .env
  static const String waBotNumber = String.fromEnvironment('WA_BOT_NUMBER', defaultValue: '6285156897928');
  static const String telegramBotUsername = String.fromEnvironment('TELEGRAM_BOT_USERNAME', defaultValue: 'FinotekuBot');

  /// Validate that required environment variables are set
  static bool validateConfig() {
    bool isValid = true;

    if (supabaseUrl == 'https://your-project-id.supabase.co' || supabaseUrl.isEmpty) {
      if (kDebugMode) {
        debugPrint('❌ Missing or invalid environment variable: SUPABASE_URL');
      }
      isValid = false;
    }

    if (supabaseAnonKey == 'your-anon-key-here' || supabaseAnonKey.isEmpty) {
      if (kDebugMode) {
        debugPrint('❌ Missing or invalid environment variable: SUPABASE_ANON_KEY');
      }
      isValid = false;
    }

    // Check URL format
    if (!supabaseUrl.startsWith('https://') ||
        !supabaseUrl.contains('.supabase.co')) {
      if (kDebugMode) {
        debugPrint('❌ SUPABASE_URL format is invalid');
      }
      isValid = false;
    }

    return isValid;
  }
}
