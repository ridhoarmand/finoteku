import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/category.dart';
import '../../../services/supabase_service.dart';

// Provider untuk SupabaseCategoryService
final supabaseCategoryServiceProvider = Provider<SupabaseCategoryService>((
  ref,
) {
  final supabase = ref.watch(supabaseProvider);
  return SupabaseCategoryService(supabase);
});

class SupabaseCategoryService {
  final SupabaseClient _supabase;

  SupabaseCategoryService(this._supabase);

  // Ambil semua categories dari server
  Future<List<Category>> getCategories(String userId) async {
    try {
      final response = await _supabase
          .from('categories')
          .select('*')
          .eq('user_id', userId)
          .order('created_at');

      // Handle empty result
      if (response.isEmpty) {
        if (kDebugMode) {
          print('ℹ️ No categories found in server for user: $userId');
        }
        return [];
      }

      return (response as List)
          .map((json) => Category.fromJson(_convertFromSupabase(json)))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching categories from server: $e');
      }
      throw Exception('Failed to fetch categories: $e');
    }
  }

  // Ambil categories by type dari server
  Future<List<Category>> getCategoriesByType(
    String userId,
    CategoryType type,
  ) async {
    try {
      final response = await _supabase
          .from('categories')
          .select('*')
          .eq('user_id', userId)
          .eq('type', type.name)
          .order('created_at');

      // Handle empty result
      if (response.isEmpty) {
        if (kDebugMode) {
          print(
            'ℹ️ No categories of type ${type.name} found in server for user: $userId',
          );
        }
        return [];
      }

      return (response as List)
          .map((json) => Category.fromJson(_convertFromSupabase(json)))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching categories by type from server: $e');
      }
      throw Exception('Failed to fetch categories: $e');
    }
  }

  // Ambil category by ID dari server
  Future<Category?> getCategory(String categoryId, String userId) async {
    try {
      final response = await _supabase
          .from('categories')
          .select('*')
          .eq('id', categoryId)
          .eq('user_id', userId)
          .single();

      return Category.fromJson(_convertFromSupabase(response));
    } catch (e) {
      if (e.toString().contains('No rows found') ||
          e.toString().contains('multiple (or no) rows returned') ||
          e.toString().contains('0 rows')) {
        if (kDebugMode) {
          print('ℹ️ Category not found in server: $categoryId');
        }
        return null;
      }
      if (kDebugMode) {
        print('❌ Error fetching category from server: $e');
      }
      throw Exception('Failed to fetch category: $e');
    }
  }

  // Buat category baru di server
  Future<Category> createCategory(
    String userId,
    CreateCategoryRequest request,
  ) async {
    try {
      final data = {
        'user_id': userId,
        'name': request.name,
        'type': request.type.name,
        'parent_id': request.parentId,
        'is_active': true,
      };

      final response = await _supabase
          .from('categories')
          .insert(data)
          .select()
          .single();

      return Category.fromJson(_convertFromSupabase(response));
    } catch (e) {
      throw Exception('Failed to create category: $e');
    }
  }

  // Update category di server
  Future<Category> updateCategory(
    String categoryId,
    String userId,
    UpdateCategoryRequest request,
  ) async {
    try {
      final data = <String, dynamic>{};
      if (request.name != null) data['name'] = request.name;
      if (request.type != null) data['type'] = request.type!.name;
      if (request.parentId != null) data['parent_id'] = request.parentId;
      if (request.isActive != null) data['is_active'] = request.isActive;

      if (data.isEmpty) {
        throw Exception('No data to update');
      }

      final response = await _supabase
          .from('categories')
          .update(data)
          .eq('id', categoryId)
          .eq('user_id', userId)
          .select()
          .single();

      return Category.fromJson(_convertFromSupabase(response));
    } catch (e) {
      throw Exception('Failed to update category: $e');
    }
  }

  // Hapus category di server
  Future<void> deleteCategory(String categoryId, String userId) async {
    try {
      await _supabase
          .from('categories')
          .delete()
          .eq('id', categoryId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete category: $e');
    }
  }

  // Sync category ke server
  Future<Category> syncCategory(Category category) async {
    try {
      if (kDebugMode) {
        print(
          '🔄 Syncing category: ${category.id} for user: ${category.userId}',
        );
      }

      // Cek apakah category sudah ada di server (tanpa menggunakan .single())
      final checkResponse = await _supabase
          .from('categories')
          .select('*')
          .eq('id', category.id)
          .eq('user_id', category.userId);

      if (checkResponse.isEmpty) {
        // Buat baru di server
        if (kDebugMode) {
          print('📝 Creating new category in server: ${category.id}');
        }
        final data = {
          'id': category.id, // Gunakan ID yang sama dari local
          'user_id': category.userId,
          'name': category.name,
          'type': category.type.name,
          'parent_id': category.parentId,
          'is_active': category.isActive,
          'created_at': category.createdAt.toIso8601String(),
        };

        final response = await _supabase
            .from('categories')
            .insert(data)
            .select()
            .single();

        if (kDebugMode) {
          print('✅ Category created successfully in server');
        }
        return Category.fromJson(_convertFromSupabase(response));
      } else {
        // Update yang sudah ada
        if (kDebugMode) {
          print('🔄 Updating existing category in server: ${category.id}');
        }
        final updateRequest = UpdateCategoryRequest(
          name: category.name,
          type: category.type,
          parentId: category.parentId,
          isActive: category.isActive,
        );
        final updatedCategory = await updateCategory(
          category.id,
          category.userId,
          updateRequest,
        );
        if (kDebugMode) {
          print('✅ Category updated successfully in server');
        }
        return updatedCategory;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to sync category ${category.id}: $e');
      }
      throw Exception('Failed to sync category: $e');
    }
  }

  // Sync penghapusan category
  Future<void> syncCategoryDeletion(String categoryId, String userId) async {
    try {
      await deleteCategory(categoryId, userId);
    } catch (e) {
      // Jika category tidak ditemukan di server, anggap sudah dihapus
      if (!e.toString().contains('No rows found')) {
        throw Exception('Failed to sync category deletion: $e');
      }
    }
  }

  // Convert dari format Supabase ke format aplikasi
  Map<String, dynamic> _convertFromSupabase(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'user_id': data['user_id'],
      'name': data['name'],
      'type': data['type'],
      'parent_id': data['parent_id'],
      'is_active': data['is_active'],
      'created_at': data['created_at'],
      'updated_at': data['updated_at'],
      'is_deleted': false, // Supabase tidak menyimpan soft delete
      'needs_sync': false, // Data dari server sudah ter-sync
    };
  }
}
