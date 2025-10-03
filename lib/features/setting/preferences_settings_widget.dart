import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../account/widgets/settings_section_widget.dart';
import '../../core/localization/app_localizations.dart';

class PreferencesSettingsWidget extends ConsumerWidget {
  const PreferencesSettingsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => ref.tr(context, key);
    return SettingsSectionWidget(
      title: t('preferences'),
      children: [
        SettingsTileWidget(
          icon: Icons.notifications_outlined,
          title: t('notifications'),
          subtitle: t('notifications_sub'),
          onTap: () => context.push('/account/notifications'),
        ),
        SettingsTileWidget(
          icon: Icons.dark_mode_outlined,
          title: t('dark_mode'),
          subtitle: t('dark_mode_sub'),
          onTap: () => context.push('/account/theme-settings'),
        ),
        SettingsTileWidget(
          icon: Icons.language_outlined,
          title: t('language'),
          subtitle: t('language_sub'),
          onTap: () => context.push('/account/language-settings'),
        ),
      ],
    );
  }
}
