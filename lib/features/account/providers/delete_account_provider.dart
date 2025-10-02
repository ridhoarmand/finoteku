import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_data_summary.dart';
import '../services/delete_account_service.dart';

/// State untuk delete account process
class DeleteAccountState {
  final bool isLoading;
  final bool isLoadingSummary;
  final bool isDeleted;
  final String? error;
  final UserDataSummary? dataSummary;

  const DeleteAccountState({
    required this.isLoading,
    required this.isLoadingSummary,
    required this.isDeleted,
    this.error,
    this.dataSummary,
  });

  const DeleteAccountState.initial()
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

  @override
  String toString() {
    return 'DeleteAccountState(isLoading: $isLoading, isLoadingSummary: $isLoadingSummary, isDeleted: $isDeleted, error: $error, dataSummary: $dataSummary)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DeleteAccountState &&
        other.isLoading == isLoading &&
        other.isLoadingSummary == isLoadingSummary &&
        other.isDeleted == isDeleted &&
        other.error == error &&
        other.dataSummary == dataSummary;
  }

  @override
  int get hashCode {
    return isLoading.hashCode ^
        isLoadingSummary.hashCode ^
        isDeleted.hashCode ^
        error.hashCode ^
        dataSummary.hashCode;
  }
}

/// State notifier untuk delete account process
/// Menghandle UI logic dan state management untuk delete account flow
class DeleteAccountNotifier extends StateNotifier<DeleteAccountState> {
  final DeleteAccountService _deleteAccountService;

  DeleteAccountNotifier(this._deleteAccountService)
    : super(const DeleteAccountState.initial());

  /// Start delete account process dengan password verification
  ///
  /// Returns true jika berhasil, false jika gagal
  Future<bool> deleteAccount(String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 1. Verify password first
      final isPasswordValid = await _deleteAccountService.verifyUserPassword(
        password,
      );
      if (!isPasswordValid) {
        state = state.copyWith(
          isLoading: false,
          error: 'Incorrect password. Please try again.',
        );
        return false;
      }

      // 2. Delete account
      await _deleteAccountService.deleteAccount();

      state = state.copyWith(isLoading: false, isDeleted: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Load user data summary untuk ditampilkan sebelum delete
  Future<void> loadUserDataSummary() async {
    state = state.copyWith(isLoadingSummary: true);

    try {
      final summary = await _deleteAccountService.getUserDataSummary();
      state = state.copyWith(isLoadingSummary: false, dataSummary: summary);
    } catch (e) {
      state = state.copyWith(isLoadingSummary: false, error: e.toString());
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Reset state ke initial
  void reset() {
    state = const DeleteAccountState.initial();
  }
}

/// Provider untuk delete account state management
final deleteAccountProvider =
    StateNotifierProvider<DeleteAccountNotifier, DeleteAccountState>((ref) {
      final service = ref.watch(deleteAccountServiceProvider);
      return DeleteAccountNotifier(service);
    });
