import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/category.dart';
import '../../../services/supabase_service.dart';

/// Provider tunggal CategoryService (online-only, Supabase langsung)
final categoryServiceProvider = Provider<CategoryService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return CategoryService(supabase);
});

/// Service kategori tanpa lapisan offline (NO-OP untuk metode legacy sync)
class CategoryService {
  final SupabaseClient _supabase;
  CategoryService(this._supabase);

  // ===== READ =====
  Future<List<Category>> getCategories(
    String userId, {
    bool includeInactive = false,
  }) async {
    try {
      final response = await _supabase
          .from('categories')
          .select('*')
          .eq('user_id', userId)
          .order('created_at');
      if (response.isEmpty) return [];
      final list = (response as List)
          .map((j) => Category.fromJson(_convertFromSupabase(j)))
          .toList();
      return includeInactive ? list : list.where((c) => c.isActive).toList();
    } catch (e) {
      if (kDebugMode) print('❌ getCategories error: $e');
      return [];
    }
  }

  Future<List<Category>> getCategoriesByType(
    String userId,
    CategoryType type, {
    bool includeInactive = false,
  }) async {
    try {
      final response = await _supabase
          .from('categories')
          .select('*')
          .eq('user_id', userId)
          .eq('type', type.name)
          .order('created_at');
      if (response.isEmpty) return [];
      final list = (response as List)
          .map((j) => Category.fromJson(_convertFromSupabase(j)))
          .toList();
      return includeInactive ? list : list.where((c) => c.isActive).toList();
    } catch (e) {
      if (kDebugMode) print('❌ getCategoriesByType error: $e');
      return [];
    }
  }

  Future<Category?> getCategoryById(
    String categoryId, {
    required String userId,
  }) async {
    try {
      final response = await _supabase
          .from('categories')
          .select('*')
          .eq('id', categoryId)
          .eq('user_id', userId)
          .maybeSingle();
      if (response == null) return null;
      return Category.fromJson(_convertFromSupabase(response));
    } catch (e) {
      if (kDebugMode) print('❌ getCategoryById error: $e');
      return null;
    }
  }

  // ===== WRITE =====
  Future<Category?> createCategory(
    String userId,
    CreateCategoryRequest request,
  ) async {
    try {
      final data = {
        'user_id': userId,
        'name': request.name,
        'type': request.type.name,
        'parent_id': request.parentId,
        'icon_code_point': request.iconCodePoint,
        'color': request.color,
        'is_active': true,
      };
      final row = await _supabase
          .from('categories')
          .insert(data)
          .select()
          .single();
      return Category.fromJson(_convertFromSupabase(row));
    } catch (e) {
      if (kDebugMode) print('❌ createCategory error: $e');
      return null;
    }
  }

  Future<Category?> updateCategory(
    String categoryId,
    String userId,
    UpdateCategoryRequest request,
  ) async {
    try {
      final data = <String, dynamic>{};
      if (request.name != null) data['name'] = request.name;
      if (request.type != null) data['type'] = request.type!.name;
      if (request.parentId != null) data['parent_id'] = request.parentId;
      if (request.iconCodePoint != null) {
        data['icon_code_point'] = request.iconCodePoint;
      }
      if (request.color != null) data['color'] = request.color;
      if (request.isActive != null) data['is_active'] = request.isActive;
      if (data.isEmpty) {
        return await getCategoryById(categoryId, userId: userId);
      }
      final row = await _supabase
          .from('categories')
          .update(data)
          .eq('id', categoryId)
          .eq('user_id', userId)
          .select()
          .single();
      return Category.fromJson(_convertFromSupabase(row));
    } catch (e) {
      if (kDebugMode) print('❌ updateCategory error: $e');
      return null;
    }
  }

  Future<bool> deleteCategory(String categoryId, String userId) async {
    try {
      await _supabase
          .from('categories')
          .delete()
          .eq('id', categoryId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ deleteCategory error: $e');
      return false;
    }
  }

  // Legacy methods removed (offline & template features deprecated)
  Future<bool> hasUserEverHadCategories(String userId) async =>
      (await getCategories(userId)).isNotEmpty;

  // ===== UTIL =====
  Map<String, dynamic> _convertFromSupabase(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'user_id': data['user_id'],
      'name': data['name'],
      'type': data['type'],
      'parent_id': data['parent_id'],
      'icon_code_point': data['icon_code_point'],
      'color': data['color'],
      'is_active': data['is_active'],
      'created_at': data['created_at'],
      'updated_at': data['updated_at'],
  'is_hidden': data['is_hidden'],
    };
  }
}
