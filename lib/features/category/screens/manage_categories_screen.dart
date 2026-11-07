import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/category_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../services/supabase_service.dart';
import '../../../models/category.dart';
import '../../../utils/category_icon_helper.dart';
import '../../category/theme/category_theme.dart';
import '../widgets/category_delete_dialog.dart';
import 'add_edit_category_screen.dart';

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
        title: Text(ref.tr(context, 'manage_categories')),
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
        actions: [
          IconButton(
            tooltip: ref.tr(context, 'add'),
            icon: const Icon(PhRegular.plus),
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
  final CategoryType categoryType;

  const CategoryListTab({super.key, required this.categoryType});

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
    final userId = SupabaseService.currentUserId;

    if (userId == null) {
      return Center(child: Text(ref.tr(context, 'login_required_short')));
    }

    final categoriesAsync = ref.watch(
      categoriesByTypeProvider((userId: userId, type: widget.categoryType)),
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
      error: (error, stackTrace) => RefreshIndicator(
        onRefresh: () async {
          refreshCategoryProviders(ref);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(PhRegular.warningCircle, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${error.toString()}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.refresh(
                      categoriesByTypeProvider((
                        userId: userId,
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
      ),
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    WidgetRef ref,
    List<Category> categories,
  ) {
    if (categories.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => refreshCategoryProviders(ref),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.categoryType == CategoryType.expense
                        ? PhRegular.trendDown
                        : PhRegular.trendUp,
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
                  const SizedBox(height: 8),
                  Text(
                    ref.tr(context, 'pull_down_to_refresh'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ),
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
        // Refresh all categories providers
        refreshCategoryProviders(ref);
      },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: hierarchicalItems,
      ),
    );
  }

  // Template import button removed (templates no longer offered in online-only mode)

  Widget _buildCategoryItem(
    BuildContext context,
    WidgetRef ref,
    Category category, {
    bool isParent = false,
    bool isChild = false,
    bool isOrphan = false,
    bool isLastChild = false, // Add parameter to identify last child
  }) {
    // Get icon from category model or use default
    IconData icon = category.iconCodePoint != null
        ? CategoryIconHelper.getIconFromCodePoint(category.iconCodePoint)
        : CategoryIconHelper.getIconForCategory(category.name);

    // Use color from database if available, otherwise use default
    // Standardized color by type (ignore stored color)
    final Color color = CategoryTheme.forType(context, category.type);

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
              PhRegular.arrowElbowDownRight,
              size: 16,
              color: Colors.grey[400],
            ),
          ),
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 10),
          ),
        ],
      );
      // Close spacing for children, but add extra bottom margin for last child to separate from next parent
      cardMargin = EdgeInsets.only(
        bottom: isLastChild ? 2 : 0,
        left: 20,
        top: 1,
      );
    } else if (isOrphan) {
      // Orphaned child styling - simple warning
      leadingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhRegular.warning, size: 18, color: Colors.orange),
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
      cardMargin = const EdgeInsets.only(
        top: 4,
      ); // Close to children, normal spacing above
    }

    return Card(
      margin: cardMargin,
      elevation: isChild ? 0.3 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isChild
            ? BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              )
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: isChild ? 6 : 8),
        leading: leadingWidget,
        title: Row(
          children: [
            Expanded(
              child: Text(
                category.name,
                style: TextStyle(
                  fontWeight: isParent ? FontWeight.w500 : FontWeight.w500,
                  fontSize: isChild ? 12 : 14,
                ),
              ),
            ),
            // Sync status indicator removed
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(PhRegular.dotsThreeVertical, size: 20, color: Colors.grey[600]),
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
            PopupMenuItem(
              value: 'edit',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhRegular.pencilSimple, size: 18),
                  SizedBox(width: 12),
                  Text(ref.tr(context, 'edit')),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhRegular.trash, size: 18, color: Colors.red),
                  SizedBox(width: 12),
                  Text(
                    ref.tr(context, 'delete'),
                    style: const TextStyle(color: Colors.red),
                  ),
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
      categoriesByTypeProvider((userId: userId, type: widget.categoryType)),
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditCategoryScreen(
          categoryType: category.type,
          editingCategory: category,
        ),
      ),
    ).then((result) {
      if (result == true) {
        // Category was saved, refresh the list
        refreshCategoryProviders(ref);
      }
    });
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) {
    // Use the new comprehensive delete dialog
    CategoryDeleteDialog.show(context, ref, category);
  }
}
