import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'utils/desktop_window.dart'
    if (dart.library.html) 'utils/desktop_window_stub.dart';
import 'routes/app_routes.dart';
import 'core/localization/locale_provider.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'services/supabase_service.dart';
import 'services/connectivity_service.dart';
import 'utils/environment.dart';

import 'features/notification/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure desktop window (no-op on web/mobile)
  await configureDesktopWindow();

  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await NotificationService.setLocalTimezone();

      // Initialize environment variables first (must be sequential)
      await Environment.initialize();

      // Validate environment configuration
      if (!Environment.validateConfig()) {
        if (kDebugMode) {
          print('⚠️ Environment configuration validation failed');
          print('📝 Please check your .env file configuration');
        }
      }

      // Initialize Supabase after environment is loaded
      try {
        await SupabaseService.initialize(
          url: Environment.supabaseUrl,
          anonKey: Environment.supabaseAnonKey,
        );
        if (kDebugMode) {
          print('✅ Supabase initialized successfully');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Failed to initialize Supabase: $e');
          print('📝 Please configure your Supabase credentials in .env file');
        }
        // Continue anyway for demo purposes
      }

      // Initialize platform-specific services in background (non-blocking)
      // Skip on web to avoid channel buffer warnings
      if (!kIsWeb) {
        // Initialize Notification Service (CRITICAL on mobile/desktop)
        NotificationService.initialize(navigatorKey: rootNavigatorKey)
            .then((_) {
              if (kDebugMode) {
                print('✅ Notification Service initialized');
              }
            })
            .catchError((e) {
              if (kDebugMode) {
                print('❌ Failed to initialize notifications: $e');
              }
            });

        // Initialize connectivity monitoring (deferred, non-blocking)
        ConnectivityService()
            .initialize()
            .then((_) {
              if (kDebugMode) {
                print('✅ Connectivity service initialized');
              }
            })
            .catchError((e) {
              if (kDebugMode) {
                print('❌ Failed to initialize connectivity service: $e');
              }
            });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Critical initialization error: $e');
      }
      // Continue to show app even with initialization errors
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        // Builder: Theme.of must be read below MaterialApp to get the app theme.
        // Same look as SplashScreen so the hand-over is seamless.
        home: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icon_transparent.png',
                      width: 100,
                      height: 100,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Finoteku',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    final localeState = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      title: 'Finoteku',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      locale: localeState.effectiveLocale,
      supportedLocales: const [Locale('en'), Locale('id')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
