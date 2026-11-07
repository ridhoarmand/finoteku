import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';

/// User service for handling user-related data operations
class UserService {
  final SupabaseClient _supabase;

  UserService(this._supabase);

  /// Get user profile data including timezone and parser settings
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('users')
          .select(
            'id, email, full_name, currency, timezone, parser_mode, ai_provider, created_at, updated_at',
          )
          .eq('id', userId)
          .single();

      return response;
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error getting user profile: $e');
    }
  }

  /// Save language preference to SharedPreferences
  Future<void> saveLanguagePreference(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_preference', languageCode);
    } catch (e) {
      throw Exception('Failed to save language preference: $e');
    }
  }

  /// Get language preference from SharedPreferences
  Future<String?> getLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('language_preference');
    } catch (e) {
      return null; // Return null if error, fallback to default
    }
  }
}

/// Provider for UserService
final userServiceProvider = Provider<UserService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return UserService(supabase);
});

/// Provider for user profile data
final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final userService = ref.watch(userServiceProvider);
  return await userService.getUserProfile();
});
