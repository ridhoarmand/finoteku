import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/category.dart';
import '../../../utils/category_icon_helper.dart';
import '../services/category_service.dart';
import '../../../services/supabase_service.dart';

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
  Color _selectedColor = Colors.blue;
  IconData? _selectedIcon;
  String? _selectedParentId;

  final List<Color> _availableColors = [
    // Red variations
    const Color(0xFFE53E3E), // Red
    const Color(0xFFFF6B6B), // Light Red
    const Color(0xFFFF4757), // Coral Red
    const Color(0xFFD63031), // Dark Red
    // Orange variations
    const Color(0xFFFF7F00), // Orange
    const Color(0xFFFF9500), // Light Orange
    const Color(0xFFE17055), // Burnt Orange
    const Color(0xFFFF6348), // Orange Red
    // Yellow variations
    const Color(0xFFFFD93D), // Yellow
    const Color(0xFFFFC312), // Golden Yellow
    const Color(0xFFFFDA79), // Light Yellow
    const Color(0xFFF39C12), // Orange Yellow
    // Green variations
    const Color(0xFF00B894), // Green
    const Color(0xFF55A3FF), // Light Green
    const Color(0xFF26de81), // Mint Green
    const Color(0xFF00a085), // Dark Green
    // Blue variations
    const Color(0xFF3742FA), // Blue
    const Color(0xFF70A1FF), // Light Blue
    const Color(0xFF5352ED), // Purple Blue
    const Color(0xFF2F3542), // Dark Blue
    // Purple variations
    const Color(0xFF8E44AD), // Purple
    const Color(0xFFA55EEA), // Light Purple
    const Color(0xFF6C5CE7), // Violet
    const Color(0xFF2D3436), // Dark Purple
    // Pink variations
    const Color(0xFFE91E63), // Pink
    const Color(0xFFFF6B9D), // Light Pink
    const Color(0xFFE84393), // Rose Pink
    const Color(0xFFD63031), // Deep Pink
    // Additional colors
    const Color(0xFF00CEC9), // Teal
    const Color(0xFF636E72), // Grey
    const Color(0xFF2D3436), // Dark Grey
    const Color(0xFFFFFFFF), // White
    const Color(0xFF000000), // Black
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _selectedIcon = widget.initialIcon;
    _selectedParentId = widget.initialParentId;
    // Initialize color with initial color or default blue
    _selectedColor = widget.initialColor ?? Colors.blue;
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
        onTap: () {
          // Dismiss keyboard when tapping outside text fields
          FocusScope.of(context).unfocus();
        },
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
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
                          labelText: 'Category Name',
                          border: const OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        maxLength: 50,
                      ),
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
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _nameController.text.trim().isEmpty
                          ? null
                          : () {
                              widget.onSave(
                                _nameController.text.trim(),
                                _selectedColor,
                                _selectedIcon ??
                                    Icons
                                        .category, // Use default if none selected
                                _selectedParentId,
                              );
                              Navigator.of(context).pop();
                            },
                      child: const Text('Save'),
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
            const Text(
              'Select Icon',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
                    'Preview: ',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CategoryIconHelper.buildCategoryIcon(
                      _selectedIcon ?? Icons.category,
                      size: 24,
                      color: _selectedColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_selectedIcon != null)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedIcon = null; // Reset to default
                        });
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reset'),
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

  Widget _buildColorSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.color_lens_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text(
              'Select Color',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const Spacer(),
            Text(
              'Swipe →',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
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
          child: SizedBox(
            height: 40, // Fixed height for horizontal scroll
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _availableColors.map((color) {
                  final isSelected = color == _selectedColor;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  width: 3,
                                )
                              : Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.2),
                                    blurRadius: 2,
                                    spreadRadius: 0,
                                  ),
                                ],
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                color: _getContrastColor(color),
                                size: 20,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

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
            const Text(
              'Parent Category',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip:
                  'Select a parent to create a sub-category, or leave empty for main category',
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
                  value: _selectedParentId,
                  isExpanded: true, // Fix overflow
                  decoration: InputDecoration(
                    labelText: 'Parent Category (Optional)',
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None (Main Category)'),
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
                    });
                  },
                );
              },
              loading: () => DropdownButtonFormField<String?>(
                items: [],
                onChanged: null,
                decoration: InputDecoration(
                  labelText: 'Loading...',
                  border: OutlineInputBorder(),
                ),
              ),
              error: (error, stack) => Text(
                'Error loading parent categories',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (error, stack) => Text('Error: $error'),
        ),
      ],
    );
  }

  Color _getContrastColor(Color backgroundColor) {
    // Calculate contrast color (white or black) based on background
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

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
            const Text('Parent Category'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Parent categories help organize your finances hierarchically:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            _buildInfoItem(
              '🏠 Main Category',
              'Select "None" to create a main category that can have sub-categories',
            ),
            const SizedBox(height: 8),
            _buildInfoItem(
              '📁 Sub-category',
              'Select a parent to create a sub-category under it',
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
                    'Example:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('🍽️ Food (Main Category)'),
                  const Text('  └── 🍕 Fast Food (Sub-category)'),
                  const Text('  └── 🥗 Groceries (Sub-category)'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
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
