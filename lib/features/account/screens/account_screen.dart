import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase_service.dart';
import '../widgets/profile_section_widget.dart';
import '../../setting/preferences_settings_widget.dart';
import '../widgets/wallet_category_settings_widget.dart';
import '../widgets/support_settings_widget.dart';
import '../widgets/logout_button_widget.dart';
import '../../../core/localization/app_localizations.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr(context, 'account_title')),
        automaticallyImplyLeading: false,
      ),
      body: currentUser.when(
        data: (user) => SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              // Profile Section
              ProfileSectionWidget(user: user),
              // Wallet & Categories Section
              const WalletCategorySettingsWidget(),
              // Preferences Section
              const PreferencesSettingsWidget(),
              // Support Section
              const SupportSettingsWidget(),
              // Logout Button
              const LogoutButtonWidget(),
              const SizedBox(height: 12),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhRegular.warningCircle,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                ref.tr(context, 'error_loading_user'),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.refresh(currentUserProvider),
                child: Text(ref.tr(context, 'retry')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
