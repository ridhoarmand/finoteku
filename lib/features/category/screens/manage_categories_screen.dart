import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/category_service.dart';
import '../../../services/supabase_service.dart';
import '../../../models/category.dart';
import '../../../utils/category_icon_helper.dart';
import '../widgets/category_form_dialog.dart';

class ManageCategoriesScreen extends ConsumerStatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  ConsumerState<ManageCategoriesScreen> createState() =>
      _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends ConsumerState<ManageCategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.trending_down), text: 'Expense'),
            Tab(icon: Icon(Icons.trending_up), text: 'Income'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddCategoryDialog(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CategoryListTab(categoryType: CategoryType.expense),
          CategoryListTab(categoryType: CategoryType.income),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    // Get current tab index to determine category type
    final isExpense = _tabController.index == 0;
    final categoryType = isExpense ? CategoryType.expense : CategoryType.income;

    showDialog(
      context: context,
      builder: (context) => CategoryFormDialog(
        title: 'Add ${isExpense ? 'Expense' : 'Income'} Category',
        categoryType: categoryType,
        onSave: (name, color, icon, parentId) {
          _handleAddCategory(categoryType, name, color, icon, parentId);
        },
      ),
    );
  }

  void _handleAddCategory(
    CategoryType type,
    String name,
    Color color,
    IconData? icon,
    String? parentId,
  ) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final categoryService = ref.read(categoryServiceProvider);
      final request = CreateCategoryRequest(
        name: name,
        type: type,
        parentId: parentId,
        iconCodePoint: icon != null
            ? CategoryIconHelper.getCodePointFromIcon(icon)
            : null,
        color: color.value,
      );

      await categoryService.createCategory(userId, request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name category added successfully')),
        );

        // Refresh the categories list
        ref.invalidate(categoriesByTypeProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class CategoryListTab extends ConsumerWidget {
  final CategoryType categoryType;

  const CategoryListTab({super.key, required this.categoryType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = SupabaseService.currentUserId;

    if (userId == null) {
      return const Center(child: Text('Please login to see categories'));
    }

    final categoriesAsync = ref.watch(
      categoriesByTypeProvider((userId: userId, type: categoryType)),
    );

    return categoriesAsync.when(
      data: (categories) => _buildCategoryList(context, ref, categories),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: ${error.toString()}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(
                categoriesByTypeProvider((userId: userId, type: categoryType)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    WidgetRef ref,
    List<Category> categories,
  ) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              categoryType == CategoryType.expense
                  ? Icons.trending_down
                  : Icons.trending_up,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No categories yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first category',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Separate parent and child categories
    final parentCategories = categories
        .where((cat) => cat.parentId == null)
        .toList();
    final childCategories = categories
        .where((cat) => cat.parentId != null)
        .toList();

    // Create hierarchical structure
    final hierarchicalItems = <Widget>[];

    for (final parent in parentCategories) {
      // Add parent category
      hierarchicalItems.add(
        _buildCategoryItem(context, ref, parent, isParent: true),
      );

      // Add children of this parent
      final children = childCategories
          .where((child) => child.parentId == parent.id)
          .toList();
      for (final child in children) {
        hierarchicalItems.add(
          _buildCategoryItem(context, ref, child, isChild: true),
        );
      }
    }

    // Add orphaned child categories (children whose parents don't exist in current list)
    final parentIds = parentCategories.map((p) => p.id).toSet();
    final orphanedChildren = childCategories
        .where((child) => !parentIds.contains(child.parentId))
        .toList();
    for (final orphan in orphanedChildren) {
      hierarchicalItems.add(
        _buildCategoryItem(context, ref, orphan, isOrphan: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(categoriesByTypeProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: hierarchicalItems,
      ),
    );
  }

  Widget _buildCategoryItem(
    BuildContext context,
    WidgetRef ref,
    Category category, {
    bool isParent = false,
    bool isChild = false,
    bool isOrphan = false,
  }) {
    // Get icon from category model or use default
    IconData icon = category.iconCodePoint != null
        ? CategoryIconHelper.getIconFromCodePoint(category.iconCodePoint)
        : CategoryIconHelper.getIconForCategory(category.name);
    
    // Use color from database if available, otherwise use default
    Color color = category.color != null 
        ? Color(category.color!) 
        : Theme.of(context).colorScheme.primary;

    // Different styling based on hierarchy level
    Widget leadingWidget;
    EdgeInsets cardMargin;

    if (isChild) {
      // Child category styling - minimalist approach
      leadingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            child: Icon(
              Icons.subdirectory_arrow_right,
              size: 16,
              color: Colors.grey[400],
            ),
          ),
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 12),
          ),
        ],
      );
      cardMargin = const EdgeInsets.only(bottom: 4, left: 20);
    } else if (isOrphan) {
      // Orphaned child styling - simple warning
      leadingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 12),
          ),
        ],
      );
      cardMargin = const EdgeInsets.only(bottom: 4);
    } else {
      // Parent category styling
      leadingWidget = CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 20),
      );
      cardMargin = const EdgeInsets.only(bottom: 8);
    }

    return Card(
      margin: cardMargin,
      elevation: isChild ? 0.3 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isChild
            ? BorderSide(color: Colors.grey[200]!, width: 0.5)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isChild ? 12 : 16,
          vertical: isChild ? 2 : 6,
        ),
        leading: leadingWidget,
        title: Text(
          category.name,
          style: TextStyle(
            fontWeight: isParent ? FontWeight.w600 : FontWeight.w500,
            fontSize: isChild ? 14 : 15,
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[600]),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showEditCategoryDialog(context, ref, category);
                break;
              case 'delete':
                _showDeleteConfirmation(context, ref, category);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 12),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool hasChildren(String parentId, WidgetRef ref) {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;

    final categoriesAsync = ref.watch(
      categoriesByTypeProvider((userId: userId, type: categoryType)),
    );

    return categoriesAsync.when(
      data: (categories) => categories.any((cat) => cat.parentId == parentId),
      loading: () => false,
      error: (_, _) => false,
    );
  }

  void _showEditCategoryDialog(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) {
    showDialog(
      context: context,
      builder: (context) => CategoryFormDialog(
        title: 'Edit ${category.type.name} Category',
        categoryType: category.type,
        initialName: category.name,
        initialParentId: category.parentId,
        editingCategoryId: category.id, // Add this to prevent self-selection
        initialIcon: category.iconCodePoint != null
            ? CategoryIconHelper.getIconFromCodePoint(category.iconCodePoint)
            : null,
        initialColor: category.color != null ? Color(category.color!) : null,
        onSave: (name, color, icon, parentId) {
          _handleEditCategory(
            context,
            ref,
            category,
            name,
            color,
            icon,
            parentId,
          );
        },
      ),
    );
  }

  void _handleEditCategory(
    BuildContext context,
    WidgetRef ref,
    Category category,
    String name,
    Color color,
    IconData? icon,
    String? parentId,
  ) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final categoryService = ref.read(categoryServiceProvider);
      final request = UpdateCategoryRequest(
        name: name,
        parentId: parentId,
        iconCodePoint: icon != null
            ? CategoryIconHelper.getCodePointFromIcon(icon)
            : null,
        color: color.value,
      );

      await categoryService.updateCategory(category.id, userId, request);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${category.name} updated successfully')),
        );

        // Refresh the categories list
        ref.invalidate(categoriesByTypeProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleDeleteCategory(context, ref, category);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _handleDeleteCategory(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final categoryService = ref.read(categoryServiceProvider);
      await categoryService.deleteCategory(category.id, userId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${category.name} deleted successfully')),
        );

        // Refresh the categories list
        ref.invalidate(categoriesByTypeProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
