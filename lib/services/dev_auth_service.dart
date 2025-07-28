import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/services/auth_service.dart';

/// Development authentication service for testing
class DevAuthService {
  final AuthService _authService;

  DevAuthService(this._authService);

  /// Auto sign in with development credentials for testing
  Future<bool> autoSignInForDevelopment() async {
    try {
      // Check if already authenticated
      if (_authService.isAuthenticated) {
        print('🟢 Already authenticated: ${_authService.currentUser?.email}');
        return true;
      }

      print('🔄 Attempting auto sign-in for development...');
      
      // Try to sign in with development credentials
      const devEmail = 'dev@finoteku.com';
      const devPassword = 'dev123456';

      try {
        // First try to sign in
        final response = await _authService.signIn(
          email: devEmail,
          password: devPassword,
        );
        
        if (response.user != null) {
          print('✅ Dev sign-in successful: ${response.user!.email}');
          return true;
        }
      } catch (e) {
        print('⚠️ Sign-in failed, trying to create dev account: $e');
        
        // If sign-in fails, try to create the account
        try {
          final signUpResponse = await _authService.signUp(
            email: devEmail,
            password: devPassword,
            fullName: 'Development User',
          );
          
          if (signUpResponse.user != null) {
            print('✅ Dev account created and signed in: ${signUpResponse.user!.email}');
            return true;
          }
        } catch (signUpError) {
          print('❌ Failed to create dev account: $signUpError');
        }
      }

      return false;
    } catch (e) {
      print('❌ Auto sign-in error: $e');
      return false;
    }
  }

  /// Get or create development user ID
  String? getDevelopmentUserId() {
    final user = _authService.currentUser;
    if (user != null) {
      print('🔍 Current user ID: ${user.id}');
      return user.id;
    }
    return null;
  }

  /// Check authentication status with detailed logging
  void checkAuthStatus() {
    final user = _authService.currentUser;
    final session = _authService.currentSession;
    
    print('🔍 Authentication Status Check:');
    print('   User: ${user?.email ?? 'Not authenticated'}');
    print('   User ID: ${user?.id ?? 'None'}');
    print('   Session exists: ${session != null}');
    print('   Session expired: ${session?.isExpired ?? 'N/A'}');
    print('   Access token: ${session?.accessToken != null ? 'Present' : 'Missing'}');
  }
}

/// Provider for DevAuthService
final devAuthServiceProvider = Provider<DevAuthService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return DevAuthService(authService);
});
