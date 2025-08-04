import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../routes/app_routes.dart';
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
          onTap: () {
            context.push(AppRoutes.manageWallets);
          },
        ),
        SettingsTileWidget(
          icon: Icons.category_outlined,
          title: 'Manage Categories',
          subtitle: 'Organize your transaction categories',
          onTap: () {
            context.push(AppRoutes.manageCategories);
          },
        ),
      ],
    );
  }
}
