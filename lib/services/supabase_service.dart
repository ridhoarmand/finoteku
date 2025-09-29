import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supabase service for managing the Supabase client instance
class SupabaseService {
  static SupabaseClient? _client;
  static bool _isInitialized = false;

  /// Check if Supabase is already initialized
  static bool get isInitialized => _isInitialized;

  /// Initialize Supabase client
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    if (_isInitialized) {
      return; // Already initialized, skip
    }

    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        debug: false, // Disabled to prevent blocking frames
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          logLevel: RealtimeLogLevel.info,
        ),
      );
      _client = Supabase.instance.client;
      _isInitialized = true;
    } catch (e) {
      // Graceful degradation if Supabase fails to initialize
      _isInitialized = false;
      rethrow;
    }
  }

  /// Get Supabase client instance
  static SupabaseClient get client {
    if (_client == null) {
      throw Exception(
        'Supabase not initialized. Call SupabaseService.initialize() first.',
      );
    }
    return _client!;
  }

  /// Check if user is authenticated
  static bool get isAuthenticated {
    return client.auth.currentUser != null;
  }

  /// Get current user
  static User? get currentUser {
    return client.auth.currentUser;
  }

  /// Get current user ID
  static String? get currentUserId {
    return client.auth.currentUser?.id;
  }
}

/// Provider for Supabase client
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return SupabaseService.client;
});

/// Provider for current user (with keepAlive for cold start optimization)
final currentUserProvider = StreamProvider.autoDispose<User?>((ref) {
  ref.keepAlive();
  final supabase = ref.watch(supabaseProvider);
  return supabase.auth.onAuthStateChange
      .map((data) => data.session?.user)
      .handleError((error) {
        // Silently handle auth errors to prevent blocking
        return null;
      });
});

/// Provider for authentication state (with keepAlive for cold start optimization)
final isAuthenticatedProvider = Provider.autoDispose<bool>((ref) {
  ref.keepAlive();
  final user = ref.watch(currentUserProvider);
  return user.when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, _) => false,
  );
});
