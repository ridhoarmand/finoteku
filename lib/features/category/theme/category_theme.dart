import 'package:flutter/material.dart';
import '../../../models/category.dart';
import '../../../theme/app_theme.dart';

class CategoryTheme {
  // Single source for money colors; matches the app's iOS palette.
  static const Color income = AppTheme.iOSSystemGreen;
  static const Color expense = AppTheme.iOSSystemRed;
  static const Color transfer = AppTheme.iOSSystemBlue;

  static Color forType(CategoryType type) {
    switch (type) {
      case CategoryType.income:
        return income;
      case CategoryType.expense:
        return expense;
    }
  }

  // Convenience: resolve by sign, for ledger entries
  static Color bySign(bool isPositive) => isPositive ? income : expense;
}
