import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase_service.dart';
import '../providers/category_providers.dart';

class CategoryTemplateDialog extends ConsumerWidget {
  const CategoryTemplateDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.category_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          const Text('Import Category Templates'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You have no categories at the moment. Would you like to import our default category templates to get started?',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📊 Templates include:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  '• Food & Dining categories',
                  style: TextStyle(fontSize: 13),
                ),
                Text(
                  '• Transportation & Shopping',
                  style: TextStyle(fontSize: 13),
                ),
                Text(
                  '• Bills, Healthcare & Education',
                  style: TextStyle(fontSize: 13),
                ),
                Text(
                  '• Employment & Investment income',
                  style: TextStyle(fontSize: 13),
                ),
                Text(
                  '• All with icons and colors pre-configured',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Import Templates'),
        ),
      ],
    );
  }

  // Static method to show dialog
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => const CategoryTemplateDialog(),
    );
  }

  // Helper method to handle the import process
  static Future<void> handleTemplateImport(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (!context.mounted) return;

    final shouldImport = await show(context);

    if (shouldImport == true && context.mounted) {
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

        // Import templates
        final categoryService = ref.read(categoryServiceProvider);
        await categoryService.importDefaultCategories(userId);

        // Refresh providers
        refreshCategoryProviders(ref);

        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Category templates imported successfully!'),
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
              content: Text('❌ Failed to import templates: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
