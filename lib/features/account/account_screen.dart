import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/supabase_service.dart';
import 'widgets/profile_section_widget.dart';
import 'widgets/preferences_settings_widget.dart';
import 'widgets/data_privacy_settings_widget.dart';
import 'widgets/wallet_category_settings_widget.dart';
import 'widgets/support_settings_widget.dart';
import 'widgets/logout_button_widget.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        automaticallyImplyLeading: false,
      ),
      body: currentUser.when(
        data: (user) => SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Profile Section
              ProfileSectionWidget(user: user),
              const SizedBox(height: 24),

              // Wallet & Categories Section
              const WalletCategorySettingsWidget(),
              const SizedBox(height: 16),

              // Data & Privacy Section
              const DataPrivacySettingsWidget(),
              const SizedBox(height: 16),

              // Support Section
              // Preferences Section
              const PreferencesSettingsWidget(),
              const SizedBox(height: 16),

              const SupportSettingsWidget(),
              const SizedBox(height: 24),

              // Logout Button
              const LogoutButtonWidget(),
              const SizedBox(height: 16),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading user data',
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
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
