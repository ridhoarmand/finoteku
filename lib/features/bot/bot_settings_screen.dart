import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/bot_link.dart';
import '../../services/supabase_service.dart';
import '../../services/user_service.dart';
import 'bot_link_service.dart';
import 'bot_provider.dart';

// Ganti sesuai nomor Whatsapp bot Finoteku yang online
const String waBotNumber = "6285156897928"; // Placeholder, can be changed later

/// Bot Settings Screen - Configure Telegram, WhatsApp and Parser Mode
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
    final userProfileAsync = ref.watch(userProfileProvider);

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
                child: Text(
                  '${ref.tr(context, 'bot_load_settings_error')}: $e',
                ),
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
                            ? '${ref.tr(context, 'bot_connected')}${botLink?.platformUsername != null ? ' (@${botLink!.platformUsername})' : ''}'
                            : ref.tr(context, 'bot_not_connected'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isConnected
                              ? Colors.green
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isConnected ? Icons.check_circle : Icons.circle_outlined,
                  color: isConnected
                      ? Colors.green
                      : Theme.of(context).colorScheme.onSurfaceVariant,
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
                icon: const Icon(Icons.link_off),
                label: Text(ref.tr(context, 'bot_disconnect')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              )
            else
              FilledButton.icon(
                onPressed: _openTelegramBot,
                icon: const Icon(Icons.link),
                label: Text(ref.tr(context, 'bot_connect_telegram')),
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

    final hasApiKey = userProfile?['has_ai_api_key'] == true;

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
                        ref.tr(context, 'bot_parser_mode'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ref.tr(context, 'bot_parser_mode_sub'),
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

            ...ParserMode.values.map(
              (mode) => _buildParserModeOption(theme, mode),
            ),

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
                _buildApiKeyStatus(theme)
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
                    : Text(ref.tr(context, 'save')),
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
                  : Theme.of(context).colorScheme.outlineVariant,
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
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
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

  Widget _buildApiKeyStatus(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.tr(context, 'bot_api_key_saved'),
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '••••••••',
                  style: TextStyle(
                    color: Colors.green,
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
            child: Text(ref.tr(context, 'bot_change')),
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
              tooltip: ref.tr(context, 'toggle_password_visibility'),
              icon: Icon(_showApiKey ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showApiKey = !_showApiKey),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).pasteButtonLabel,
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
        info = ref.tr(context, 'bot_info_ai_server');
        icon = Icons.cloud;
        color = Colors.blue;
      case ParserMode.userKey:
        info = ref.tr(context, 'bot_info_ai_own_key');
        icon = Icons.key;
        color = theme.colorScheme.primary;
      case ParserMode.regex:
        info = ref.tr(context, 'bot_info_regex');
        icon = Icons.rule;
        color = Colors.teal;
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
        return ref.tr(context, 'bot_key_hint_gemini');
      case AIProvider.openrouter:
        return ref.tr(context, 'bot_key_hint_openrouter');
    }
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
        content: Text(ref.tr(context, 'bot_disconnect_telegram_body')),
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
      "https://wa.me/$waBotNumber?text=${Uri.encodeComponent(message)}",
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
          SnackBar(content: Text(ref.tr(context, 'bot_whatsapp_open_failed'))),
        );
      }
    }
  }

  Future<void> _confirmDisconnectWhatsApp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ref.tr(context, 'bot_disconnect_whatsapp_title')),
        content: Text(ref.tr(context, 'bot_disconnect_whatsapp_body')),
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
                          color: isConnected
                              ? Colors.green
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isConnected ? Icons.check_circle : Icons.circle_outlined,
                  color: isConnected
                      ? Colors.green
                      : Theme.of(context).colorScheme.onSurfaceVariant,
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
                icon: const Icon(Icons.link_off),
                label: Text(ref.tr(context, 'bot_disconnect')),
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
                label: Text(ref.tr(context, 'bot_connect_whatsapp')),
              ),
          ],
        ),
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.tr(context, 'bot_settings_saved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ref.tr(context, 'bot_save_failed')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
