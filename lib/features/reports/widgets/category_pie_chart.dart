import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/report_providers.dart';
import '../models/report_models.dart';
import '../../../utils/currency_formatter.dart';

class CategoryPieChart extends ConsumerWidget {
  final List<CategoryReportItem> categories;

  const CategoryPieChart({super.key, required this.categories});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportStateProvider);

    if (categories.isEmpty) {
      return _buildEmptyChart(context, state);
    }

    final totalAmount = categories.fold<double>(
      0,
      (sum, cat) => sum + cat.amount,
    );

    return Container(
      height: 200, // Ukuran yang sekarang
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          // Pie Chart
          Center(
            child: PieChart(
              PieChartData(
                sections: _buildPieSections(),
                centerSpaceRadius: 50, // Ruang di tengah untuk total
                sectionsSpace: 2,
                startDegreeOffset: -90,
                borderData: FlBorderData(show: false),
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    // Handle touch interactions if needed
                  },
                ),
              ),
            ),
          ),

          // Total amount di tengah
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.type == ReportType.income
                      ? 'Total Pemasukan'
                      : 'Total Pengeluaran',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.formatCompact(totalAmount),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Toggle button di kiri atas (pojok container)
          Positioned(
            top: 2,
            left: 2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    spreadRadius: 0,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () => toggleDetailCategories(ref),
                borderRadius: BorderRadius.circular(6),
                child: Icon(
                  state.showDetailCategories
                      ? Icons.unfold_less
                      : Icons.unfold_more,
                  size: 16,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    if (categories.isEmpty) return [];

    final totalAmount = categories.fold<double>(
      0,
      (sum, cat) => sum + cat.amount,
    );

    // Define vibrant colors for pie chart
    final pieColors = [
      const Color(0xFF0293EE),
      const Color(0xFFFF6740),
      const Color(0xFF13D38E),
      const Color(0xFFFFD23F),
      const Color(0xFFFF4081),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFFF44336),
    ];

    // Take top 6 categories for cleaner display
    final displayCategories = categories.take(6).toList();
    final sections = <PieChartSectionData>[];

    for (int i = 0; i < displayCategories.length; i++) {
      final category = displayCategories[i];
      final percentage = totalAmount > 0
          ? (category.amount / totalAmount * 100)
          : 0;

      sections.add(
        PieChartSectionData(
          value: category.amount,
          color: pieColors[i % pieColors.length],
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 55,
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          titlePositionPercentageOffset: 0.65,
        ),
      );
    }

    // Add "Others" section if there are more than 6 categories
    if (categories.length > 6) {
      final othersAmount = categories
          .skip(6)
          .fold<double>(0, (sum, cat) => sum + cat.amount);

      if (othersAmount > 0) {
        final percentage = totalAmount > 0
            ? (othersAmount / totalAmount * 100)
            : 0;
        sections.add(
          PieChartSectionData(
            value: othersAmount,
            color: Colors.grey[400]!,
            title: '${percentage.toStringAsFixed(1)}%',
            radius: 55,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            titlePositionPercentageOffset: 0.65,
          ),
        );
      }
    }

    return sections;
  }

  Widget _buildEmptyChart(BuildContext context, ReportState state) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              state.type == ReportType.income
                  ? 'Belum ada data pemasukan'
                  : 'Belum ada data pengeluaran',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
