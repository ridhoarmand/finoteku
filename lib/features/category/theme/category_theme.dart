import 'package:flutter/material.dart';
import '../../../models/category.dart';

class CategoryTheme {
  // Standardized colors
  static const Color income = Colors.green;
  static const Color expense = Colors.red;
  static const Color transfer = Colors.blue;

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
