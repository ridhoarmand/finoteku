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
import 'utils/environment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone database (light operation)
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

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

  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
