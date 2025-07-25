import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/auth_wrapper.dart';
import 'features/splash/splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'services/supabase_service.dart';
import 'utils/environment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: Environment.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const AuthWrapper(),
        '/home': (context) => const AuthWrapper(),
      },
    );
  }
}
