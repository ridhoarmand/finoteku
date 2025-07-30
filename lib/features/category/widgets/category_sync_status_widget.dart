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
    final expenseCategoriesAsync = ref.watch(expenseCategoriesProvider(userId));
    final incomeCategoriesAsync = ref.watch(incomeCategoriesProvider(userId));

    return connectionAsync.when(
      data: (isConnected) => expenseCategoriesAsync.when(
        data: (expenseCategories) => incomeCategoriesAsync.when(
          data: (incomeCategories) {
            final allCategories = [...expenseCategories, ...incomeCategories];
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
            } else {
              return Tooltip(
                message: isConnected
                    ? '$unsyncedCount categories will sync automatically'
                    : '$unsyncedCount categories waiting for internet connection',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.orange : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isConnected ? Icons.sync : Icons.sync_disabled,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$unsyncedCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isConnected) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.wifi_off,
                          color: Colors.white,
                          size: 12,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
