import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/category.dart';
import '../providers/category_providers.dart';
import '../screens/add_edit_category_screen.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../utils/category_icon_helper.dart';

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
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(PhRegular.x),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(PhRegular.trendDown),
              text: ref.tr(context, 'expense'),
            ),
            Tab(
              icon: const Icon(PhRegular.trendUp),
              text: ref.tr(context, 'income'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(),
        child: const Icon(PhRegular.plus),
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditCategoryScreen(categoryType: categoryType),
      ),
    ).then((result) {
      if (result == true) {
        // Category was saved, refresh the list
        refreshCategoryProviders(ref);
      }
    });
  }
}

class CategoryListTab extends ConsumerStatefulWidget {
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
  ConsumerState<CategoryListTab> createState() => _CategoryListTabState();
}

class _CategoryListTabState extends ConsumerState<CategoryListTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Category> _filterCategories(List<Category> categories, String query) {
    if (query.isEmpty) {
      return categories;
    }

    final matchingCategories = categories
        .where((cat) => cat.name.toLowerCase().contains(query))
        .toList();

    final Set<String> visibleIds = {};
    for (final cat in matchingCategories) {
      visibleIds.add(cat.id);
      if (cat.parentId != null) {
        visibleIds.add(cat.parentId!);
      }
    }

    return categories.where((cat) => visibleIds.contains(cat.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(
      categoriesByTypeProvider((
        userId: widget.userId,
        type: widget.categoryType,
      )),
    );

    return categoriesAsync.when(
      data: (categories) {
        final filteredCategories = _filterCategories(categories, _searchQuery);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: ref.tr(context, 'search_category'),
                  prefixIcon: const Icon(PhRegular.magnifyingGlass),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          tooltip: ref.tr(context, 'clear'),
                          icon: const Icon(PhRegular.x),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
              ),
            ),
            Expanded(
              child: _buildCategoryList(context, ref, filteredCategories),
            ),
          ],
        );
      },
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
    final isSelected = widget.selectedCategory?.id == category.id;

    // Get icon from category model or use default
    final icon = CategoryIconHelper.iconFor(codePoint: category.iconCodePoint, name: category.name);
    // Neutral tile like every list in the app (selection is shown by the row itself).
    Widget tile(double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.sunken,
        borderRadius: BorderRadius.circular(AppTheme.rControl),
      ),
      child: Icon(icon, size: size * 0.55, color: theme.colorScheme.onSurface),
    );

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
              PhRegular.arrowElbowDownRight,
              size: 16,
              color: context.colors.muted,
            ),
          ),
          tile(32),
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
          Icon(PhRegular.warning, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          tile(32),
        ],
      );
      cardMargin = const EdgeInsets.only(bottom: 4);
    } else {
      // Parent category styling
      leadingWidget = tile(40);
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
              : (isChild ? context.colors.muted : context.colors.muted),
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
                PhFill.checkCircle,
                color: theme.colorScheme.primary,
                size: 20,
              )
            : null,
        onTap: () => widget.onCategorySelected(category),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.categoryType == CategoryType.expense
                ? PhRegular.trendDown
                : PhRegular.trendUp,
            size: 64,
            color: context.colors.muted,
          ),
          const SizedBox(height: 16),
          Text(
            ref.tr(context, 'categories_empty_title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: context.colors.muted),
          ),
          const SizedBox(height: 8),
          Text(
            ref.tr(context, 'categories_empty_sub'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.colors.muted),
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
                Icon(PhRegular.warningCircle, size: 64, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text('Error: ${error.toString()}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(
                    categoriesByTypeProvider((
                      userId: widget.userId,
                      type: widget.categoryType,
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
