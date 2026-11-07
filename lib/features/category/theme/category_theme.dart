import 'package:flutter/material.dart';
import '../../../models/category.dart';
import '../../../theme/app_theme.dart';

/// Money colours, resolved for the current light/dark theme (tokens in AppColors).
class CategoryTheme {
  static Color income(BuildContext context) => context.colors.income;
  static Color expense(BuildContext context) => context.colors.expense;
  static Color transfer(BuildContext context) => Theme.of(context).colorScheme.primary;

  static Color forType(BuildContext context, CategoryType type) =>
      type == CategoryType.income ? income(context) : expense(context);

  /// For ledger entries: positive = income colour.
  static Color bySign(BuildContext context, bool isPositive) =>
      isPositive ? income(context) : expense(context);
}
