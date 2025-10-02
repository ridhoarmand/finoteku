import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/category.dart';

class TransactionSearchFilter extends ConsumerWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final bool showFilters;
  final String? selectedCategoryId;
  final DateTime? startDate;
  final DateTime? endDate;
  final AsyncValue<List<Category>> categoriesAsync;
  final Function(String) onSearchChanged;
  final Function() onToggleFilters;
  final Function(String?) onCategoryChanged;
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
    required this.startDate,
    required this.endDate,
    required this.categoriesAsync,
    required this.onSearchChanged,
    required this.onToggleFilters,
    required this.onCategoryChanged,
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
              Expanded(flex: 7, child: _buildSearchSection(theme)),
              const SizedBox(width: 8),
              // Filter button (30% width)
              Expanded(flex: 3, child: _buildFilterToggle(theme)),
            ],
          ),

          // Filter content (collapsible)
          if (showFilters) ...[
            const SizedBox(height: 8),
            _buildFilterContent(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchSection(ThemeData theme) {
    return Container(
      height: 42, // Fixed height untuk consistency dengan filter button
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        onChanged: onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Cari transaksi...',
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
          prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 18),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[600], size: 16),
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
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFilterToggle(ThemeData theme) {
    final hasActiveFilters =
        selectedCategoryId != null || startDate != null || endDate != null;

    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onToggleFilters,
        icon: Icon(
          showFilters ? Icons.filter_list_off : Icons.tune,
          size: 16,
          color: hasActiveFilters ? Colors.white : theme.colorScheme.primary,
        ),
        label: Text(
          'Filter',
          style: TextStyle(
            color: hasActiveFilters ? Colors.white : theme.colorScheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: hasActiveFilters
              ? theme.colorScheme.primary
              : Colors.white,
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

  Widget _buildFilterContent(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
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
                  'Filter Transaksi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onResetFilters,
                  child: Text(
                    'Reset Semua',
                    style: TextStyle(color: Colors.orange[600], fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date Range Filter
            Builder(
              builder: (context) => _buildDateRangeFilter(context, theme),
            ),
            const SizedBox(height: 16),

            // Category Filter
            _buildCategoryFilter(theme),
            const SizedBox(height: 16),

            // Close Button
            Center(
              child: TextButton.icon(
                onPressed: onToggleFilters,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Tutup Filter'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeFilter(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rentang Tanggal:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Start Date
            Expanded(
              child: _buildDatePicker(
                context: context,
                label: 'Dari Tanggal',
                date: startDate,
                onDateSelected: onStartDateChanged,
                theme: theme,
              ),
            ),
            const SizedBox(width: 8),
            // End Date
            Expanded(
              child: _buildDatePicker(
                context: context,
                label: 'Sampai Tanggal',
                date: endDate,
                onDateSelected: onEndDateChanged,
                theme: theme,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required BuildContext context,
    required String label,
    required DateTime? date,
    required Function(DateTime?) onDateSelected,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        onDateSelected(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[50],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
            const SizedBox(height: 2),
            Text(
              date != null
                  ? '${date.day}/${date.month}/${date.year}'
                  : 'Pilih tanggal',
              style: TextStyle(
                fontSize: 12,
                color: date != null ? Colors.black87 : Colors.grey[500],
                fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(ThemeData theme) {
    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kategori:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: selectedCategoryId,
                  hint: Text(
                    'Pilih Kategori',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                  style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                  items: [
                    // All categories option
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        'Semua Kategori',
                        style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                      ),
                    ),
                    // Category options
                    ...categories.map(
                      (category) => DropdownMenuItem<String?>(
                        value: category.id,
                        child: Text(
                          category.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ),
                  ],
                  onChanged: onCategoryChanged,
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, stackTrace) => const SizedBox.shrink(),
    );
  }
}
