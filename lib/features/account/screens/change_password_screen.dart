import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/services/auth_service.dart';
import '../../../core/localization/app_localizations.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = ref.read(authServiceProvider);

      // Verify current password first
      final isPasswordCorrect = await authService.verifyPassword(
        _currentPasswordController.text,
      );

      if (!isPasswordCorrect) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ref.tr(context, 'error_current_password_incorrect'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Update to new password
      await authService.updatePassword(_newPasswordController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.tr(context, 'password_changed_success')),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to account screen
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(String errorString) {
    if (errorString.contains('Password should be at least 6 characters')) {
      return ref.tr(context, 'password_error_too_short');
    } else if (errorString.contains('password_error_same') ||
        errorString.contains('New password should be different')) {
      return ref.tr(context, 'password_error_same');
    } else if (errorString.contains('Network')) {
      return ref.tr(context, 'password_error_network');
    } else if (errorString.contains('timeout')) {
      return ref.tr(context, 'password_error_timeout');
    } else {
      return ref.tr(context, 'password_error_generic');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr(context, 'change_password_title')),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(PhRegular.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Icon(
                  PhRegular.lockKey,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  ref.tr(context, 'change_password_header'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  ref.tr(context, 'change_password_description'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                // Current Password Field
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrentPassword,
                  decoration: InputDecoration(
                    labelText: ref.tr(context, 'current_password'),
                    prefixIcon: const Icon(PhRegular.lockKey),
                    suffixIcon: IconButton(
                      tooltip: ref.tr(context, 'toggle_password_visibility'),
                      icon: Icon(
                        _obscureCurrentPassword
                            ? PhRegular.eye
                            : PhRegular.eyeSlash,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureCurrentPassword = !_obscureCurrentPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return ref.tr(context, 'current_password_required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // New Password Field
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: ref.tr(context, 'new_password'),
                    prefixIcon: const Icon(PhRegular.lock),
                    suffixIcon: IconButton(
                      tooltip: ref.tr(context, 'toggle_password_visibility'),
                      icon: Icon(
                        _obscureNewPassword
                            ? PhRegular.eye
                            : PhRegular.eyeSlash,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return ref.tr(context, 'password_required');
                    }
                    if (value!.length < 6) {
                      return ref.tr(context, 'password_min_length');
                    }
                    if (value == _currentPasswordController.text) {
                      return ref.tr(context, 'password_error_same');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm New Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: ref.tr(context, 'confirm_new_password'),
                    prefixIcon: const Icon(PhRegular.lock),
                    suffixIcon: IconButton(
                      tooltip: ref.tr(context, 'toggle_password_visibility'),
                      icon: Icon(
                        _obscureConfirmPassword
                            ? PhRegular.eye
                            : PhRegular.eyeSlash,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return ref.tr(context, 'password_confirm_required');
                    }
                    if (value != _newPasswordController.text) {
                      return ref.tr(context, 'passwords_not_match');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Change Password Button
                FilledButton(
                  onPressed: _isLoading ? null : _handleChangePassword,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(ref.tr(context, 'change_password_button')),
                ),
                const SizedBox(height: 16),

                // Security Notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            PhRegular.info,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ref.tr(context, 'security_tips'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ref.tr(context, 'security_tips_content'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
