import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/category.dart';
import '../services/category_service.dart';
import '../../../core/state/refresh_token.dart';

// Unified refresh token for categories
final categoryRefreshProvider = createRefreshTokenProvider();

// Provider untuk CategoryService sudah didefinisikan di file service; gunakan langsung.
// Alias for consistency with other features
final categoryRepositoryProvider = categoryServiceProvider;

// Helper function untuk manual refresh semua category providers
void refreshCategoryProviders(WidgetRef ref) {
  if (kDebugMode) {
    print('🔄 Refreshing all category providers...');
  }
  ref.read(categoryRefreshProvider.notifier).bump();
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

// Peta kategori by ID agar tidak perlu mem-build map berulang kali
final categoriesMapProvider =
    FutureProvider.family<Map<String, Category>, String>((ref, userId) async {
      ref.watch(categoryRefreshProvider);
      final list = await ref.watch(categoriesProvider(userId).future);
      return {for (final c in list) c.id: c};
    });

// Semua kategori (termasuk non-aktif/hidden) – berguna untuk klasifikasi historis
final categoriesAllProvider = FutureProvider.family<List<Category>, String>((
  ref,
  userId,
) async {
  ref.watch(categoryRefreshProvider);
  final svc = ref.watch(categoryServiceProvider);
  return svc.getCategories(userId, includeInactive: true);
});

// Peta semua kategori
final categoriesAllMapProvider =
    FutureProvider.family<Map<String, Category>, String>((ref, userId) async {
      ref.watch(categoryRefreshProvider);
      final list = await ref.watch(categoriesAllProvider(userId).future);
      return {for (final c in list) c.id: c};
    });

// Provider untuk categories by type dengan sorting alphabetical
final categoriesByTypeProvider =
    FutureProvider.family<List<Category>, ({String userId, CategoryType type})>(
      (ref, params) async {
        ref.watch(categoryRefreshProvider);
        final all = await ref.watch(categoriesProvider(params.userId).future);
        final filtered = all
            .where((c) => c.type == params.type && !c.isHidden)
            .toList();

        // Urutkan berdasarkan nama secara alphabetical (A-Z)
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

        return filtered;
      },
    );

final expenseCategoriesProvider = FutureProvider.family<List<Category>, String>(
  (ref, userId) async {
    ref.watch(categoryRefreshProvider);
    return ref.watch(
      categoriesByTypeProvider((
        userId: userId,
        type: CategoryType.expense,
      )).future,
    );
  },
);

final incomeCategoriesProvider = FutureProvider.family<List<Category>, String>((
  ref,
  userId,
) async {
  ref.watch(categoryRefreshProvider);
  return ref.watch(
    categoriesByTypeProvider((
      userId: userId,
      type: CategoryType.income,
    )).future,
  );
});

final categoryProvider =
    FutureProvider.family<Category?, ({String categoryId, String userId})>((
      ref,
      params,
    ) async {
      ref.watch(categoryRefreshProvider);
      final categoryService = ref.watch(categoryServiceProvider);
      return categoryService.getCategoryById(
        params.categoryId,
        userId: params.userId,
      );
    });

final activeCategoriesProvider = FutureProvider.family<List<Category>, String>((
  ref,
  userId,
) async {
  ref.watch(categoryRefreshProvider);
  final categories = await ref.watch(categoriesProvider(userId).future);
  return categories.where((c) => !c.isHidden).toList();
});

// Provider untuk kategori yang diurutkan secara alphabetical
final sortedCategoriesProvider = FutureProvider.family<List<Category>, String>((
  ref,
  userId,
) async {
  ref.watch(categoryRefreshProvider);
  final categories = await ref.watch(categoriesProvider(userId).future);

  // Filter hanya kategori yang aktif dan urutkan berdasarkan nama secara alphabetical
  final activeCategories = categories.where((c) => !c.isHidden).toList();

  // Urutkan berdasarkan nama secara alphabetical (A-Z)
  activeCategories.sort(
    (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );

  return activeCategories;
});

// Template-related providers dihapus karena konsep template/offline sudah dihilangkan.
