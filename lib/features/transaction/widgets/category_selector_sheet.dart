import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/category.dart';
import '../../category/theme/category_theme.dart';
import '../../../core/localization/app_localizations.dart';

class CategorySelectorSheet extends StatefulWidget {
  final List<Category> categories;
  final Function(Category) onCategorySelected;
  final BuildContext rootContext; // context dari screen induk

  const CategorySelectorSheet({
    super.key,
    required this.categories,
    required this.onCategorySelected,
    required this.rootContext,
  });

  @override
  State<CategorySelectorSheet> createState() => _CategorySelectorSheetState();
}

class _CategorySelectorSheetState extends State<CategorySelectorSheet>
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
    final theme = Theme.of(context);
    final expenseCategories = widget.categories
        .where((cat) => cat.type == CategoryType.expense)
        .toList();
    final incomeCategories = widget.categories
        .where((cat) => cat.type == CategoryType.income)
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8, // 80% of screen height
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Consumer(
              builder: (context, ref, _) => Text(
                ref.tr(context, 'select_category'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Tab Bar
          Consumer(
            builder: (context, ref, _) => TabBar(
              controller: _tabController,
              tabs: [
                Tab(icon: const Icon(Icons.trending_down), text: ref.tr(context, 'expense')),
                Tab(icon: const Icon(Icons.trending_up), text: ref.tr(context, 'income')),
              ],
            ),
          ),
          
          // Tab Bar View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList(expenseCategories, CategoryType.expense),
                _buildCategoryList(incomeCategories, CategoryType.income),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(List<Category> categories, CategoryType categoryType) {
    if (categories.isEmpty) {
      // Empty state: show the inline "Add New Category" action as a list item
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildAddNewCategoryItem(categoryType),
          const SizedBox(height: 8),
          Center(
            child: Consumer(
              builder: (context, ref, _) => Text(
                ref.tr(context, 'no_categories_yet_create_one'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ),
          ),
        ],
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

    // Add "Add New Category" option at the top
    hierarchicalItems.add(_buildAddNewCategoryItem(categoryType));

    for (int i = 0; i < parentCategories.length; i++) {
      final parent = parentCategories[i];
      
      // Add parent category
      hierarchicalItems.add(
        _buildCategoryItem(parent, isParent: true),
      );

      // Add children of this parent
      final children = childCategories
          .where((child) => child.parentId == parent.id)
          .toList();
      for (int j = 0; j < children.length; j++) {
        final child = children[j];
        final isLastChild = j == children.length - 1;
        hierarchicalItems.add(
          _buildCategoryItem(
            child, 
            isChild: true, 
            isLastChild: isLastChild,
          ),
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
        _buildCategoryItem(orphan, isOrphan: true),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: hierarchicalItems,
    );
  }

  Widget _buildAddNewCategoryItem(CategoryType categoryType) {
    final theme = Theme.of(context);
    final isExpense = categoryType == CategoryType.expense;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.primary,
          width: 1.5,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            Icons.add,
            color: theme.colorScheme.primary,
            size: 16,
          ),
        ),
        title: Consumer(
          builder: (context, ref, _) => Text(
            isExpense
                ? ref.tr(context, 'add_expense_category')
                : ref.tr(context, 'add_income_category'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        subtitle: Consumer(
          builder: (context, ref, _) => Text(
            ref.tr(context, 'create_new_category'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: theme.colorScheme.primary,
        ),
        onTap: () {
          // Capture router (not context) before async boundary
          final router = GoRouter.of(widget.rootContext);
          if (!mounted) return;
          Navigator.pop(context);
          // Schedule navigation after sheet pop without reusing context
          WidgetsBinding.instance.addPostFrameCallback((_) {
            router.push('/categories/manage');
          });
        },
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 2,
        ),
      ),
    );
  }

  Widget _buildCategoryItem(
    Category category, {
    bool isParent = false,
    bool isChild = false,
    bool isOrphan = false,
    bool isLastChild = false,
  }) {
    final theme = Theme.of(context);
    
    // Get icon and color
    IconData icon = category.iconCodePoint != null
        ? IconData(
            category.iconCodePoint!,
            fontFamily: 'MaterialIcons',
          )
        : Icons.category;
    
  // Standardized color by type
  Color color = CategoryTheme.forType(category.type);

    // Different styling based on hierarchy level
    Widget leadingWidget;
    EdgeInsets cardMargin;

    if (isChild) {
      // Child category styling
      leadingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            child: Icon(
              Icons.subdirectory_arrow_right,
              size: 14,
              color: Colors.grey[400],
            ),
          ),
          CircleAvatar(
            radius: 12,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 10),
          ),
        ],
      );
      cardMargin = EdgeInsets.only(
        bottom: isLastChild ? 4 : 1,
        left: 12,
        top: 1,
      );
    } else if (isOrphan) {
      // Orphaned child styling
      leadingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 12,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 10),
          ),
        ],
      );
      cardMargin = const EdgeInsets.only(bottom: 2);
    } else {
      // Parent category styling
      leadingWidget = CircleAvatar(
        radius: 16,
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 16),
      );
      cardMargin = const EdgeInsets.only(bottom: 1, top: 2);
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
        leading: leadingWidget,
        title: Text(
          category.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: isChild ? 12 : 14,
            fontWeight: isParent ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: isOrphan 
            ? Consumer(
                builder: (context, ref, _) => Text(
                  ref.tr(context, 'missing_parent_category'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            : isParent
                ? Text(
                    category.type.name.toUpperCase(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: category.type == CategoryType.expense 
                          ? CategoryTheme.expense 
                          : CategoryTheme.income,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => widget.onCategorySelected(category),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isChild ? 8 : 10,
          vertical: isChild ? 1 : 2,
        ),
      ),
    );
  }
}
