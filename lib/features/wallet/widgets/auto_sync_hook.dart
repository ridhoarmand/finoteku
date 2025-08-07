import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase_service.dart';
import '../../../services/connectivity_service.dart';
import '../providers/wallet_providers.dart';

/// Hook untuk auto sync yang bisa digunakan di berbagai screen
/// Sistem ini akan otomatis trigger sync saat diperlukan tanpa manual intervention
class AutoSyncHook extends ConsumerStatefulWidget {
  final Widget child;
  final bool enableAutoSync;

  const AutoSyncHook({
    super.key,
    required this.child,
    this.enableAutoSync = true,
  });

  @override
  ConsumerState<AutoSyncHook> createState() => _AutoSyncHookState();
}

class _AutoSyncHookState extends ConsumerState<AutoSyncHook> {
  @override
  void initState() {
    super.initState();
    if (widget.enableAutoSync) {
      // Trigger wallet data fetch which will auto sync if needed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureDataLoaded();
      });
    }
  }

  void _ensureDataLoaded() {
    final currentUser = ref.read(currentUserProvider);
    currentUser.whenData((user) {
      if (user != null && mounted) {
        // Simply reading walletsProvider will trigger auto sync if needed
        ref.read(walletsProvider(user.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to connectivity changes to refresh data when coming online
    ref.listen(connectionStatusProvider, (previous, next) {
      next.when(
        data: (isConnected) {
          if (isConnected && previous?.value == false) {
            // Just came online, refresh wallet data which will auto sync
            final currentUser = ref.read(currentUserProvider);
            currentUser.whenData((user) {
              if (user != null && mounted) {
                ref.invalidate(walletsProvider(user.id));
              }
            });
          }
        },
        loading: () {},
        error: (_, _) {},
      );
    });

    return widget.child;
  }
}

/// Widget builder untuk screen yang membutuhkan auto sync
class AutoSyncScreenBuilder extends ConsumerWidget {
  final WidgetBuilder builder;
  final bool enableAutoSync;

  const AutoSyncScreenBuilder({
    super.key,
    required this.builder,
    this.enableAutoSync = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AutoSyncHook(
      enableAutoSync: enableAutoSync,
      child: builder(context),
    );
  }
}
