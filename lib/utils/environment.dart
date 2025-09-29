import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration loader for Finoteku
/// Handles loading configuration from .env file
class Environment {
  /// Initialize environment variables from .env file
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: ".env");
      debugPrint('✅ Environment variables loaded from .env');
    } catch (e) {
      debugPrint('⚠️ Could not load .env file: $e');
      debugPrint('📝 Using default values for development');
    }
  }

  // Supabase Configuration
  static String get supabaseUrl {
    return dotenv.env['SUPABASE_URL'] ?? 'https://your-project-id.supabase.co';
  }

  static String get supabaseAnonKey {
    return dotenv.env['SUPABASE_ANON_KEY'] ?? 'your-anon-key-here';
  }

  /// Validate that required environment variables are set
  static bool validateConfig() {
    final requiredVars = ['SUPABASE_URL', 'SUPABASE_ANON_KEY'];

    bool isValid = true;
    for (final varName in requiredVars) {
      final value = dotenv.env[varName];
      if (value == null || value.isEmpty || value.contains('your-')) {
        debugPrint('❌ Missing or invalid environment variable: $varName');
        isValid = false;
      }
    }

    // Check URL format
    if (!supabaseUrl.startsWith('https://') ||
        !supabaseUrl.contains('.supabase.co')) {
      debugPrint('❌ SUPABASE_URL format is invalid');
      isValid = false;
    }

    return isValid;
  }
}
