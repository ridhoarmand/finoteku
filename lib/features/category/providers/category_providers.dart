import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/category.dart';
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

// Provider untuk CategoryService (online-only)
final categoryServiceProvider = Provider<CategoryService>((ref) {
  final supabaseCategoryService = ref.watch(supabaseCategoryServiceProvider);
  // CategoryService tidak lagi punya callback data change; gunakan manual refresh via notifier
  return CategoryService(supabaseCategoryService);
});

// Helper function untuk manual refresh semua category providers
void refreshCategoryProviders(WidgetRef ref) {
  if (kDebugMode) {
    print('🔄 Refreshing all category providers...');
  }
  ref.read(categoryRefreshProvider.notifier).refresh();
  if (kDebugMode) {
    print('✅ Category providers refresh triggered');
  }
}

// Provider untuk daftar categories berdasarkan user ID
final categoriesProvider = FutureProvider.family<List<Category>, String>((
  ref,
  userId,
) async {
  ref.watch(categoryRefreshProvider); // invalidate on refresh
  final categoryService = ref.watch(categoryServiceProvider);
  return categoryService.getCategories(userId);
});

// Provider untuk categories by type
final categoriesByTypeProvider =
    FutureProvider.family<List<Category>, ({String userId, CategoryType type})>(
      (ref, params) async {
        ref.watch(categoryRefreshProvider);
        final all = await ref.watch(categoriesProvider(params.userId).future);
        return all
            .where((c) => c.type == params.type && c.isActive)
            .toList();
      },
    );

final expenseCategoriesProvider = FutureProvider.family<List<Category>, String>(
  (ref, userId) async {
    ref.watch(categoryRefreshProvider);
    return ref.watch(categoriesByTypeProvider((userId: userId, type: CategoryType.expense)).future);
  },
);

final incomeCategoriesProvider = FutureProvider.family<List<Category>, String>((
  ref,
  userId,
) async {
  ref.watch(categoryRefreshProvider);
  return ref.watch(categoriesByTypeProvider((userId: userId, type: CategoryType.income)).future);
});

final categoryProvider = FutureProvider.family<Category?, ({String categoryId, String userId})>((
  ref,
  params,
) async {
  ref.watch(categoryRefreshProvider);
  final categoryService = ref.watch(categoryServiceProvider);
  return categoryService.getCategoryById(params.categoryId, userId: params.userId);
});

final activeCategoriesProvider = FutureProvider.family<List<Category>, String>((
  ref,
  userId,
) async {
  ref.watch(categoryRefreshProvider);
  final categories = await ref.watch(categoriesProvider(userId).future);
  return categories.where((c) => c.isActive).toList();
});

// Template-related providers dihapus karena konsep template/offline sudah dihilangkan.
