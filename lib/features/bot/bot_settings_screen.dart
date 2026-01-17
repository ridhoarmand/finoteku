import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/bot_link.dart';
import '../../services/supabase_service.dart';
import '../../services/user_service.dart';
import 'bot_link_service.dart';
import 'bot_provider.dart';

/// Bot Settings Screen - Configure Telegram and Parser Mode
class BotSettingsScreen extends ConsumerStatefulWidget {
  const BotSettingsScreen({super.key});

  @override
  ConsumerState<BotSettingsScreen> createState() => _BotSettingsScreenState();
}

class _BotSettingsScreenState extends ConsumerState<BotSettingsScreen> {
  final _apiKeyController = TextEditingController();
  ParserMode _selectedParserMode = ParserMode.serverKey;
  AIProvider _selectedAIProvider = AIProvider.gemini;
  bool _showApiKey = false;
  bool _isSaving = false;
  bool _isEditing = false;
  bool _hasInitialized = false;

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
      appBar: AppBar(title: const Text('Chat Bot')),
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
    final userProfileAsync = ref.watch(userProfileProvider);

    return RefreshIndicator(
      onRefresh: () async {
        // Invalidate providers to reload data
        ref.invalidate(telegramBotLinkProvider);
        ref.invalidate(userProfileProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Telegram Connection Card
          _buildTelegramCard(context, theme, botLink),

          const SizedBox(height: 24),

          // Parser Configuration (ALWAYS show - stored in users table)
          userProfileAsync.when(
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading settings: $e'),
              ),
            ),
            data: (userProfile) =>
                _buildParserConfigCard(context, theme, userProfile),
          ),
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

  Widget _buildParserConfigCard(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic>? userProfile,
  ) {
    // Initialize state from user profile on first build only
    if (!_hasInitialized && userProfile != null) {
      _hasInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedParserMode = ParserMode.fromValue(
              userProfile['parser_mode'] as String? ?? 'server_key',
            );
            _selectedAIProvider = AIProvider.fromValue(
              userProfile['ai_provider'] as String? ?? 'none',
            );
          });
        }
      });
    }

    final hasApiKey =
        userProfile?['ai_api_key'] != null &&
        (userProfile!['ai_api_key'] as String).isNotEmpty;

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
                        'Mode Parser',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Pilih cara parsing transaksi',
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

            // Parser mode selection (exclude regex)
            ...ParserMode.values
                .where((mode) => mode != ParserMode.regex)
                .map((mode) => _buildParserModeOption(theme, mode)),

            // Show AI provider and API key input only for user_key mode
            if (_selectedParserMode == ParserMode.userKey) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // AI Provider dropdown
              DropdownButtonFormField<AIProvider>(
                initialValue: _selectedAIProvider,
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
                    _selectedAIProvider = value ?? AIProvider.gemini;
                  });
                },
              ),

              const SizedBox(height: 16),

              // API Key status or input
              if (hasApiKey && !_isEditing)
                _buildApiKeyStatus(theme, userProfile)
              else
                _buildApiKeyInput(theme),
            ],

            const SizedBox(height: 16),

            // Info box based on selected mode
            _buildInfoBox(theme),

            const SizedBox(height: 16),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveConfig,
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

  Widget _buildParserModeOption(ThemeData theme, ParserMode mode) {
    final isSelected = _selectedParserMode == mode;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedParserMode = mode;
            if (mode != ParserMode.userKey) {
              _isEditing = false;
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.05)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? theme.colorScheme.primary : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    Text(
                      mode.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApiKeyStatus(ThemeData theme, Map<String, dynamic> userProfile) {
    final apiKey = userProfile['ai_api_key'] as String? ?? '';
    final maskedKey = apiKey.length <= 8
        ? '••••••••'
        : '${apiKey.substring(0, 4)}••••${apiKey.substring(apiKey.length - 4)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'API Key tersimpan',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  maskedKey,
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _isEditing = true;
                _apiKeyController.clear();
              });
            },
            child: const Text('Ubah'),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyInput(ThemeData theme) {
    return TextFormField(
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
              icon: Icon(_showApiKey ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showApiKey = !_showApiKey),
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
    );
  }

  Widget _buildInfoBox(ThemeData theme) {
    String info;
    IconData icon;
    Color color;

    switch (_selectedParserMode) {
      case ParserMode.serverKey:
        info = 'Parsing dengan AI menggunakan server. Akurasi ~95%. Gratis!';
        icon = Icons.cloud;
        color = Colors.blue;
      case ParserMode.userKey:
        info = 'Parsing dengan AI menggunakan API key Anda. Akurasi ~95%.';
        icon = Icons.key;
        color = theme.colorScheme.primary;
      case ParserMode.regex:
        // Shouldn't reach here since regex is filtered out
        info = 'Mode tidak tersedia';
        icon = Icons.error;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(info, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  String _getApiKeyHelperText() {
    switch (_selectedAIProvider) {
      case AIProvider.gemini:
        return 'Dapatkan dari aistudio.google.com atau GCP Console';
      case AIProvider.openai:
        return 'Dapatkan dari platform.openai.com';
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

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    try {
      String? apiKey;
      String aiProvider = 'none';

      if (_selectedParserMode == ParserMode.userKey) {
        apiKey = _apiKeyController.text.isNotEmpty
            ? _apiKeyController.text
            : null;
        aiProvider = _selectedAIProvider.value;
      }

      await ref
          .read(botLinkServiceProvider)
          .updateParserConfig(
            parserMode: _selectedParserMode.value,
            aiProvider: aiProvider,
            aiApiKey: apiKey,
          );

      // Refresh user profile to reflect new settings
      ref.invalidate(userProfileProvider);

      setState(() {
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pengaturan disimpan')));
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
