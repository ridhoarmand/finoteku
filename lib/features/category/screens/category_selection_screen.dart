import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/category.dart';
import '../providers/category_providers.dart';
import '../widgets/category_form_dialog.dart';
import '../../../core/localization/app_localizations.dart';

class CategorySelectionScreen extends ConsumerStatefulWidget {
  final String userId;
  final Category? selectedCategory;
  final String title;

  const CategorySelectionScreen({
    super.key,
    required this.userId,
    this.selectedCategory,
    this.title = 'Select Category',
  });

  @override
  ConsumerState<CategorySelectionScreen> createState() =>
      _CategorySelectionScreenState();
}

class _CategorySelectionScreenState
    extends ConsumerState<CategorySelectionScreen>
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
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.trending_down),
              text: ref.tr(context, 'expense'),
            ),
            Tab(
              icon: const Icon(Icons.trending_up),
              text: ref.tr(context, 'income'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(),
        tooltip: ref.tr(context, 'category_add'),
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CategoryListTab(
            userId: widget.userId,
            categoryType: CategoryType.expense,
            selectedCategory: widget.selectedCategory,
            onCategorySelected: (category) => context.pop(category),
          ),
          CategoryListTab(
            userId: widget.userId,
            categoryType: CategoryType.income,
            selectedCategory: widget.selectedCategory,
            onCategorySelected: (category) => context.pop(category),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    // Get current tab index to determine category type
    final isExpense = _tabController.index == 0;
    final categoryType = isExpense ? CategoryType.expense : CategoryType.income;

    showDialog(
      context: context,
      builder: (_) => CategoryFormDialog(
        title: isExpense
            ? ref.tr(context, 'add_expense_category')
            : ref.tr(context, 'add_income_category'),
        categoryType: categoryType,
        onSave: (name, color, icon, parentId) async {
          try {
            final request = CreateCategoryRequest(
              name: name,
              type: categoryType,
              parentId: parentId,
              iconCodePoint: icon?.codePoint,
            );
            await ref
                .read(categoryRepositoryProvider)
                .createCategory(widget.userId, request);
            refreshCategoryProviders(ref);
          } catch (e) {
            rethrow;
          }
        },
      ),
    );
  }
}

class CategoryListTab extends ConsumerWidget {
  final String userId;
  final CategoryType categoryType;
  final Category? selectedCategory;
  final Function(Category) onCategorySelected;

  const CategoryListTab({
    super.key,
    required this.userId,
    required this.categoryType,
    this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(
      categoriesByTypeProvider((userId: userId, type: categoryType)),
    );

    return categoriesAsync.when(
      data: (categories) => _buildCategoryList(context, ref, categories),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _buildErrorState(context, ref, error),
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    WidgetRef ref,
    List<Category> categories,
  ) {
    if (categories.isEmpty) {
      return _buildEmptyState(context, ref);
    }

    // Categories sudah diurutkan secara alphabetical dari provider
    // Separate parent and child categories
    final parentCategories = categories
        .where((cat) => cat.parentId == null)
        .toList();
    final childCategories = categories
        .where((cat) => cat.parentId != null)
        .toList();

    // Create hierarchical structure
    final hierarchicalItems = <Widget>[];

    for (int i = 0; i < parentCategories.length; i++) {
      final parent = parentCategories[i];

      // Add parent category
      hierarchicalItems.add(
        _buildCategoryItem(context, ref, parent, isParent: true),
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
            context,
            ref,
            child,
            isChild: true,
            isLastChild: isLastChild,
          ),
        );
      }
    }

    // Add orphaned child categories
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
        refreshCategoryProviders(ref);
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
    bool isLastChild = false,
  }) {
    final theme = Theme.of(context);
    final isSelected = selectedCategory?.id == category.id;

    // Get icon from category model or use default
    IconData icon = category.iconCodePoint != null
        ? IconData(category.iconCodePoint!, fontFamily: 'MaterialIcons')
        : Icons.category;

    // Use standardized color by type
    final Color color = categoryType == CategoryType.expense
        ? Colors.red
        : Colors.green;

    // Different styling based on hierarchy level
    Widget leadingWidget;
    EdgeInsets cardMargin;

    if (isChild) {
      // Child category styling
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
      cardMargin = EdgeInsets.only(
        bottom: isLastChild ? 8 : 2,
        left: 20,
        top: 2,
      );
    } else if (isOrphan) {
      // Orphaned child styling
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
      cardMargin = const EdgeInsets.only(bottom: 2, top: 4);
    }

    return Container(
      margin: cardMargin,
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : (isChild ? theme.colorScheme.surface : theme.colorScheme.surface),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : (isChild ? Colors.grey.shade200 : Colors.grey.shade200),
          width: isSelected ? 2 : (isChild ? 0.5 : 1),
        ),
        borderRadius: BorderRadius.circular(12),
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
            color: isSelected ? theme.colorScheme.onPrimaryContainer : null,
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 20,
              )
            : null,
        onTap: () => onCategorySelected(category),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
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
            ref.tr(context, 'categories_empty_title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            ref.tr(context, 'categories_empty_sub'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return RefreshIndicator(
      onRefresh: () async {
        refreshCategoryProviders(ref);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${error.toString()}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(
                    categoriesByTypeProvider((
                      userId: userId,
                      type: categoryType,
                    )),
                  ),
                  child: Text(ref.tr(context, 'retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
