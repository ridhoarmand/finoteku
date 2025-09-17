import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/category.dart';
import '../../../utils/category_icon_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../providers/category_providers.dart';
import '../data/category_suggestions.dart';
import '../../../services/supabase_service.dart';
import '../theme/category_theme.dart';

class CategoryFormDialog extends ConsumerStatefulWidget {
  final String title;
  final CategoryType categoryType;
  final String? initialName;
  final String? initialParentId;
  final IconData? initialIcon;
  final Color? initialColor; // Add initial color parameter
  final String? editingCategoryId; // Add this to prevent self-selection
  final Function(String name, Color color, IconData? icon, String? parentId)
  onSave;

  const CategoryFormDialog({
    super.key,
    required this.title,
    required this.categoryType,
    this.initialName,
    this.initialParentId,
    this.initialIcon,
    this.initialColor, // Add this parameter
    this.editingCategoryId, // Add this parameter
    required this.onSave,
  });

  @override
  ConsumerState<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<CategoryFormDialog> {
  late TextEditingController _nameController;
  IconData? _selectedIcon;
  String? _selectedParentId;
  String? _selectedParentName; // keep name for icon/suggestion context

  // Color palette removed

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _selectedIcon = widget.initialIcon;
    _selectedParentId = widget.initialParentId;
  // Parent name is resolved lazily when dropdown loads
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxDialogHeight = screenHeight * 0.90; // 90% of screen height
    final maxDialogWidth = screenWidth * 0.98; // 98% of screen width

    return Dialog(
      insetPadding: const EdgeInsets.all(8), // Reduce default padding
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: maxDialogHeight,
            maxWidth: maxDialogWidth.clamp(
              450.0, // Increased minimum width
              double.infinity, // Remove max width limit
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      widget.categoryType == CategoryType.expense
                          ? Icons.trending_down
                          : Icons.trending_up,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Name Input
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: ref.tr(context, 'category_name_label'),
                          border: const OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        maxLength: 50,
                      ),
                      // Saran Kategori (ringkas)
                      _buildSuggestionChips(context),
                      const SizedBox(height: 8),

                      // Parent Category Selection
                      _buildParentSelectionSection(context),
                      const SizedBox(height: 20),

                      // Icon Selection Section
                      _buildIconSection(context),
                      const SizedBox(height: 20),

                      // Color Selection Section
                      _buildColorSection(context),
                    ],
                  ),
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(ref.tr(context, 'cancel')),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _nameController.text.trim().isEmpty
                          ? null
                          : () {
                              final autoColor = CategoryTheme.forType(widget.categoryType);
                              widget.onSave(
                                _nameController.text.trim(),
                                autoColor,
                                _selectedIcon ?? Icons.category,
                                _selectedParentId,
                              );
                              Navigator.of(context).pop();
                            },
                      child: Text(ref.tr(context, 'save')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionChips(BuildContext context) {
    final suggestions = CategorySuggestions.forType(widget.categoryType);
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header dihilangkan agar ringkas
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in suggestions.take(6))
              ActionChip(
                label: Text(s),
                onPressed: () {
                  setState(() {
                    _nameController.text = s;
                    _selectedIcon = CategoryIconHelper.getIconForCategory(s);
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildIconSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.palette_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              ref.tr(context, 'select_icon'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Current Icon Display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    '${ref.tr(context, 'preview')}: ',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  Builder(builder: (context) {
                    final previewColor = CategoryTheme.forType(widget.categoryType);
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: previewColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CategoryIconHelper.buildCategoryIcon(
                        _selectedIcon ?? Icons.category,
                        size: 24,
                        color: previewColor,
                      ),
                    );
                  }),
                  const SizedBox(width: 12),
                  if (_selectedIcon != null)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedIcon = null; // Reset to default
                        });
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(ref.tr(context, 'reset')),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Icon Grid
              Container(
                height: 180, // Fixed height to prevent overflow
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: CategoryIconHelper.buildIconSelectionGrid(
                  selectedIcon: _selectedIcon,
                  onIconSelected: (icon) {
                    setState(() {
                      _selectedIcon = icon;
                    });
                  },
                  iconSize: 20,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Color selector removed
  Widget _buildColorSection(BuildContext context) => const SizedBox.shrink();

  Widget _buildParentSelectionSection(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              ref.tr(context, 'parent_category'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: ref.tr(context, 'parent_info_tooltip'),
              onPressed: () {
                _showParentCategoryInfo(context);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Parent Category Dropdown
        currentUser.when(
          data: (user) {
            if (user == null) return const SizedBox.shrink();

            final parentCategoriesAsync = ref.watch(
              categoriesByTypeProvider((
                userId: user.id,
                type: widget.categoryType,
              )),
            );

            return parentCategoriesAsync.when(
              data: (categories) {
                // Filter only parent categories (those with parentId == null)
                // AND exclude the category being edited to prevent self-selection
                // AND exclude any child categories of the category being edited
                final parentCategories = categories.where((cat) {
                  // Must be a parent category (parentId == null)
                  if (cat.parentId != null) return false;

                  // Cannot be the category being edited
                  if (cat.id == widget.editingCategoryId) return false;

                  // Cannot be a child of the category being edited
                  if (widget.editingCategoryId != null &&
                      cat.parentId == widget.editingCategoryId) {
                    return false;
                  }

                  return true;
                }).toList();

                return DropdownButtonFormField<String?>(
                  initialValue: _selectedParentId,
                  isExpanded: true, // Fix overflow
                  decoration: InputDecoration(
                    labelText: ref.tr(context, 'parent_category_optional'),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(ref.tr(context, 'none_main_category')),
                    ),
                    ...parentCategories.map((category) {
                      return DropdownMenuItem<String?>(
                        value: category.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CategoryIconHelper.buildCategoryIcon(
                              category.iconCodePoint != null
                                  ? IconData(
                                      category.iconCodePoint!,
                                      fontFamily: 'MaterialIcons',
                                    )
                                  : CategoryIconHelper.getIconForCategory(
                                      category.name,
                                    ),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                category.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedParentId = value;
                        // Update selected parent name for suggestions/icon inheritance
                        if (value == null) {
                          _selectedParentName = null;
                        } else {
                          final found = parentCategories.firstWhere(
                            (c) => c.id == value,
                            orElse: () => parentCategories.first,
                          );
                          _selectedParentName = found.name;
                          // If user hasn't chosen an icon, inherit from parent name
                          _selectedIcon = CategoryIconHelper.inheritIcon(
                            childIcon: _selectedIcon,
                            parentName: _selectedParentName!,
                          );
                        }
                    });
                  },
                );
              },
              loading: () => DropdownButtonFormField<String?>(
                items: [],
                onChanged: null,
                decoration: InputDecoration(
                  labelText: ref.tr(context, 'loading'),
                  border: OutlineInputBorder(),
                ),
              ),
              error: (error, stack) => Text(
                ref.tr(context, 'error_loading_parent_categories'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (error, stack) => Text(ref.tr(context, 'error_loading_user')),
        ),
      ],
    );
  }

  // Contrast helper removed (no longer used)

  void _showParentCategoryInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.account_tree_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(ref.tr(context, 'parent_info_title')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.tr(context, 'parent_info_desc'),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            _buildInfoItem(
              ref.tr(context, 'main_category'),
              ref.tr(context, 'main_category_desc'),
            ),
            const SizedBox(height: 8),
            _buildInfoItem(
              ref.tr(context, 'sub_category'),
              ref.tr(context, 'sub_category_desc'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref.tr(context, 'example'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(ref.tr(context, 'example_food_main')),
                  Text(ref.tr(context, 'example_fast_food_sub')),
                  Text(ref.tr(context, 'example_groceries_sub')),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(ref.tr(context, 'got_it')),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          description,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
