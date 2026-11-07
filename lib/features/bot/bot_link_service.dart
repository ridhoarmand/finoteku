import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/bot_link.dart';
import '../../../services/supabase_service.dart';
import '../../../core/errors/failure.dart';
import '../../../core/logging/logger.dart';

/// Provider for BotLinkService
final botLinkServiceProvider = Provider<BotLinkService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return BotLinkService(supabase);
});

/// Service for managing bot links (Telegram, WhatsApp, etc.)
class BotLinkService {
  final SupabaseClient _supabase;

  BotLinkService(this._supabase);

  /// Check if platform is linked (platform_user_id != null)
  Future<bool> isLinked(String platform) async {
    try {
      final response =
          await _supabase.rpc('get_bot_link', params: {'p_platform': platform})
              as List?;
      if (response == null || response.isEmpty) return false;
      final data = response.first as Map<String, dynamic>;
      return data['platform_user_id'] != null;
    } catch (e, st) {
      AppLogger.e('isLinked error', error: e, stackTrace: st);
      return false;
    }
  }

  /// Get bot link for a specific platform
  Future<BotLink?> getBotLink(String platform) async {
    try {
      final response =
          await _supabase.rpc('get_bot_link', params: {'p_platform': platform})
              as List?;

      if (response == null || response.isEmpty) return null;
      return BotLink.fromJson(response.first as Map<String, dynamic>);
    } catch (e, st) {
      AppLogger.e('getBotLink error', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  /// Get all bot links for user
  Future<List<BotLink>> getAllBotLinks() async {
    try {
      final response = await _supabase
          .from('bot_links')
          .select('*')
          .order('created_at');

      if (response.isEmpty) return [];
      return (response as List)
          .map((j) => BotLink.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      AppLogger.e('getAllBotLinks error', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  /// Update metadata (settings) for bot link
  Future<void> updateMetadata(
    String platform,
    Map<String, dynamic> metadata,
  ) async {
    try {
      await _supabase.rpc(
        'update_bot_link_metadata',
        params: {'p_platform': platform, 'p_metadata': metadata},
      );
    } catch (e, st) {
      AppLogger.e('updateMetadata error', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  /// One-time link token (15 minutes) for the bot deep link
  Future<String> createLinkToken(String platform) async {
    try {
      final token = await _supabase.rpc(
        'create_bot_link_token',
        params: {'p_platform': platform},
      );
      return token as String;
    } catch (e, st) {
      AppLogger.e('createLinkToken error', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  /// Unlink platform
  Future<void> unlinkPlatform(String platform) async {
    try {
      await _supabase.rpc('unlink_platform', params: {'p_platform': platform});
    } catch (e, st) {
      AppLogger.e('unlinkPlatform error', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  /// Update parser configuration (stored in users table, not bot_links)
  Future<void> updateParserConfig({
    required String parserMode,
    required String aiProvider,
    String? aiApiKey,
  }) async {
    try {
      await _supabase.rpc(
        'update_parser_settings',
        params: {
          'p_parser_mode': parserMode,
          'p_ai_provider': aiProvider,
          'p_ai_api_key': aiApiKey,
        },
      );
    } catch (e, st) {
      AppLogger.e('updateParserConfig error', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }
}
