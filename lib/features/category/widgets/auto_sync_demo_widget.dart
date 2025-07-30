import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/sync_service.dart';
import '../../../services/supabase_service.dart';

/// Widget demo untuk menunjukkan auto sync functionality
class AutoSyncDemoWidget extends ConsumerWidget {
  const AutoSyncDemoWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(connectionStatusProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Auto Sync Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Connection Status
            connectionAsync.when(
              data: (isConnected) => _buildStatusRow(
                'Internet Connection',
                isConnected ? 'Connected' : 'Disconnected',
                isConnected ? Colors.green : Colors.red,
                isConnected ? Icons.wifi : Icons.wifi_off,
              ),
              loading: () => _buildStatusRow(
                'Internet Connection',
                'Checking...',
                Colors.grey,
                Icons.wifi_find,
              ),
              error: (_, _) => _buildStatusRow(
                'Internet Connection',
                'Error',
                Colors.red,
                Icons.error,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Auth Status
            currentUser.when(
              data: (user) => _buildStatusRow(
                'Authentication',
                user != null ? 'Authenticated' : 'Not authenticated',
                user != null ? Colors.green : Colors.red,
                user != null ? Icons.check_circle : Icons.cancel,
              ),
              loading: () => _buildStatusRow(
                'Authentication',
                'Checking...',
                Colors.grey,
                Icons.person_search,
              ),
              error: (_, _) => _buildStatusRow(
                'Authentication',
                'Error',
                Colors.red,
                Icons.error,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Sync Status
            _buildStatusRow(
              'Auto Sync',
              _getSyncStatusText(syncStatus),
              _getSyncStatusColor(syncStatus),
              _getSyncStatusIcon(syncStatus),
            ),
            
            const SizedBox(height: 16),
            
            // Manual sync button
            ElevatedButton.icon(
              onPressed: () => _manualSync(ref),
              icon: const Icon(Icons.sync),
              label: const Text('Manual Sync'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String status, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Text(
          status,
          style: TextStyle(color: color),
        ),
      ],
    );
  }

  String _getSyncStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return 'Ready';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.success:
        return 'Success';
      case SyncStatus.error:
        return 'Error';
    }
  }

  Color _getSyncStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Colors.blue;
      case SyncStatus.syncing:
        return Colors.orange;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.error:
        return Colors.red;
    }
  }

  IconData _getSyncStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Icons.sync;
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.success:
        return Icons.check_circle;
      case SyncStatus.error:
        return Icons.error;
    }
  }

  void _manualSync(WidgetRef ref) async {
    final userId = SupabaseService.currentUserId;
    if (userId != null) {
      ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
      
      try {
        final syncService = ref.read(syncServiceProvider);
        await syncService.syncUserData(userId);
        ref.read(syncStatusProvider.notifier).state = SyncStatus.success;
        
        // Reset status setelah 3 detik
        Future.delayed(const Duration(seconds: 3), () {
          ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
        });
      } catch (e) {
        ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
        
        // Reset status setelah 3 detik
        Future.delayed(const Duration(seconds: 3), () {
          ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
        });
      }
    }
  }
}
