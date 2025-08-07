import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../auth/services/auth_service.dart';
import '../onboarding/providers/onboarding_provider.dart';
import '../../services/supabase_service.dart';

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
  
  String _statusText = 'Initializing...';
  
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

    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _textAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    ));

    _logoController.forward();
    Timer(const Duration(milliseconds: 500), () {
      _textController.forward();
    });
  }

  Future<void> _initializeApp() async {
    try {
      // Show splash for minimum 1.5 seconds for better UX
      final minDelay = Future.delayed(const Duration(milliseconds: 1500));
      
      if (!mounted) return;

      // Check authentication status
      _updateStatus('Checking authentication...');
      final authState = ref.read(authStateProvider);
      
      await authState.when(
        data: (auth) async {
          final isAuthenticated = auth.session != null;
          final hasSeenOnboarding = ref.read(onboardingProvider);

          if (!hasSeenOnboarding) {
            _updateStatus('Preparing onboarding...');
            await minDelay;
            if (mounted) context.go('/onboarding');
            return;
          }

          if (!isAuthenticated) {
            _updateStatus('Redirecting to login...');
            await minDelay;
            if (mounted) context.go('/login');
            return;
          }

          // User is authenticated - data already synced during login
          _updateStatus('Loading app...');
          
          // Get current user untuk memastikan user data available
          final currentUserAsync = ref.read(currentUserProvider);
          await currentUserAsync.when(
            data: (user) async {
              if (user != null) {
                _updateStatus('User data loaded');
              }
            },
            loading: () async => _updateStatus('Loading user data...'),
            error: (_, _) async => _updateStatus('Error loading user data'),
          );

          _updateStatus('Loading app...');
          await minDelay;
          if (mounted) context.go('/home');
        },
        loading: () async {
          _updateStatus('Loading...');
          await minDelay;
          // GoRouter redirect will handle this
        },
        error: (_, _) async {
          _updateStatus('Authentication error');
          await minDelay;
          if (mounted) context.go('/login');
        },
      );
    } catch (e) {
      _updateStatus('Initialization error');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) context.go('/login');
    }
  }

  void _updateStatus(String status) {
    if (mounted) {
      setState(() {
        _statusText = status;
      });
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
            
            // Status Text with Progress Indicator
            AnimatedBuilder(
              animation: _textAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _textAnimation.value,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _statusText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
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
