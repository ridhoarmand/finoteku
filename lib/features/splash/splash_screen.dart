import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../auth/screens/login_screen.dart';
import '../home/home_screen.dart';
import '../../utils/environment.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Show splash for minimum 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    try {
      // Get AuthService instance and check if user is authenticated
      final authService = AuthService(SupabaseService.client);
      final isAuthenticated = authService.isAuthenticated;

      if (!mounted) return;

      if (isAuthenticated) {
        // User is logged in, go to home
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        // User is not logged in, go to login
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      // If there's an error checking auth, go to login screen
      if (Environment.debugMode) {
        if (kDebugMode) {
          print('Auth check error: $e');
        }
      }

      if (!mounted) return;

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icon.png', width: 120, height: 120),
            const SizedBox(height: 24),
            Text(
              'Finoteku',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
