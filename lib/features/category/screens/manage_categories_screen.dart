import 'package:flutter/material.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen>
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
            Tab(
              icon: Icon(Icons.trending_down),
              text: 'Expense',
            ),
            Tab(
              icon: Icon(Icons.trending_up),
              text: 'Income',
            ),
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
        children: const [
          CategoryListTab(categoryType: 'expense'),
          CategoryListTab(categoryType: 'income'),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    // Get current tab index to determine category type
    final isExpense = _tabController.index == 0;
    final categoryType = isExpense ? 'expense' : 'income';
    
    showDialog(
      context: context,
      builder: (context) => CategoryFormDialog(
        title: 'Add ${isExpense ? 'Expense' : 'Income'} Category',
        categoryType: categoryType,
        onSave: (name, color) {
          _handleAddCategory(categoryType, name, color);
        },
      ),
    );
  }

  void _handleAddCategory(String type, String name, int color) async {
    try {
      // TODO: Implement category creation when CategoryService is ready
      print('Adding $type category: $name with color: $color');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name category added successfully')),
        );
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

class CategoryListTab extends StatelessWidget {
  final String categoryType;

  const CategoryListTab({
    super.key,
    required this.categoryType,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual category provider when ready
    return _buildMockCategoryList(context);
  }

  Widget _buildMockCategoryList(BuildContext context) {
    final isExpense = categoryType == 'expense';
    
    // Mock data for now
    final mockCategories = isExpense
        ? [
            {'name': 'Food & Dining', 'color': Colors.red.value, 'icon': Icons.restaurant},
            {'name': 'Transportation', 'color': Colors.blue.value, 'icon': Icons.directions_car},
            {'name': 'Shopping', 'color': Colors.purple.value, 'icon': Icons.shopping_bag},
            {'name': 'Entertainment', 'color': Colors.orange.value, 'icon': Icons.movie},
            {'name': 'Healthcare', 'color': Colors.green.value, 'icon': Icons.local_hospital},
            {'name': 'Utilities', 'color': Colors.brown.value, 'icon': Icons.electrical_services},
          ]
        : [
            {'name': 'Salary', 'color': Colors.green.value, 'icon': Icons.work},
            {'name': 'Freelance', 'color': Colors.blue.value, 'icon': Icons.computer},
            {'name': 'Investment', 'color': Colors.teal.value, 'icon': Icons.trending_up},
            {'name': 'Gift', 'color': Colors.pink.value, 'icon': Icons.card_giftcard},
            {'name': 'Other Income', 'color': Colors.indigo.value, 'icon': Icons.attach_money},
          ];

    if (mockCategories.isEmpty) {
      return _buildEmptyState(context, isExpense);
    }

    return RefreshIndicator(
      onRefresh: () async {
        // TODO: Implement refresh when CategoryService is ready
        print('Refreshing ${categoryType} categories');
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: mockCategories.length,
        itemBuilder: (context, index) {
          final category = mockCategories[index];
          return _buildCategoryCard(context, category);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isExpense) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isExpense ? Icons.trending_down : Icons.trending_up,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 24),
          Text(
            'No ${isExpense ? 'Expense' : 'Income'} Categories',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first ${isExpense ? 'expense' : 'income'} category\nto start organizing your transactions',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => _showAddCategoryDialog(context, isExpense),
            icon: const Icon(Icons.add),
            label: Text('Add ${isExpense ? 'Expense' : 'Income'} Category'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Map<String, dynamic> category) {
    final theme = Theme.of(context);
    final color = Color(category['color'] as int);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(
            category['icon'] as IconData,
            color: color,
          ),
        ),
        title: Text(
          category['name'] as String,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          '${categoryType.toUpperCase()} Category',
          style: theme.textTheme.bodySmall,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, category, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showCategoryDetails(context, category),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, Map<String, dynamic> category, String action) {
    switch (action) {
      case 'edit':
        _showEditCategoryDialog(context, category);
        break;
      case 'delete':
        _showDeleteConfirmation(context, category);
        break;
    }
  }

  void _showAddCategoryDialog(BuildContext context, bool isExpense) {
    showDialog(
      context: context,
      builder: (context) => CategoryFormDialog(
        title: 'Add ${isExpense ? 'Expense' : 'Income'} Category',
        categoryType: isExpense ? 'expense' : 'income',
        onSave: (name, color) {
          // TODO: Implement when CategoryService is ready
          print('Adding category: $name with color: $color');
        },
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (context) => CategoryFormDialog(
        title: 'Edit Category',
        categoryType: categoryType,
        initialName: category['name'] as String,
        initialColor: category['color'] as int,
        onSave: (name, color) {
          // TODO: Implement when CategoryService is ready
          print('Editing category: $name with color: $color');
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category['name']}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteCategory(context, category);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(BuildContext context, Map<String, dynamic> category) {
    // TODO: Implement when CategoryService is ready
    print('Deleting category: ${category['name']}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${category['name']} deleted')),
    );
  }

  void _showCategoryDetails(BuildContext context, Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category['name'] as String),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Type: '),
                Text(
                  categoryType.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Color: '),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Color(category['color'] as int),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Usage: 0 transactions'), // TODO: Get real usage count
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class CategoryFormDialog extends StatefulWidget {
  final String title;
  final String categoryType;
  final String? initialName;
  final int? initialColor;
  final Function(String name, int color) onSave;

  const CategoryFormDialog({
    super.key,
    required this.title,
    required this.categoryType,
    this.initialName,
    this.initialColor,
    required this.onSave,
  });

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _selectedColor = Colors.blue.value;
  bool _isLoading = false;

  final List<Color> _availableColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
    if (widget.initialColor != null) {
      _selectedColor = widget.initialColor!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter category name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Color',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _availableColors.length,
                itemBuilder: (context, index) {
                  final color = _availableColors[index];
                  final isSelected = _selectedColor == color.value;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color.value;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleSave,
          child: _isLoading 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      widget.onSave(_nameController.text.trim(), _selectedColor);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.initialName != null 
                  ? 'Category updated successfully' 
                  : 'Category created successfully',
            ),
          ),
        );
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
