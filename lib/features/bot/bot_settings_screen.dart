import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import '../../core/localization/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/bot_link.dart';
import '../../services/agent_training_service.dart';
import '../../services/supabase_service.dart';
import '../../services/user_service.dart';
import '../../utils/environment.dart';
import 'agent_training_screen.dart';
import 'bot_provider.dart';
import 'bot_link_service.dart';

/// Bot Settings Screen - Configure Telegram, WhatsApp and Parser Mode
class BotSettingsScreen extends ConsumerStatefulWidget {
  const BotSettingsScreen({super.key});

  @override
  ConsumerState<BotSettingsScreen> createState() => _BotSettingsScreenState();
}

class _BotSettingsScreenState extends ConsumerState<BotSettingsScreen> {

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final telegramBotLinkAsync = ref.watch(telegramBotLinkProvider);
    final whatsappBotLinkAsync = ref.watch(whatsappBotLinkProvider);

    return Scaffold(
      appBar: AppBar(title: Text(ref.tr(context, 'bot_title'))),
      body: telegramBotLinkAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (telegramBotLink) {
          return whatsappBotLinkAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (whatsappBotLink) =>
                _buildContent(context, theme, telegramBotLink, whatsappBotLink),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    BotLink? telegramBotLink,
    BotLink? whatsappBotLink,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        // Invalidate providers to reload data
        ref.invalidate(telegramBotLinkProvider);
        ref.invalidate(whatsappBotLinkProvider);
        ref.invalidate(userProfileProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // WhatsApp Connection Card
          _buildWhatsAppCard(context, theme, whatsappBotLink),

          const SizedBox(height: 16),

          // Telegram Connection Card
          _buildTelegramCard(context, theme, telegramBotLink),

          const SizedBox(height: 24),

          // Agent Training & Few-Shot Customization
          _buildAgentTrainingCard(context, theme),
        ],
      ),
    );
  }

  Widget _buildTelegramCard(
    BuildContext context,
    ThemeData theme,
    BotLink? botLink,
  ) {
    // Check if actually connected (has platform_user_id), not just if row exists
    final isConnected = botLink?.platformUserId != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0088CC).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    PhRegular.telegramLogo,
                    color: Color(0xFF0088CC),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Telegram Bot',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isConnected
                            ? '${ref.tr(context, 'bot_connected')}${botLink?.platformUsername != null ? ' (@${botLink!.platformUsername})' : ''}'
                            : ref.tr(context, 'bot_not_connected'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isConnected ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isConnected ? PhFill.checkCircle : PhRegular.circle,
                  color: isConnected ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              isConnected
                  ? ref.tr(context, 'bot_telegram_connected_desc')
                  : ref.tr(context, 'bot_telegram_disconnected_desc'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (isConnected)
              OutlinedButton.icon(
                onPressed: _confirmDisconnect,
                icon: const Icon(PhRegular.linkBreak),
                label: Text(ref.tr(context, 'bot_disconnect')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              )
            else
              FilledButton.icon(
                onPressed: _openTelegramBot,
                icon: const Icon(PhRegular.link),
                label: Text(ref.tr(context, 'bot_connect_telegram')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentTrainingCard(BuildContext context, ThemeData theme) {
    final trainingAsync = ref.watch(agentTrainingListProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    PhRegular.brain,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.tr(context, 'bot_training_title'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ref.tr(context, 'bot_training_sub'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            trainingAsync.when(
              loading: () => const SizedBox(),
              error: (e, _) => const SizedBox(),
              data: (trainingList) {
                final instructions = trainingList.where((i) => i.isInstruction && i.isActive).length;
                final examples = trainingList.where((i) => i.isFewShot && i.isActive).length;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(PhRegular.checkCircle, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ref.tr(context, 'bot_training_active').replaceAll('{instructions}', '$instructions').replaceAll('{examples}', '$examples'),
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AgentTrainingScreen(),
                    ),
                  );
                },
                icon: const Icon(PhRegular.slidersHorizontal),
                label: Text(ref.tr(context, 'bot_training_button')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTelegramBot() async {
    // Get current user ID
    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.tr(context, 'bot_login_first'))),
        );
      }
      return;
    }

    // Bot username - replace with your actual bot username
    const botUsername = 'FinotekuBot';

    final token = await ref
        .read(botLinkServiceProvider)
        .createLinkToken('telegram');
    final uri = Uri.parse('https://t.me/$botUsername?start=$token');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);

      // After returning from Telegram, refresh the bot link state
      // Add a small delay to allow the Edge Function to process
      await Future.delayed(const Duration(seconds: 2));
      ref.invalidate(telegramBotLinkProvider);
    }
  }

  Future<void> _confirmDisconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ref.tr(context, 'bot_disconnect_telegram_title')),
        content: Text(
          ref.tr(context, 'bot_disconnect_telegram_body'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(ref.tr(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(ref.tr(context, 'bot_disconnect')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(telegramBotLinkProvider.notifier).disconnect();
    }
  }

  Future<void> _openWhatsAppBot() async {
    // 1. Dapatkan User ID saat ini
    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.tr(context, 'bot_login_first'))),
        );
      }
      return;
    }

    // 2. Token sekali pakai (15 menit) dalam format pesan yang dikenali Edge Function WA
    final token = await ref
        .read(botLinkServiceProvider)
        .createLinkToken('whatsapp');
    final String message = "/hubungkan $token";

    // 3. Konversi menjadi URI skema whatsapp
    final Uri whatsappUri = Uri.parse(
      "https://wa.me/${Environment.waBotNumber}?text=${Uri.encodeComponent(message)}",
    );

    // 4. Buka aplikasi WhatsApp
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);

      // After returning from WhatsApp, refresh the bot link state
      // Add a small delay to allow the Edge Function to process
      await Future.delayed(const Duration(seconds: 2));
      ref.invalidate(whatsappBotLinkProvider);
    } else {
      // Tampilkan Alert/Tooltip bila aplikasi WhatsApp tidak terinstal
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.tr(context, 'bot_whatsapp_open_failed'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDisconnectWhatsApp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ref.tr(context, 'bot_disconnect_whatsapp_title')),
        content: Text(
          ref.tr(context, 'bot_disconnect_whatsapp_body'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(ref.tr(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(ref.tr(context, 'bot_disconnect')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(whatsappBotLinkProvider.notifier).disconnect();
    }
  }

  Widget _buildWhatsAppCard(
    BuildContext context,
    ThemeData theme,
    BotLink? botLink,
  ) {
    // Check if actually connected (has platform_user_id), not just if row exists
    final isConnected = botLink?.platformUserId != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons
                        .wechat, // Using wechat as a generic chat icon, or replace with an image
                    color: Color(0xFF25D366),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WhatsApp Bot',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isConnected
                            ? '${ref.tr(context, 'bot_connected')}${botLink?.platformUserId != null ? ' (${botLink!.platformUserId})' : ''}'
                            : ref.tr(context, 'bot_not_connected'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isConnected ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isConnected ? PhFill.checkCircle : PhRegular.circle,
                  color: isConnected ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              isConnected
                  ? ref.tr(context, 'bot_whatsapp_connected_desc')
                  : ref.tr(context, 'bot_whatsapp_disconnected_desc'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (isConnected)
              OutlinedButton.icon(
                onPressed: _confirmDisconnectWhatsApp,
                icon: const Icon(PhRegular.linkBreak),
                label: Text(ref.tr(context, 'bot_disconnect')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              )
            else
              FilledButton.icon(
                onPressed: _openWhatsAppBot,
                icon: const Icon(PhRegular.link),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
                label: Text(ref.tr(context, 'bot_connect_whatsapp')),
              ),
          ],
        ),
      ),
    );
  }
}
