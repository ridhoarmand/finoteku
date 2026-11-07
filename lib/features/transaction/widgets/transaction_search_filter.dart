import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/category.dart';
import '../../../utils/category_icon_helper.dart';
import '../../../utils/monday_first_date_picker.dart';
import '../../category/screens/category_selection_screen.dart';
import '../../../core/localization/app_localizations.dart';

class TransactionSearchFilter extends ConsumerWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final bool showFilters;
  final String? selectedCategoryId;
  final bool includeChildren;
  final DateTime? startDate;
  final DateTime? endDate;
  final String userId;
  final AsyncValue<List<Category>> categoriesAsync;
  final Function(String) onSearchChanged;
  final Function() onToggleFilters;
  final Function(String?) onCategoryChanged;
  final Function(bool) onIncludeChildrenChanged;
  final Function(DateTime?) onStartDateChanged;
  final Function(DateTime?) onEndDateChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onResetFilters;

  const TransactionSearchFilter({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.showFilters,
    required this.selectedCategoryId,
    required this.includeChildren,
    required this.startDate,
    required this.endDate,
    required this.userId,
    required this.categoriesAsync,
    required this.onSearchChanged,
    required this.onToggleFilters,
    required this.onCategoryChanged,
    required this.onIncludeChildrenChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onClearSearch,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          // Compact search and filter button row
          Row(
            children: [
              // Search field (70% width)
              Expanded(
                flex: 7,
                child: _buildSearchSection(context, ref, theme),
              ),
              const SizedBox(width: 8),
              // Filter button (30% width)
              Expanded(flex: 3, child: _buildFilterToggle(context, ref, theme)),
            ],
          ),

          // Filter content (collapsible)
          if (showFilters) ...[
            const SizedBox(height: 8),
            _buildFilterContent(context, ref, theme),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchSection(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    return Container(
      height: 42, // Fixed height untuk consistency dengan filter button
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        onChanged: onSearchChanged,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: ref.tr(context, 'search_transactions'),
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            size: 18,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  tooltip: ref.tr(context, 'clear'),
                  icon: Icon(
                    Icons.clear,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    size: 16,
                  ),
                  onPressed: onClearSearch,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          filled: true,
          fillColor: theme.colorScheme.surface,
        ),
      ),
    );
  }

  Widget _buildFilterToggle(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    final hasActiveFilters = selectedCategoryId != null;

    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onToggleFilters,
        icon: Icon(
          showFilters ? Icons.filter_list_off : Icons.tune,
          size: 16,
          color: hasActiveFilters
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.primary,
        ),
        label: Text(
          ref.tr(context, 'filter'),
          style: TextStyle(
            color: hasActiveFilters
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: hasActiveFilters
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          side: BorderSide(
            color: hasActiveFilters
                ? theme.colorScheme.primary
                : theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterContent(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        // Wrap dengan SingleChildScrollView
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with reset button
            Row(
              children: [
                Text(
                  ref.tr(context, 'filter_title'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: onResetFilters,
                  icon: const Icon(Icons.restart_alt, size: 13),
                  label: Text(ref.tr(context, 'reset')),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Category Filter
            _buildCategoryFilter(context, ref, theme),
            const SizedBox(height: 10),

            // Date Range Filter
            _buildDateRangeFilter(context, ref, theme),
            const SizedBox(height: 10),

            // Close Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onToggleFilters,
                icon: const Icon(Icons.close, size: 15),
                label: Text(ref.tr(context, 'filter_close')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();
        final categoryMap = {
          for (final category in categories) category.id: category,
        };
        final selectedCategory = selectedCategoryId == null
            ? null
            : categoryMap[selectedCategoryId!];
        final selectedLabel = selectedCategory == null
            ? 'Semua Kategori'
            : _buildCategoryPath(selectedCategory, categoryMap);

        final selectedIcon = selectedCategory != null
            ? CategoryIconHelper.getIconFromCodePoint(
                selectedCategory.iconCodePoint,
              )
            : Icons.category;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.tr(context, 'filter_category_label'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final pickedCategory = await Navigator.of(context)
                      .push<Category>(
                        MaterialPageRoute(
                          builder: (context) => CategorySelectionScreen(
                            userId: userId,
                            title: ref.tr(context, 'filter_pick_category'),
                            selectedCategory: selectedCategory,
                          ),
                        ),
                      );

                  if (pickedCategory != null) {
                    onCategoryChanged(pickedCategory.id);
                  }
                },
                icon: Icon(selectedIcon, size: 15),
                label: Text(
                  selectedLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size.fromHeight(36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: selectedCategoryId != null
                      ? () => onCategoryChanged(null)
                      : null,
                  icon: const Icon(Icons.clear, size: 14),
                  label: Text(ref.tr(context, 'all_categories')),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
                const Spacer(),
                FilterChip(
                  label: Text(ref.tr(context, 'subcategories')),
                  selected: includeChildren,
                  onSelected: selectedCategoryId != null
                      ? onIncludeChildrenChanged
                      : null,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, stackTrace) => const SizedBox.shrink(),
    );
  }

  String _buildCategoryPath(
    Category category,
    Map<String, Category> categoryMap,
  ) {
    final parts = <String>[category.name];
    var current = category;

    while (current.parentId != null) {
      final parent = categoryMap[current.parentId!];
      if (parent == null) break;
      parts.add(parent.name);
      current = parent;
    }

    return parts.reversed.join(' > ');
  }

  Widget _buildDateRangeFilter(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    final startDateLabel = startDate != null
        ? _formatDate(startDate!)
        : 'Mulai';
    final endDateLabel = endDate != null ? _formatDate(endDate!) : 'Hingga';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ref.tr(context, 'filter_date_label'),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showMondayFirstDatePicker(
                    context: context,
                    initialDate: startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    onStartDateChanged(picked);
                  }
                },
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(
                  startDateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size.fromHeight(36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showMondayFirstDatePicker(
                    context: context,
                    initialDate: endDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    onEndDateChanged(picked);
                  }
                },
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(
                  endDateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size.fromHeight(36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
