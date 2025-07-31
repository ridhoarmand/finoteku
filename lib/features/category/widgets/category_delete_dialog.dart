import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/category.dart';
import '../../../services/supabase_service.dart';
import '../providers/category_providers.dart';

class CategoryDeleteDialog extends ConsumerWidget {
  final Category category;

  const CategoryDeleteDialog({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryService = ref.read(categoryServiceProvider);
    final userId = SupabaseService.currentUserId;

    return FutureBuilder<Map<String, dynamic>>(
      future: userId != null 
          ? categoryService.getCategoryDeletionInfo(category.id, userId)
          : Future.value({'canDelete': false, 'reason': 'User not authenticated'}),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AlertDialog(
            content: SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final deletionInfo = snapshot.data ?? {'canDelete': false, 'reason': 'Unknown error'};
        final canDelete = deletionInfo['canDelete'] as bool;
        final reason = deletionInfo['reason'] as String;
        final transactionCount = deletionInfo['transactionCount'] as int? ?? 0;
        final childrenWithTransactions = deletionInfo['childrenWithTransactions'] as List<String>? ?? [];

        return AlertDialog(
          title: Row(
            children: [
              Icon(
                canDelete ? Icons.delete_outline : Icons.warning_amber_rounded,
                color: canDelete ? Colors.red : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  canDelete ? 'Delete Category' : 'Cannot Delete Category',
                  style: TextStyle(
                    color: canDelete ? Colors.red : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Category: ${category.name}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 12),
              
              if (canDelete) ...[
                const Text(
                  'This category can be safely deleted.',
                  style: TextStyle(color: Colors.green, fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Are you sure you want to proceed?',
                  style: TextStyle(fontSize: 14),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Cannot delete:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(reason, style: const TextStyle(fontSize: 14)),
                      
                      if (transactionCount > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.receipt_long, color: Colors.orange, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Has $transactionCount transaction(s)',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      if (childrenWithTransactions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Child categories with transactions:',
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        ...childrenWithTransactions.map((child) => Padding(
                          padding: const EdgeInsets.only(left: 12, top: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(child: Text(child, style: const TextStyle(fontSize: 12))),
                            ],
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Transfer transactions to another category first, then try deleting again.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            if (canDelete)
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
          ],
        );
      },
    );
  }

  // Static method to show dialog and handle deletion
  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => CategoryDeleteDialog(category: category),
    );

    if (shouldDelete == true && context.mounted) {
      try {
        final userId = SupabaseService.currentUserId;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        // Show loading
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AlertDialog(
              content: SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        }

        // Delete category
        final categoryService = ref.read(categoryServiceProvider);
        await categoryService.deleteCategory(category.id, userId);

        // Refresh providers
        refreshCategoryProviders(ref);

        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Category "${category.name}" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        // Show error message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to delete category: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
