import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:finoteku/theme/ph_icons.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/currency_formatter.dart';
import '../../category/providers/category_providers.dart';
import '../../report/providers/report_providers.dart';
import '../models/budget.dart';
import '../providers/budget_providers.dart';
import 'budget_view.dart';

/// This month's budget on Beranda: what is left, one bar, and the category that
/// needs attention. Opens Laporan → Anggaran. Hidden while loading or on error
/// (e.g. the budgets migration has not run yet), so Beranda never breaks on it.
class BudgetSummaryCard extends ConsumerWidget {
  final String userId;
  const BudgetSummaryCard({super.key, required this.userId});

  void _open(BuildContext context, WidgetRef ref) {
    final n = ref.read(reportStateProvider.notifier);
    n.updateSelectedMonth(DateTime.now());
    ref.read(reportTabProvider.notifier).show(ReportTab.budget);
    context.go('/reports');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final m = ref.watch(budgetMonthProvider(budgetKey(userId, now))).value;
    if (m == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = context.colors.muted;

    if (m.isEmpty) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(PhRegular.piggyBank, color: theme.colorScheme.primary),
          title: Text(ref.tr(context, 'budget_setup_cta')),
          trailing: Icon(PhRegular.caretRight, size: 16, color: muted),
          onTap: () => _open(context, ref),
        ),
      );
    }

    final (limit, spent) = m.total;
    final ratio = limit <= 0 ? 0.0 : spent / limit;
    final state = BudgetProgress.stateOf(ratio);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final names = {for (final c in ref.watch(categoriesAllProvider(userId)).value ?? const []) c.id: c.name};
    final critical = m.mostCritical;
    final String note;
    if (critical == null) {
      note = ref.tr(context, 'budget_all_ok');
    } else {
      final name = names[critical.budget.categoryId] ?? '';
      note = critical.state == BudgetState.over
          ? ref
                .tr(context, 'budget_cat_over')
                .replaceAll('{name}', name)
                .replaceAll('{amount}', CurrencyFormatter.format(-critical.remaining, 'IDR'))
          : ref
                .tr(context, 'budget_cat_near')
                .replaceAll('{name}', name)
                .replaceAll('{p}', '${((1 - critical.ratio) * 100).round()}');
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ref
                          .tr(context, 'budget_title_month')
                          .replaceAll('{month}', DateFormat('MMMM', locale).format(now)),
                      style: theme.textTheme.labelLarge?.copyWith(color: muted),
                    ),
                  ),
                  Text(
                    '${(ratio * 100).round()}%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontFeatures: tabularFigures,
                      color: state == BudgetState.ok ? muted : budgetColor(context, state, muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                budgetTotalLine(ref, context, limit, spent),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: tabularFigures,
                  fontWeight: FontWeight.w700,
                  color: state == BudgetState.over ? context.colors.expense : null,
                ),
              ),
              const SizedBox(height: 10),
              BudgetBar(ratio: ratio, color: budgetColor(context, state, theme.colorScheme.primary), height: 8),
              const SizedBox(height: 8),
              Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: critical == null ? muted : budgetColor(context, critical.state, muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
