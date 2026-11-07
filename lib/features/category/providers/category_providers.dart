import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/category.dart';
import '../services/category_service.dart';
import '../../../core/state/refresh_token.dart';

// Unified refresh token for categories
final categoryRefreshProvider = refreshTokenProvider();

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

// Semua kategori (termasuk non-aktif/hidden) – berguna untuk klasifikasi historis
final categoriesAllProvider = FutureProvider.family<List<Category>, String>((
  ref,
  userId,
) async {
  ref.watch(categoryRefreshProvider);
  final svc = ref.watch(categoryServiceProvider);
  return svc.getCategories(userId, includeInactive: true);
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

// Template-related providers dihapus karena konsep template/offline sudah dihilangkan.
