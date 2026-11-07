import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../models/category.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/category_icon_helper.dart';
import '../providers/category_providers.dart';
import '../services/category_service.dart';
import '../theme/category_theme.dart';
import '../widgets/category_icon_picker.dart';

class AddEditCategoryScreen extends ConsumerStatefulWidget {
  final CategoryType categoryType;
  final Category? editingCategory;

  const AddEditCategoryScreen({
    super.key,
    required this.categoryType,
    this.editingCategory,
  });

  @override
  ConsumerState<AddEditCategoryScreen> createState() =>
      _AddEditCategoryScreenState();
}

class _AddEditCategoryScreenState extends ConsumerState<AddEditCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  IconData? _selectedIcon;
  String? _selectedParentId;
  bool _isLoading = false;

  bool get isEditing => widget.editingCategory != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final category = widget.editingCategory!;
      _nameController.text = category.name;
      _selectedParentId = category.parentId;
      if (category.iconCodePoint != null) {
        _selectedIcon = CategoryIconHelper.getIconFromCodePoint(
          category.iconCodePoint,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = SupabaseService.currentUserId;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(ref.tr(context, 'error'))),
        body: Center(child: Text(ref.tr(context, 'user_not_authenticated'))),
      );
    }

    final categoriesAsync = ref.watch(categoriesProvider(userId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        title: Text(
          isEditing
              ? ref.tr(context, 'edit_category')
              : ref.tr(context, 'add_category'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _saveCategory,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(ref.tr(context, 'save')),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(80, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card with Category Type
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CategoryTheme.forType(widget.categoryType),
                      CategoryTheme.forType(
                        widget.categoryType,
                      ).withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        widget.categoryType == CategoryType.expense
                            ? Icons.trending_down
                            : Icons.trending_up,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.categoryType == CategoryType.expense
                          ? ref.tr(context, 'expense_category')
                          : ref.tr(context, 'income_category'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Category Name Section
              _buildSectionCard(
                context,
                title: ref.tr(context, 'category_information'),
                icon: Icons.info_outline_rounded,
                showHint: true,
                hintAction: () => _showCategoryExamplesModal(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref.tr(context, 'category_name'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: ref.tr(context, 'enter_category_name'),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline,
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.error,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return ref.tr(context, 'category_name_required');
                        }
                        if (value.trim().length < 2) {
                          return ref.tr(context, 'category_name_too_short');
                        }
                        return null;
                      },
                      autofocus: !isEditing,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Icon Selection Section
              _buildSectionCard(
                context,
                title: ref.tr(context, 'select_icon'),
                icon: Icons.palette_outlined,
                child: CategoryIconPicker(
                  selectedIcon: _selectedIcon,
                  onIconSelected: (icon) {
                    setState(() {
                      _selectedIcon = icon;
                    });
                  },
                  categoryType: widget.categoryType,
                ),
              ),

              const SizedBox(height: 12),

              // Parent Category Selection
              categoriesAsync.when(
                loading: () => _buildSectionCard(
                  context,
                  title: ref.tr(context, 'parent_category'),
                  icon: Icons.account_tree_outlined,
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
                error: (error, stack) => _buildSectionCard(
                  context,
                  title: ref.tr(context, 'parent_category'),
                  icon: Icons.account_tree_outlined,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ref.tr(context, 'error_loading_categories'),
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (categories) {
                  final parentCandidates = categories
                      .where(
                        (c) =>
                            c.type == widget.categoryType &&
                            c.parentId == null &&
                            (isEditing
                                ? c.id != widget.editingCategory!.id
                                : true),
                      )
                      .toList();

                  if (parentCandidates.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return _buildSectionCard(
                    context,
                    title: ref.tr(context, 'parent_category_optional'),
                    icon: Icons.account_tree_outlined,
                    showHint: true,
                    hintAction: () => _showParentCategoryHintModal(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ref.tr(context, 'parent_category_description'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonFormField<String?>(
                            initialValue: _selectedParentId,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            hint: Text(
                              ref.tr(context, 'select_parent_category'),
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.clear,
                                      size: 20,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      ref.tr(context, 'no_parent_category'),
                                      style: TextStyle(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...parentCandidates.map(
                                (category) => DropdownMenuItem<String>(
                                  value: category.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: CategoryTheme.forType(
                                            widget.categoryType,
                                          ).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Icon(
                                          category.iconCodePoint != null
                                              ? CategoryIconHelper.getIconFromCodePoint(
                                                  category.iconCodePoint!,
                                                )
                                              : Icons.category,
                                          size: 18,
                                          color: CategoryTheme.forType(
                                            widget.categoryType,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: Text(
                                          category.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedParentId = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
    bool showHint = false,
    VoidCallback? hintAction,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 20, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (showHint) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: hintAction,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = SupabaseService.currentUserId!;
      final categoryService = ref.read(categoryServiceProvider);

      if (isEditing) {
        // Update existing category
        await categoryService.updateCategory(
          widget.editingCategory!.id,
          userId,
          UpdateCategoryRequest(
            name: _nameController.text.trim(),
            iconCodePoint: _selectedIcon?.codePoint,
            parentId: _selectedParentId,
          ),
        );
      } else {
        // Create new category
        await categoryService.createCategory(
          userId,
          CreateCategoryRequest(
            name: _nameController.text.trim(),
            type: widget.categoryType,
            iconCodePoint: _selectedIcon?.codePoint,
            parentId: _selectedParentId,
          ),
        );
      }

      // Refresh categories provider
      ref.invalidate(categoriesProvider(userId));

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? ref.tr(context, 'category_updated_success')
                  : ref.tr(context, 'category_added_success'),
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? ref.tr(context, 'error_updating_category')
                  : ref.tr(context, 'error_creating_category'),
            ),
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

  void _showCategoryExamplesModal(BuildContext context) {
    final theme = Theme.of(context);
    final examples = widget.categoryType == CategoryType.expense
        ? [
            {'icon': Icons.restaurant, 'name': 'Makanan'},
            {'icon': Icons.checkroom, 'name': 'Fashion/Pakaian'},
            {'icon': Icons.school, 'name': 'Pendidikan'},
            {'icon': Icons.receipt_long, 'name': 'Tagihan'},
            {'icon': Icons.home, 'name': 'Angsuran'},
          ]
        : [
            {'icon': Icons.work, 'name': 'Gaji'},
            {'icon': Icons.trending_up, 'name': 'Investasi'},
            {'icon': Icons.card_giftcard, 'name': 'Bonus'},
            {'icon': Icons.redeem, 'name': 'Hadiah'},
            {'icon': Icons.business, 'name': 'Bisnis'},
          ];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contoh Kategori ${widget.categoryType == CategoryType.expense ? 'Pengeluaran' : 'Pemasukan'}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...examples.map(
                (example) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        example['icon'] as IconData,
                        size: 20,
                        color: CategoryTheme.forType(widget.categoryType),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        example['name'] as String,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(ref.tr(context, 'close')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showParentCategoryHintModal(BuildContext context) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contoh Kategori Induk',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.school,
                          size: 18,
                          color: CategoryTheme.forType(widget.categoryType),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pendidikan',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.subdirectory_arrow_right, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Bayar Sekolah',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.subdirectory_arrow_right, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Beli Alat Sekolah',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(ref.tr(context, 'close')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
