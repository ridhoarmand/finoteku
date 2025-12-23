import 'package:flutter/material.dart';
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
          Icon(Icons.warning_amber_rounded, color: Colors.red[600], size: 28),
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
                color: Colors.red[50],
                border: Border.all(color: Colors.red[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ref.tr(context, 'delete_permanent_action'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ref.tr(context, 'delete_warning_message'),
                    style: TextStyle(color: Colors.red[600], fontSize: 13),
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
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.data_usage, color: Colors.grey[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ref.tr(context, 'delete_data_summary'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(
                        _showDataSummary
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.grey[600],
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
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildDataRow(
                        ref.tr(context, 'delete_wallets'),
                        deleteState.dataSummary!.walletsCount,
                        Icons.account_balance_wallet,
                      ),
                      _buildDataRow(
                        ref.tr(context, 'delete_categories'),
                        deleteState.dataSummary!.categoriesCount,
                        Icons.category,
                      ),
                      _buildDataRow(
                        ref.tr(context, 'delete_transactions'),
                        deleteState.dataSummary!.transactionsCount,
                        Icons.receipt_long,
                      ),
                      _buildDataRow(
                        ref.tr(context, 'delete_transfers'),
                        deleteState.dataSummary!.transfersCount,
                        Icons.swap_horiz,
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
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
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
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[200]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  deleteState.error!,
                  style: TextStyle(color: Colors.red[700], fontSize: 13),
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
            backgroundColor: Colors.red[600],
            foregroundColor: Colors.white,
          ),
          child: deleteState.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.tr(context, 'delete_success')),
          backgroundColor: Colors.green,
        ),
      );

      // Clear navigation stack and navigate to login page
      if (context.mounted) {
        while (context.canPop()) {
          context.pop();
        }
        context.pushReplacement('/login');
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
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                ),
                child: Text(ref.tr(context, 'delete_yes_delete')),
              ),
            ],
          ),
        ) ??
        false;
  }
}
