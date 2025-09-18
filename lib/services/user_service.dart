import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';

/// User service for handling user-related data operations
class UserService {
  final SupabaseClient _supabase;

  UserService(this._supabase);

  /// Get user profile data including timezone
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('users')
          .select('id, email, full_name, currency, timezone, created_at, updated_at')
          .eq('id', userId)
          .single();

      return response;
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error getting user profile: $e');
    }
  }

  /// Get user timezone
  Future<String> getUserTimezone() async {
    try {
      final profile = await getUserProfile();
      return profile?['timezone'] ?? 'Asia/Jakarta'; // Default fallback
    } catch (e) {
      // Return default timezone if error occurs
      return 'Asia/Jakarta';
    }
  }

  /// Update user timezone
  Future<void> updateUserTimezone(String timezone) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('users')
          .update({
            'timezone': timezone,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating timezone: $e');
    }
  }

  /// Update user profile
  Future<void> updateUserProfile({
    String? fullName,
    String? currency,
    String? timezone,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updateData['full_name'] = fullName;
      if (currency != null) updateData['currency'] = currency;
      if (timezone != null) updateData['timezone'] = timezone;

      await _supabase
          .from('users')
          .update(updateData)
          .eq('id', userId);
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating profile: $e');
    }
  }

  /// Create user profile (called after registration)
  Future<void> createUserProfile({
    required String id,
    required String email,
    String? fullName,
    String? currency,
    String? timezone,
  }) async {
    try {
      await _supabase.from('users').insert({
        'id': id,
        'email': email,
        'full_name': fullName,
        'currency': currency ?? 'IDR',
        'timezone': timezone ?? 'Asia/Jakarta',
      });
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error creating user profile: $e');
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

/// Provider for user timezone
final userTimezoneProvider = FutureProvider<String>((ref) async {
  final userService = ref.watch(userServiceProvider);
  return await userService.getUserTimezone();
});
