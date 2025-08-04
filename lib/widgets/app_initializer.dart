import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/category/providers/category_providers.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';

class AppInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const AppInitializer({super.key, required this.child});

  @override
  ConsumerState<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<AppInitializer> {
  bool _isInitialized = false;
  String _initStatus = 'Initializing application...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _initStatus = 'Starting initialization...';
        _progress = 0.2;
      });

      // Wait a bit to show the loading
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _initStatus = 'Loading user data...';
        _progress = 0.6;
      });

      // Initialize notification service with user service
      final userService = ref.read(userServiceProvider);
      await NotificationService.initialize(userService: userService);

      // Check if user is authenticated - kalau tidak ada user, biarkan auth wrapper handle
      final currentUser = ref.read(currentUserProvider).value;
      
      if (currentUser != null) {
        // User sudah login - load data user
        ref.read(categoriesProvider(currentUser.id));
        
        setState(() {
          _initStatus = 'Ready to use!';
          _progress = 1.0;
        });
      } else {
        // Tidak ada user - auth wrapper akan redirect ke login
        setState(() {
          _initStatus = 'Please login to continue';
          _progress = 1.0;
        });
      }

      // Small delay to show completion
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _initStatus = 'Initialization failed: $e';
        _progress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      final isLoadingCategories =
          _initStatus.contains('categories') || _initStatus.contains('Loading');

      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Loading animation with progress
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isLoadingCategories ? Colors.green : Colors.blue,
                        ),
                        backgroundColor: Colors.grey[200],
                      ),
                    ),
                    Icon(
                      isLoadingCategories
                          ? Icons.category
                          : Icons.monetization_on,
                      size: 32,
                      color: isLoadingCategories ? Colors.green : Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Finoteku',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _initStatus,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                      fontSize: 16,
                    ),
                  ),
                ),
                if (isLoadingCategories) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Setting up your financial categories for easy expense tracking',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
                // Progress percentage
                const SizedBox(height: 12),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
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
