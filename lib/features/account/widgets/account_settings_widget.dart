import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'delete_account_dialog.dart';
import '../../../core/localization/app_localizations.dart';

class AccountSettingsWidget extends ConsumerWidget {
  const AccountSettingsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.tr(context, 'account_settings'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline),
              title: Text(ref.tr(context, 'change_password')),
              subtitle: Text(ref.tr(context, 'change_password_sub')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.go('/account/change-password');
              },
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline),
              title: Text(ref.tr(context, 'delete_account')),
              subtitle: Text(ref.tr(context, 'delete_account_sub')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDeleteAccountDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const DeleteAccountDialog(),
    );
  }
}
