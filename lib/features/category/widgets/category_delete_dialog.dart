import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/category.dart';
import '../../../services/supabase_service.dart';
import '../providers/category_providers.dart';
import '../services/category_service.dart';

class CategoryDeleteDialog extends ConsumerWidget {
  final Category category;

  const CategoryDeleteDialog({super.key, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.delete_outline, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Delete Category',
              style: const TextStyle(color: Colors.red),
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
          const Text(
            'Are you sure you want to delete this category? This action cannot be undone.',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
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
              content: Text(
                '✅ Category "${category.name}" deleted successfully',
              ),
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
