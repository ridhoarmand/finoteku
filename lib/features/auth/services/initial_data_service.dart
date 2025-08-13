import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../wallet/services/wallet_service.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../../category/services/category_service.dart';
import '../../../models/wallet.dart';

/// Service untuk mengelola initial data setup dan full sync
class InitialDataService {
  final WalletService _walletService;
  final CategoryService _categoryService;

  InitialDataService(
    this._walletService,
    this._categoryService,
  );

  /// Setup initial data untuk new user (dipanggil saat register)
  Future<void> setupInitialData(String userId) async {
    try {
      if (kDebugMode) {
        print('🚀 Setting up initial data for new user: $userId');
      }

      // Create default wallet
      await _createDefaultWallet(userId);

      // Create default categories
      await _createDefaultCategories(userId);

      if (kDebugMode) {
        print('✅ Initial data setup completed for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error setting up initial data: $e');
      }
      throw Exception('Failed to setup initial data: $e');
    }
  }


  // _syncFromServerToLocal removed (online-only)


  /// Create default wallet untuk new user
  Future<void> _createDefaultWallet(String userId) async {
    try {
      if (kDebugMode) {
        print('🏦 Creating default wallet for new user...');
      }

      // Check if user already has wallets (prevent duplicates)
      final existingWallets = await _walletService.getWallets(userId);
      if (existingWallets.isNotEmpty) {
        if (kDebugMode) {
          print('✅ User already has wallets, skipping default creation');
        }
        return;
      }

      // Create default Cash wallet
      await _walletService.createWallet(
        userId,
        CreateWalletRequest(
          name: 'Cash',
          initialBalance: 0.0,
          currency: 'IDR',
          icon: 'cash',
        ),
      );

      if (kDebugMode) {
        print('✅ Default wallet created successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating default wallet: $e');
      }
      throw Exception('Failed to create default wallet: $e');
    }
  }

  /// Create default categories untuk new user
  Future<void> _createDefaultCategories(String userId) async {
    try {
      if (kDebugMode) {
        print('📂 Creating default categories for new user...');
      }

      // Check if user already has categories (prevent duplicates)
      final existingCategories = await _categoryService.getCategories(userId);
      if (existingCategories.isNotEmpty) {
        if (kDebugMode) {
          print('✅ User already has categories, skipping default creation');
        }
        return;
      }

  // Default categories import removed (template/import deprecated)

      if (kDebugMode) {
        print('✅ Default categories created successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating default categories: $e');
      }
      throw Exception('Failed to create default categories: $e');
    }
  }

  /// Cleanup dan reset semua data (untuk testing atau troubleshooting)
  Future<void> resetUserData(String userId) async {
    try {
      if (kDebugMode) {
        print('🧹 Resetting all data for user: $userId');
      }

      // Note: Implement cleanup methods in respective services
      // This is for emergency cases or testing

      // Clear local data
      // await _localDb.clearUserData(userId);

      // Recreate default data
      await setupInitialData(userId);

      if (kDebugMode) {
        print('✅ User data reset completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error resetting user data: $e');
      }
      throw Exception('Failed to reset user data: $e');
    }
  }
}

/// Provider untuk InitialDataService
final initialDataServiceProvider = Provider<InitialDataService>((ref) {
  final walletService = ref.watch(walletServiceProvider);
  final categoryService = ref.watch(categoryServiceProvider);
    return InitialDataService(walletService, categoryService);
});

/// Provider untuk setup initial data (new user)
final setupInitialDataProvider = FutureProvider.family<bool, String>((
  ref,
  userId,
) async {
  final service = ref.read(initialDataServiceProvider);
  try {
    await service.setupInitialData(userId);
    return true;
  } catch (e) {
    if (kDebugMode) {
      print('Setup initial data failed: $e');
    }
    return false;
  }
});

// fullSyncProvider removed (online-only mode)
