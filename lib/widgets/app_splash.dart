import 'package:flutter/material.dart';

/// The one startup screen. main() shows it while it initialises, SplashScreen while it
/// routes: being the same, still widget, the hand-over between them cannot flash.
class AppSplash extends StatelessWidget {
  const AppSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon_transparent.png', width: 100, height: 100),
            const SizedBox(height: 24),
            Text(
              'Finoteku',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ),
    );
  }
}
