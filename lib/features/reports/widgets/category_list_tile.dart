import 'package:flutter/material.dart';
import '../models/report_models.dart';
import '../../../utils/currency_formatter.dart';

class CategoryListTile extends StatelessWidget {
  final CategoryReportItem category;
  final VoidCallback? onTap;
  final int? index; // Index untuk menentukan warna pie chart

  const CategoryListTile({
    super.key,
    required this.category,
    this.onTap,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    // Warna yang sama dengan pie chart
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

    final displayColor = index != null && index! < pieColors.length
        ? pieColors[index!]
        : Colors.grey[400]!;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 4.0,
      ), // Jarak antar item lebih kecil
      padding: const EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 8.0, // Padding vertikal lebih kecil
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(category.icon, color: category.color, size: 20),
                ),

                const SizedBox(width: 10),

                // Category name dengan jumlah transaksi di bawahnya
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${category.transactionCount} transaksi',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                // Full amount (tidak diringkas)
                Text(
                  CurrencyFormatter.format(category.amount, 'IDR'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            // Progress bar sebagai subtitle
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: category.percentage / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(displayColor),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${category.percentage.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
