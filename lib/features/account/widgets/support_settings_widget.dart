import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'settings_section_widget.dart';
import '../../../core/localization/app_localizations.dart';

import '../../../services/app_update_service.dart';
import '../../settings/widgets/app_update_dialog.dart';

class SupportSettingsWidget extends ConsumerWidget {
  const SupportSettingsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSectionWidget(
      title: ref.tr(context, 'support_section'),
      children: [
        SettingsTileWidget(
          icon: PhRegular.arrowCircleDown,
          title: 'Cek Pembaruan Aplikasi',
          subtitle: 'Periksa versi rilis terbaru Finoteku',
          onTap: () => _checkAppUpdate(context, ref),
        ),
        SettingsTileWidget(
          icon: PhRegular.question,
          title: ref.tr(context, 'help_faq'),
          subtitle: ref.tr(context, 'help_faq_sub'),
          onTap: () => _showHelpDialog(context, ref),
        ),
        SettingsTileWidget(
          icon: PhRegular.info,
          title: ref.tr(context, 'about'),
          subtitle: ref.tr(context, 'about_sub'),
          onTap: () => _showAboutDialog(context, ref),
        ),
      ],
    );
  }

  Future<void> _showAboutDialog(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);

    try {
      final packageInfo = await PackageInfo.fromPlatform();

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Image.asset('assets/icon_transparent.png', width: 40, height: 40),
              const SizedBox(width: 12),
              Text(
                'Finoteku',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Aplikasi pencatatan keuangan pribadi yang membantu Anda mengelola keuangan dengan mudah. Fitur lengkap meliputi pencatatan pemasukan & pengeluaran, kategorisasi transaksi, laporan keuangan visual, dan notifikasi pengingat.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),

                // Version Info
                _buildInfoRow(
                  context,
                  'Version',
                  '${packageInfo.version} (${packageInfo.buildNumber})',
                  theme,
                ),
                const SizedBox(height: 8),

                // Developer Info
                _buildInfoRow(context, 'Developer', 'Ridho Armansyah', theme),
                const SizedBox(height: 8),

                // GitHub Profile
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      debugPrint('GitHub profile link tapped');
                      _launchUrl('https://github.com/ridhoarmand');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: _buildInfoRow(
                        context,
                        'GitHub',
                        '@ridhoarmand',
                        theme,
                        isLink: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // GitHub Repository
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      debugPrint('GitHub repository link tapped');
                      _launchUrl('https://github.com/ridhoarmand/finoteku');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhRegular.code,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'GitHub Repository',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Footer
                Text(
                  'Dibuat dengan Flutter & Supabase\n\n© 2025 Ridho Armansyah\nAll rights reserved.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(ref.tr(context, 'close')),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error loading package info: $e');
      // Show a fallback dialog without version info if needed
    }
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    ThemeData theme, {
    bool isLink = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isLink
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
              decoration: isLink ? TextDecoration.underline : null,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showHelpDialog(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);

    final faqData = [
      {
        'question': 'Bagaimana cara menambah transaksi?',
        'answer':
            'Tekan tombol + di beranda, isi nominal dan kategori, lalu simpan.',
      },
      {
        'question': 'Bagaimana cara melihat laporan?',
        'answer':
            'Buka tab Laporan untuk melihat grafik dan ringkasan keuangan.',
      },
      {
        'question': 'Bagaimana cara mengubah tema?',
        'answer':
            'Buka Pengaturan > Tema untuk beralih antara light/dark mode.',
      },
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(PhRegular.question, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(ref.tr(context, 'help_faq')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 250,
          child: ListView.builder(
            itemCount: faqData.length,
            itemBuilder: (context, index) {
              final faq = faqData[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  title: Text(
                    faq['question']!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        faq['answer']!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(ref.tr(context, 'close')),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);

      // Try different launch modes to ensure compatibility
      bool launched = false;

      // First try external application mode
      if (await canLaunchUrl(uri)) {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          launched = true;
        } catch (e) {
          debugPrint('Failed with externalApplication mode: $e');
        }
      }

      // If external application fails, try platform default
      if (!launched && await canLaunchUrl(uri)) {
        try {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
          launched = true;
        } catch (e) {
          debugPrint('Failed with platformDefault mode: $e');
        }
      }

      // If still not launched, try basic launch
      if (!launched) {
        try {
          await launchUrl(uri);
          launched = true;
        } catch (e) {
          debugPrint('Failed with basic launch: $e');
        }
      }

      if (!launched) {
        debugPrint('Cannot launch URL: $url');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Future<void> _checkAppUpdate(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Memeriksa versi terbaru…'),
        duration: Duration(seconds: 2),
      ),
    );

    final service = ref.read(appUpdateServiceProvider);
    final updateInfo = await service.checkForUpdate();

    if (!context.mounted) return;

    if (updateInfo.isUpdateAvailable && updateInfo.latestRelease != null) {
      await AppUpdateDialog.show(
        context,
        release: updateInfo.latestRelease!,
        currentVersion: updateInfo.currentVersion,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Finoteku sudah versi terbaru (v${updateInfo.currentVersion}).'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
