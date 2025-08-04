import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'utils/environment.dart';
import 'widgets/app_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone database
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

  // Initialize environment variables from .env file
  await Environment.initialize();

  // Validate environment configuration
  if (!Environment.validateConfig()) {
    if (kDebugMode) {
      print('⚠️ Environment configuration validation failed');
      print('📝 Please check your .env file configuration');
    }
  }

  // Print configuration in debug mode
  Environment.printConfig();

  // Initialize Supabase with environment variables
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

  // Initialize notification service on startup (non-blocking)
  NotificationService.initialize().then((_) {
    if (kDebugMode) {
      print('🔔 Notification service initialized successfully');
    }
  }).catchError((error) {
    if (kDebugMode) {
      print('⚠️ Error initializing notification service: $error');
    }
  });

  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return AppInitializer(
      child: MaterialApp.router(
        title: Environment.appName,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: router,
      ),
    );
  }
}
