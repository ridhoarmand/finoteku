import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../../../core/localization/app_localizations.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  int _cooldownSeconds = 0;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _cooldownSeconds = 60;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;

      setState(() {
        _cooldownSeconds--;
      });

      return _cooldownSeconds > 0;
    });
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.resetPassword(_emailController.text.trim());

      if (mounted) {
        setState(() {
          _emailSent = true;
        });
        _startCooldown();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.tr(context, 'reset_email_sent')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${ref.tr(context, 'failed_to_send_reset_email')}: ${e.toString()}',
            ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr(context, 'reset_password_title')),
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
                  ref.tr(context, 'reset_password_title'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _emailSent
                      ? ref.tr(context, 'reset_email_sent')
                      : ref.tr(context, 'reset_password_description'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                if (!_emailSent) ...[
                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: ref.tr(context, 'email_label'),
                      prefixIcon: const Icon(PhRegular.envelopeSimple),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return ref.tr(context, 'email_required');
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value!)) {
                        return ref.tr(context, 'email_invalid');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Reset Password Button
                  FilledButton(
                    onPressed: _isLoading ? null : _handleResetPassword,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(ref.tr(context, 'send_reset_link')),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // Success actions
                  FilledButton.icon(
                    onPressed: _cooldownSeconds > 0
                        ? null
                        : _handleResetPassword,
                    icon: const Icon(PhRegular.arrowClockwise),
                    label: Text(
                      _cooldownSeconds > 0
                          ? 'Wait $_cooldownSeconds s'
                          : ref.tr(context, 'resend_email'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Back to Login
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text(ref.tr(context, 'back_to_login')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
