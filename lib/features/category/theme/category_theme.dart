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

  // Categorical palette (dataviz reference, validated for colour-blind separation),
  // stepped per theme. No colour is stored in the DB, so a category keeps one
  // colour by its slot: the same everywhere and in every month.
  static const _light = [0xFF2A78D6, 0xFFEB6834, 0xFF1BAF7A, 0xFFEDA100, 0xFFE87BA4, 0xFF008300, 0xFF6250D6, 0xFFE34948];
  static const _dark = [0xFF3987E5, 0xFFD95926, 0xFF199E70, 0xFFC98500, 0xFFD55181, 0xFF008300, 0xFF9085E9, 0xFFE66767];

  // shortcut: one app-wide map filled when categories load (categoriesAllProvider);
  // move to a provider if categories of two users are ever shown at once.
  static Map<String, int> _slots = const {};

  /// Slot by creation order among root categories of the same type, so the first
  /// eight income and the first eight expense categories never share a colour.
  static void assignSlots(List<Category> categories) {
    final slots = <String, int>{};
    for (final type in CategoryType.values) {
      final roots = categories.where((c) => c.parentId == null && c.type == type).toList()
        ..sort((a, b) {
          final t = a.createdAt.compareTo(b.createdAt);
          return t != 0 ? t : a.id.compareTo(b.id);
        });
      for (var i = 0; i < roots.length; i++) {
        slots[roots[i].id] = i % 8;
      }
    }
    _slots = slots;
  }

  /// [key]: the root category id, so subcategories share their parent's colour.
  static Color forCategory(BuildContext context, String? key) {
    if (key == null || key.isEmpty) return context.colors.muted;
    var slot = _slots[key];
    if (slot == null) {
      var h = 0;
      for (final c in key.codeUnits) {
        h = (h * 31 + c) & 0x7fffffff; // stable across runs, unlike String.hashCode
      }
      slot = h % 8;
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Color((dark ? _dark : _light)[slot]);
  }

  /// For ledger entries: positive = income colour.
  static Color bySign(BuildContext context, bool isPositive) =>
      isPositive ? income(context) : expense(context);
}
