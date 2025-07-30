import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../models/category.dart';
import '../services/supabase_category_service.dart';
import '../../../services/local_database_service.dart';

/// Helper class untuk sync operations pada category
class CategorySyncHelper {
  final LocalDatabaseService _localDb;
  final SupabaseCategoryService _supabaseCategoryService;

  CategorySyncHelper(this._localDb, this._supabaseCategoryService);

  /// Sync unsynced categories to server
  Future<void> syncUnsyncedCategories(String userId) async {
    try {
      if (kDebugMode) {
        print('🔄 Starting sync unsynced categories for user: $userId');
      }

      // Ambil categories yang belum ter-sync
      final unsyncedCategories = await _localDb.getUnsyncedCategories(userId);
      
      if (unsyncedCategories.isEmpty) {
        if (kDebugMode) {
          print('✅ No unsynced categories found');
        }
        return;
      }

      if (kDebugMode) {
        print('📤 Found ${unsyncedCategories.length} unsynced categories');
      }

      int syncedCount = 0;
      for (final category in unsyncedCategories) {
        try {
          // Sync ke server
          final syncedCategory = await _supabaseCategoryService.syncCategory(category);
          
          // Update local dengan data dari server dan tandai sudah sync
          final updatedCategory = syncedCategory.copyWith(needsSync: false);
          await _localDb.saveCategory(updatedCategory);
          
          syncedCount++;
          if (kDebugMode) {
            print('✅ Synced category: ${category.name}');
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Failed to sync category ${category.name}: $e');
          }
          // Continue dengan category lainnya
        }
      }

      if (kDebugMode) {
        print('🎉 Sync completed: $syncedCount/${unsyncedCategories.length} categories synced');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during sync unsynced categories: $e');
      }
      throw Exception('Failed to sync categories: $e');
    }
  }

  /// Try sync single category to server
  Future<void> trySyncCategory(Category category) async {
    try {
      // Coba sync ke Supabase
      final syncedCategory = await _supabaseCategoryService.syncCategory(category);
      
      // Update local dengan data dari server dan tandai sudah sync
      final updatedCategory = syncedCategory.copyWith(needsSync: false);
      await _localDb.saveCategory(updatedCategory);
      
      if (kDebugMode) {
        print('✅ Category synced successfully: ${category.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Sync category error: $e');
        print('📝 Category will remain with needsSync=true until next sync attempt');
      }
      // Jangan throw error, biarkan tetap tersimpan local dengan needsSync = true
    }
  }

  /// Try sync category deletion to server
  Future<void> trySyncCategoryDeletion(String categoryId, String userId) async {
    try {
      // Coba sync penghapusan ke Supabase
      await _supabaseCategoryService.syncCategoryDeletion(categoryId, userId);
    } catch (e) {
      if (kDebugMode) {
        print('Sync category deletion error: $e');
      }
      // Jangan throw error
    }
  }

  /// Fetch and merge categories from server
  Future<void> fetchAndMergeFromServer(String userId) async {
    try {
      // Ambil data category dari server dan merge dengan local
      final serverCategories = await _supabaseCategoryService.getCategories(userId);

      for (final serverCategory in serverCategories) {
        final localCategory = await _localDb.getCategory(serverCategory.id, userId);

        if (localCategory == null) {
          // Category baru dari server, simpan ke local
          await _localDb.saveCategory(serverCategory);
        } else if (serverCategory.updatedAt.isAfter(localCategory.updatedAt)) {
          // Server lebih baru, update local
          await _localDb.saveCategory(serverCategory);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Fetch categories from server error: $e');
      }
    }
  }
}
