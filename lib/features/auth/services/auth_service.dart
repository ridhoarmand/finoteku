import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../services/supabase_service.dart';
import 'initial_data_service.dart';

/// Authentication service for handling user auth operations
class AuthService {
  final SupabaseClient _supabase;
  final Ref _ref;

  AuthService(this._supabase, this._ref);

  /// Sign up with email and password + setup initial data
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'id.ridhoarmand.finoteku://auth/callback',
        data: {'full_name': fullName},
      );

      // If signup successful and user is confirmed, setup initial data
      if (response.user != null) {
        try {
          final initialDataService = _ref.read(initialDataServiceProvider);
          await initialDataService.setupInitialData(response.user!.id);
        } catch (e) {
          // Log error but don't fail signup
          debugPrint('⚠️ Failed to setup initial data: $e');
        }
      }

      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Unexpected error during sign up: $e');
    }
  }

  /// Sign in with email and password + perform full sync
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 Attempting sign in for: $email');
      }

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        debugPrint('✅ Sign in successful for: $email');
      }

      return response;
    } on AuthException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Auth error during sign in: ${e.message}');
      }
      throw AuthException(e.message);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Unexpected error during sign in: $e');
      }
      throw Exception('Unexpected error during sign in: $e');
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Unexpected error during sign out: $e');
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'id.ridhoarmand.finoteku://auth/callback',
      );
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Unexpected error during password reset: $e');
    }
  }

  /// Verify current password by attempting to sign in
  Future<bool> verifyPassword(String password) async {
    try {
      final user = currentUser;
      if (user == null || user.email == null) return false;

      final response = await _supabase.auth.signInWithPassword(
        email: user.email,
        password: password,
      );
      return response.user != null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Password verification failed: $e');
      }
      return false;
    }
  }

  /// Update user password
  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return response;
    } on AuthException catch (e) {
      if (e.message ==
          'New password should be different from the old password.') {
        throw const AuthException('password_error_same');
      }
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Unexpected error during password update: $e');
    }
  }

  /// Update user profile
  Future<UserResponse> updateProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            if (fullName != null) 'full_name': fullName,
            if (avatarUrl != null) 'avatar_url': avatarUrl,
          },
        ),
      );
      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Unexpected error during profile update: $e');
    }
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    try {
      // Note: This requires a server-side function to properly delete user
      // as Supabase doesn't allow direct user deletion from client
      await _supabase.rpc('delete_user_account_complete');
    } on PostgrestException catch (e) {
      throw Exception('Database error during account deletion: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error during account deletion: $e');
    }
  }

  /// Get current user session
  Session? get currentSession => _supabase.auth.currentSession;

  /// Get current user
  User? get currentUser => _supabase.auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Listen to auth state changes
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;
}

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return AuthService(supabase, ref);
});

/// Provider for current auth state
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.onAuthStateChange;
});

/// Provider for current session (synchronous)
final currentSessionProvider = Provider<Session?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (state) => state.session,
    loading: () => null,
    error: (_, stackTrace) => null,
  );
});

/// Provider for immediate auth check (synchronous)
final currentAuthProvider = Provider<bool>((ref) {
  // Listen to auth state changes instead of just reading current session
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (state) => state.session != null,
    loading: () {
      // During loading, check current session as fallback
      final supabase = ref.watch(supabaseProvider);
      return supabase.auth.currentSession != null;
    },
    error: (_, _) => false,
  );
});
