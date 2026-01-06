import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bot_link.dart';
import '../../services/supabase_service.dart';
import 'bot_link_service.dart';

/// State for Telegram bot link
final telegramBotLinkProvider =
    AsyncNotifierProvider<TelegramBotLinkNotifier, BotLink?>(
      TelegramBotLinkNotifier.new,
    );

class TelegramBotLinkNotifier extends AsyncNotifier<BotLink?> {
  @override
  Future<BotLink?> build() async {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    if (user == null) {
      debugPrint('🔗 BotLink: No user logged in');
      return null;
    }

    try {
      final service = ref.watch(botLinkServiceProvider);
      final botLink = await service.getBotLink(user.id, 'telegram');
      debugPrint(
        '🔗 BotLink: Fetched link = ${botLink?.platformUsername ?? "null"}',
      );
      return botLink;
    } catch (e) {
      debugPrint('🔗 BotLink: Error fetching = $e');
      return null;
    }
  }

  /// Refresh the bot link state
  Future<void> refresh() async {
    debugPrint('🔗 BotLink: Refreshing...');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  /// Update parser configuration (parser_mode, ai_provider, api_key)
  Future<void> updateParserConfig({
    required String parserMode,
    required String aiProvider,
    String? apiKey,
  }) async {
    final currentLink = state.value;
    if (currentLink == null) return;

    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;
    if (user == null) return;

    final service = ref.read(botLinkServiceProvider);

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return service.updateParserConfig(
        botLinkId: currentLink.id,
        userId: user.id,
        parserMode: parserMode,
        aiProvider: aiProvider,
        aiApiKey: apiKey,
      );
    });
  }

  /// Disconnect Telegram
  Future<void> disconnect() async {
    final currentLink = state.value;
    if (currentLink == null) return;

    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;
    if (user == null) return;

    final service = ref.read(botLinkServiceProvider);

    await service.deleteBotLink(currentLink.id, user.id);
    state = const AsyncValue.data(null);
  }
}

/// Check if Telegram is connected
final isTelegramConnectedProvider = Provider<bool>((ref) {
  final link = ref.watch(telegramBotLinkProvider);
  return link.value != null;
});
