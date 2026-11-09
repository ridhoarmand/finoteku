import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../category/theme/category_theme.dart';
import '../models/report_models.dart';

/// Share of each category as a ring. Slices wear the category's colour, the
/// same as its tile and bar in the list below, which serves as the legend.
class CategoryDonut extends StatelessWidget {
  final List<CategoryReportItem> categories;
  final double size;

  const CategoryDonut({super.key, required this.categories, this.size = 132});

  @override
  Widget build(BuildContext context) {
    final total = categories.fold<double>(0, (s, c) => s + c.amount);
    final slices = [
      for (final c in categories)
        if (c.amount > 0) (c.amount / total, CategoryTheme.forCategory(context, c.parentId ?? c.id)),
    ];
    return Semantics(
      label: categories.map((c) => '${c.name} ${c.percentage.toStringAsFixed(0)}%').join(', '),
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _DonutPainter(slices, Theme.of(context).colorScheme.surface)),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(double, Color)> slices;
  final Color gap;
  _DonutPainter(this.slices, this.gap);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    var start = -math.pi / 2;
    for (final (share, color) in slices) {
      final sweep = share * 2 * math.pi;
      canvas.drawArc(rect, start, sweep, false, paint..color = color);
      start += sweep;
    }
    // 2px surface gap between slices so neighbours stay apart
    if (slices.length > 1) {
      final gapPaint = Paint()
        ..color = gap
        ..strokeWidth = 2;
      final c = rect.center;
      final rIn = rect.width / 2 - stroke / 2 - 1, rOut = rect.width / 2 + stroke / 2 + 1;
      var a = -math.pi / 2;
      for (final (share, _) in slices) {
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + dir * rIn, c + dir * rOut, gapPaint);
        a += share * 2 * math.pi;
      }
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.slices != slices || old.gap != gap;
}
