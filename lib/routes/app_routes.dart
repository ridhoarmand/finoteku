import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/services/auth_service.dart';
import '../features/home/screens/home_screen.dart';
import '../features/notification/screens/notification_screen.dart';
import '../features/transaction/screens/transaction_screen.dart';
import '../features/chart/screens/chart_screen.dart';
import '../features/account/screens/account_screen.dart';
import '../features/account/screens/edit_profile_screen.dart';
import '../features/account/screens/change_password_screen.dart';
import '../features/settings/theme_settings_screen.dart';
import '../features/settings/language_settings_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/onboarding/screens/language_selection_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/wallet/screens/manage_wallets_screen.dart';
import '../features/category/screens/manage_categories_screen.dart';
import '../features/onboarding/providers/onboarding_provider.dart';
import '../features/onboarding/providers/language_preference_provider.dart';
import '../widgets/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Keep router instance alive to prevent recreations
  ref.keepAlive();

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false, // Disable debug logging for better performance
    redirect: (context, state) {
      final location = state.matchedLocation;

      // Allow splash screen to always load - let splash handle logic
      if (location == '/') return null;

      // Read providers individually to avoid blocking main thread
      final authState = ref.read(authStateProvider);
      final hasSeenOnboarding = ref.read(onboardingProvider);
      final hasLanguagePreference = ref.read(hasLanguagePreferenceProvider);

      // Handle auth state
      return authState.when(
        data: (auth) {
          final isAuthenticated = auth.session != null;

          // Handle language preference
          return hasLanguagePreference.when(
            data: (hasLangPref) {
              // First time user - show language selection if not set
              if (!hasLangPref && location != '/language-selection') {
                return '/language-selection';
              }

              // If language is set but onboarding not seen, show onboarding
              if (hasLangPref &&
                  !hasSeenOnboarding &&
                  location != '/onboarding') {
                return '/onboarding';
              }

              // Public routes (accessible when not authenticated)
              final publicRoutes = [
                '/login',
                '/login/register',
                '/login/forgot-password',
                '/onboarding',
                '/language-selection',
              ];
              final isPublicRoute = publicRoutes.contains(location);

              // If not authenticated, redirect to login (except for public routes)
              if (!isAuthenticated && !isPublicRoute) {
                return '/login';
              }

              // If authenticated and trying to access auth routes, redirect to home
              if (isAuthenticated &&
                  isPublicRoute &&
                  location != '/onboarding' &&
                  location != '/language-selection') {
                return '/home';
              }

              return null;
            },
            loading: () => null, // Allow navigation during loading
            error: (error, stackTrace) =>
                '/language-selection', // Default to language selection on error
          );
        },
        loading: () => null, // Allow navigation during loading
        error: (error, stackTrace) =>
            '/login', // Redirect to login on auth error
      );
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/language-selection',
        builder: (context, state) => const LanguageSelectionScreen(),
      ),
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
                path: 'edit-profile',
                builder: (context, state) => const EditProfileScreen(),
              ),
              GoRoute(
                path: 'change-password',
                builder: (context, state) => const ChangePasswordScreen(),
              ),
              GoRoute(
                path: 'theme-settings',
                builder: (context, state) => const ThemeSettingsScreen(),
              ),
              GoRoute(
                path: 'language-settings',
                builder: (context, state) => const LanguageSettingsScreen(),
              ),
              GoRoute(
                path: 'notifications',
                builder: (context, state) => const NotificationScreen(),
              ),
            ],
          ),
        ],
      ),
      // Wallet management route
      GoRoute(
        path: '/wallets/manage',
        builder: (context, state) => const ManageWalletsScreen(),
      ),
      // Category management route
      GoRoute(
        path: '/categories/manage',
        builder: (context, state) => const ManageCategoriesScreen(),
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
  static const String editProfile = '/account/edit-profile';
  static const String changePassword = '/account/change-password';
  static const String themeSettings = '/account/theme-settings';
  static const String notifications = '/account/notifications';
  static const String manageWallets = '/wallets/manage';
  static const String manageCategories = '/categories/manage';
}
