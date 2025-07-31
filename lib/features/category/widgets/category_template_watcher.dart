import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase_service.dart';
import '../providers/category_providers.dart';
import 'category_template_dialog.dart';

class CategoryTemplateWatcher extends ConsumerWidget {
  final Widget child;
  final bool autoShow;

  const CategoryTemplateWatcher({
    super.key,
    required this.child,
    this.autoShow = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    
    return currentUser.when(
      data: (user) {
        if (user == null || !autoShow) return child;
        
        // Watch untuk template offer check
        final shouldOfferAsync = ref.watch(shouldOfferTemplateProvider(user.id));
        
        return shouldOfferAsync.when(
          data: (shouldOffer) {
            if (shouldOffer) {
              // Schedule dialog to show after build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  CategoryTemplateDialog.handleTemplateImport(context, ref);
                }
              });
            }
            return child;
          },
          loading: () => child,
          error: (_, _) => child,
        );
      },
      loading: () => child,
      error: (_, _) => child,
    );
  }

  // Static method untuk manual check dan show dialog
  static Future<void> checkAndShowTemplate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      final categoryService = ref.read(categoryServiceProvider);
      final shouldOffer = await categoryService.shouldOfferCategoryTemplate(userId);
      
      if (shouldOffer && context.mounted) {
        await CategoryTemplateDialog.handleTemplateImport(context, ref);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking template availability: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}
