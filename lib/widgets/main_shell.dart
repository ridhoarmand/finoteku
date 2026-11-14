import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finoteku/theme/ph_icons.dart';
import '../core/localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../features/settings/widgets/app_update_dialog.dart';

/// Watches the shell's own navigator. Detail pages, account sub-pages and sheets opened
/// from a tab land there, on top of the tab: then the add button and the tab bar step
/// aside so they never cover that page's own buttons.
class ShellRouteObserver extends NavigatorObserver {
  final covered = ValueNotifier(false);

  void _sync() => WidgetsBinding.instance.addPostFrameCallback((_) => covered.value = navigator?.canPop() ?? false);

  @override
  void didPush(Route route, Route? previousRoute) => _sync();
  @override
  void didPop(Route route, Route? previousRoute) => _sync();
  @override
  void didRemove(Route route, Route? previousRoute) => _sync();
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) => _sync();
}

final shellRouteObserver = ShellRouteObserver();

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

  static const _items = [
    (PhRegular.house, PhFill.house, 'nav_home', '/home'),
    (PhRegular.receipt, PhFill.receipt, 'nav_transaction', '/transaction'),
    (PhRegular.chartPieSlice, PhFill.chartPieSlice, 'nav_reports', '/reports'),
    (PhRegular.user, PhFill.user, 'nav_account', '/account'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final index = _getCurrentIndex(context);

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
        child: ValueListenableBuilder<bool>(
          valueListenable: shellRouteObserver.covered,
          builder: (context, covered, _) => Scaffold(
          body: child,
          // The add button sits in a notch of the bar with a ring of page colour
          // around it: it reads as its own control, not a fifth tab.
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButton: covered ? null : SizedBox.square(
            dimension: 60,
            child: FloatingActionButton(
              tooltip: ref.tr(context, 'add_transaction'),
              shape: CircleBorder(side: BorderSide(color: theme.scaffoldBackgroundColor, width: 4)),
              elevation: 4,
              onPressed: () => context.push('/transaction/add'),
              child: const Icon(PhBold.plus, size: 26),
            ),
          ),
          bottomNavigationBar: covered ? null : BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 5,
            height: 68,
            padding: EdgeInsets.zero,
            color: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            child: Row(
              children: [
                for (final (i, item) in _items.indexed) ...[
                  if (i == 2) const SizedBox(width: 76), // room for the add button
                  Expanded(
                    child: _NavItem(
                      icon: item.$1,
                      selectedIcon: item.$2,
                      label: ref.tr(context, item.$3),
                      selected: index == i,
                      onTap: () => context.go(item.$4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// One tab: icon in a pill when active (Regular → Fill), label below. ≥48dp tall.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = context.colors.muted;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 52,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                selected ? selectedIcon : icon,
                size: 22,
                color: selected ? scheme.onPrimaryContainer : muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? scheme.onSurface : muted,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
