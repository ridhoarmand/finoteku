import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../notification/services/notification_service.dart';
import '../../services/user_service.dart';
import '../../core/localization/app_localizations.dart';

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
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );

    _logoController.forward();
    Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _textController.forward();
      }
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
      _updateStatus(_safeTranslate('initializing_services'));

      // Run initialization tasks in parallel to reduce blocking
      final futures = <Future>[
        // Initialize notification service with user service (non-blocking)
        Future(() async {
          try {
            final userService = ref.read(userServiceProvider);
            await NotificationService.initialize(userService: userService);
          } catch (e) {
            // Ignore notification init errors for now
          }
        }),

        // Minimum splash delay
        Future.delayed(const Duration(milliseconds: 2000)),
      ];

      if (!mounted) return;
      _updateStatus(_safeTranslate('checking_authentication'));

      // Wait for all parallel tasks to complete
      await Future.wait(futures);

      if (!mounted) return;
      _updateStatus(_safeTranslate('ready'));

      // Brief delay to show ready status, then navigate
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // Simple navigation trigger - let router redirect logic handle the rest
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      _updateStatus(_safeTranslate('something_went_wrong'));
      await Future.delayed(const Duration(milliseconds: 1000));
      // On error, go to login
      if (mounted) context.go('/login');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
