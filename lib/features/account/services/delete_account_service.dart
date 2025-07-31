import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';
import '../../../services/local_database_service.dart';

/// Service untuk menangani delete account
class DeleteAccountService {
  final SupabaseClient _supabase;
  final LocalDatabaseService _localDb;

  DeleteAccountService(this._supabase, this._localDb);

  /// Delete user account dan semua data terkait
  Future<void> deleteAccount() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      if (kDebugMode) {
        print('🗑️ Starting account deletion process for user: $userId');
      }

      // 1. Hapus data dari local database terlebih dahulu
      await _deleteLocalUserData(userId);

      // 2. Panggil function di Supabase untuk menghapus semua data user
      // Ini akan menghapus data dari database dan storage files
      await _supabase.rpc('delete_user_account_complete');

      // 3. Sign out user after successful deletion
      await _supabase.auth.signOut();

      if (kDebugMode) {
        print('✅ Account deletion completed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during account deletion: $e');
      }
      
      // Provide specific error messages
      if (e.toString().contains('User not authenticated')) {
        throw Exception('You must be logged in to delete your account');
      } else if (e.toString().contains('function does not exist')) {
        throw Exception('Account deletion feature is not properly configured. Please contact support.');
      } else {
        throw Exception('Failed to delete account: ${e.toString()}');
      }
    }
  }

  /// Hapus semua data user dari local database
  Future<void> _deleteLocalUserData(String userId) async {
    try {
      if (kDebugMode) {
        print('🧹 Cleaning up local user data...');
      }

      // Hapus data user dari local database
      // LocalDatabaseService menggunakan SharedPreferences, jadi kita hapus langsung
      await _localDb.clearAllData(userId);

      if (kDebugMode) {
        print('✅ Local user data cleaned up successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error cleaning up local data: $e');
      }
      // Continue with server deletion even if local cleanup fails
    }
  }

  /// Verify user identity sebelum delete (untuk keamanan)
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
  Future<UserDataSummary> getUserDataSummary() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Count data from local database
      final wallets = await _localDb.getWallets(userId);
      final categories = await _localDb.getCategories(userId);

      // For transactions, we don't have them in LocalDatabaseService yet
      // So we'll use 0 for now or implement it later
      final transactionsCount = 0;

      return UserDataSummary(
        walletsCount: wallets.length,
        categoriesCount: categories.length,
        transactionsCount: transactionsCount,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting user data summary: $e');
      }
      return UserDataSummary(
        walletsCount: 0,
        categoriesCount: 0,
        transactionsCount: 0,
      );
    }
  }
}

/// Model untuk summary data user
class UserDataSummary {
  final int walletsCount;
  final int categoriesCount;
  final int transactionsCount;

  UserDataSummary({
    required this.walletsCount,
    required this.categoriesCount,
    required this.transactionsCount,
  });

  bool get hasData => walletsCount > 0 || categoriesCount > 0 || transactionsCount > 0;
}

/// Provider untuk DeleteAccountService
final deleteAccountServiceProvider = Provider<DeleteAccountService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final localDb = ref.watch(localDatabaseServiceProvider);
  return DeleteAccountService(supabase, localDb);
});

/// State notifier untuk delete account process
class DeleteAccountNotifier extends StateNotifier<DeleteAccountState> {
  final DeleteAccountService _deleteAccountService;

  DeleteAccountNotifier(this._deleteAccountService) : super(DeleteAccountState.initial());

  /// Start delete account process
  Future<bool> deleteAccount(String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 1. Verify password first
      final isPasswordValid = await _deleteAccountService.verifyUserPassword(password);
      if (!isPasswordValid) {
        state = state.copyWith(
          isLoading: false,
          error: 'Incorrect password. Please try again.',
        );
        return false;
      }

      // 2. Delete account
      await _deleteAccountService.deleteAccount();

      state = state.copyWith(
        isLoading: false,
        isDeleted: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Get user data summary
  Future<void> loadUserDataSummary() async {
    state = state.copyWith(isLoadingSummary: true);

    try {
      final summary = await _deleteAccountService.getUserDataSummary();
      state = state.copyWith(
        isLoadingSummary: false,
        dataSummary: summary,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingSummary: false,
        error: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// State untuk delete account process
class DeleteAccountState {
  final bool isLoading;
  final bool isLoadingSummary;
  final bool isDeleted;
  final String? error;
  final UserDataSummary? dataSummary;

  DeleteAccountState({
    required this.isLoading,
    required this.isLoadingSummary,
    required this.isDeleted,
    this.error,
    this.dataSummary,
  });

  DeleteAccountState.initial()
      : isLoading = false,
        isLoadingSummary = false,
        isDeleted = false,
        error = null,
        dataSummary = null;

  DeleteAccountState copyWith({
    bool? isLoading,
    bool? isLoadingSummary,
    bool? isDeleted,
    String? error,
    UserDataSummary? dataSummary,
  }) {
    return DeleteAccountState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingSummary: isLoadingSummary ?? this.isLoadingSummary,
      isDeleted: isDeleted ?? this.isDeleted,
      error: error ?? this.error,
      dataSummary: dataSummary ?? this.dataSummary,
    );
  }
}

/// Provider untuk delete account state
final deleteAccountProvider = StateNotifierProvider<DeleteAccountNotifier, DeleteAccountState>((ref) {
  final service = ref.watch(deleteAccountServiceProvider);
  return DeleteAccountNotifier(service);
});
