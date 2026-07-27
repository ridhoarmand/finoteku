import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/bot_link.dart';
import '../../services/agent_training_service.dart';
import '../../services/supabase_service.dart';
import '../../services/user_service.dart';
import '../../utils/environment.dart';
import 'agent_training_screen.dart';
import 'bot_provider.dart';

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
      appBar: AppBar(title: const Text('Chat Bot')),
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
                    Icons.telegram,
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
                            ? 'Terhubung${botLink?.platformUsername != null ? ' (@${botLink!.platformUsername})' : ''}'
                            : 'Belum terhubung',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isConnected ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isConnected ? Icons.check_circle : Icons.circle_outlined,
                  color: isConnected ? Colors.green : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              isConnected
                  ? 'Anda dapat mencatat transaksi dengan mengirim pesan ke Finoteku Bot.'
                  : 'Hubungkan Telegram untuk mencatat transaksi dengan mudah via chat.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (isConnected)
              OutlinedButton.icon(
                onPressed: _confirmDisconnect,
                icon: const Icon(Icons.link_off),
                label: const Text('Putuskan Koneksi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              )
            else
              FilledButton.icon(
                onPressed: _openTelegramBot,
                icon: const Icon(Icons.link),
                label: const Text('Hubungkan Telegram'),
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
                    Icons.psychology,
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
                        'Instruksi & Contoh Chat',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Latih dan arahkan gaya AI dengan instruksi & contoh chat Anda',
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
                      Icon(Icons.check_circle_outline, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$instructions Instruksi & $examples Contoh Chat Aktif',
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
                icon: const Icon(Icons.tune),
                label: const Text('Atur Instruksi & Contoh Chat'),
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
          const SnackBar(content: Text('Silakan login terlebih dahulu')),
        );
      }
      return;
    }

    // Bot username - replace with your actual bot username
    const botUsername = 'FinotekuBot';

    // Deep link with user ID: t.me/BotUsername?start=<user_id>
    final uri = Uri.parse('https://t.me/$botUsername?start=${user.id}');

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
        title: const Text('Putuskan Koneksi?'),
        content: const Text(
          'Anda tidak akan bisa mencatat transaksi via Telegram setelah memutuskan koneksi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Putuskan'),
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
          const SnackBar(content: Text('Silakan login terlebih dahulu')),
        );
      }
      return;
    }

    final String userId = user.id;

    // 2. Siapkan format pesan yang diwajibkan oleh Edge Function WA
    final String message = "/hubungkan $userId";

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
          const SnackBar(
            content: Text(
              'Tidak dapat membuka WhatsApp. Pastikan aplikasi telah terinstal.',
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
        title: const Text('Putuskan Koneksi WhatsApp?'),
        content: const Text(
          'Anda tidak akan bisa mencatat transaksi via WhatsApp setelah memutuskan koneksi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Putuskan'),
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
                            ? 'Terhubung${botLink?.platformUserId != null ? ' (${botLink!.platformUserId})' : ''}'
                            : 'Belum terhubung',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isConnected ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isConnected ? Icons.check_circle : Icons.circle_outlined,
                  color: isConnected ? Colors.green : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              isConnected
                  ? 'Anda dapat mencatat transaksi dengan mengirim pesan WhatsApp ke Bot Finoteku.'
                  : 'Hubungkan WhatsApp untuk mencatat transaksi dengan mudah via chat.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (isConnected)
              OutlinedButton.icon(
                onPressed: _confirmDisconnectWhatsApp,
                icon: const Icon(Icons.link_off),
                label: const Text('Putuskan Koneksi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              )
            else
              FilledButton.icon(
                onPressed: _openWhatsAppBot,
                icon: const Icon(Icons.link),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
                label: const Text('Hubungkan WhatsApp'),
              ),
          ],
        ),
      ),
    );
  }
}
