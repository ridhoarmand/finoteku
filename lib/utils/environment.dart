import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration loader for Finoteku
/// Handles loading configuration from .env file
class Environment {
  /// Initialize environment variables from .env file
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: ".env");
      if (kDebugMode) {
        print('✅ Environment variables loaded from .env');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Could not load .env file: $e');
        print('📝 Using default values for development');
      }
    }
  }

  // Supabase Configuration
  static String get supabaseUrl {
    return dotenv.env['SUPABASE_URL'] ?? 'https://your-project-id.supabase.co';
  }

  static String get supabaseAnonKey {
    return dotenv.env['SUPABASE_ANON_KEY'] ?? 'your-anon-key-here';
  }

  static String get supabaseServiceRoleKey {
    return dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ??
        'your-service-role-key-here';
  }

  // App Configuration
  static String get appName {
    return dotenv.env['APP_NAME'] ?? 'Finoteku';
  }

  static String get appVersion {
    return dotenv.env['APP_VERSION'] ?? '1.0.0';
  }

  static String get environment {
    return dotenv.env['ENVIRONMENT'] ?? 'development';
  }

  static bool get isProduction {
    return environment.toLowerCase() == 'production';
  }

  static bool get isDevelopment {
    return environment.toLowerCase() == 'development';
  }

  static bool get isStaging {
    return environment.toLowerCase() == 'staging';
  }

  static bool get debugMode {
    final value = dotenv.env['DEBUG_MODE']?.toLowerCase();
    return value == 'true' || (value == null && isDevelopment);
  }

  // Storage Configuration
  static int get maxFileSize {
    final value = dotenv.env['MAX_FILE_SIZE'];
    return value != null
        ? int.tryParse(value) ?? 10485760
        : 10485760; // 10MB default
  }

  static String get allowedFileTypes {
    return dotenv.env['ALLOWED_FILE_TYPES'] ?? 'jpg,jpeg,png,pdf';
  }

  static List<String> get allowedFileTypesList =>
      allowedFileTypes.split(',').map((e) => e.trim()).toList();

  // Notification Configuration
  static bool get enableNotifications {
    final value = dotenv.env['ENABLE_NOTIFICATIONS']?.toLowerCase();
    return value == 'true' || value == null; // default true
  }

  static String get notificationChannelId {
    return dotenv.env['NOTIFICATION_CHANNEL_ID'] ?? 'finoteku_notifications';
  }

  // Analytics Configuration
  static bool get enableAnalytics {
    return dotenv.env['ENABLE_ANALYTICS']?.toLowerCase() == 'true';
  }

  static String get analyticsEndpoint {
    return dotenv.env['ANALYTICS_ENDPOINT'] ?? '';
  }

  // Security Configuration
  static bool get enableBiometrics {
    final value = dotenv.env['ENABLE_BIOMETRICS']?.toLowerCase();
    return value == 'true' || value == null; // default true
  }

  static int get sessionTimeout {
    final value = dotenv.env['SESSION_TIMEOUT'];
    return value != null
        ? int.tryParse(value) ?? 3600000
        : 3600000; // 1 hour default
  }

  static String get encryptionKeyAlias {
    return dotenv.env['ENCRYPTION_KEY_ALIAS'] ?? 'finoteku_key';
  }

  static int get maxRetryAttempts {
    final value = dotenv.env['MAX_RETRY_ATTEMPTS'];
    return value != null ? int.tryParse(value) ?? 3 : 3;
  }

  static String get logLevel {
    return dotenv.env['LOG_LEVEL'] ?? 'debug';
  }

  /// Validate that required environment variables are set
  static bool validateConfig() {
    final requiredVars = ['SUPABASE_URL', 'SUPABASE_ANON_KEY'];

    bool isValid = true;
    for (final varName in requiredVars) {
      final value = dotenv.env[varName];
      if (value == null || value.isEmpty || value.contains('your-')) {
        if (kDebugMode) {
          print('❌ Missing or invalid environment variable: $varName');
        }
        isValid = false;
      }
    }

    // Check URL format
    if (!supabaseUrl.startsWith('https://') ||
        !supabaseUrl.contains('.supabase.co')) {
      if (kDebugMode) {
        print('❌ SUPABASE_URL format is invalid');
      }
      isValid = false;
    }

    return isValid;
  }

  /// Print current configuration (for debugging)
  static void printConfig() {
    if (!debugMode) return;

    if (kDebugMode) {
      print('🔧 Environment Configuration:');
      print('   App Name: $appName');
      print('   App Version: $appVersion');
      print('   Environment: $environment');
      print('   Debug Mode: $debugMode');
      print(
        '   Supabase URL: ${supabaseUrl.replaceAll(RegExp(r'https://(.+)\.supabase\.co'), 'https://*****.supabase.co')}',
      );
      print(
        '   Supabase Anon Key: ${supabaseAnonKey.length > 10 ? '${supabaseAnonKey.substring(0, 10)}...' : 'Not configured'}',
      );
      print(
        '   Max File Size: ${(maxFileSize / 1024 / 1024).toStringAsFixed(1)}MB',
      );
      print('   Allowed File Types: $allowedFileTypes');
      print('   Enable Notifications: $enableNotifications');
      print('   Enable Analytics: $enableAnalytics');
      print('   Enable Biometrics: $enableBiometrics');
    }
  }
}
