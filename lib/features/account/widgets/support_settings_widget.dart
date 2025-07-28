import 'package:flutter/material.dart';
import 'settings_section_widget.dart';

class SupportSettingsWidget extends StatelessWidget {
  const SupportSettingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSectionWidget(
      title: 'Support',
      children: [
        SettingsTileWidget(
          icon: Icons.help_outline,
          title: 'Help & FAQ',
          subtitle: 'Get help and support',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Help section coming soon')),
            );
          },
        ),
        SettingsTileWidget(
          icon: Icons.info_outline,
          title: 'About',
          subtitle: 'App version and information',
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'Finoteku',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2025 Finoteku. All rights reserved.',
              children: [const Text('Personal Finance Manager')],
            );
          },
        ),
      ],
    );
  }
}
