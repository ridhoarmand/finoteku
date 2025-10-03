import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/theme_provider.dart';
import '../../core/localization/app_localizations.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    String t(String key) => ref.tr(context, key);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('theme_settings')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Options
            Text(
              t('choose_theme'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t('choose_theme_sub'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Theme Options Cards
            _buildThemeOption(
              context,
              theme,
              ThemeMode.light,
              themeMode,
              Icons.light_mode,
              t('light_mode'),
              t('light_mode_sub'),
              () => ref.read(themeModeProvider.notifier).setLightMode(),
            ),
            const SizedBox(height: 4),

            _buildThemeOption(
              context,
              theme,
              ThemeMode.dark,
              themeMode,
              Icons.dark_mode,
              t('dark_mode_full'),
              t('dark_mode_full_sub'),
              () => ref.read(themeModeProvider.notifier).setDarkMode(),
            ),
            const SizedBox(height: 4),

            _buildThemeOption(
              context,
              theme,
              ThemeMode.system,
              themeMode,
              Icons.brightness_auto,
              t('system_default'),
              t('system_default_sub'),
              () => ref.read(themeModeProvider.notifier).setSystemMode(),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeData theme,
    ThemeMode mode,
    ThemeMode currentMode,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final isSelected = mode == currentMode;

    return Card(
      elevation: isSelected ? 3 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
