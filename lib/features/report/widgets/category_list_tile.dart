import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/report_models.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/amount_text.dart';

/// One ranked category: name and amount, share as a bar in the single accent hue.
/// One hue on purpose: bars on one baseline compare by length, and colour never
/// has to follow a category across months (dataviz "ranked horizontal bars").
class CategoryListTile extends ConsumerWidget {
  final CategoryReportItem category;
  final VoidCallback? onTap;
  final int? index; // kept for callers; ranking is the list order

  /// Share of the largest category, so the top bar fills the row.
  final double? relativeToMax;

  const CategoryListTile({
    super.key,
    required this.category,
    this.onTap,
    this.index,
    this.relativeToMax,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = context.colors.muted;
    final share = (relativeToMax ?? category.percentage / 100).clamp(0.0, 1.0);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.colors.sunken,
                borderRadius: BorderRadius.circular(AppTheme.rControl),
              ),
              child: Icon(category.icon, size: 22, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(category.name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                      ),
                      AmountText(category.amount, style: theme.textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: share,
                      minHeight: 6,
                      backgroundColor: context.colors.sunken,
                      color: theme.colorScheme.primary,
                      semanticsLabel: category.name,
                      semanticsValue: '${category.percentage.toStringAsFixed(0)}%',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${category.percentage.toStringAsFixed(1)}% · ${ref.tr(context, 'report_tx_count').replaceAll('{n}', '${category.transactionCount}')}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted, fontFeatures: tabularFigures),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(PhRegular.caretRight, size: 16, color: muted),
            ],
          ],
        ),
      ),
    );
  }
}
