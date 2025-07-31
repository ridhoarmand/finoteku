import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/supabase_service.dart';
import '../providers/category_providers.dart';

class CategorySyncStatusWidget extends ConsumerWidget {
  const CategorySyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = SupabaseService.currentUserId;

    if (userId == null) return const SizedBox.shrink();

    final connectionAsync = ref.watch(connectionStatusProvider);
    // Gunakan categoriesProvider untuk menghindari duplicate calls dengan expense/income providers
    final categoriesAsync = ref.watch(categoriesProvider(userId));

    return connectionAsync.when(
      data: (isConnected) => categoriesAsync.when(
        data: (allCategories) {
          final unsyncedCount = allCategories
              .where((cat) => cat.needsSync)
              .length;

          if (unsyncedCount == 0) {
            return Tooltip(
              message: isConnected
                  ? 'All categories synced'
                  : 'All categories synced (offline)',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_done, color: Colors.green[600], size: 20),
                  if (!isConnected) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.wifi_off, color: Colors.grey[600], size: 16),
                  ],
                ],
              ),
            );
          }

          return Tooltip(
            message: isConnected
                ? '$unsyncedCount categories waiting to sync'
                : '$unsyncedCount categories waiting to sync (offline)',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isConnected
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isConnected
                      ? Colors.orange.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isConnected ? Icons.sync_problem : Icons.sync_disabled,
                    color: isConnected ? Colors.orange[700] : Colors.grey[600],
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$unsyncedCount',
                    style: TextStyle(
                      color: isConnected ? Colors.orange[700] : Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!isConnected) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.wifi_off, color: Colors.grey[600], size: 14),
                  ],
                ],
              ),
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
