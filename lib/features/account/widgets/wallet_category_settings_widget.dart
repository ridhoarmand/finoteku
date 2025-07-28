import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'settings_section_widget.dart';

class WalletCategorySettingsWidget extends StatelessWidget {
  const WalletCategorySettingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSectionWidget(
      title: 'Wallet & Categories',
      children: [
        SettingsTileWidget(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Manage Wallets',
          subtitle: 'Add, edit, or delete your wallets',
          iconColor: Colors.green,
          onTap: () {
            context.push('/wallets/manage');
          },
        ),
        SettingsTileWidget(
          icon: Icons.category_outlined,
          title: 'Manage Categories',
          subtitle: 'Organize your transaction categories',
          iconColor: Colors.blue,
          onTap: () {
            context.push('/categories/manage');
          },
        ),
        SettingsTileWidget(
          icon: Icons.swap_horiz_outlined,
          title: 'Default Settings',
          subtitle: 'Set default wallet and categories',
          iconColor: Colors.orange,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Default settings coming soon'),
              ),
            );
          },
        ),
        SettingsTileWidget(
          icon: Icons.import_export_outlined,
          title: 'Import/Export',
          subtitle: 'Import or export wallets and categories',
          iconColor: Colors.purple,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Import/Export feature coming soon'),
              ),
            );
          },
        ),
      ],
    );
  }
}
