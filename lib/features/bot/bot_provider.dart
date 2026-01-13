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
      final botLink = await service.getBotLink('telegram');
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

  /// Disconnect Telegram
  Future<void> disconnect() async {
    final service = ref.read(botLinkServiceProvider);

    state = const AsyncValue.loading();
    await service.unlinkPlatform('telegram');
    state = const AsyncValue.data(null);
  }
}

/// Check if Telegram is connected (has platform_user_id)
final isTelegramConnectedProvider = Provider<bool>((ref) {
  final link = ref.watch(telegramBotLinkProvider);
  // Row exists but check if actually linked (platform_user_id != null)
  return link.value?.platformUserId != null;
});
