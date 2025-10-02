import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/localization/app_localizations.dart';

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    switch (location) {
      case '/home':
        return 0;
      case '/transaction':
        return 1;
      case '/reports':
        return 2;
      case '/account':
        return 3;
      default:
        return 0;
    }
  }

  Future<bool> _onWillPop(BuildContext context, WidgetRef ref) async {
    // Jika sedang di tab Home, tampilkan konfirmasi keluar
    final currentIndex = _getCurrentIndex(context);
    if (currentIndex != 0) {
      // Jika tidak di Home tab, navigasi ke Home terlebih dahulu
      context.go('/home');
      return false;
    }

    // Jika di Home tab, tampilkan dialog konfirmasi keluar
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(ref.tr(context, 'exit_app_title')),
            content: Text(ref.tr(context, 'exit_app_message')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(ref.tr(context, 'exit_cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(ref.tr(context, 'exit_confirm')),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPop = await _onWillPop(context, ref);
        if (shouldPop && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _getCurrentIndex(context),
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.onSurfaceVariant,
          backgroundColor: theme.colorScheme.surface,
          elevation: 8,
          onTap: (index) {
            switch (index) {
              case 0:
                context.go('/home');
                break;
              case 1:
                context.go('/transaction');
                break;
              case 2:
                context.go('/reports');
                break;
              case 3:
                context.go('/account');
                break;
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: ref.tr(context, 'nav_home'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: ref.tr(context, 'nav_transaction'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assessment_outlined),
              activeIcon: Icon(Icons.assessment),
              label: ref.tr(context, 'nav_reports'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: ref.tr(context, 'nav_account'),
            ),
          ],
        ),
      ),
    );
  }
}
