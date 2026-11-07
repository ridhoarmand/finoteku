import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finoteku/theme/ph_icons.dart';
import '../core/localization/app_localizations.dart';
import '../features/settings/widgets/app_update_dialog.dart';

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    // Use startsWith to match nested routes
    if (location.startsWith('/account')) {
      return 3;
    } else if (location.startsWith('/reports')) {
      return 2;
    } else if (location.startsWith('/transaction')) {
      return 1;
    } else if (location.startsWith('/home')) {
      return 0;
    }
    return 0;
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

    return AutoUpdateCheck(
      child: PopScope(
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
          // NavigationBar styled by AppTheme; Phosphor Regular → Fill marks the active tab by shape.
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.dividerTheme.color ?? theme.dividerColor,
                ),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _getCurrentIndex(context),
              onDestinationSelected: (index) => context.go(
                const ['/home', '/transaction', '/reports', '/account'][index],
              ),
              destinations: [
                NavigationDestination(
                  icon: const Icon(PhRegular.house),
                  selectedIcon: const Icon(PhFill.house),
                  label: ref.tr(context, 'nav_home'),
                ),
                NavigationDestination(
                  icon: const Icon(PhRegular.receipt),
                  selectedIcon: const Icon(PhFill.receipt),
                  label: ref.tr(context, 'nav_transaction'),
                ),
                NavigationDestination(
                  icon: const Icon(PhRegular.chartPieSlice),
                  selectedIcon: const Icon(PhFill.chartPieSlice),
                  label: ref.tr(context, 'nav_reports'),
                ),
                NavigationDestination(
                  icon: const Icon(PhRegular.user),
                  selectedIcon: const Icon(PhFill.user),
                  label: ref.tr(context, 'nav_account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
