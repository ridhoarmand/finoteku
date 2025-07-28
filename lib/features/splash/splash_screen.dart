import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../onboarding/providers/onboarding_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Show splash for minimum 2 seconds for better UX
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check authentication and onboarding status
    final authState = ref.read(authStateProvider);
    final hasSeenOnboarding = ref.read(onboardingProvider);

    authState.when(
      data: (auth) {
        final isAuthenticated = auth.session != null;

        if (!hasSeenOnboarding) {
          // First time user - go to onboarding
          context.go('/onboarding');
        } else if (!isAuthenticated) {
          // Returning user but not authenticated - go to login
          context.go('/login');
        } else {
          // Authenticated user - go to home
          context.go('/home');
        }
      },
      loading: () {
        // Still loading auth state, stay on splash
        // GoRouter redirect will handle this
      },
      error: (_, _) {
        // Error loading auth state - go to login
        context.go('/login');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icon.png', width: 120, height: 120),
            const SizedBox(height: 24),
            Text(
              'Finoteku',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
