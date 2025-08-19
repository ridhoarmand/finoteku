import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../routes/app_routes.dart';
import 'settings_section_widget.dart';
import '../../../core/localization/app_localizations.dart';

class WalletCategorySettingsWidget extends ConsumerWidget {
  const WalletCategorySettingsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSectionWidget(
      title: ref.tr(context, 'wallet_categories_section'),
      children: [
        SettingsTileWidget(
          icon: Icons.account_balance_wallet_outlined,
          title: ref.tr(context, 'manage_wallets'),
          subtitle: ref.tr(context, 'manage_wallets_sub'),
          onTap: () {
            context.push(AppRoutes.manageWallets);
          },
        ),
        SettingsTileWidget(
          icon: Icons.category_outlined,
          title: ref.tr(context, 'manage_categories'),
          subtitle: ref.tr(context, 'manage_categories_sub'),
          onTap: () {
            context.push(AppRoutes.manageCategories);
          },
        ),
      ],
    );
  }
}
