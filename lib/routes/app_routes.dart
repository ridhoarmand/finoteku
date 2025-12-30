import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/auth/services/auth_service.dart';
import '../features/onboarding/providers/onboarding_provider.dart';
import '../features/onboarding/providers/language_preference_provider.dart';
import '../features/home/screens/home_screen.dart';
import '../features/notification/screens/notification_screen.dart';
import '../features/transaction/screens/transaction_screen.dart';
import '../features/report/screens/report_screen.dart';
import '../features/account/screens/account_screen.dart';
import '../features/account/screens/edit_profile_screen.dart';
import '../features/account/screens/change_password_screen.dart';
import '../features/setting/theme_settings_screen.dart';
import '../features/setting/language_settings_screen.dart';
import '../features/help/screens/faq_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/onboarding/screens/language_selection_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/wallet/screens/manage_wallets_screen.dart';
import '../features/category/screens/manage_categories_screen.dart';
import '../features/category/screens/category_selection_screen.dart';
import '../features/category/screens/add_edit_category_screen.dart';
import '../models/category.dart';
import '../features/transaction/screens/wallet_selection_screen.dart';
import '../features/transaction/screens/add_edit_transaction_screen.dart';
import '../widgets/main_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Keep router instance alive to prevent recreations
  ref.keepAlive();

  // Watch providers for router rebuilds
  ref.watch(currentAuthProvider);
  ref.watch(hasLanguagePreferenceProvider);
  ref.watch(onboardingProvider);
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: false, // Keep false for production
    redirect: (context, state) {
      final location = state.matchedLocation;
      debugPrint('🚦 Router redirect check: $location');

      // Check for password recovery event specifically (Priority High)
      // This must be checked before other logic to ensure the reset screen opens
      final authEvent = authState.asData?.value.event;
      if (authEvent == AuthChangeEvent.passwordRecovery) {
        debugPrint(
          '🔑 Password recovery event detected, redirecting to reset password',
        );
        return '/reset-password';
      }

      // Allow splash screen to handle initial routing
      if (location == '/') return null;

      // Check app state for proper navigation flow
      final isAuthenticated = ref.read(currentAuthProvider);
      final hasLanguagePreferenceAsync = ref.read(
        hasLanguagePreferenceProvider,
      );

      // Safe reading of onboarding provider to avoid race conditions
      bool hasSeenOnboarding;
      try {
        hasSeenOnboarding = ref.read(onboardingProvider);
      } catch (e) {
        // If provider is rebuilding, assume onboarding not seen
        debugPrint('⚠️ Onboarding provider rebuilding, assuming false');
        hasSeenOnboarding = false;
      }

      debugPrint('🔐 Auth: $isAuthenticated, Location: $location');

      // Public routes (accessible when not authenticated)
      final publicRoutes = [
        '/login',
        '/login/register',
        '/login/forgot-password',
        '/onboarding',
        '/language-selection',
        '/reset-password',
      ];
      final isPublicRoute = publicRoutes.contains(location);

      // Handle language preference check
      // Handle language preference check
      final redirectResult = hasLanguagePreferenceAsync.when(
        data: (hasLangPref) {
          debugPrint(
            '📝 Lang pref: $hasLangPref, Onboarding: $hasSeenOnboarding',
          );

          // Fresh install flow: language -> onboarding -> login/home
          if (!hasLangPref && location != '/language-selection') {
            debugPrint(
              '❌ No language preference, redirecting to language selection',
            );
            return '/language-selection';
          }

          // Language set but onboarding not seen
          if (hasLangPref && !hasSeenOnboarding && location != '/onboarding') {
            debugPrint(
              '❌ Language set but onboarding not seen, redirecting to onboarding',
            );
            return '/onboarding';
          }

          // Onboarding completed, check authentication
          if (hasLangPref && hasSeenOnboarding) {
            // If not authenticated and trying to access protected route
            if (!isAuthenticated && !isPublicRoute) {
              debugPrint('❌ Not authenticated, redirecting to login');
              return '/login';
            }

            // If authenticated and trying to access login routes only
            if (isAuthenticated && location == '/login') {
              debugPrint(
                '✅ Authenticated user on login page, redirecting to home',
              );
              return '/home';
            }
          }

          // Special case: After onboarding completion, redirect to login
          if (hasLangPref &&
              hasSeenOnboarding &&
              !isAuthenticated &&
              location == '/onboarding') {
            debugPrint('✅ Onboarding completed, redirecting to login');
            return '/login';
          }

          debugPrint('✅ No redirect needed');
          return null;
        },
        loading: () {
          // While loading language preference, allow splash screen
          if (location == '/') return null;
          // Otherwise redirect to language selection as safe fallback
          return '/language-selection';
        },
        error: (error, stackTrace) {
          // On error, start fresh install flow
          debugPrint(
            '❌ Error checking language preference: $error, redirecting to language selection',
          );
          return '/language-selection';
        },
      );

      return redirectResult;
    },
    routes: [
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
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
            path: '/reports',
            builder: (context, state) => const ReportScreen(),
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
              GoRoute(
                path: 'help-faq',
                builder: (context, state) => const FAQScreen(),
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
      // Wallet selection route
      GoRoute(
        path: '/wallets/select',
        builder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ?? '';
          final title = state.uri.queryParameters['title'] ?? 'Select Wallet';
          return WalletSelectionScreen(userId: userId, title: title);
        },
      ),
      // Category management route
      GoRoute(
        path: '/categories/manage',
        builder: (context, state) => const ManageCategoriesScreen(),
      ),
      // Add/Edit category route
      GoRoute(
        path: '/categories/add-edit',
        builder: (context, state) {
          final typeParam = state.uri.queryParameters['type'] ?? 'expense';
          final categoryType = typeParam == 'income'
              ? CategoryType.income
              : CategoryType.expense;

          // For edit mode, you would need to fetch the category data
          // For now, using navigation with direct object passing is simpler
          return AddEditCategoryScreen(categoryType: categoryType);
        },
      ),
      // Category selection route
      GoRoute(
        path: '/categories/select',
        builder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ?? '';
          final title = state.uri.queryParameters['title'] ?? 'Select Category';
          return CategorySelectionScreen(userId: userId, title: title);
        },
      ),
      // Add transaction route
      GoRoute(
        path: '/transaction/add',
        builder: (context, state) => const AddEditTransactionScreen(),
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
  static const String reports = '/reports';
  static const String account = '/account';
  static const String editProfile = '/account/edit-profile';
  static const String changePassword = '/account/change-password';
  static const String themeSettings = '/account/theme-settings';
  static const String notifications = '/account/notifications';
  static const String helpFAQ = '/account/help-faq';
  static const String manageWallets = '/wallets/manage';
  static const String selectWallet = '/wallets/select';
  static const String manageCategories = '/categories/manage';
  static const String selectCategory = '/categories/select';
}
