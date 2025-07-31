import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase_service.dart';
import '../providers/category_providers.dart';

/// Widget untuk debugging dan monitoring sync issues
class CategorySyncDiagnosticsWidget extends ConsumerStatefulWidget {
  const CategorySyncDiagnosticsWidget({super.key});

  @override
  ConsumerState<CategorySyncDiagnosticsWidget> createState() => _CategorySyncDiagnosticsWidgetState();
}

class _CategorySyncDiagnosticsWidgetState extends ConsumerState<CategorySyncDiagnosticsWidget> {
  Map<String, dynamic>? _syncStats;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSyncStats();
  }

  Future<void> _loadSyncStats() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        final categoryService = ref.read(categoryServiceProvider);
        // We'll need to expose the sync helper or add this method to CategoryService
        // For now, let's create a simple stats method in CategoryService
        final unsyncedCategories = await categoryService.getUnsyncedCategoriesCount(userId);
        final allCategories = await categoryService.getCategories(userId);
        
        setState(() {
          _syncStats = {
            'totalCategories': allCategories.length,
            'unsyncedCount': unsyncedCategories,
            'syncedCount': allCategories.length - unsyncedCategories,
            'syncPercentage': allCategories.isEmpty ? 100.0 : 
              ((allCategories.length - unsyncedCategories) / allCategories.length * 100),
          };
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sync stats: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forceSyncAll() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        final categoryService = ref.read(categoryServiceProvider);
        await categoryService.syncUnsyncedCategories(userId);
        
        // Refresh providers
        refreshCategoryProviders(ref);
        
        // Reload stats
        await _loadSyncStats();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Force sync completed!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Force sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Category Sync Diagnostics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _isLoading ? null : _loadSyncStats,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Stats',
                ),
              ],
            ),
            const Divider(),
            
            if (_isLoading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else if (_syncStats != null) ...[
              _buildStatsGrid(),
              const SizedBox(height: 16),
              if (_syncStats!['unsyncedCount'] > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${_syncStats!['unsyncedCount']} categories need sync',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Possible causes:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const Text('• Poor internet connection'),
                      const Text('• Server issues or rate limiting'),
                      const Text('• Authentication problems'),
                      const Text('• Data conflicts or validation errors'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _forceSyncAll,
                    icon: const Icon(Icons.sync),
                    label: const Text('Force Sync All Categories'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'All categories are synced!',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              const Center(
                child: Text('No sync data available'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        _buildStatCard(
          'Total Categories',
          '${_syncStats!['totalCategories']}',
          Icons.category,
          Colors.blue,
        ),
        _buildStatCard(
          'Synced',
          '${_syncStats!['syncedCount']}',
          Icons.cloud_done,
          Colors.green,
        ),
        _buildStatCard(
          'Unsynced',
          '${_syncStats!['unsyncedCount']}',
          Icons.sync_problem,
          Colors.orange,
        ),
        _buildStatCard(
          'Sync Rate',
          '${(_syncStats!['syncPercentage'] as double).toStringAsFixed(1)}%',
          Icons.analytics,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
