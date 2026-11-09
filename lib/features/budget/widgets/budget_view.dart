import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:finoteku/theme/ph_icons.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../models/category.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/category_icon_helper.dart';
import '../../../utils/currency_formatter.dart';
import '../../../widgets/icon_tile.dart';
import '../../../widgets/inline_error.dart';
import '../../category/providers/category_providers.dart';
import '../../category/theme/category_theme.dart';
import '../models/budget.dart';
import '../providers/budget_providers.dart';
import 'budget_sheet.dart';

String _rp(double v) => CurrencyFormatter.format(v, 'IDR');

/// Bar colour: the given hue while within budget, amber from 80%, red from 100%.
/// The text next to every bar says the same, so colour is never the only signal.
Color budgetColor(BuildContext context, BudgetState state, Color hue) => switch (state) {
  BudgetState.ok => hue,
  BudgetState.near => context.colors.warning,
  BudgetState.over => context.colors.expense,
};

class BudgetBar extends StatelessWidget {
  final double ratio;
  final Color color;
  final double height;
  const BudgetBar({super.key, required this.ratio, required this.color, this.height = 6});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: ratio.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: context.colors.sunken,
        color: color,
      ),
    );
  }
}

/// "Sisa Rp x dari Rp y" or "Lewat Rp x dari Rp y".
String budgetTotalLine(WidgetRef ref, BuildContext context, double limit, double spent) => spent > limit
    ? ref.tr(context, 'budget_over_of').replaceAll('{over}', _rp(spent - limit)).replaceAll('{limit}', _rp(limit))
    : ref.tr(context, 'budget_left_of').replaceAll('{left}', _rp(limit - spent)).replaceAll('{limit}', _rp(limit));

/// Picks an expense category, then opens the limit sheet for it.
Future<void> addBudgetFlow(BuildContext context, WidgetRef ref, String userId) async {
  final picked = await context.push(
    '/categories/select?userId=$userId&title=${Uri.encodeComponent(ref.tr(context, 'budget_add'))}',
  );
  if (picked is! Category || !context.mounted) return;
  if (picked.type != CategoryType.expense) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.tr(context, 'budget_pick_expense'))));
    return;
  }
  // a subcategory's spending counts toward its parent: budget the parent
  final rootId = picked.parentId ?? picked.id;
  final all = ref.read(categoriesAllProvider(userId)).value ?? const <Category>[];
  final root = all.where((c) => c.id == rootId).firstOrNull ?? picked;
  final existing = ref
      .read(budgetMonthProvider(budgetKey(userId, DateTime.now())))
      .value
      ?.categories
      .where((p) => p.budget.categoryId == root.id)
      .firstOrNull;
  await showBudgetSheet(context, userId: userId, categoryId: root.id, title: root.name, existing: existing?.budget);
}

/// The Anggaran tab inside Laporan: month total, one row per budget, then
/// categories with spending but no budget.
class BudgetView extends ConsumerWidget {
  final String userId;
  final DateTime month;
  const BudgetView({super.key, required this.userId, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = budgetKey(userId, month);
    final async = ref.watch(budgetMonthProvider(key));
    final categories = ref.watch(categoriesAllProvider(userId)).value ?? const <Category>[];
    final byId = {for (final c in categories) c.id: c};

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: InlineError(onRetry: () => ref.invalidate(budgetMonthProvider(key))),
        ),
      ),
      data: (m) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _TotalCard(userId: userId, month: month, data: m),
          const SizedBox(height: 16),
          if (m.categories.isNotEmpty)
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < m.categories.length; i++) ...[
                    if (i > 0) const Divider(indent: 68),
                    _BudgetRow(
                      userId: userId,
                      progress: m.categories[i],
                      category: byId[m.categories[i].budget.categoryId],
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => addBudgetFlow(context, ref, userId),
            icon: const Icon(PhRegular.plus),
            label: Text(ref.tr(context, 'budget_add')),
          ),
          if (m.unbudgeted.isNotEmpty) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                ref.tr(context, 'budget_unbudgeted'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.colors.muted),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < m.unbudgeted.length; i++) ...[
                    if (i > 0) const Divider(indent: 68),
                    _UnbudgetedRow(userId: userId, category: byId[m.unbudgeted[i].$1], spent: m.unbudgeted[i].$2),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TotalCard extends ConsumerWidget {
  final String userId;
  final DateTime month;
  final BudgetMonth data;
  const _TotalCard({required this.userId, required this.month, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final (limit, spent) = data.total;
    final overall = data.overall;
    final title = ref
        .tr(context, 'budget_title_month')
        .replaceAll('{month}', DateFormat('MMMM yyyy', locale).format(month));

    if (data.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(PhRegular.piggyBank, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(ref.tr(context, 'budget_setup_cta'), style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                ref.tr(context, 'budget_setup_body'),
                style: theme.textTheme.bodyMedium?.copyWith(color: context.colors.muted),
              ),
            ],
          ),
        ),
      );
    }

    final state = BudgetProgress.stateOf(limit <= 0 ? 0 : spent / limit);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showBudgetSheet(
          context,
          userId: userId,
          categoryId: null,
          title: ref.tr(context, 'budget_overall'),
          existing: overall?.budget,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.labelLarge?.copyWith(color: context.colors.muted)),
              const SizedBox(height: 4),
              Text(
                budgetTotalLine(ref, context, limit, spent),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFeatures: tabularFigures,
                  color: state == BudgetState.over ? context.colors.expense : null,
                ),
              ),
              const SizedBox(height: 12),
              BudgetBar(
                ratio: limit <= 0 ? 0 : spent / limit,
                color: budgetColor(context, state, theme.colorScheme.primary),
                height: 8,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      overall == null ? ref.tr(context, 'budget_overall_hint') : ref.tr(context, 'budget_overall'),
                      style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
                    ),
                  ),
                  Icon(PhRegular.pencilSimple, size: 16, color: context.colors.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetRow extends ConsumerWidget {
  final String userId;
  final BudgetProgress progress;
  final Category? category;
  const _BudgetRow({required this.userId, required this.progress, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hue = CategoryTheme.forCategory(context, progress.budget.categoryId);
    final name = category?.name ?? ref.tr(context, 'uncategorized');
    final state = progress.state;
    final status = switch (state) {
      BudgetState.over =>
        ref
            .tr(context, 'budget_over_of')
            .replaceAll('{over}', _rp(-progress.remaining))
            .replaceAll('{limit}', _rp(progress.budget.amount)),
      _ =>
        ref
            .tr(context, 'budget_spent_of')
            .replaceAll('{spent}', _rp(progress.spent))
            .replaceAll('{limit}', _rp(progress.budget.amount)),
    };

    return InkWell(
      onTap: () => showBudgetSheet(
        context,
        userId: userId,
        categoryId: progress.budget.categoryId,
        title: name,
        existing: progress.budget,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            IconTile(
              CategoryIconHelper.iconFor(codePoint: category?.iconCodePoint, name: name),
              color: hue,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        '${(progress.ratio * 100).round()}%',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFeatures: tabularFigures,
                          color: state == BudgetState.ok ? null : budgetColor(context, state, hue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  BudgetBar(ratio: progress.ratio, color: budgetColor(context, state, hue)),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: tabularFigures,
                      color: state == BudgetState.ok ? context.colors.muted : budgetColor(context, state, hue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnbudgetedRow extends ConsumerWidget {
  final String userId;
  final Category? category;
  final double spent;
  const _UnbudgetedRow({required this.userId, required this.category, required this.spent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = category;
    final name = c?.name ?? ref.tr(context, 'uncategorized');
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      child: Row(
        children: [
          IconTile(
            CategoryIconHelper.iconFor(codePoint: c?.iconCodePoint, name: name),
            color: context.colors.muted,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                Text(
                  _rp(spent),
                  style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted, fontFeatures: tabularFigures),
                ),
              ],
            ),
          ),
          if (c != null)
            TextButton(
              onPressed: () => showBudgetSheet(context, userId: userId, categoryId: c.id, title: name),
              child: Text(ref.tr(context, 'budget_set')),
            ),
        ],
      ),
    );
  }
}
