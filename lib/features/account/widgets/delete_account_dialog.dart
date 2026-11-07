import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/delete_account_provider.dart';
import '../../auth/services/auth_service.dart';
import '../../../services/supabase_service.dart';
import '../../../core/localization/app_localizations.dart';

class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  ConsumerState<DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _showDataSummary = false;

  @override
  void initState() {
    super.initState();
    // Load user data summary
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deleteAccountProvider.notifier).loadUserDataSummary();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deleteState = ref.watch(deleteAccountProvider);
    final user = SupabaseService.currentUser;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            PhRegular.warning,
            color: Theme.of(context).colorScheme.error,
            size: 28,
          ),
          const SizedBox(width: 8),
          Text(ref.tr(context, 'delete_account_title')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.4),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        PhRegular.warningCircle,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ref.tr(context, 'delete_permanent_action'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ref.tr(context, 'delete_warning_message'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Data summary section
            if (deleteState.dataSummary != null &&
                deleteState.dataSummary!.hasData) ...[
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showDataSummary = !_showDataSummary;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhRegular.chartDonut,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ref.tr(context, 'delete_data_summary'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(
                        _showDataSummary
                            ? PhRegular.caretUp
                            : PhRegular.caretDown,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),

              if (_showDataSummary) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildDataRow(
                        ref.tr(context, 'delete_wallets'),
                        deleteState.dataSummary!.walletsCount,
                        PhRegular.wallet,
                      ),
                      _buildDataRow(
                        ref.tr(context, 'delete_categories'),
                        deleteState.dataSummary!.categoriesCount,
                        PhRegular.squaresFour,
                      ),
                      _buildDataRow(
                        ref.tr(context, 'delete_transactions'),
                        deleteState.dataSummary!.transactionsCount,
                        PhRegular.receipt,
                      ),
                      _buildDataRow(
                        ref.tr(context, 'delete_transfers'),
                        deleteState.dataSummary!.transfersCount,
                        PhRegular.arrowsLeftRight,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
            ],

            // Account info
            Text(
              '${ref.tr(context, 'delete_account_label')}: ${user?.email ?? 'Unknown'}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),

            const SizedBox(height: 16),

            // Password confirmation
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref.tr(context, 'delete_enter_password'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: ref.tr(context, 'delete_password_hint'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      suffixIcon: IconButton(
                        tooltip: ref.tr(context, 'toggle_password_visibility'),
                        icon: Icon(
                          _obscurePassword
                              ? PhRegular.eye
                              : PhRegular.eyeSlash,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return ref.tr(context, 'delete_password_required');
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),

            // Error message
            if (deleteState.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ref.tr(context, deleteState.error!),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: deleteState.isLoading
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: Text(ref.tr(context, 'delete_cancel')),
        ),
        ElevatedButton(
          onPressed: deleteState.isLoading ? null : _handleDeleteAccount,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: deleteState.isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onError,
                    ),
                  ),
                )
              : Text(ref.tr(context, 'delete_confirm_button')),
        ),
      ],
    );
  }

  Widget _buildDataRow(String label, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            count.toString(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final password = _passwordController.text.trim();

    // Show final confirmation
    final confirmed = await _showFinalConfirmation();
    if (!confirmed) return;

    // Attempt to delete account
    final success = await ref
        .read(deleteAccountProvider.notifier)
        .deleteAccount(password);

    if (success && mounted) {
      // Account deleted successfully
      Navigator.of(context).pop(); // Close dialog

      // Wait a bit for auth state to propagate
      await Future.delayed(const Duration(milliseconds: 500));

      // Force invalidate authentication providers
      ref.invalidate(currentUserProvider);
      ref.invalidate(authStateProvider);

      // Wait a bit more for providers to refresh
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.tr(context, 'delete_success')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Clear navigation stack and go to login to avoid black screen
      if (context.mounted) {
        while (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        context.go('/login');
      }
    }
  }

  Future<bool> _showFinalConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(ref.tr(context, 'delete_final_title')),
            content: Text(ref.tr(context, 'delete_final_message')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(ref.tr(context, 'delete_cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: Text(ref.tr(context, 'delete_yes_delete')),
              ),
            ],
          ),
        ) ??
        false;
  }
}
