import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/faq_models.dart';
import '../services/faq_service.dart';

// FAQ service provider
final faqServiceProvider = Provider<FAQService>((ref) {
  return const FAQService();
});

// FAQ data provider
final faqDataProvider = Provider<List<FAQSection>>((ref) {
  final faqService = ref.read(faqServiceProvider);
  return faqService.getAllFAQs();
});

// Search notifier untuk FAQ
class FAQSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  
  void updateSearch(String query) => state = query;
  void clear() => state = '';
}

final faqSearchProvider = NotifierProvider<FAQSearchNotifier, String>(
  FAQSearchNotifier.new,
);

// Selected category notifier untuk filter
class SelectedFAQCategoryNotifier extends Notifier<FAQCategory?> {
  @override
  FAQCategory? build() => null;
  
  void selectCategory(FAQCategory? category) => state = category;
  void clear() => state = null;
}

final selectedFAQCategoryProvider = NotifierProvider<SelectedFAQCategoryNotifier, FAQCategory?>(
  SelectedFAQCategoryNotifier.new,
);

// Filtered FAQ provider berdasarkan search dan category
final filteredFAQProvider = Provider<List<FAQItem>>((ref) {
  final allFAQs = ref.watch(faqDataProvider);
  final searchQuery = ref.watch(faqSearchProvider);
  final selectedCategory = ref.watch(selectedFAQCategoryProvider);

  List<FAQItem> filteredItems = [];

  // Collect all items
  for (final section in allFAQs) {
    if (selectedCategory == null || section.category == selectedCategory) {
      filteredItems.addAll(section.items);
    }
  }

  // Apply search filter
  if (searchQuery.isNotEmpty) {
    filteredItems = filteredItems
        .where((item) => item.matchesSearch(searchQuery))
        .toList();

    // Sort by priority
    filteredItems.sort((a, b) => b.priority.compareTo(a.priority));
  }

  return filteredItems;
});
