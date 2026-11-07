import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/faq_models.dart';
import '../../../core/localization/app_localizations.dart';
import '../providers/faq_providers.dart';

class FAQScreen extends ConsumerStatefulWidget {
  const FAQScreen({super.key});

  @override
  ConsumerState<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends ConsumerState<FAQScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  FAQCategory? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final faqData = ref.watch(faqDataProvider);

    final filteredFAQs = _getFilteredFAQs(faqData);

    return Scaffold(
      appBar: AppBar(title: Text(ref.tr(context, 'help_faq')), elevation: 0),
      body: Column(
        children: [
          // Search bar
          Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search input
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: ref.tr(context, 'faq_search_hint'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            tooltip: ref.tr(context, 'clear'),
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),

                const SizedBox(height: 12),

                // Category filter chips
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: FAQCategory.values.length + 1, // +1 for "All"
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // "All" chip
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(ref.tr(context, 'all')),
                            selected: _selectedCategory == null,
                            onSelected: (selected) {
                              setState(() => _selectedCategory = null);
                            },
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            selectedColor: theme.colorScheme.primaryContainer,
                          ),
                        );
                      }

                      final category = FAQCategory.values[index - 1];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category.displayName),
                          selected: _selectedCategory == category,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = selected ? category : null;
                            });
                          },
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          selectedColor: category.color.withValues(alpha: 0.2),
                          avatar: Icon(
                            category.icon,
                            size: 16,
                            color: _selectedCategory == category
                                ? category.color
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // FAQ content
          Expanded(
            child: _searchQuery.isEmpty && _selectedCategory == null
                ? _buildCategoryView(faqData, theme)
                : _buildSearchResults(filteredFAQs, theme),
          ),
        ],
      ),
    );
  }

  List<FAQItem> _getFilteredFAQs(List<FAQSection> faqData) {
    List<FAQItem> allItems = [];

    for (final section in faqData) {
      if (_selectedCategory == null || section.category == _selectedCategory) {
        allItems.addAll(section.items);
      }
    }

    if (_searchQuery.isNotEmpty) {
      allItems = allItems
          .where((item) => item.matchesSearch(_searchQuery))
          .toList();

      // Sort by priority and relevance
      allItems.sort((a, b) => b.priority.compareTo(a.priority));
    }

    return allItems;
  }

  Widget _buildCategoryView(List<FAQSection> faqData, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: faqData.length,
      itemBuilder: (context, index) {
        final section = faqData[index];
        return _buildCategorySection(section, theme);
      },
    );
  }

  Widget _buildCategorySection(FAQSection section, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: section.category.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: section.category.color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                section.category.icon,
                color: section.category.color,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                section.category.displayName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: section.category.color,
                ),
              ),
              const Spacer(),
              Text(
                '${section.items.length} FAQ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: section.category.color,
                ),
              ),
            ],
          ),
        ),

        // FAQ items preview (show first 3)
        ...section.items.take(3).map((item) => _buildFAQTile(item, theme)),

        // Show more button if there are more items
        if (section.items.length > 3)
          TextButton.icon(
            onPressed: () {
              setState(() => _selectedCategory = section.category);
            },
            icon: const Icon(Icons.expand_more),
            label: Text(
              ref
                  .tr(context, 'faq_see_more')
                  .replaceAll('{count}', '${section.items.length - 3}'),
            ),
          ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSearchResults(List<FAQItem> items, ThemeData theme) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              ref.tr(context, 'faq_no_results'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ref.tr(context, 'faq_no_results_hint'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildFAQTile(items[index], theme);
      },
    );
  }

  Widget _buildFAQTile(FAQItem item, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: item.category.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(item.category.icon, color: item.category.color, size: 20),
        ),
        title: Text(
          item.question,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          item.category.displayName,
          style: theme.textTheme.bodySmall?.copyWith(
            color: item.category.color,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  item.answer,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
