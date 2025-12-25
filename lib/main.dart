import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
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
      // Initialize timezone database (light operation)
      // Note: NotificationService also handles this rigorously
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

      // Initialize Notification Service (CRITICAL)
      // Must be done early to setup channels and icon resources
      await NotificationService.initialize();
      if (kDebugMode) {
        print('✅ Notification Service initialized');
      }

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

      // Initialize connectivity monitoring (deferred, non-blocking)
      // Run in background to avoid blocking UI
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
        home: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Image.asset('assets/icon.png', width: 100, height: 100),
                const SizedBox(height: 24),

                // App Name
                const Text(
                  'Finoteku',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Loading indicator
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 16),

                // Loading text
                const Text(
                  'Initializing...',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
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
