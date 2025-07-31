import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
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

    // Check if category has transactions - CRITICAL VALIDATION
    final hasTransactions = await _localDb.categoryHasTransactions(categoryId, userId);
    if (hasTransactions) {
      throw Exception('Cannot delete category that has transactions. Please transfer transactions to another category first.');
    }

    // Check if this is a parent category - also check children for transactions
    final childCategories = await _localDb.getCategories(userId);
    final children = childCategories.where((cat) => cat.parentId == categoryId);
    
    for (final child in children) {
      final childHasTransactions = await _localDb.categoryHasTransactions(child.id, userId);
      if (childHasTransactions) {
        throw Exception('Cannot delete parent category "${category.name}" because child category "${child.name}" has transactions. Please transfer transactions first.');
      }
    }

    // If parent category, delete all children first
    for (final child in children) {
      await _localDb.deleteCategory(child.id, userId);
      // Sync child deletion to server
      await _syncHelper.trySyncCategoryDeletion(child.id, userId);
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

  // Check if category can be deleted dengan validasi lengkap
  Future<bool> canDeleteCategory(String categoryId, String userId) async {
    // Check if category has transactions
    final hasTransactions = await _localDb.categoryHasTransactions(categoryId, userId);
    if (hasTransactions) {
      return false;
    }

    // If this is a parent category, check if any children have transactions
    final childCategories = await _localDb.getCategories(userId);
    final children = childCategories.where((cat) => cat.parentId == categoryId);
    
    for (final child in children) {
      final childHasTransactions = await _localDb.categoryHasTransactions(child.id, userId);
      if (childHasTransactions) {
        return false; // Cannot delete if any child has transactions
      }
    }

    return true; // Safe to delete
  }

  // Get detailed info about why category cannot be deleted
  Future<Map<String, dynamic>> getCategoryDeletionInfo(String categoryId, String userId) async {
    final result = {
      'canDelete': false,
      'reason': '',
      'transactionCount': 0,
      'childrenWithTransactions': <String>[],
    };

    // Check if category has transactions
    final transactionCount = await getCategoryTransactionCount(categoryId, userId);
    if (transactionCount > 0) {
      result['canDelete'] = false;
      result['reason'] = 'Category has $transactionCount transaction(s)';
      result['transactionCount'] = transactionCount;
      return result;
    }

    // If this is a parent category, check children
    final childCategories = await _localDb.getCategories(userId);
    final children = childCategories.where((cat) => cat.parentId == categoryId);
    final childrenWithTransactions = <String>[];
    
    for (final child in children) {
      final childTransactionCount = await getCategoryTransactionCount(child.id, userId);
      if (childTransactionCount > 0) {
        childrenWithTransactions.add('${child.name} ($childTransactionCount transactions)');
      }
    }

    if (childrenWithTransactions.isNotEmpty) {
      result['canDelete'] = false;
      result['reason'] = 'Child categories have transactions';
      result['childrenWithTransactions'] = childrenWithTransactions;
      return result;
    }

    result['canDelete'] = true;
    result['reason'] = 'Safe to delete';
    return result;
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

  // Check if user has ever had categories (untuk tracking first-time user)
  Future<bool> hasUserEverHadCategories(String userId) async {
    try {
      // Check active categories first
      final activeCategories = await _localDb.getCategories(userId);
      if (activeCategories.isNotEmpty) {
        return true;
      }
      
      // For checking deleted categories, we can use a simple flag approach
      // or check if there are any transaction records which would indicate previous categories
      final transactions = await _localDb.getTransactions(userId);
      return transactions.isNotEmpty; // If user has transactions, they had categories before
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking user category history: $e');
      }
      return false;
    }
  }

  // Import default categories (public method untuk UI)
  Future<void> importDefaultCategories(String userId) async {
    await _createDefaultCategories(userId);
    _notifyDataChanged();
  }

  // Check if user needs category template offer
  Future<bool> shouldOfferCategoryTemplate(String userId) async {
    final activeCategories = await _localDb.getCategories(userId);
    final hasEverHadCategories = await hasUserEverHadCategories(userId);
    
    // Offer template if user has no active categories but has had categories before
    return activeCategories.isEmpty && hasEverHadCategories;
  }
  // Ambil semua categories user
  Future<List<Category>> getCategories(String userId) async {
    try {
      final categories = await _localDb.getCategories(userId);
      
      // Jika belum ada category dan user belum pernah punya categories (first-time user)
      if (categories.isEmpty) {
        final hasEverHadCategories = await hasUserEverHadCategories(userId);
        
        if (!hasEverHadCategories) {
          // First-time user - auto create default categories
          if (kDebugMode) {
            print('📂 First-time user detected, creating default categories for user $userId');
          }
          await _createDefaultCategories(userId);
          return await _localDb.getCategories(userId);
        } else {
          // User had categories before but deleted them all - don't auto-create
          if (kDebugMode) {
            print('📂 User $userId has no active categories but had categories before - not auto-creating');
          }
          return [];
        }
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
      
      // Jika belum ada category dan user belum pernah punya categories (first-time user)
      if (categories.isEmpty) {
        final hasEverHadCategories = await hasUserEverHadCategories(userId);
        
        if (!hasEverHadCategories) {
          // First-time user - auto create default categories
          if (kDebugMode) {
            print('📂 First-time user detected, creating default categories for user $userId');
          }
          await _createDefaultCategories(userId);
          // Ambil ulang setelah create default
          final newCategories = await _localDb.getCategories(userId);
          return newCategories
              .where((category) => category.type == type && category.isActive)
              .toList();
        } else {
          // User had categories before but deleted them all - don't auto-create
          if (kDebugMode) {
            print('📂 User $userId has no active categories of type $type but had categories before - not auto-creating');
          }
          return [];
        }
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

      // Collect all categories untuk batch save
      final categoriesToCreate = <Category>[];
      final now = DateTime.now();

      // Define default expense categories with icons and colors
      final expenseCategories = [
        // Parent categories with 2-3 children each for variety
        {
          'name': 'Food & Dining',
          'icon': Icons.restaurant,
          'color': const Color(0xFFE53E3E), // Red
          'children': [
            {'name': 'Restaurants', 'icon': Icons.restaurant, 'color': const Color(0xFFFF6B6B)},
            {'name': 'Groceries', 'icon': Icons.shopping_cart, 'color': const Color(0xFFD63031)},
            {'name': 'Coffee & Snacks', 'icon': Icons.coffee, 'color': const Color(0xFFE17055)},
          ]
        },
        {
          'name': 'Transportation',
          'icon': Icons.directions_car,
          'color': const Color(0xFF3742FA), // Blue
          'children': [
            {'name': 'Fuel & Parking', 'icon': Icons.local_gas_station, 'color': const Color(0xFF70A1FF)},
            {'name': 'Public Transport', 'icon': Icons.directions_bus, 'color': const Color(0xFF5352ED)},
          ]
        },
        {
          'name': 'Shopping',
          'icon': Icons.shopping_bag,
          'color': const Color(0xFFFF9500), // Orange
          'children': [
            {'name': 'Clothing & Fashion', 'icon': Icons.checkroom, 'color': const Color(0xFFFFC312)},
            {'name': 'Electronics', 'icon': Icons.laptop, 'color': const Color(0xFFE17055)},
            {'name': 'Personal Care', 'icon': Icons.face, 'color': const Color(0xFFFFDA79)},
          ]
        },
        {
          'name': 'Entertainment',
          'icon': Icons.movie,
          'color': const Color(0xFF8E44AD), // Purple
          'children': [
            {'name': 'Movies & Cinema', 'icon': Icons.movie, 'color': const Color(0xFFA55EEA)},
            {'name': 'Games & Hobbies', 'icon': Icons.sports_esports, 'color': const Color(0xFF6C5CE7)},
          ]
        },
        {
          'name': 'Bills & Utilities',
          'icon': Icons.receipt,
          'color': const Color(0xFF636E72), // Grey
          'children': [
            {'name': 'Electricity & Water', 'icon': Icons.electrical_services, 'color': const Color(0xFFFFCC00)},
            {'name': 'Internet & Phone', 'icon': Icons.wifi, 'color': const Color(0xFF55A3FF)},
          ]
        },
        {
          'name': 'Healthcare',
          'icon': Icons.local_hospital,
          'color': const Color(0xFF00B894), // Green
          'children': [
            {'name': 'Medical & Dental', 'icon': Icons.medical_services, 'color': const Color(0xFF55A3FF)},
            {'name': 'Pharmacy', 'icon': Icons.local_pharmacy, 'color': const Color(0xFF26de81)},
          ]
        },
        {
          'name': 'Education',
          'icon': Icons.school,
          'color': const Color(0xFF5AC8FA), // Teal
          'children': [
            {'name': 'Tuition & Fees', 'icon': Icons.school, 'color': const Color(0xFF00CEC9)},
            {'name': 'Books & Supplies', 'icon': Icons.book, 'color': const Color(0xFF636E72)},
            {'name': 'Online Courses', 'icon': Icons.computer, 'color': const Color(0xFF2D3436)},
          ]
        },
        // Simple categories without children
        {
          'name': 'Travel',
          'icon': Icons.flight,
          'color': const Color(0xFFE91E63), // Pink
        },
        {
          'name': 'Insurance',
          'icon': Icons.security,
          'color': const Color(0xFF00CEC9), // Teal
        }
      ];

      // Define default income categories with icons and colors
      final incomeCategories = [
        {
          'name': 'Employment',
          'icon': Icons.work,
          'color': const Color(0xFF00B894), // Green
          'children': [
            {'name': 'Salary', 'icon': Icons.work, 'color': const Color(0xFF55A3FF)},
            {'name': 'Bonus & Overtime', 'icon': Icons.star, 'color': const Color(0xFF26de81)},
          ]
        },
        {
          'name': 'Business',
          'icon': Icons.business,
          'color': const Color(0xFF3742FA), // Blue
          'children': [
            {'name': 'Freelance', 'icon': Icons.computer, 'color': const Color(0xFF70A1FF)},
            {'name': 'Business Revenue', 'icon': Icons.store, 'color': const Color(0xFF5352ED)},
          ]
        },
        {
          'name': 'Investment',
          'icon': Icons.trending_up,
          'color': const Color(0xFFFF9500), // Orange
          'children': [
            {'name': 'Dividends & Interest', 'icon': Icons.account_balance, 'color': const Color(0xFFFFC312)},
            {'name': 'Capital Gains', 'icon': Icons.show_chart, 'color': const Color(0xFFE17055)},
          ]
        },
        // Simple categories without children
        {
          'name': 'Gifts & Rewards',
          'icon': Icons.card_giftcard,
          'color': const Color(0xFF8E44AD), // Purple
        },
        {
          'name': 'Other Income',
          'icon': Icons.more_horiz,
          'color': const Color(0xFF636E72), // Grey
        }
      ];

      // Create expense categories with parent-child relationships
      for (final categoryData in expenseCategories) {
        // Check if category has children
        final children = categoryData['children'] as List<Map<String, dynamic>>?;
        
        if (children != null && children.isNotEmpty) {
          // Create parent category with children
          final parentId = _uuid.v4();
          categoriesToCreate.add(Category(
            id: parentId,
            userId: userId,
            name: categoryData['name'] as String,
            type: CategoryType.expense,
            iconCodePoint: (categoryData['icon'] as IconData).codePoint,
            color: (categoryData['color'] as Color).toARGB32(),
            isActive: true,
            needsSync: true,
            createdAt: now,
            updatedAt: now,
          ));

          // Create child categories
          for (final childData in children) {
            categoriesToCreate.add(Category(
              id: _uuid.v4(),
              userId: userId,
              name: childData['name'] as String,
              type: CategoryType.expense,
              parentId: parentId,
              iconCodePoint: (childData['icon'] as IconData).codePoint,
              color: (childData['color'] as Color).toARGB32(),
              isActive: true,
              needsSync: true,
              createdAt: now,
              updatedAt: now,
            ));
          }
        } else {
          // Create simple category without children
          categoriesToCreate.add(Category(
            id: _uuid.v4(),
            userId: userId,
            name: categoryData['name'] as String,
            type: CategoryType.expense,
            iconCodePoint: (categoryData['icon'] as IconData).codePoint,
            color: (categoryData['color'] as Color).toARGB32(),
            isActive: true,
            needsSync: true,
            createdAt: now,
            updatedAt: now,
          ));
        }
      }

      // Create income categories with parent-child relationships
      for (final categoryData in incomeCategories) {
        // Check if category has children
        final children = categoryData['children'] as List<Map<String, dynamic>>?;
        
        if (children != null && children.isNotEmpty) {
          // Create parent category with children
          final parentId = _uuid.v4();
          categoriesToCreate.add(Category(
            id: parentId,
            userId: userId,
            name: categoryData['name'] as String,
            type: CategoryType.income,
            iconCodePoint: (categoryData['icon'] as IconData).codePoint,
            color: (categoryData['color'] as Color).toARGB32(),
            isActive: true,
            needsSync: true,
            createdAt: now,
            updatedAt: now,
          ));

          // Create child categories
          for (final childData in children) {
            categoriesToCreate.add(Category(
              id: _uuid.v4(),
              userId: userId,
              name: childData['name'] as String,
              type: CategoryType.income,
              parentId: parentId,
              iconCodePoint: (childData['icon'] as IconData).codePoint,
              color: (childData['color'] as Color).toARGB32(),
              isActive: true,
              needsSync: true,
              createdAt: now,
              updatedAt: now,
            ));
          }
        } else {
          // Create simple category without children
          categoriesToCreate.add(Category(
            id: _uuid.v4(),
            userId: userId,
            name: categoryData['name'] as String,
            type: CategoryType.income,
            iconCodePoint: (categoryData['icon'] as IconData).codePoint,
            color: (categoryData['color'] as Color).toARGB32(),
            isActive: true,
            needsSync: true,
            createdAt: now,
            updatedAt: now,
          ));
        }
      }

      // Batch save semua categories sekaligus - lebih efisien
      for (final category in categoriesToCreate) {
        await _localDb.saveCategory(category);
      }

      // Try sync in background tapi jangan block creation
      _syncCategoriesInBackground(categoriesToCreate);

      if (kDebugMode) {
        print('✅ Default categories created successfully for user: $userId');
        print('📊 Created ${categoriesToCreate.length} total categories');
        print('   - ${expenseCategories.length} expense category groups');
        print('   - ${incomeCategories.length} income category groups');
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

  // Get count of unsynced categories for diagnostics
  Future<int> getUnsyncedCategoriesCount(String userId) async {
    try {
      final unsyncedCategories = await _localDb.getUnsyncedCategories(userId);
      return unsyncedCategories.length;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting unsynced categories count: $e');
      }
      return 0;
    }
  }

  // Get sync statistics for debugging
  Future<Map<String, dynamic>> getSyncStatistics(String userId) async {
    return await _syncHelper.getSyncStatistics(userId);
  }
}
