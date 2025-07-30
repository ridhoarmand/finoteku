import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/category.dart';
import '../../../services/local_database_service.dart';
import '../services/category_service.dart';
import '../services/supabase_category_service.dart';

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
final categoryProvider = FutureProvider.family<Category?, ({String categoryId, String userId})>((
  ref,
  params,
) async {
  final categoryService = ref.watch(categoryServiceProvider);
  return categoryService.getCategoryById(params.categoryId, userId: params.userId);
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
