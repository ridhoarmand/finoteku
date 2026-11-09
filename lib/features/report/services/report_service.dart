import '../../../models/transaction.dart';
import '../../../models/category.dart';
import '../../../services/supabase_service.dart';
import '../models/report_models.dart';
import '../../../utils/category_icon_helper.dart';

class ReportService {
  const ReportService();

  Future<ReportData> getReportData({
    required String userId,
    required DateTime period,
    required ReportType type,
    required ReportPeriod periodType,
    bool showDetailCategories = false,
  }) async {
    try {
      // Tentukan date range berdasarkan period
      final dateRange = _getDateRange(period, periodType);
      final previousDateRange = _getPreviousDateRange(period, periodType);

      final categories = await _getCategories(userId);

      // Query transactions untuk period saat ini
      final currentTransactions = await _getTransactions(
        userId: userId,
        categories: categories,
        startDate: dateRange.start,
        endDate: dateRange.end,
        type: type,
      );

      // Query transactions untuk period sebelumnya (untuk comparison)
      final previousTransactions = await _getTransactions(
        userId: userId,
        categories: categories,
        startDate: previousDateRange.start,
        endDate: previousDateRange.end,
        type: type,
      );

      // Build category report items
      final categoryItems = await _buildCategoryReportItems(
        currentTransactions,
        categories,
        showDetailCategories,
      );

      // Calculate totals using absolute values since we filter by category type
      final totalAmount = currentTransactions.fold<double>(
        0,
        (sum, transaction) => sum + transaction.amount.abs(),
      );

      final previousTotalAmount = previousTransactions.fold<double>(
        0,
        (sum, transaction) => sum + transaction.amount.abs(),
      );

      final changePercentage = previousTotalAmount == 0
          ? 0.0
          : ((totalAmount - previousTotalAmount) / previousTotalAmount) * 100;

      return ReportData(
        period: period,
        type: type,
        periodType: periodType,
        categories: categoryItems,
        totalAmount: totalAmount,
        totalTransactions: currentTransactions.length,
        previousPeriodAmount: previousTotalAmount,
        changePercentage: changePercentage,
      );
    } catch (e) {
      throw Exception('Failed to get report data: $e');
    }
  }

  Future<List<Transaction>> _getTransactions({
    required String userId,
    required List<Category> categories,
    required DateTime startDate,
    required DateTime endDate,
    required ReportType type,
  }) async {
    final client = SupabaseService.client;

    final targetCategoryType = type == ReportType.income
        ? CategoryType.income
        : CategoryType.expense;
    final categoryIds = categories
        .where((cat) => cat.type == targetCategoryType)
        .map((cat) => cat.id)
        .toList();

    if (categoryIds.isEmpty) {
      return [];
    }

    final response = await fetchAllRows(
      client
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .gte('date', startDate.toIso8601String())
          .lte('date', endDate.toIso8601String())
          .inFilter('category_id', categoryIds)
          .order('date', ascending: false)
          .order('id'),
    );

    return response.map((json) => Transaction.fromJson(json)).toList();
  }

  Future<List<Category>> _getCategories(String userId) async {
    final client = SupabaseService.client;

    final response = await client
        .from('categories')
        .select()
        .eq(
          'user_id',
          userId,
        ) // hidden categories included: their transactions still count
        .order('name', ascending: true);

    return (response as List).map((json) => Category.fromJson(json)).toList();
  }

  Future<List<CategoryReportItem>> _buildCategoryReportItems(
    List<Transaction> transactions,
    List<Category> categories,
    bool showDetailCategories,
  ) async {
    // Group transactions by category
    final Map<String, List<Transaction>> groupedTransactions = {};

    for (final transaction in transactions) {
      if (transaction.categoryId != null) {
        final categoryId = transaction.categoryId!;
        groupedTransactions.putIfAbsent(categoryId, () => []);
        groupedTransactions[categoryId]!.add(transaction);
      }
    }

    // Calculate total amount for percentage calculation
    final totalAmount = transactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.amount.abs(),
    );

    final categoryItems = <CategoryReportItem>[];

    for (final categoryEntry in groupedTransactions.entries) {
      final categoryId = categoryEntry.key;
      final categoryTransactions = categoryEntry.value;

      final category = categories.firstWhere(
        (cat) => cat.id == categoryId,
        orElse: () => Category(
          id: categoryId,
          userId: '',
          name: 'Unknown',
          type: CategoryType.expense,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final categoryAmount = categoryTransactions.fold<double>(
        0,
        (sum, transaction) => sum + transaction.amount.abs(),
      );

      final percentage = totalAmount == 0
          ? 0.0
          : (categoryAmount / totalAmount) * 100;

      // Get icon for category
      final icon = CategoryIconHelper.iconFor(codePoint: category.iconCodePoint, name: category.name);

      categoryItems.add(
        CategoryReportItem(
          id: category.id,
          name: category.name,
          icon: icon,
          type: category.type,
          amount: categoryAmount,
          percentage: percentage,
          transactionCount: categoryTransactions.length,
          parentId: category.parentId,
        ),
      );
    }

    // Sort by amount descending
    categoryItems.sort((a, b) => b.amount.compareTo(a.amount));

    // Handle parent-child relationship if needed
    if (!showDetailCategories) {
      return _groupByParentCategories(categoryItems, categories);
    }

    return categoryItems;
  }

  List<CategoryReportItem> _groupByParentCategories(
    List<CategoryReportItem> items,
    List<Category> categories,
  ) {
    final Map<String, CategoryReportItem> parentItems = {};
    final Map<String, List<CategoryReportItem>> childrenMap = {};

    // Separate parent and child items
    for (final item in items) {
      if (item.parentId == null) {
        // This is a parent category
        parentItems[item.id] = item;
      } else {
        // This is a child category, group under parent
        final parentCategory = categories.firstWhere(
          (cat) => cat.id == item.parentId,
          orElse: () => Category(
            id: item.parentId!,
            userId: '',
            name: 'Unknown Parent',
            type: CategoryType.expense,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Add child amount to parent if parent doesn't exist in items
        if (!parentItems.containsKey(item.parentId)) {
          final icon = CategoryIconHelper.iconFor(codePoint: parentCategory.iconCodePoint, name: parentCategory.name);

          parentItems[item.parentId!] = CategoryReportItem(
            id: parentCategory.id,
            name: parentCategory.name,
            icon: icon,
            type: parentCategory.type,
            amount: 0,
            percentage: 0,
            transactionCount: 0,
          );
        }

        childrenMap.putIfAbsent(item.parentId!, () => []);
        childrenMap[item.parentId!]!.add(item);
      }
    }

    // Aggregate child amounts to parent
    for (final parentId in childrenMap.keys) {
      final children = childrenMap[parentId]!;
      final totalChildAmount = children.fold<double>(
        0,
        (sum, child) => sum + child.amount,
      );
      final totalChildTransactions = children.fold<int>(
        0,
        (sum, child) => sum + child.transactionCount,
      );

      if (parentItems.containsKey(parentId)) {
        final parent = parentItems[parentId]!;
        parentItems[parentId] = parent.copyWith(
          amount: parent.amount + totalChildAmount,
          transactionCount: parent.transactionCount + totalChildTransactions,
          children: children,
        );
      }
    }

    // Recalculate percentages for parent items
    final totalAmount = parentItems.values.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    final result = parentItems.values.map((item) {
      final percentage = totalAmount == 0
          ? 0.0
          : (item.amount / totalAmount) * 100;
      return item.copyWith(percentage: percentage);
    }).toList();

    // Sort by amount descending
    result.sort((a, b) => b.amount.compareTo(a.amount));

    return result;
  }

  DateTimeRange _getDateRange(DateTime period, ReportPeriod periodType) {
    switch (periodType) {
      case ReportPeriod.weekly:
        final startOfWeek = period.subtract(Duration(days: period.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return DateTimeRange(
          start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          end: DateTime(
            endOfWeek.year,
            endOfWeek.month,
            endOfWeek.day,
            23,
            59,
            59,
          ),
        );
      case ReportPeriod.monthly:
        final startOfMonth = DateTime(period.year, period.month, 1);
        final endOfMonth = DateTime(
          period.year,
          period.month + 1,
          0,
          23,
          59,
          59,
        );
        return DateTimeRange(start: startOfMonth, end: endOfMonth);
      case ReportPeriod.yearly:
        final startOfYear = DateTime(period.year, 1, 1);
        final endOfYear = DateTime(period.year, 12, 31, 23, 59, 59);
        return DateTimeRange(start: startOfYear, end: endOfYear);
    }
  }

  DateTimeRange _getPreviousDateRange(
    DateTime period,
    ReportPeriod periodType,
  ) {
    switch (periodType) {
      case ReportPeriod.weekly:
        final previousWeek = period.subtract(const Duration(days: 7));
        return _getDateRange(previousWeek, periodType);
      case ReportPeriod.monthly:
        final previousMonth = DateTime(period.year, period.month - 1, 1);
        return _getDateRange(previousMonth, periodType);
      case ReportPeriod.yearly:
        final previousYear = DateTime(period.year - 1, 1, 1);
        return _getDateRange(previousYear, periodType);
    }
  }

  /// Get transactions for a specific category within a report period
  Future<List<Transaction>> getTransactionsByCategory({
    required String userId,
    required String categoryId,
    required DateTime period,
    required ReportPeriod periodType,
  }) async {
    try {
      final dateRange = _getDateRange(period, periodType);
      final client = SupabaseService.client;

      // Get child category IDs as well
      final categories = await _getCategories(userId);
      final childIds = categories
          .where((c) => c.parentId == categoryId)
          .map((c) => c.id)
          .toList();
      final allCategoryIds = [categoryId, ...childIds];

      final response = await fetchAllRows(
        client
            .from('transactions')
            .select()
            .eq('user_id', userId)
            .inFilter('category_id', allCategoryIds)
            .gte('date', dateRange.start.toIso8601String())
            .lte('date', dateRange.end.toIso8601String())
            .order('date', ascending: false)
            .order('id'),
      );

      return response.map((json) => Transaction.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get transactions by category: $e');
    }
  }
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;

  const DateTimeRange({required this.start, required this.end});
}
