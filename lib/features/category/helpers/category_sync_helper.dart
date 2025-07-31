import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../models/category.dart';
import '../services/supabase_category_service.dart';
import '../../../services/local_database_service.dart';

/// Helper class untuk sync operations pada category
class CategorySyncHelper {
  final LocalDatabaseService _localDb;
  final SupabaseCategoryService _supabaseCategoryService;

  CategorySyncHelper(this._localDb, this._supabaseCategoryService);

  /// Get sync statistics for debugging
  Future<Map<String, dynamic>> getSyncStatistics(String userId) async {
    try {
      final unsyncedCategories = await _localDb.getUnsyncedCategories(userId);
      final allCategories = await _localDb.getCategories(userId);
      
      final stats = {
        'totalCategories': allCategories.length,
        'unsyncedCount': unsyncedCategories.length,
        'syncedCount': allCategories.length - unsyncedCategories.length,
        'syncPercentage': allCategories.isEmpty ? 100.0 : 
          ((allCategories.length - unsyncedCategories.length) / allCategories.length * 100),
        'unsyncedCategories': unsyncedCategories.map((cat) => {
          'id': cat.id,
          'name': cat.name,
          'type': cat.type.name,
          'createdAt': cat.createdAt.toIso8601String(),
          'updatedAt': cat.updatedAt.toIso8601String(),
        }).toList(),
      };
      
      if (kDebugMode) {
        print('📊 Sync Statistics for user $userId:');
        print('   Total Categories: ${stats['totalCategories']}');
        print('   Synced: ${stats['syncedCount']}');
        print('   Unsynced: ${stats['unsyncedCount']}');
        print('   Sync Rate: ${(stats['syncPercentage'] as double).toStringAsFixed(1)}%');
      }
      
      return stats;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting sync statistics: $e');
      }
      return {'error': e.toString()};
    }
  }

  /// Smart sync with adaptive scheduling based on failure history
  Future<void> smartSyncCategory(Category category) async {
    // Check how long this category has been waiting to sync
    final waitingTime = DateTime.now().difference(category.updatedAt);
    
    if (kDebugMode) {
      print('🧠 Smart sync for ${category.name} (waiting for ${waitingTime.inMinutes} minutes)');
    }
    
    // Use different strategies based on waiting time
    if (waitingTime.inMinutes < 5) {
      // Recent change, try immediate sync
      await trySyncCategory(category);
    } else if (waitingTime.inMinutes < 30) {
      // Been waiting for a while, try with longer timeout
      await trySyncCategoryWithTimeout(category, Duration(seconds: 10));
    } else {
      // Been waiting too long, force sync with extended retry
      await forceSyncCategoryWithExtendedRetry(category);
    }
  }

  /// Sync category with custom timeout
  Future<void> trySyncCategoryWithTimeout(Category category, Duration timeout) async {
    try {
      final syncedCategory = await _supabaseCategoryService.syncCategory(category)
          .timeout(timeout);
      
      final updatedCategory = syncedCategory.copyWith(needsSync: false);
      await _localDb.saveCategory(updatedCategory);
      
      if (kDebugMode) {
        print('✅ Category synced with timeout: ${category.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Timeout sync failed for ${category.name}: $e');
      }
    }
  }

  /// Force sync with extended retry for stubborn categories
  Future<void> forceSyncCategoryWithExtendedRetry(Category category) async {
    const maxRetries = 5;
    const baseDelay = Duration(seconds: 5);
    
    if (kDebugMode) {
      print('🔧 Force sync with extended retry for: ${category.name}');
    }
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Try to fetch fresh data from server first
        final serverCategory = await _supabaseCategoryService.getCategory(category.id, category.userId);
        
        if (serverCategory != null) {
          // Category exists on server, merge and mark as synced
          await _localDb.saveCategory(serverCategory.copyWith(needsSync: false));
          if (kDebugMode) {
            print('✅ Force sync successful - found on server: ${category.name}');
          }
          return;
        } else {
          // Category doesn't exist on server, push our version
          final syncedCategory = await _supabaseCategoryService.syncCategory(category);
          await _localDb.saveCategory(syncedCategory.copyWith(needsSync: false));
          if (kDebugMode) {
            print('✅ Force sync successful - pushed to server: ${category.name}');
          }
          return;
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Force sync attempt $attempt failed: $e');
        }
        
        if (attempt == maxRetries) {
          if (kDebugMode) {
            print('💀 Force sync completely failed for: ${category.name}');
          }
          return;
        }
        
        // Exponential backoff with jitter
        final delay = Duration(milliseconds: 
          baseDelay.inMilliseconds * (1 << (attempt - 1)) + 
          (DateTime.now().millisecondsSinceEpoch % 1000));
        await Future.delayed(delay);
      }
    }
  }
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

  /// Try sync single category to server with retry logic
  Future<void> trySyncCategory(Category category) async {
    const maxRetries = 3;
    const baseDelay = Duration(seconds: 2);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        if (kDebugMode) {
          print('🔄 Starting sync for category: ${category.name} (ID: ${category.id}) - Attempt $attempt/$maxRetries');
        }
        
        // Coba sync ke Supabase
        final syncedCategory = await _supabaseCategoryService.syncCategory(category);
        
        // Update local dengan data dari server dan tandai sudah sync
        final updatedCategory = syncedCategory.copyWith(needsSync: false);
        await _localDb.saveCategory(updatedCategory);
        
        if (kDebugMode) {
          print('✅ Category synced successfully: ${category.name} on attempt $attempt');
          print('📝 Category saved to local DB with needsSync=false');
          
          // Verify the save by reading it back
          final verifyCategory = await _localDb.getCategory(category.id, category.userId);
          print('🔍 Verification - Category in local DB: ${verifyCategory?.name}, needsSync: ${verifyCategory?.needsSync}');
        }
        
        // Success! Exit retry loop
        return;
      } catch (e) {
        if (kDebugMode) {
          print('❌ Sync category error on attempt $attempt: $e');
        }
        
        // If this was the last attempt, give up
        if (attempt == maxRetries) {
          if (kDebugMode) {
            print('📝 All retry attempts failed. Category will remain with needsSync=true until next sync attempt');
          }
          // Don't throw error, let it remain local with needsSync = true
          return;
        }
        
        // Wait before retrying with exponential backoff
        final delay = Duration(milliseconds: baseDelay.inMilliseconds * (1 << (attempt - 1)));
        if (kDebugMode) {
          print('⏳ Waiting ${delay.inSeconds}s before retry attempt ${attempt + 1}');
        }
        await Future.delayed(delay);
      }
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
      if (kDebugMode) {
        print('🔄 Fetching categories from server for user: $userId');
      }
      
      // Ambil data category dari server dan merge dengan local
      final serverCategories = await _supabaseCategoryService.getCategories(userId);
      
      if (kDebugMode) {
        print('📥 Got ${serverCategories.length} categories from server');
        for (final cat in serverCategories) {
          print('   - ${cat.name} (${cat.type.name})');
        }
      }

      for (final serverCategory in serverCategories) {
        final localCategory = await _localDb.getCategory(serverCategory.id, userId);

        if (localCategory == null) {
          // Category baru dari server, simpan ke local
          if (kDebugMode) {
            print('📝 Saving new category from server: ${serverCategory.name}');
          }
          await _localDb.saveCategory(serverCategory);
        } else if (serverCategory.updatedAt.isAfter(localCategory.updatedAt)) {
          // Server lebih baru, update local
          if (kDebugMode) {
            print('📝 Updating category from server: ${serverCategory.name}');
          }
          await _localDb.saveCategory(serverCategory);
        }
      }
      
      if (kDebugMode) {
        // Verify all categories are in local DB
        final allLocalCategories = await _localDb.getCategories(userId);
        print('🔍 Verification - Total categories in local DB: ${allLocalCategories.length}');
        for (final cat in allLocalCategories) {
          print('   - ${cat.name} (${cat.type.name}) needsSync: ${cat.needsSync}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Fetch categories from server error: $e');
      }
    }
  }
}
