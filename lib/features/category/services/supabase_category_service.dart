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
      if (request.name.trim().isEmpty) {
        throw Exception('Name is required');
      }
      final data = {
        'user_id': userId,
        'name': request.name,
        'type': request.type.name,
        'parent_id': request.parentId,
  'icon_code_point': request.iconCodePoint,
        'is_active': true,
      };

      final response = await _supabase
          .from('categories')
          .insert(data)
          .select()
          .single();

      return Category.fromJson(_convertFromSupabase(response));
    } catch (e) {
  throw Exception(_friendlyError('create category', e));
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
      if (request.iconCodePoint != null) data['icon_code_point'] = request.iconCodePoint;
      if (request.isHidden != null) data['is_hidden'] = request.isHidden;

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
  throw Exception(_friendlyError('update category', e));
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
    throw Exception(_friendlyError('delete category', e));
    }
  }
  // Legacy sync methods removed (online-only)

  // Convert dari format Supabase ke format aplikasi
  Map<String, dynamic> _convertFromSupabase(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'user_id': data['user_id'],
      'name': data['name'],
      'type': data['type'],
      'parent_id': data['parent_id'],
      'icon_code_point': data['icon_code_point'],
      'is_hidden': data['is_hidden'],
      'created_at': data['created_at'],
      'updated_at': data['updated_at'],
    };
  }

  String _friendlyError(String action, Object e) {
    final msg = e.toString();
    if (msg.contains('foreign key') && msg.contains('parent_id')) {
      return 'Failed to $action: parent category not found';
    }
    if (msg.contains('duplicate key') || msg.contains('already exists')) {
      return 'Failed to $action: duplicate name';
    }
    if (msg.contains('null value')) {
      return 'Failed to $action: missing required field';
    }
    return 'Failed to $action: $e';
  }
}
