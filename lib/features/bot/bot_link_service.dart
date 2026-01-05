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

  /// Get bot link for a specific platform
  Future<BotLink?> getBotLink(String userId, String platform) async {
    try {
      final response = await _supabase
          .from('bot_links')
          .select('*')
          .eq('user_id', userId)
          .eq('platform', platform)
          .maybeSingle();

      if (response == null) return null;
      return BotLink.fromJson(response);
    } catch (e, st) {
      AppLogger.e('getBotLink error', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  /// Get all bot links for user
  Future<List<BotLink>> getAllBotLinks(String userId) async {
    try {
      final response = await _supabase
          .from('bot_links')
          .select('*')
          .eq('user_id', userId)
          .order('created_at');

      if (response.isEmpty) return [];
      return (response as List).map((j) => BotLink.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('getAllBotLinks error', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  /// Create a new bot link
  Future<BotLink> createBotLink({
    required String userId,
    required String platform,
    required String platformUserId,
    String? platformUsername,
  }) async {
    try {
      final data = {
        'user_id': userId,
        'platform': platform,
        'platform_user_id': platformUserId,
        'platform_username': platformUsername,
        'is_active': true,
        'ai_provider': 'none',
      };

      final response = await _supabase
          .from('bot_links')
          .insert(data)
          .select()
          .single();

      return BotLink.fromJson(response);
    } catch (e, st) {
      AppLogger.e('createBotLink error', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  /// Update AI configuration for a bot link
  Future<BotLink> updateAIConfig({
    required String botLinkId,
    required String userId,
    required String aiProvider,
    String? aiApiKey,
  }) async {
    try {
      final data = <String, dynamic>{'ai_provider': aiProvider};
      if (aiApiKey != null) {
        data['ai_api_key'] = aiApiKey;
      }

      final response = await _supabase
          .from('bot_links')
          .update(data)
          .eq('id', botLinkId)
          .eq('user_id', userId)
          .select()
          .single();

      return BotLink.fromJson(response);
    } catch (e, st) {
      AppLogger.e('updateAIConfig error', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  /// Delete bot link (disconnect)
  Future<void> deleteBotLink(String botLinkId, String userId) async {
    try {
      await _supabase
          .from('bot_links')
          .delete()
          .eq('id', botLinkId)
          .eq('user_id', userId);
    } catch (e, st) {
      AppLogger.e('deleteBotLink error', error: e, stackTrace: st);
      throw mapException(e, st);
    }
  }

  /// Generate Telegram deep link for connecting
  String generateTelegramDeepLink(String botUsername, String userId) {
    // The user will click this link to start the bot
    // The bot will receive /start command with the userId as payload
    return 'https://t.me/$botUsername?start=$userId';
  }
}
