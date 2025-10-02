import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';
import '../models/user_data_summary.dart';

/// Service untuk menangani operasi delete account
/// Focused hanya pada business logic untuk penghapusan akun
class DeleteAccountService {
  final SupabaseClient _supabase;

  DeleteAccountService(this._supabase);

  /// Delete user account dan semua data terkait
  ///
  /// Memanggil stored procedure di Supabase yang akan:
  /// - Menghapus semua data user dari database
  /// - Menghapus file storage yang terkait
  /// - Sign out user
  Future<void> deleteAccount() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw const DeleteAccountException('User not authenticated');
    }

    if (kDebugMode) {
      print('🗑️ Starting account deletion process for user: $userId');
    }

    try {
      // Panggil function di Supabase untuk menghapus semua data user
      await _supabase.rpc('delete_user_account_complete');

      // Sign out user after successful deletion
      await _supabase.auth.signOut();

      if (kDebugMode) {
        print('✅ Account deletion completed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during account deletion: $e');
      }

      // Transform errors into domain-specific exceptions
      if (e.toString().contains('function does not exist')) {
        throw const DeleteAccountException(
          'Account deletion feature is not properly configured. Please contact support.',
        );
      } else {
        throw DeleteAccountException(
          'Failed to delete account: ${e.toString()}',
        );
      }
    }
  }

  /// Verify user identity dengan password sebelum delete (untuk keamanan)
  ///
  /// Returns true jika password benar, false jika salah
  Future<bool> verifyUserPassword(String password) async {
    try {
      final user = SupabaseService.currentUser;
      if (user?.email == null) {
        return false;
      }

      // Coba sign in ulang dengan password untuk verifikasi
      final response = await _supabase.auth.signInWithPassword(
        email: user!.email!,
        password: password,
      );

      return response.user != null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Password verification failed: $e');
      }
      return false;
    }
  }

  /// Get summary of user data yang akan dihapus
  ///
  /// Memanggil RPC function di Supabase untuk mendapatkan count data user
  Future<UserDataSummary> getUserDataSummary() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        throw const DeleteAccountException('User not authenticated');
      }

      if (kDebugMode) {
        print('📊 Fetching user data summary for user: $userId');
      }

      // Call RPC function untuk mendapatkan summary dari server
      final response = await _supabase.rpc('get_user_data_summary');

      if (kDebugMode) {
        print('📊 User data summary response: $response');
      }

      // Parse response as JSON
      if (response is Map<String, dynamic>) {
        return UserDataSummary.fromJson(response);
      } else {
        // Handle unexpected response format
        if (kDebugMode) {
          print(
            '⚠️ Unexpected response format from get_user_data_summary: $response',
          );
        }
        return UserDataSummary.empty();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting user data summary: $e');
      }

      // Transform specific errors
      if (e.toString().contains('function does not exist')) {
        throw const DeleteAccountException(
          'Data summary feature is not properly configured. Please contact support.',
        );
      }

      // For other errors, return empty summary instead of throwing
      return UserDataSummary.empty();
    }
  }
}

/// Exception khusus untuk operasi delete account
class DeleteAccountException implements Exception {
  final String message;

  const DeleteAccountException(this.message);

  @override
  String toString() => message;
}

/// Provider untuk DeleteAccountService
final deleteAccountServiceProvider = Provider<DeleteAccountService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return DeleteAccountService(supabase);
});
