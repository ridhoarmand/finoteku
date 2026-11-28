import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../notification/services/notification_service.dart';
import '../../services/connectivity_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../widgets/app_splash.dart';
import '../auth/services/auth_service.dart';
import '../onboarding/providers/onboarding_provider.dart';
import '../onboarding/providers/language_preference_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _isInitialized = false; // Add flag to prevent multiple initialization

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Call _initializeApp after widget tree is fully built, only once
    if (!_isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isInitialized) {
          _isInitialized = true;
          _initializeApp();
        }
      });
    }
  }

  Future<void> _initializeApp() async {
    try {
      if (!mounted) return;

      // Quick connectivity check (non-blocking). Skip on web to avoid CORS/flags.
      if (!kIsWeb) {
        try {
          final connectivityService = ref.read(connectivityServiceProvider);
          // Quick check only, no retry to avoid blocking
          final isConnected = await connectivityService.checkConnectivity();

          if (!isConnected) {
            if (!mounted) return;
            // Show retry dialog
            await _showRetryDialog();
            return;
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Connectivity check skipped: $e');
          }
          // Continue even if connectivity check fails
        }
      }

      if (!mounted) return;

      // Initialize notification service efficiently
      await _initializeServices();

      if (!mounted) return;

      // Determine correct navigation destination based on app state
      await _navigateToCorrectDestination();
    } catch (e) {
      if (mounted) context.go('/login');
    }
  }

  // Smart navigation based on app state
  Future<void> _navigateToCorrectDestination() async {
    if (!mounted) return;

    // Check authentication state
    final authState = ref.read(authStateProvider);
    final hasSeenOnboarding = ref.read(onboardingProvider);
    final hasLanguagePreference = ref.read(hasLanguagePreferenceProvider);

    await authState.when(
      data: (auth) async {
        final isAuthenticated = auth.session != null;

        await hasLanguagePreference.when(
          data: (hasLangPref) async {
            if (!mounted) return;

            String destination;

            // First time user - language selection
            if (!hasLangPref) {
              destination = '/language-selection';
            }
            // Language set but onboarding not seen
            else if (hasLangPref && !hasSeenOnboarding) {
              destination = '/onboarding';
            }
            // Not authenticated - login
            else if (!isAuthenticated) {
              destination = '/login';
            }
            // Authenticated - home
            else {
              destination = '/home';
            }


            if (mounted) context.go(destination);
          },
          loading: () async {
            if (mounted) context.go('/language-selection');
          },
          error: (_, stackTrace) async {
            if (mounted) context.go('/language-selection');
          },
        );
      },
      loading: () async {
        // Wait a bit for auth state to load
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) context.go('/login');
      },
      error: (_, stackTrace) async {
        if (mounted) context.go('/login');
      },
    );
  }

  // Efficient service initialization
  Future<void> _initializeServices() async {
    try {
      await NotificationService.initialize();
    } catch (e) {
      // Ignore notification init errors - non-critical
    }
  }

  // Show retry dialog when connection fails
  Future<void> _showRetryDialog() async {
    if (!mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(PhRegular.wifiSlash, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 12),
              Text(ref.tr(context, 'no_connection_title')),
            ],
          ),
          content: Text(ref.tr(context, 'no_connection_body')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Retry initialization
                if (mounted) {
                  _isInitialized = false;
                  _initializeApp();
                }
              },
              child: Text(ref.tr(context, 'retry')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => const AppSplash();
}
