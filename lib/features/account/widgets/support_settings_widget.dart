import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_section_widget.dart';
import '../../../core/localization/app_localizations.dart';

class SupportSettingsWidget extends ConsumerWidget {
  const SupportSettingsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSectionWidget(
      title: ref.tr(context, 'support_section'),
      children: [
        SettingsTileWidget(
          icon: Icons.help_outline,
          title: ref.tr(context, 'help_faq'),
          subtitle: ref.tr(context, 'help_faq_sub'),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ref.tr(context, 'help_faq_sub'))),
            );
          },
        ),
        SettingsTileWidget(
          icon: Icons.info_outline,
          title: ref.tr(context, 'about'),
          subtitle: ref.tr(context, 'about_sub'),
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'Finoteku',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2025 Finoteku',
              children: [Text(ref.tr(context, 'about_app_description'))],
            );
          },
        ),
      ],
    );
  }
}
