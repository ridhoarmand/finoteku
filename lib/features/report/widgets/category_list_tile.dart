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
    final theme = Theme.of(context);

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
        : const Color(0xFF9E9E9E); // Consistent gray color for both themes

    return Container(
      margin: const EdgeInsets.only(
        bottom: 4.0,
      ), // Jarak antar item lebih kecil
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0, // Padding vertikal lebih kecil
            ),
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
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${category.transactionCount} transaksi',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Full amount (tidak diringkas)
                    Text(
                      CurrencyFormatter.format(category.amount, 'IDR'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // Progress bar sebagai subtitle
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: category.percentage / 100,
                        backgroundColor: theme.colorScheme.outline.withValues(
                          alpha: 0.2,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(displayColor),
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${category.percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
