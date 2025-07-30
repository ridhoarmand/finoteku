import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/category.dart';
import '../../../services/local_database_service.dart';
import 'supabase_category_service.dart';
import '../../../services/supabase_service.dart';

// Provider untuk CategoryService
final categoryServiceProvider = Provider<CategoryService>((ref) {
  final localDb = ref.watch(localDatabaseServiceProvider);
  final supabaseCategoryService = ref.watch(supabaseCategoryServiceProvider);
  return CategoryService(localDb, supabaseCategoryService);
});

// Provider untuk daftar categories berdasarkan user ID
final categoriesProvider = FutureProvider.family<List<Category>, String>((
  ref,
  userId,
) async {
  final categoryService = ref.watch(categoryServiceProvider);
  return categoryService.getCategories(userId);
});

// Provider untuk categories by type
final categoriesByTypeProvider =
    FutureProvider.family<List<Category>, ({String userId, CategoryType type})>(
      (ref, params) async {
        final categoryService = ref.watch(categoryServiceProvider);
        return categoryService.getCategoriesByType(params.userId, params.type);
      },
    );

// Provider untuk expense categories
final expenseCategoriesProvider = FutureProvider.family<List<Category>, String>(
  (ref, userId) async {
    final categoryService = ref.watch(categoryServiceProvider);
    return categoryService.getCategoriesByType(userId, CategoryType.expense);
  },
);

// Provider untuk income categories
final incomeCategoriesProvider = FutureProvider.family<List<Category>, String>((
  ref,
  userId,
) async {
  final categoryService = ref.watch(categoryServiceProvider);
  return categoryService.getCategoriesByType(userId, CategoryType.income);
});

// Provider untuk category by ID
final categoryProvider = FutureProvider.family<Category?, String>((
  ref,
  categoryId,
) async {
  final categoryService = ref.watch(categoryServiceProvider);
  return categoryService.getCategoryById(categoryId);
});

// Provider untuk active categories saja
final activeCategoriesProvider = FutureProvider.family<List<Category>, String>((
  ref,
  userId,
) async {
  final categoryService = ref.watch(categoryServiceProvider);
  final categories = await categoryService.getCategories(userId);
  return categories.where((category) => category.isActive).toList();
});

class CategoryService {
  final LocalDatabaseService _localDb;
  final SupabaseCategoryService _supabaseCategoryService;
  final _uuid = const Uuid();

  CategoryService(this._localDb, this._supabaseCategoryService);

  // Buat category baru
  Future<Category> createCategory(
    String userId,
    CreateCategoryRequest request,
  ) async {
    final category = Category(
      id: _uuid.v4(),
      userId: userId,
      name: request.name,
      type: request.type,
      parentId: request.parentId,
      iconCodePoint: request.iconCodePoint,
      color: request.color,
      isActive: true,
      needsSync: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Simpan ke local database
    await _localDb.saveCategory(category);

    // Coba sync ke server jika online
    await _trySyncCategory(category);

    return category;
  }

  // Update category
  Future<Category> updateCategory(
    String categoryId,
    String userId,
    UpdateCategoryRequest request,
  ) async {
    final existingCategory = await _localDb.getCategory(categoryId, userId);
    if (existingCategory == null) {
      throw Exception('Category not found');
    }

    if (existingCategory.userId != userId) {
      throw Exception('Unauthorized');
    }

    final updatedCategory = existingCategory.copyWith(
      name: request.name ?? existingCategory.name,
      type: request.type ?? existingCategory.type,
      parentId: request.parentId ?? existingCategory.parentId,
      iconCodePoint: request.iconCodePoint ?? existingCategory.iconCodePoint,
      color: request.color ?? existingCategory.color,
      isActive: request.isActive ?? existingCategory.isActive,
      needsSync: true,
      updatedAt: DateTime.now(),
    );

    await _localDb.saveCategory(updatedCategory);

    // Coba sync ke server jika online
    await _trySyncCategory(updatedCategory);

    return updatedCategory;
  }

  // Hapus category
  Future<void> deleteCategory(String categoryId, String userId) async {
    final category = await _localDb.getCategory(categoryId, userId);
    if (category == null) {
      throw Exception('Category not found');
    }

    if (category.userId != userId) {
      throw Exception('Unauthorized');
    }

    // Hapus dari local database (soft delete)
    await _localDb.deleteCategory(categoryId, userId);

    // Coba sync penghapusan ke server jika online
    await _trySyncCategoryDeletion(categoryId, userId);
  }

  // Ambil semua categories user
  Future<List<Category>> getCategories(String userId) async {
    final categories = await _localDb.getCategories(userId);

    // Jika belum ada category, buat default categories
    if (categories.isEmpty) {
      await _createDefaultCategories(userId);
      return _localDb.getCategories(userId);
    }

    return categories;
  }

  // Ambil categories by type
  Future<List<Category>> getCategoriesByType(
    String userId,
    CategoryType type,
  ) async {
    final categories = await getCategories(
      userId,
    ); // Ini akan create default jika belum ada
    return categories.where((category) => category.type == type).toList();
  }

  // Ambil category by ID
  Future<Category?> getCategoryById(String categoryId) async {
    // TODO: Implement proper getCategoryById without userId
    // Untuk saat ini, return null karena perlu userId
    return null;
  }

  // Sync semua categories ke server
  Future<void> syncCategories(String userId) async {
    try {
      final localCategories = await _localDb.getCategories(userId);
      final categoriesNeedingSync = localCategories
          .where((c) => c.needsSync)
          .toList();

      for (final category in categoriesNeedingSync) {
        await _trySyncCategory(category);
      }

      // Ambil data terbaru dari server
      await _fetchAndMergeFromServer(userId);
    } catch (e) {
      if (kDebugMode) {
        print('Sync categories error: $e');
      }
      // Jangan throw error, biarkan app tetap berfungsi offline
    }
  }

  // Private methods

  Future<void> _createDefaultCategories(String userId) async {
    final defaultExpenseCategories = [
      'Food & Dining',
      'Transportation',
      'Shopping',
      'Bills & Utilities',
      'Entertainment',
      'Health & Medical',
      'Education',
      'Others',
    ];

    final defaultIncomeCategories = [
      'Salary',
      'Freelance',
      'Investment',
      'Business',
      'Gift',
      'Others',
    ];

    // Create expense categories
    for (final name in defaultExpenseCategories) {
      final category = Category(
        id: _uuid.v4(),
        userId: userId,
        name: name,
        type: CategoryType.expense,
        isActive: true,
        needsSync: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _localDb.saveCategory(category);
      await _trySyncCategory(category);
    }

    // Create income categories
    for (final name in defaultIncomeCategories) {
      final category = Category(
        id: _uuid.v4(),
        userId: userId,
        name: name,
        type: CategoryType.income,
        isActive: true,
        needsSync: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _localDb.saveCategory(category);
      await _trySyncCategory(category);
    }
  }

  // Public method untuk force sync category
  Future<void> forceSyncCategory(String categoryId, String userId) async {
    final category = await _localDb.getCategory(categoryId, userId);
    if (category != null) {
      await _trySyncCategory(category);
    } else {
      throw Exception('Category not found: $categoryId');
    }
  }

  // Public method untuk sync semua unsynced categories
  Future<void> syncUnsyncedCategories(String userId) async {
    try {
      if (kDebugMode) {
        print('🔄 Starting auto sync for unsynced categories...');
      }

      final unsyncedCategories = await _localDb.getUnsyncedCategories(userId);
      if (unsyncedCategories.isEmpty) {
        if (kDebugMode) {
          print('✅ No categories need sync');
        }
        return;
      }

      if (kDebugMode) {
        print('📝 Found ${unsyncedCategories.length} categories to sync');
      }

      for (final category in unsyncedCategories) {
        await _trySyncCategory(category);
      }

      // Fetch and merge dari server
      await _fetchAndMergeFromServer(userId);

      if (kDebugMode) {
        print('✅ Auto sync completed for categories');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Auto sync failed for categories: $e');
      }
    }
  }

  Future<void> _trySyncCategory(Category category) async {
    try {
      if (kDebugMode) {
        print(
          '🔄 Attempting to sync category: ${category.name} (${category.id})',
        );
      }

      // Cek authentication terlebih dahulu
      if (!SupabaseService.isAuthenticated) {
        if (kDebugMode) {
          print('❌ User not authenticated, skipping sync');
        }
        return;
      }

      if (kDebugMode) {
        print('✅ User authenticated, proceeding with sync');
      }

      // Coba sync ke Supabase jika online dan authenticated
      await _supabaseCategoryService.syncCategory(category);

      if (kDebugMode) {
        print('✅ Category synced successfully to Supabase');
      }

      // Mark as synced jika berhasil
      final syncedCategory = category.copyWith(needsSync: false);
      await _localDb.saveCategory(syncedCategory);

      if (kDebugMode) {
        print('✅ Category marked as synced locally');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sync category error: $e');
        print(
          '📝 Category will remain with needsSync=true until next sync attempt',
        );
      }
      // Jangan throw error, biarkan tetap tersimpan local dengan needsSync = true
    }
  }

  Future<void> _trySyncCategoryDeletion(
    String categoryId,
    String userId,
  ) async {
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

  Future<void> _fetchAndMergeFromServer(String userId) async {
    try {
      // Ambil data category dari server dan merge dengan local
      final serverCategories = await _supabaseCategoryService.getCategories(
        userId,
      );

      for (final serverCategory in serverCategories) {
        final localCategory = await _localDb.getCategory(
          serverCategory.id,
          userId,
        );

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
