import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/bot_link.dart';
import '../../services/supabase_service.dart';
import 'bot_provider.dart';

/// Bot Settings Screen - Configure Telegram and AI
class BotSettingsScreen extends ConsumerStatefulWidget {
  const BotSettingsScreen({super.key});

  @override
  ConsumerState<BotSettingsScreen> createState() => _BotSettingsScreenState();
}

class _BotSettingsScreenState extends ConsumerState<BotSettingsScreen> {
  final _apiKeyController = TextEditingController();
  AIProvider _selectedProvider = AIProvider.none;
  bool _showApiKey = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final botLinkAsync = ref.watch(telegramBotLinkProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Bot'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh status',
            onPressed: () {
              ref.read(telegramBotLinkProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: botLinkAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (botLink) => _buildContent(context, theme, botLink),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    BotLink? botLink,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Telegram Connection Card
        _buildTelegramCard(context, theme, botLink),

        const SizedBox(height: 24),

        // AI Configuration (only show if connected)
        if (botLink != null) ...[_buildAIConfigCard(context, theme, botLink)],
      ],
    );
  }

  Widget _buildTelegramCard(
    BuildContext context,
    ThemeData theme,
    BotLink? botLink,
  ) {
    final isConnected = botLink != null;

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
                            ? 'Terhubung${botLink.platformUsername != null ? ' (@${botLink.platformUsername})' : ''}'
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

  Widget _buildAIConfigCard(
    BuildContext context,
    ThemeData theme,
    BotLink botLink,
  ) {
    // Initialize state from botLink
    if (_selectedProvider == AIProvider.none && botLink.aiProvider != 'none') {
      _selectedProvider = AIProvider.fromValue(botLink.aiProvider);
    }

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
                    Icons.auto_awesome,
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
                        'AI Parser (Opsional)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Tingkatkan akurasi parsing transaksi',
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

            // Provider dropdown
            DropdownButtonFormField<AIProvider>(
              initialValue: _selectedProvider,
              decoration: const InputDecoration(
                labelText: 'AI Provider',
                border: OutlineInputBorder(),
              ),
              items: AIProvider.values.map((provider) {
                return DropdownMenuItem(
                  value: provider,
                  child: Text(provider.displayName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProvider = value ?? AIProvider.none;
                  if (_selectedProvider == AIProvider.none) {
                    _apiKeyController.clear();
                  }
                });
              },
            ),

            // API Key input (show only if provider selected)
            if (_selectedProvider != AIProvider.none) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _apiKeyController,
                obscureText: !_showApiKey,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  border: const OutlineInputBorder(),
                  helperText: _getApiKeyHelperText(),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _showApiKey ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _showApiKey = !_showApiKey),
                      ),
                      IconButton(
                        icon: const Icon(Icons.content_paste),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            _apiKeyController.text = data!.text!;
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedProvider == AIProvider.none
                          ? 'Tanpa AI, parsing menggunakan aturan sederhana dengan akurasi ~70-80%.'
                          : 'Dengan AI, parsing lebih cerdas dengan akurasi ~95%.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveAIConfig,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getApiKeyHelperText() {
    switch (_selectedProvider) {
      case AIProvider.gemini:
        return 'Dapatkan dari aistudio.google.com';
      case AIProvider.openai:
        return 'Dapatkan dari platform.openai.com';
      default:
        return '';
    }
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

  Future<void> _saveAIConfig() async {
    setState(() => _isSaving = true);

    try {
      await ref
          .read(telegramBotLinkProvider.notifier)
          .updateAIConfig(
            _selectedProvider.value,
            _selectedProvider != AIProvider.none
                ? _apiKeyController.text
                : null,
          );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pengaturan AI disimpan')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
