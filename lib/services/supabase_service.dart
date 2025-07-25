import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supabase service for managing the Supabase client instance
class SupabaseService {
  static SupabaseClient? _client;

  /// Initialize Supabase client
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      debug: false, // Set to true for debugging
    );
    _client = Supabase.instance.client;
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

/// Provider for current user
final currentUserProvider = StreamProvider<User?>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.auth.onAuthStateChange.map((data) => data.session?.user);
});

/// Provider for authentication state
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user.when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, _) => false,
  );
});
