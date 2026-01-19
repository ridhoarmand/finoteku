import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/report_providers.dart';
import '../widgets/report_header.dart';
import '../widgets/income_expense_toggle.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/category_list_tile.dart';
import '../widgets/category_transactions_sheet.dart';
import '../services/report_service.dart';
import '../../transaction/screens/transaction_detail_screen.dart';
import '../models/report_models.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(currentUserIdProvider);
    final reportState = ref.watch(reportStateProvider);

    if (currentUserId == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
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
                          'Gagal memuat data laporan',
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
                          child: const Text('Coba Lagi'),
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
              'Mulai catat transaksi untuk melihat laporan',
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
            // onTap: () => _showCategoryTransactions(category, reportState), // Disabled temporarily
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

  Future<void> _showCategoryTransactions(
    CategoryReportItem category,
    ReportState state,
  ) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
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
      Navigator.of(context).pop(); // Close loading

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
      Navigator.of(context).pop(); // Close loading on error
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat transaksi: $e')));
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
                      'Detail Kategori Lainnya',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
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
