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
  
  // Callback untuk notify UI when data changes
  void Function()? _onDataChanged;

  CategoryService(this._localDb, this._supabaseCategoryService) {
    _syncHelper = CategorySyncHelper(_localDb, _supabaseCategoryService);
  }
  
  // Set callback untuk notify UI changes
  void setDataChangeCallback(void Function()? callback) {
    _onDataChanged = callback;
  }
  
  // Notify UI tentang data changes
  void _notifyDataChanged() {
    if (_onDataChanged != null) {
      _onDataChanged!();
    }
  }

  // Buat category baru
  Future<Category> createCategory(
    String userId,
    CreateCategoryRequest request,
  ) async {
    final id = _uuid.v4();
    final newCategory = Category(
      id: id,
      name: request.name,
      type: request.type,
      userId: userId,
      iconCodePoint: request.iconCodePoint,
      color: request.color,
      parentId: request.parentId,
      needsSync: true, // Always sync - user pasti sudah login
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: true,
    );

    // Simpan ke local database
    await _localDb.saveCategory(newCategory);

    // Sync ke server
    await _syncHelper.trySyncCategory(newCategory);
    
    // Notify UI about data changes
    _notifyDataChanged();

    return newCategory;
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

    // Check if category type is changing
    final isTypeChanging = request.type != null && request.type != existingCategory.type;
    
    if (isTypeChanging) {
      // Check if category has transactions
      final hasTransactions = await _localDb.categoryHasTransactions(categoryId, userId);
      if (hasTransactions) {
        // Type change will flip all transaction amounts and recalculate wallet balances
        await _handleCategoryTypeChange(categoryId, userId, existingCategory.type, request.type!);
      }
    }

    final updatedCategory = existingCategory.copyWith(
      name: request.name ?? existingCategory.name,
      type: request.type ?? existingCategory.type,
      parentId: request.parentId ?? existingCategory.parentId,
      iconCodePoint: request.iconCodePoint ?? existingCategory.iconCodePoint,
      color: request.color ?? existingCategory.color,
      isActive: request.isActive ?? existingCategory.isActive,
      needsSync: true, // Always sync
      updatedAt: DateTime.now(),
    );

    await _localDb.saveCategory(updatedCategory);

    // Sync ke server
    await _syncHelper.trySyncCategory(updatedCategory);
    
    // Notify UI about data changes
    _notifyDataChanged();

    return updatedCategory;
  }

  // Handle category type change
  Future<void> _handleCategoryTypeChange(String categoryId, String userId, CategoryType oldType, CategoryType newType) async {
    if (oldType == newType) return;

    // Get all transactions with this category
    final transactions = await _localDb.getTransactions(userId, categoryId: categoryId);
    
    // Flip all transaction amounts
    for (final transaction in transactions) {
      final updatedTransaction = transaction.copyWith(
        amount: -transaction.amount,
        needsSync: true,
        updatedAt: DateTime.now(),
      );
      await _localDb.saveTransaction(updatedTransaction);
    }

    // Recalculate all wallet balances
    await _localDb.recalculateAllWalletBalances(userId);
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

    // Check if category has transactions
    final hasTransactions = await _localDb.categoryHasTransactions(categoryId, userId);
    if (hasTransactions) {
      throw Exception('Cannot delete category that has transactions. Please transfer transactions to another category first.');
    }

    // Hapus dari local database (soft delete)
    await _localDb.deleteCategory(categoryId, userId);

    // Sync ke server
    await _syncHelper.trySyncCategoryDeletion(categoryId, userId);
    
    // Notify UI about data changes
    _notifyDataChanged();
  }

  // Safe delete category with transaction transfer
  Future<void> safeDeleteCategory(String categoryId, String userId, {String? transferToCategoryId}) async {
    final category = await _localDb.getCategory(categoryId, userId);
    if (category == null) {
      throw Exception('Category not found');
    }

    if (category.userId != userId) {
      throw Exception('Unauthorized');
    }

    // Use the safe delete method from local database
    await _localDb.safeDeleteCategory(categoryId, userId, transferToCategoryId: transferToCategoryId);

    // Sync ke server
    await _syncHelper.trySyncCategoryDeletion(categoryId, userId);
  }

  // Check if category can be deleted
  Future<bool> canDeleteCategory(String categoryId, String userId) async {
    return !(await _localDb.categoryHasTransactions(categoryId, userId));
  }

  // Get transaction count for category
  Future<int> getCategoryTransactionCount(String categoryId, String userId) async {
    final transactions = await _localDb.getTransactions(userId, categoryId: categoryId);
    return transactions.length;
  }

  // Transfer transactions between categories
  Future<int> transferTransactionsToCategory(String fromCategoryId, String toCategoryId, String userId) async {
    // Validate both categories exist and belong to user
    final fromCategory = await _localDb.getCategory(fromCategoryId, userId);
    final toCategory = await _localDb.getCategory(toCategoryId, userId);
    
    if (fromCategory == null || toCategory == null) {
      throw Exception('Category not found');
    }

    if (fromCategory.userId != userId || toCategory.userId != userId) {
      throw Exception('Unauthorized');
    }

    return await _localDb.transferTransactionsToCategory(fromCategoryId, toCategoryId, userId);
  }

  // Ambil semua categories user
  Future<List<Category>> getCategories(String userId) async {
    try {
      final categories = await _localDb.getCategories(userId);
      
      // Jika belum ada category, buat default categories
      if (categories.isEmpty) {
        if (kDebugMode) {
          print('📂 No categories found for user $userId, creating default categories');
        }
        await _createDefaultCategories(userId);
        // Return hasil dari _createDefaultCategories langsung tanpa query ulang
        return await _localDb.getCategories(userId);
      }
      
      return categories.where((category) => category.isActive).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting categories for user $userId: $e');
      }
      // Return empty list on error to prevent crashes
      return [];
    }
  }

  // Ambil categories by type
  Future<List<Category>> getCategoriesByType(
    String userId,
    CategoryType type,
  ) async {
    try {
      // Langsung ambil semua categories dari database (jangan lewat getCategories)
      final categories = await _localDb.getCategories(userId);
      
      // Jika belum ada category, buat default categories
      if (categories.isEmpty) {
        if (kDebugMode) {
          print('📂 No categories found for user $userId, creating default categories');
        }
        await _createDefaultCategories(userId);
        // Ambil ulang setelah create default
        final newCategories = await _localDb.getCategories(userId);
        return newCategories
            .where((category) => category.type == type && category.isActive)
            .toList();
      }
      
      return categories
          .where((category) => category.type == type && category.isActive)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting categories by type for user $userId: $e');
      }
      return [];
    }
  }

  // Ambil category by ID (memerlukan userId untuk security)
  Future<Category?> getCategoryById(String categoryId, {String? userId}) async {
    if (userId != null) {
      return await _localDb.getCategory(categoryId, userId);
    }
    
    // Jika tidak ada userId, tidak bisa mengambil category untuk security
    return null;
  }

  // Sync semua categories ke server (simplified)
  Future<void> syncCategories(String userId) async {
    try {
      if (kDebugMode) {
        print('🔄 Starting category sync for user: $userId');
      }

      // Sync unsynced categories to server
      await syncUnsyncedCategories(userId);
      
      // Fetch and merge dari server
      await _syncHelper.fetchAndMergeFromServer(userId);

      if (kDebugMode) {
        print('✅ Category sync completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Category sync failed: $e');
      }
      // Jangan throw error, biarkan app tetap berfungsi offline
    }
  }

  // Private methods

  Future<void> _createDefaultCategories(String userId) async {
    try {
      if (kDebugMode) {
        print('📂 Creating default categories for user: $userId');
      }

      // Default expense categories
      final expenseCategories = [
        'Food & Dining', 'Transportation', 'Shopping', 'Entertainment',
        'Bills & Utilities', 'Healthcare', 'Education', 'Travel'
      ];

      // Default income categories
      final incomeCategories = [
        'Salary', 'Business', 'Investment', 'Gift', 'Other Income'
      ];

      // Collect all categories untuk batch save
      final categoriesToCreate = <Category>[];

      // Create expense categories (tapi jangan save dulu)
      for (final name in expenseCategories) {
        categoriesToCreate.add(Category(
          id: _uuid.v4(),
          userId: userId,
          name: name,
          type: CategoryType.expense,
          isActive: true,
          needsSync: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      // Create income categories (tapi jangan save dulu)
      for (final name in incomeCategories) {
        categoriesToCreate.add(Category(
          id: _uuid.v4(),
          userId: userId,
          name: name,
          type: CategoryType.income,
          isActive: true,
          needsSync: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      // Batch save semua categories sekaligus - lebih efisien
      for (final category in categoriesToCreate) {
        await _localDb.saveCategory(category);
      }

      // Try sync in background tapi jangan block creation
      _syncCategoriesInBackground(categoriesToCreate);

      if (kDebugMode) {
        print('✅ Default categories created successfully for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating default categories: $e');
      }
      rethrow;
    }
  }

  // Background sync untuk tidak block UI
  void _syncCategoriesInBackground(List<Category> categories) {
    // Fire and forget - jangan block creation process
    for (final category in categories) {
      _syncHelper.trySyncCategory(category).catchError((error) {
        if (kDebugMode) {
          print('⚠️ Background sync failed for category ${category.name}: $error');
        }
      });
    }
  }

  // Public method untuk force sync category
  Future<void> forceSyncCategory(String categoryId, String userId) async {
    final category = await _localDb.getCategory(categoryId, userId);
    if (category != null) {
      await _syncHelper.trySyncCategory(category);
      // Notify UI about data changes after force sync
      _notifyDataChanged();
    } else {
      throw Exception('Category not found: $categoryId');
    }
  }

  // Public method untuk sync semua unsynced categories (simplified)
  Future<void> syncUnsyncedCategories(String userId) async {
    try {
      final unsyncedCategories = await _localDb.getUnsyncedCategories(userId);
      if (unsyncedCategories.isEmpty) {
        return;
      }

      if (kDebugMode) {
        print('📝 Syncing ${unsyncedCategories.length} unsynced categories');
      }

      for (final category in unsyncedCategories) {
        await _syncHelper.trySyncCategory(category);
      }
      
      // Notify UI about data changes after sync
      _notifyDataChanged();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sync unsynced categories failed: $e');
      }
    }
  }
}
