import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/thousand_separator_formatter.dart';
import '../models/budget.dart';
import '../providers/budget_providers.dart';

/// Bottom sheet to set, change or delete one limit. [categoryId] null = overall limit.
Future<void> showBudgetSheet(
  BuildContext context, {
  required String userId,
  required String? categoryId,
  required String title,
  Budget? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BudgetSheet(userId: userId, categoryId: categoryId, title: title, existing: existing),
  );
}

class _BudgetSheet extends ConsumerStatefulWidget {
  final String userId;
  final String? categoryId;
  final String title;
  final Budget? existing;
  const _BudgetSheet({required this.userId, required this.categoryId, required this.title, this.existing});

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  late final _controller = TextEditingController(
    text: widget.existing == null ? '' : CurrencyFormatter.formatForInput(widget.existing!.amount),
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.read(budgetRefreshProvider.notifier).bump();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = ref.tr(context, 'budget_save_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _save() {
    final amount = CurrencyFormatter.parse(_controller.text) ?? 0;
    if (amount <= 0) {
      setState(() => _error = ref.tr(context, 'budget_amount_invalid'));
      return;
    }
    _run(
      () =>
          ref.read(budgetServiceProvider).upsert(userId: widget.userId, categoryId: widget.categoryId, amount: amount),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: theme.textTheme.titleLarge),
          if (widget.categoryId == null) ...[
            const SizedBox(height: 4),
            Text(ref.tr(context, 'budget_overall_hint'), style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandSeparatorFormatter()],
            style: theme.textTheme.headlineSmall,
            decoration: InputDecoration(
              labelText: ref.tr(context, 'budget_amount_label'),
              prefixText: 'Rp ',
              errorText: _error,
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _save, child: Text(ref.tr(context, 'budget_save'))),
          if (widget.existing != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => _run(() => ref.read(budgetServiceProvider).delete(widget.existing!.id)),
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              child: Text(ref.tr(context, 'budget_delete')),
            ),
          ],
        ],
      ),
    );
  }
}
