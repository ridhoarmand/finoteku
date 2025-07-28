import 'package:flutter/material.dart';
import 'settings_section_widget.dart';

class DataPrivacySettingsWidget extends StatelessWidget {
  const DataPrivacySettingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSectionWidget(
      title: 'Data & Privacy',
      children: [
        SettingsTileWidget(
          icon: Icons.backup_outlined,
          title: 'Backup & Sync',
          subtitle: 'Manage your data backup',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Backup settings coming soon'),
              ),
            );
          },
        ),
        SettingsTileWidget(
          icon: Icons.security_outlined,
          title: 'Privacy & Security',
          subtitle: 'Manage privacy settings',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Privacy settings coming soon'),
              ),
            );
          },
        ),
      ],
    );
  }
}
