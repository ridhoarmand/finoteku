import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'settings_section_widget.dart';

class PreferencesSettingsWidget extends StatelessWidget {
  const PreferencesSettingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSectionWidget(
      title: 'Preferences',
      children: [
        SettingsTileWidget(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Manage your notification preferences',
          onTap: () {
                              context.push('/account/notifications');
          },
        ),
        SettingsTileWidget(
          icon: Icons.dark_mode_outlined,
          title: 'Dark Mode',
          subtitle: 'Toggle app theme',
          onTap: () {
            context.push('/account/theme-settings');
          },
        ),
        SettingsTileWidget(
          icon: Icons.language_outlined,
          title: 'Language',
          subtitle: 'Change app language',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Language settings coming soon'),
              ),
            );
          },
        ),
      ],
    );
  }
}
