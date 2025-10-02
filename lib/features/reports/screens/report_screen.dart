import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/report_providers.dart';
import '../widgets/report_header.dart';
import '../widgets/income_expense_toggle.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/category_list_tile.dart';
import '../models/report_models.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final reportState = ref.watch(reportStateProvider);

    if (currentUserId == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    final reportDataAsync = ref.watch(reportDataProvider(currentUserId));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            const ReportHeader(),

            // Content
            Expanded(
              child: reportDataAsync.when(
                data: (data) => _buildContent(data, reportState),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Gagal memuat data laporan',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.red[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
    );
  }

  Widget _buildContent(ReportData data, ReportState reportState) {
    return Column(
      children: [
        // Chart dan List Section (digabung dengan toggle)
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
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
                  color: Colors.grey.shade200,
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
    final categories = data.categories;

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              reportState.type == ReportType.income
                  ? 'Belum ada data pemasukan'
                  : 'Belum ada data pengeluaran',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mulai catat transaksi untuk melihat laporan',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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
            onTap: () => _navigateToDetail(category),
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
            color: Colors.grey[400]!,
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

  void _navigateToDetail(CategoryReportItem category) {
    // TODO: Navigate to category detail screen
    // Navigator.pushNamed(
    //   context,
    //   '/category-detail',
    //   arguments: category,
    // );
  }

  void _showOthersDetail(
    List<CategoryReportItem> otherCategories,
    ReportState reportState,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
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
                      style: const TextStyle(
                        fontSize: 18,
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
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToDetail(category);
                    },
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
