import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_update_model.dart';
import '../../../services/app_update_service.dart';

/// Glassmorphic UI Dialog for In-App Updates
class AppUpdateDialog extends ConsumerWidget {
  final AppRelease release;
  final String currentVersion;

  const AppUpdateDialog({
    super.key,
    required this.release,
    required this.currentVersion,
  });

  /// Static helper to show update dialog
  static Future<void> show(
    BuildContext context, {
    required AppRelease release,
    required String currentVersion,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: !release.isMandatory,
      builder: (ctx) =>
          AppUpdateDialog(release: release, currentVersion: currentVersion),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final service = ref.watch(appUpdateServiceProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Icon & Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhRegular.arrowCircleDown,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pembaruan Tersedia!',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v$currentVersion ➔ v${release.tagName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Release Title
            Text(
              release.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Changelog / Release Notes
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                child: Text(
                  release.changelog.isNotEmpty
                      ? release.changelog
                      : 'Pembaruan aplikasi Finoteku dengan fitur terbaru dan perbaikan bug.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                if (!release.isMandatory)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Nanti Saja'),
                    ),
                  ),
                if (!release.isMandatory) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      final success = await service.downloadAndInstallUpdate(
                        release.downloadUrl,
                      );
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '⚠️ Gagal mengunduh rilis APK. Silakan periksa koneksi internet.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(PhRegular.downloadSimple, size: 18),
                    label: const Text('Update Sekarang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Checks for a newer release once a day when the app shell opens (Android only:
/// the update is an APK that the system installer puts over the current app).
class AutoUpdateCheck extends ConsumerStatefulWidget {
  final Widget child;
  const AutoUpdateCheck({super.key, required this.child});

  @override
  ConsumerState<AutoUpdateCheck> createState() => _AutoUpdateCheckState();
}

class _AutoUpdateCheckState extends ConsumerState<AutoUpdateCheck> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final info = await ref
            .read(appUpdateServiceProvider)
            .checkForUpdateDaily();
        if (!mounted || info == null || !info.isUpdateAvailable) return;
        await AppUpdateDialog.show(
          context,
          release: info.latestRelease!,
          currentVersion: info.currentVersion,
        );
      } catch (e) {
        debugPrint('[AutoUpdateCheck] $e'); // offline etc.: try again tomorrow
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
