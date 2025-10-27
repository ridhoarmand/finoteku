import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../notification/services/notification_service.dart';
import '../../services/user_service.dart';
import '../../services/connectivity_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../auth/services/auth_service.dart';
import '../onboarding/providers/onboarding_provider.dart';
import '../onboarding/providers/language_preference_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  String _statusText = 'Loading...';
  bool _isInitialized = false; // Add flag to prevent multiple initialization

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

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

  void _initializeAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 600), // Reduced further
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 400), // Reduced further
      vsync: this,
    );

    // Simple, efficient animations
    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));

    _textAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    // Start animations with optimal timing
    _logoController.forward();
    Timer(const Duration(milliseconds: 200), () {
      if (mounted) _textController.forward();
    });
  }

  void _updateStatus(String status) {
    if (mounted) {
      setState(() {
        _statusText = status;
      });
    }
  }

  String _safeTranslate(String key) {
    try {
      if (mounted) {
        return ref.tr(context, key);
      }
    } catch (e) {
      // Fallback if translation is not available
      switch (key) {
        case 'initializing_services':
          return 'Initializing services...';
        case 'checking_authentication':
          return 'Checking authentication...';
        case 'setting_up':
          return 'Setting up...';
        case 'loading_user_data':
          return 'Loading user data...';
        case 'ready':
          return 'Ready!';
        case 'something_went_wrong':
          return 'Something went wrong';
        case 'login_required_continue':
          return 'Login required to continue';
        default:
          return key;
      }
    }
    return key;
  }

  Future<void> _initializeApp() async {
    try {
      if (!mounted) return;

      // Check connectivity first with retry mechanism
      _updateStatus('Memeriksa koneksi...');

      try {
        final connectivityService = ref.read(connectivityServiceProvider);
        final isConnected = await connectivityService.waitUntilOnline(
          maxRetries: 5, // Reduced retries
          retryDelay: const Duration(seconds: 1),
        );

        if (!isConnected) {
          if (!mounted) return;
          _updateStatus('Tidak dapat terhubung ke internet');
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

      if (!mounted) return;
      _updateStatus(_safeTranslate('initializing_services'));

      // Initialize notification service efficiently
      await _initializeServices();

      if (!mounted) return;
      _updateStatus(_safeTranslate('checking_authentication'));

      // Determine correct navigation destination based on app state
      await _navigateToCorrectDestination();
    } catch (e) {
      if (!mounted) return;
      _updateStatus(_safeTranslate('something_went_wrong'));
      await Future.delayed(const Duration(milliseconds: 500));
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

            _updateStatus(_safeTranslate('ready'));
            await Future.delayed(const Duration(milliseconds: 200));

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
      final userService = ref.read(userServiceProvider);
      await NotificationService.initialize(userService: userService);
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
          title: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red),
              SizedBox(width: 12),
              Text('Tidak Ada Koneksi'),
            ],
          ),
          content: const Text(
            'Aplikasi ini memerlukan koneksi internet untuk berjalan. '
            'Pastikan Anda terhubung ke internet dan coba lagi.',
          ),
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
              child: const Text('Coba Lagi'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get theme mode to ensure consistent background
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Logo
            AnimatedBuilder(
              animation: _logoAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _logoAnimation.value,
                  child: Image.asset(
                    'assets/icon.png',
                    width: 120,
                    height: 120,
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Animated App Name
            AnimatedBuilder(
              animation: _textAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _textAnimation.value,
                  child: Text(
                    'Finoteku',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 2,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            // Animated Status Text and Loading Indicator
            AnimatedBuilder(
              animation: _textAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _textAnimation.value,
                  child: Column(
                    children: [
                      // Loading Indicator
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Status Text
                      Text(
                        _statusText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
