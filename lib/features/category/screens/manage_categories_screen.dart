import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/category_service.dart';
import '../../../services/supabase_service.dart';
import '../../../models/category.dart';
import '../widgets/category_form_dialog.dart';

class ManageCategoriesScreen extends ConsumerStatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  ConsumerState<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
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
        onSave: (name, color) {
          _handleAddCategory(categoryType, name, color);
        },
      ),
    );
  }

  void _handleAddCategory(CategoryType type, String name, Color color) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final categoryService = ref.read(categoryServiceProvider);
      final request = CreateCategoryRequest(
        name: name,
        type: type,
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

  const CategoryListTab({
    super.key,
    required this.categoryType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = SupabaseService.currentUserId;
    
    if (userId == null) {
      return const Center(
        child: Text('Please login to see categories'),
      );
    }

    final categoriesAsync = ref.watch(categoriesByTypeProvider(
      (userId: userId, type: categoryType),
    ));

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
              onPressed: () => ref.refresh(categoriesByTypeProvider(
                (userId: userId, type: categoryType),
              )),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context, WidgetRef ref, List<Category> categories) {
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
              'No ${categoryType.name} categories yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Categories will be created automatically when you first use the app',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(categoriesByTypeProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _buildCategoryItem(context, ref, category);
        },
      ),
    );
  }

  Widget _buildCategoryItem(BuildContext context, WidgetRef ref, Category category) {
    // Generate icon based on category name
    IconData icon = _getCategoryIcon(category.name);
    Color color = _getCategoryColor(category.name);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${category.type.name.toUpperCase()} Category',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        trailing: PopupMenuButton<String>(
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
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, WidgetRef ref, Category category) {
    showDialog(
      context: context,
      builder: (context) => CategoryFormDialog(
        title: 'Edit ${category.type.name} Category',
        categoryType: category.type,
        initialName: category.name,
        onSave: (name, color) {
          _handleEditCategory(context, ref, category, name, color);
        },
      ),
    );
  }

  void _handleEditCategory(BuildContext context, WidgetRef ref, Category category, String name, Color color) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final categoryService = ref.read(categoryServiceProvider);
      final request = UpdateCategoryRequest(name: name);
      
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

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${category.name}"?\n\n'
          'This action cannot be undone.',
        ),
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

  void _handleDeleteCategory(BuildContext context, WidgetRef ref, Category category) async {
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

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('food') || name.contains('dining')) return Icons.restaurant;
    if (name.contains('transport')) return Icons.directions_car;
    if (name.contains('shopping')) return Icons.shopping_bag;
    if (name.contains('entertainment')) return Icons.movie;
    if (name.contains('health')) return Icons.local_hospital;
    if (name.contains('bill') || name.contains('utilities')) return Icons.electrical_services;
    if (name.contains('salary') || name.contains('work')) return Icons.work;
    if (name.contains('freelance') || name.contains('computer')) return Icons.computer;
    if (name.contains('investment')) return Icons.trending_up;
    if (name.contains('gift')) return Icons.card_giftcard;
    if (name.contains('education')) return Icons.school;
    return Icons.category;
  }

  Color _getCategoryColor(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('food')) return Colors.red;
    if (name.contains('transport')) return Colors.blue;
    if (name.contains('shopping')) return Colors.purple;
    if (name.contains('entertainment')) return Colors.orange;
    if (name.contains('health')) return Colors.green;
    if (name.contains('bill') || name.contains('utilities')) return Colors.brown;
    if (name.contains('salary')) return Colors.green;
    if (name.contains('freelance')) return Colors.blue;
    if (name.contains('investment')) return Colors.teal;
    if (name.contains('gift')) return Colors.pink;
    if (name.contains('education')) return Colors.indigo;
    return Colors.grey;
  }
}
