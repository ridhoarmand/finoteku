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
  final Function(String name, Color color, IconData? icon, String? parentId) onSave;

  const CategoryFormDialog({
    super.key,
    required this.title,
    required this.categoryType,
    this.initialName,
    this.initialParentId,
    this.initialIcon,
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
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.brown,
    Colors.indigo,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _selectedIcon = widget.initialIcon;
    _selectedParentId = widget.initialParentId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxDialogHeight = screenHeight * 0.8; // 80% of screen height
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: maxDialogHeight,
          maxWidth: 500, // Max width for better UX on tablets
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                        prefixIcon: Icon(
                          Icons.label_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      textCapitalization: TextCapitalization.words,
                      maxLength: 50,
                      onChanged: (value) {
                        setState(() {
                          // Auto-suggest icon based on name if no custom icon selected
                          _selectedIcon ??= CategoryIconHelper.getIconForCategory(value);
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    
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
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
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
                                  _selectedIcon,
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
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Current: ',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CategoryIconHelper.buildCategoryIcon(
                      _selectedIcon ?? CategoryIconHelper.getIconForCategory(_nameController.text),
                      size: 24,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedIcon != null ? 'Custom Icon' : 'Auto-detected',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (_selectedIcon == null)
                          Text(
                            'Based on category name',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_selectedIcon != null)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedIcon = null; // Reset to auto-detect
                        });
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reset'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
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
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _availableColors.map((color) {
              final isSelected = color == _selectedColor;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = color;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 3,
                          )
                        : Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: _getContrastColor(color),
                          size: 20,
                        )
                      : null,
                ),
              );
            }).toList(),
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
          ],
        ),
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a parent category to create a sub-category, or leave empty for a main category.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              
              // Parent Category Dropdown
              currentUser.when(
                data: (user) {
                  if (user == null) return const SizedBox.shrink();
                  
                  final parentCategoriesAsync = ref.watch(
                    categoriesByTypeProvider((userId: user.id, type: widget.categoryType))
                  );
                  
                  return parentCategoriesAsync.when(
                    data: (categories) {
                      // Filter only parent categories (those with parentId == null)
                      final parentCategories = categories
                          .where((cat) => cat.parentId == null)
                          .toList();
                      
                      return DropdownButtonFormField<String?>(
                        value: _selectedParentId,
                        decoration: InputDecoration(
                          labelText: 'Parent Category (Optional)',
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.category_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
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
                                children: [
                                  CategoryIconHelper.buildCategoryIcon(
                                    category.iconCodePoint != null 
                                        ? IconData(category.iconCodePoint!, fontFamily: 'MaterialIcons')
                                        : CategoryIconHelper.getIconForCategory(category.name),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(category.name),
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
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, stack) => Text(
                      'Error loading parent categories: ${error.toString()}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (error, stack) => Text('Error: $error'),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Color _getContrastColor(Color backgroundColor) {
    // Calculate contrast color (white or black) based on background
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
