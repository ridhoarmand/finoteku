import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/home/home_screen.dart';
import '../features/transaction/transaction_screen.dart';
import '../features/chart/chart_screen.dart';
import '../features/account/account_screen.dart';
import '../features/settings/theme_settings_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/splash/splash_screen.dart';
import '../services/auth_service.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final hasSeenOnboarding = ref.watch(onboardingProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final location = state.matchedLocation;

      // Allow splash screen to always load
      if (location == '/') return null;

      // Handle loading states
      return authState.when(
        data: (auth) {
          final isAuthenticated = auth.session != null;

          // First time user - show onboarding
          if (!hasSeenOnboarding && location != '/onboarding') {
            return '/onboarding';
          }

          // Public routes (accessible when not authenticated)
          final publicRoutes = [
            '/login',
            '/login/register',
            '/login/forgot-password',
            '/onboarding',
          ];
          final isPublicRoute = publicRoutes.contains(location);

          // If not authenticated, redirect to login (except for public routes)
          if (!isAuthenticated && !isPublicRoute) {
            return '/login';
          }

          // If authenticated and trying to access auth routes, redirect to home
          if (isAuthenticated && isPublicRoute && location != '/onboarding') {
            return '/home';
          }

          return null;
        },
        loading: () => null, // Allow navigation during loading
        error: (error, stackTrace) =>
            '/login', // Redirect to login on auth error
      );
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Login route dengan sub-routes untuk register dan forgot password
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
        routes: [
          // Register sebagai child route dari login
          GoRoute(
            path: 'register',
            builder: (context, state) => const RegisterScreen(),
          ),
          // Forgot password sebagai child route dari login
          GoRoute(
            path: 'forgot-password',
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
        ],
      ),
      // Shell route untuk main app dengan bottom navigation
      ShellRoute(
        builder: (context, state, child) {
          return MainShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/transaction',
            builder: (context, state) => const TransactionScreen(),
          ),
          GoRoute(
            path: '/chart',
            builder: (context, state) => const ChartScreen(),
          ),
          GoRoute(
            path: '/account',
            builder: (context, state) => const AccountScreen(),
            routes: [
              GoRoute(
                path: 'theme-settings',
                builder: (context, state) => const ThemeSettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'The page "${state.matchedLocation}" does not exist.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

// Constants for route paths
class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/login/register';
  static const String forgotPassword = '/login/forgot-password';
  static const String home = '/home';
  static const String transaction = '/transaction';
  static const String chart = '/chart';
  static const String account = '/account';
  static const String themeSettings = '/account/theme-settings';
}
