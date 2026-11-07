import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';
import '../providers/report_providers.dart';
import '../widgets/report_header.dart';
import '../widgets/income_expense_toggle.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/category_list_tile.dart';
import '../widgets/category_transactions_sheet.dart';
import '../../transaction/screens/transaction_detail_screen.dart';
import '../../../core/localization/app_localizations.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId != null) {
      ref.invalidate(reportDataProvider(currentUserId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(currentUserIdProvider);
    final reportState = ref.watch(reportStateProvider);

    if (currentUserId == null) {
      return Scaffold(
        body: Center(child: Text(ref.tr(context, 'login_required_short'))),
      );
    }

    final reportDataAsync = ref.watch(reportDataProvider(currentUserId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Invalidate report data provider to reload data
            ref.invalidate(reportDataProvider(currentUserId));
          },
          child: Column(
            children: [
              // Header
              const ReportHeader(),

              // Content
              Expanded(
                child: reportDataAsync.when(
                  data: (data) => _buildContent(data, reportState),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          ref.tr(context, 'report_load_failed'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            ref.invalidate(reportDataProvider(currentUserId));
                          },
                          child: Text(ref.tr(context, 'retry')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ReportData data, ReportState reportState) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Chart dan List Section (digabung dengan toggle)
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Income/Expense Toggle (masuk ke container)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: IncomeExpenseToggle(),
                ),

                // Pie Chart
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: CategoryPieChart(categories: data.categories),
                ),

                const SizedBox(height: 6), // Jarak antara chart dan divider
                // Divider tipis
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),

                const SizedBox(height: 6), // Jarak antara divider dan list
                // Category List (sebagai legend)
                Expanded(child: _buildCategoryList(data, reportState)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCategoryList(ReportData data, ReportState reportState) {
    final theme = Theme.of(context);
    final categories = data.categories;

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              reportState.type == ReportType.income
                  ? 'Belum ada data pemasukan'
                  : 'Belum ada data pengeluaran',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ref.tr(context, 'start_recording'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    // Tampilkan maksimal 6 kategori (sesuai dengan chart) + Others jika ada
    final displayCategories = categories.take(6).toList();
    final hasOthers = categories.length > 6;

    final totalAmount = categories.fold<double>(
      0,
      (sum, cat) => sum + cat.amount,
    );

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 4.0,
      ), // Jarak lebih kecil
      itemCount: displayCategories.length + (hasOthers ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < displayCategories.length) {
          final category = displayCategories[index];
          return CategoryListTile(
            category: category,
            index: index, // Pass index untuk warna yang sama dengan chart
            onTap: () => _handleCategoryTap(category, reportState),
          );
        } else {
          // Others category
          final othersAmount = categories
              .skip(6)
              .fold<double>(0, (sum, cat) => sum + cat.amount);
          final othersPercentage = totalAmount > 0
              ? (othersAmount / totalAmount * 100).toDouble()
              : 0.0;

          final othersCategory = CategoryReportItem(
            id: 'others',
            name: 'Lainnya',
            amount: othersAmount,
            percentage: othersPercentage,
            transactionCount: categories
                .skip(6)
                .fold<int>(0, (sum, cat) => sum + cat.transactionCount),
            color: const Color(0xFF9E9E9E), // Better gray color for both themes
            icon: Icons.more_horiz,
            parentId: null,
            children: [],
          );

          return CategoryListTile(
            category: othersCategory,
            index: 6, // Grey color index
            onTap: () =>
                _showOthersDetail(categories.skip(6).toList(), reportState),
          );
        }
      },
    );
  }

  void _handleCategoryTap(
    CategoryReportItem category,
    ReportState state,
  ) async {
    if (category.hasChildren) {
      await _showSubcategoryDetail(category, state);
    } else {
      _showCategoryTransactions(category, state);
    }
  }

  Future<void> _showSubcategoryDetail(
    CategoryReportItem parentCategory,
    ReportState state,
  ) async {
    final theme = Theme.of(context);
    final children = parentCategory.children ?? [];

    final selectedCategory = await showModalBottomSheet<CategoryReportItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ref
                          .tr(context, 'report_subcategory_of')
                          .replaceAll('{name}', parentCategory.name),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Subcategory list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Parent category option (Semua)
                  CategoryListTile(
                    category: CategoryReportItem(
                      id: parentCategory.id,
                      name: 'Semua ${parentCategory.name}',
                      icon: parentCategory.icon,
                      color: parentCategory.color,
                      amount: parentCategory.amount,
                      percentage: parentCategory.percentage,
                      transactionCount: parentCategory.transactionCount,
                    ),
                    index: 9,
                    onTap: () {
                      Navigator.pop(context, parentCategory);
                    },
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Text(
                          ref.tr(context, 'report_subcategory_detail'),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Expanded(child: Divider(indent: 8)),
                      ],
                    ),
                  ),

                  ...children.asMap().entries.map((entry) {
                    final index = entry.key;
                    final child = entry.value;
                    return CategoryListTile(
                      category: child,
                      index: index % 10,
                      onTap: () {
                        Navigator.pop(context, child);
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedCategory != null && mounted) {
      await Future.delayed(Duration.zero);
      _showCategoryTransactions(selectedCategory, state);
    }
  }

  Future<void> _showCategoryTransactions(
    CategoryReportItem category,
    ReportState state,
  ) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    final startTime = DateTime.now();

    // Show loading dialog safely
    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final transactions = await const ReportService()
          .getTransactionsByCategory(
            userId: currentUserId,
            categoryId: category.id,
            period: state.selectedMonth,
            periodType: state.period,
          );

      if (!mounted) return;

      // Ensure the dialog has been open for at least 150ms to avoid transition conflicts
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      if (elapsed < 150) {
        await Future.delayed(Duration(milliseconds: 150 - elapsed));
      }

      if (!mounted) return;

      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      } else {
        Navigator.of(context).pop();
      }

      // Wait a brief moment for the dialog's closing transition to settle
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      // Show sheet
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => CategoryTransactionsSheet(
          category: category,
          transactions: transactions,
          onTransactionTap: (transactionId) async {
            // Navigate to detail
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    TransactionDetailScreen(transactionId: transactionId),
              ),
            );

            // If transaction changed/deleted, refresh report and close sheet
            if (result == true && mounted) {
              Navigator.of(context).pop();
              ref.invalidate(reportDataProvider(currentUserId));
            }
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // Ensure dialog is closed on error
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      } else {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref
                .tr(context, 'error_loading_transactions')
                .replaceAll('{error}', '$e'),
          ),
        ),
      );
    }
  }

  void _showOthersDetail(
    List<CategoryReportItem> otherCategories,
    ReportState state,
  ) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ref.tr(context, 'report_other_category_detail'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Category list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: otherCategories.length,
                itemBuilder: (context, index) {
                  final category = otherCategories[index];
                  return CategoryListTile(
                    category: category,
                    index: (index + 6) % 10, // Continue color pattern
                    onTap: () => _handleCategoryTap(category, state),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
