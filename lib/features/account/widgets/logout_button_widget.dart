import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/services/auth_service.dart';
import '../../../services/supabase_service.dart';

class LogoutButtonWidget extends ConsumerWidget {
  const LogoutButtonWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.read(authServiceProvider);

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () async {
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Logout'),
              content: const Text('Are you sure you want to logout?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Logout'),
                ),
              ],
            ),
          );

          if (shouldLogout == true && context.mounted) {
            try {
              debugPrint('🚪 Starting logout process...');
              await authService.signOut();
              debugPrint('✅ Auth signOut completed');

              // Force refresh auth providers to trigger router redirect
              ref.invalidate(currentAuthProvider);
              ref.invalidate(currentUserProvider);
              debugPrint('🔄 Auth providers invalidated');

              if (context.mounted) {
                // Clear navigation stack and go to login
                while (context.canPop()) {
                  context.pop();
                }
                debugPrint('🔄 Navigation stack cleared, redirecting to login');
                context.pushReplacement('/login');
              }
            } catch (e) {
              debugPrint('❌ Logout error: $e');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Logout failed: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        },
        icon: const Icon(Icons.logout),
        label: const Text('Logout'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
