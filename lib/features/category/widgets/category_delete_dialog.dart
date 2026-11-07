import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/category.dart';
import '../../../services/supabase_service.dart';
import '../providers/category_providers.dart';
import '../services/category_service.dart';
import '../../../core/localization/app_localizations.dart';

class CategoryDeleteDialog extends ConsumerWidget {
  final Category category;

  const CategoryDeleteDialog({super.key, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(PhRegular.trash, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ref.tr(context, 'delete_category_title'),
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
            '${ref.tr(context, 'category_name')}: ${category.name}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            ref.tr(context, 'delete_category_confirm'),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(ref.tr(context, 'cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(ref.tr(context, 'delete')),
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
          throw Exception(ref.tr(context, 'user_not_authenticated'));
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
          final msg = ref
              .tr(context, 'category_deleted_success')
              .replaceAll('{category}', category.name);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ $msg'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        // Show error message
        if (context.mounted) {
          final msg = ref
              .tr(context, 'category_delete_failed')
              .replaceAll('{error}', e.toString());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
