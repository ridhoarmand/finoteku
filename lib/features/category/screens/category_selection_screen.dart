import 'package:flutter/material.dart';
import 'package:finoteku/features/category/theme/category_theme.dart';
import 'package:finoteku/widgets/icon_tile.dart';
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

    // Categories sudah diurutkan secara alphabetical dari provider.
    // One card per parent with its children, rows split by dividers (like the ledger list).
    final parents = categories.where((c) => c.parentId == null).toList();
    final children = categories.where((c) => c.parentId != null).toList();
    final parentIds = parents.map((p) => p.id).toSet();
    final groups = [
      for (final p in parents) [p, ...children.where((c) => c.parentId == p.id)],
      // children whose parent is missing (hidden or deleted)
      if (children.any((c) => !parentIds.contains(c.parentId)))
        children.where((c) => !parentIds.contains(c.parentId)).toList(),
    ];

    return RefreshIndicator(
      onRefresh: () async {
        refreshCategoryProviders(ref);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), // room for the FAB
        children: [
          for (final group in groups)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < group.length; i++) ...[
                    if (i > 0) Divider(indent: group[i].parentId == null ? 64 : 88),
                    _buildCategoryItem(context, group[i], isChild: group[i].parentId != null),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(BuildContext context, Category category, {required bool isChild}) {
    final theme = Theme.of(context);
    final isSelected = widget.selectedCategory?.id == category.id;
    final tile = IconTile(
      CategoryIconHelper.iconFor(codePoint: category.iconCodePoint, name: category.name),
      size: isChild ? 28 : 36,
      color: CategoryTheme.forCategory(context, category.parentId ?? category.id),
    );

    return ListTile(
      dense: isChild,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer,
      selectedColor: theme.colorScheme.onPrimaryContainer,
      contentPadding: EdgeInsets.only(left: isChild ? 24 : 14, right: 14),
      leading: isChild
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhRegular.arrowElbowDownRight, size: 16, color: context.colors.muted),
                const SizedBox(width: 6),
                tile,
              ],
            )
          : tile,
      title: Text(
        category.name,
        style: (isChild ? theme.textTheme.bodyMedium : theme.textTheme.titleSmall)?.copyWith(
          color: isSelected ? theme.colorScheme.onPrimaryContainer : null,
        ),
      ),
      trailing: isSelected ? Icon(PhFill.checkCircle, color: theme.colorScheme.primary, size: 20) : null,
      onTap: () => widget.onCategorySelected(category),
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
