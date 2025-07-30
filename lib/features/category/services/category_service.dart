import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:uuid/uuid.dart';
import '../../../models/category.dart';
import '../../../services/local_database_service.dart';
import 'supabase_category_service.dart';
import '../helpers/category_sync_helper.dart';

class CategoryService {
  final LocalDatabaseService _localDb;
  final SupabaseCategoryService _supabaseCategoryService;
  late final CategorySyncHelper _syncHelper;
  final _uuid = const Uuid();

  CategoryService(this._localDb, this._supabaseCategoryService) {
    _syncHelper = CategorySyncHelper(_localDb, _supabaseCategoryService);
  }

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
    await _syncHelper.trySyncCategory(category);

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
    await _syncHelper.trySyncCategory(updatedCategory);

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
    await _syncHelper.trySyncCategoryDeletion(categoryId, userId);
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

  // Ambil category by ID (memerlukan userId untuk security)
  Future<Category?> getCategoryById(String categoryId, {String? userId}) async {
    if (userId != null) {
      return await _localDb.getCategory(categoryId, userId);
    }
    
    // Jika tidak ada userId, tidak bisa mengambil category untuk security
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
        await _syncHelper.trySyncCategory(category);
      }

      // Ambil data terbaru dari server
      await _syncHelper.fetchAndMergeFromServer(userId);
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
      await _syncHelper.trySyncCategory(category);
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
      await _syncHelper.trySyncCategory(category);
    }
  }

  // Public method untuk force sync category
  Future<void> forceSyncCategory(String categoryId, String userId) async {
    final category = await _localDb.getCategory(categoryId, userId);
    if (category != null) {
      await _syncHelper.trySyncCategory(category);
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
        await _syncHelper.trySyncCategory(category);
      }

      // Fetch and merge dari server
      await _syncHelper.fetchAndMergeFromServer(userId);

      if (kDebugMode) {
        print('✅ Auto sync completed for categories');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Auto sync failed for categories: $e');
      }
    }
  }
}
