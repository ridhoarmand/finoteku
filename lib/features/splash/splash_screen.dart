import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../auth/services/auth_service.dart';
import '../onboarding/providers/onboarding_provider.dart';
import '../../services/supabase_service.dart';
import '../category/providers/category_providers.dart';
import '../notification/services/notification_service.dart';
import '../../services/user_service.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeApp();
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

  Future<void> _initializeApp() async {
    try {
      if (!mounted) return;
      _updateStatus('Initializing services...');

      // Initialize notification service with user service
      final userService = ref.read(userServiceProvider);
      await NotificationService.initialize(userService: userService);

      if (!mounted) return;
      _updateStatus('Checking authentication...');

      // Show splash for minimum 2 seconds for better UX and animation
      final minDelay = Future.delayed(const Duration(milliseconds: 2000));

      if (!mounted) return;

      // Check authentication status
      final authState = ref.read(authStateProvider);

      await authState.when(
        data: (auth) async {
          if (!mounted) return;
          
          final isAuthenticated = auth.session != null;
          final hasSeenOnboarding = ref.read(onboardingProvider);

          if (!hasSeenOnboarding) {
            if (!mounted) return;
            _updateStatus('Setting up...');
            await minDelay;
            if (mounted) context.go('/onboarding');
            return;
          }

          if (!isAuthenticated) {
            if (!mounted) return;
            _updateStatus('Please login to continue');
            await minDelay;
            if (mounted) context.go('/login');
            return;
          }

          // User is authenticated - load user data
          if (!mounted) return;
          _updateStatus('Loading user data...');
          
          final currentUserAsync = ref.read(currentUserProvider);
          await currentUserAsync.when(
            data: (user) async {
              if (!mounted) return;
              if (user != null) {
                // Preload user categories
                try {
                  ref.read(categoriesProvider(user.id));
                } catch (e) {
                  // Ignore preload errors
                }
              }
            },
            loading: () async {
              // Still loading user data
            },
            error: (_, _) async {
              // User data error, that's fine
            },
          );

          if (!mounted) return;
          _updateStatus('Ready!');
          await minDelay;
          if (mounted) context.go('/home');
        },
        loading: () async {
          if (!mounted) return;
          _updateStatus('Loading...');
          await minDelay;
          // GoRouter redirect will handle this
        },
        error: (_, _) async {
          if (!mounted) return;
          _updateStatus('Please login to continue');
          await minDelay;
          if (mounted) context.go('/login');
        },
      );
    } catch (e) {
      if (!mounted) return;
      _updateStatus('Something went wrong');
      await Future.delayed(const Duration(seconds: 2));
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
