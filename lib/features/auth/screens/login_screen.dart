import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../../../services/supabase_service.dart';
import '../../../core/localization/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() {
    return _LoginScreenState();
  }
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    debugPrint('🔐 LoginScreen: initState called');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint('🔐 LoginScreen: didChangeDependencies called');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ref.tr(context, 'exit_app_title')),
        content: Text(ref.tr(context, 'exit_app_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(ref.tr(context, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(ref.tr(context, 'exit')),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  String _getErrorMessage(String errorString) {
    // Parse Supabase error messages to user-friendly messages
    if (errorString.contains('Invalid login credentials')) {
      return ref.tr(context, 'invalid_email_password');
    } else if (errorString.contains('Email not confirmed')) {
      return 'Please check your email and confirm your account before signing in.';
    } else if (errorString.contains('Too many requests')) {
      return 'Too many login attempts. Please wait a few minutes and try again.';
    } else if (errorString.contains('Network')) {
      return ref.tr(context, 'network_error');
    } else if (errorString.contains('timeout')) {
      return 'Request timeout. Please try again.';
    } else {
      return ref.tr(context, 'unknown_error');
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // Dismiss keyboard immediately when login starts
    FocusScope.of(context).unfocus();

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final authService = ref.read(authServiceProvider);
      debugPrint('🔐 Starting sign in process...');

      final response = await authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      debugPrint('✅ Sign in successful: ${response.session?.user.email}');

      if (mounted) {
        // Force refresh auth providers to trigger router redirect
        ref.invalidate(currentAuthProvider);
        ref.invalidate(currentUserProvider);
        debugPrint('🔄 Auth providers invalidated');

        // Save credentials to password manager after successful login
        TextInput.finishAutofillContext();

        debugPrint('🚀 Navigating to home...');

        // Small delay to ensure providers are refreshed
        await Future.delayed(const Duration(milliseconds: 100));

        // Reset loading state first
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        if (mounted) {
          // Navigate to home
          context.go('/home');
          debugPrint('📍 Navigation to /home completed');
        }
      }
    } catch (e) {
      debugPrint('❌ Login error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e.toString())),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: ref.tr(context, 'dismiss'),
              textColor: Colors.white,
              onPressed: () {
                if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                }
              },
            ),
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
    debugPrint('🔐 LoginScreen: build method called');
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          // Use SystemNavigator.pop() to properly exit the app
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: GestureDetector(
          onTap: () {
            // Dismiss keyboard when tapping outside input fields
            FocusScope.of(context).unfocus();
          },
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).viewPadding.top -
                      MediaQuery.of(context).viewPadding.bottom -
                      48,
                ),
                child: IntrinsicHeight(
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 32),
                          // App Logo/Title
                          Center(
                            child: SizedBox(
                              height: 140,
                              width: 140,
                              child: Image.asset(
                                'assets/icon_transparent.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Finoteku',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Personal Finance Manager',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 40),

                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: ref.tr(context, 'email_label'),
                              prefixIcon: const Icon(Icons.email),
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return ref.tr(context, 'email_required');
                              }
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value)) {
                                return ref.tr(context, 'email_invalid');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: ref.tr(context, 'password_label'),
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                tooltip: ref.tr(
                                  context,
                                  'toggle_password_visibility',
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  if (mounted) {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  }
                                },
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return ref.tr(context, 'password_required');
                              }
                              if (value.length < 6) {
                                return ref.tr(context, 'password_min_length');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Login Button
                          FilledButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(ref.tr(context, 'login_button')),
                          ),
                          const Spacer(),

                          // Forgot Password
                          Column(
                            children: [
                              TextButton(
                                onPressed: () {
                                  context.go('/login/forgot-password');
                                },
                                child: Text(ref.tr(context, 'forgot_password')),
                              ),

                              // Sign Up Link
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => context.go('/login/register'),
                                child: Text(
                                  ref.tr(context, 'create_new_account'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
