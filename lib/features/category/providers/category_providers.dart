import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/category.dart';
import '../../../services/local_database_service.dart';
import '../services/category_service.dart';
import '../services/supabase_category_service.dart';

// Global refresh notifier untuk trigger refresh semua category providers
class CategoryRefreshNotifier extends StateNotifier<int> {
  CategoryRefreshNotifier() : super(0);
  
  void refresh() {
    state = state + 1;
  }
}

final categoryRefreshProvider = StateNotifierProvider<CategoryRefreshNotifier, int>((ref) {
  return CategoryRefreshNotifier();
});

// Provider untuk CategoryService
final categoryServiceProvider = Provider<CategoryService>((ref) {
  final localDb = ref.watch(localDatabaseServiceProvider);
  final supabaseCategoryService = ref.watch(supabaseCategoryServiceProvider);
  final categoryService = CategoryService(localDb, supabaseCategoryService);
  
  // Set callback untuk auto-refresh providers saat data berubah
  categoryService.setDataChangeCallback(() {
    ref.read(categoryRefreshProvider.notifier).refresh();
  });
  
  return categoryService;
});

// Provider untuk daftar categories berdasarkan user ID
final categoriesProvider = FutureProvider.family<List<Category>, String>((
  ref,
  userId,
) async {
  // Watch refresh trigger to invalidate cache
  ref.watch(categoryRefreshProvider);
  
  final categoryService = ref.watch(categoryServiceProvider);
  return categoryService.getCategories(userId);
});

// Provider untuk categories by type
final categoriesByTypeProvider =
    FutureProvider.family<List<Category>, ({String userId, CategoryType type})>(
      (ref, params) async {
        // Watch refresh trigger to invalidate cache
        ref.watch(categoryRefreshProvider);
        
        // OPTIMASI: Gunakan data dari categoriesProvider untuk menghindari duplicate database calls
        final allCategories = await ref.watch(categoriesProvider(params.userId).future);
        return allCategories
            .where((category) => category.type == params.type && category.isActive)
            .toList();
      },
    );

// Provider untuk expense categories
final expenseCategoriesProvider = FutureProvider.family<List<Category>, String>(
  (ref, userId) async {
    // Watch refresh trigger to invalidate cache
    ref.watch(categoryRefreshProvider);
    
    // OPTIMASI: Gunakan categoriesByTypeProvider untuk consistency
    return ref.watch(categoriesByTypeProvider((userId: userId, type: CategoryType.expense)).future);
  },
);

// Provider untuk income categories
final incomeCategoriesProvider = FutureProvider.family<List<Category>, String>((
  ref,
  userId,
) async {
  // Watch refresh trigger to invalidate cache
  ref.watch(categoryRefreshProvider);
  
  // OPTIMASI: Gunakan categoriesByTypeProvider untuk consistency
  return ref.watch(categoriesByTypeProvider((userId: userId, type: CategoryType.income)).future);
});

// Provider untuk category by ID
final categoryProvider = FutureProvider.family<Category?, ({String categoryId, String userId})>((
  ref,
  params,
) async {
  // Watch refresh trigger to invalidate cache
  ref.watch(categoryRefreshProvider);
  
  final categoryService = ref.watch(categoryServiceProvider);
  return categoryService.getCategoryById(params.categoryId, userId: params.userId);
});

// Provider untuk active categories saja
final activeCategoriesProvider = FutureProvider.family<List<Category>, String>((
  ref,
  userId,
) async {
  // Watch refresh trigger to invalidate cache
  ref.watch(categoryRefreshProvider);
  
  // OPTIMASI: Gunakan categoriesProvider untuk menghindari duplicate calls
  final categories = await ref.watch(categoriesProvider(userId).future);
  return categories.where((category) => category.isActive).toList();
});

// Provider for checking if template offer should be shown
final shouldOfferTemplateProvider = FutureProvider.family<bool, String>((ref, userId) async {
  // Watch refresh notifier untuk invalidate ketika ada perubahan
  ref.watch(categoryRefreshProvider);
  
  final categoryService = ref.watch(categoryServiceProvider);
  return await categoryService.shouldOfferCategoryTemplate(userId);
});

// Provider untuk check apakah user sudah pernah punya categories
final hasUserEverHadCategoriesProvider = FutureProvider.family<bool, String>((ref, userId) async {
  // Watch refresh notifier untuk invalidate ketika ada perubahan
  ref.watch(categoryRefreshProvider);
  
  final categoryService = ref.watch(categoryServiceProvider);
  return await categoryService.hasUserEverHadCategories(userId);
});

// Helper function untuk refresh semua category providers
void refreshCategoryProviders(WidgetRef ref) {
  if (kDebugMode) {
    print('🔄 Refreshing all category providers...');
  }
  ref.read(categoryRefreshProvider.notifier).refresh();
  if (kDebugMode) {
    print('✅ Category providers refresh triggered');
  }
}
