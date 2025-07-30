import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/dev_auth_service.dart';
import '../features/wallet/providers/wallet_providers.dart';
import '../features/category/providers/category_providers.dart';
import '../services/sync_service.dart';

class AppInitializer extends ConsumerStatefulWidget {
  final Widget child;
  
  const AppInitializer({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<AppInitializer> {
  bool _isInitialized = false;
  String _initStatus = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _initStatus = 'Setting up authentication...';
      });

      // Initialize development authentication
      final devAuthService = ref.read(devAuthServiceProvider);
      final authSuccess = await devAuthService.autoSignInForDevelopment();

      if (!authSuccess) {
        setState(() {
          _initStatus = 'Authentication failed - continuing with offline mode';
        });
        if (kDebugMode) {
          print('⚠️ Auth failed, continuing with offline mode');
        }
      } else {
        devAuthService.checkAuthStatus();
      }

      setState(() {
        _initStatus = 'Setting up local data...';
      });

      // Get user ID for data initialization
      final userId = devAuthService.getDevelopmentUserId();
      if (userId == null) {
        if (kDebugMode) {
          print('⚠️ No user ID available, using demo mode');
        }
        // Use a demo user ID for offline mode
        const demoUserId = 'demo-user-123';
        
        // Initialize wallet service (create default wallet if needed)
        final walletService = ref.read(walletServiceProvider);
        await walletService.getWallets(demoUserId);

        // Initialize category service (create default categories if needed)
        final categoryService = ref.read(categoryServiceProvider);
        await categoryService.getCategories(demoUserId);
      } else {
        // Initialize wallet service (create default wallet if needed)
        final walletService = ref.read(walletServiceProvider);
        await walletService.getWallets(userId);

        // Initialize category service (create default categories if needed)
        final categoryService = ref.read(categoryServiceProvider);
        await categoryService.getCategories(userId);
      }

      setState(() {
        _initStatus = 'Starting sync service...';
      });

      // Start sync service if authenticated
      if (authSuccess) {
        final syncService = ref.read(syncServiceProvider);
        syncService.startAutoSync();
      }

      await Future.delayed(const Duration(milliseconds: 500)); // Brief delay to show completion

      setState(() {
        _isInitialized = true;
      });

      if (kDebugMode) {
        print('✅ App initialization completed');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ App initialization error: $e');
      }
      setState(() {
        _initStatus = 'Initialization failed - continuing anyway';
        _isInitialized = true; // Continue anyway
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Finoteku',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _initStatus,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
