import 'package:flutter/material.dart';
import '../../../models/category.dart';

enum ReportType { income, expense }

enum ReportPeriod { weekly, monthly, yearly }

class ReportData {
  final DateTime period;
  final ReportType type;
  final ReportPeriod periodType;
  final List<CategoryReportItem> categories;
  final double totalAmount;
  final int totalTransactions;
  final double previousPeriodAmount;
  final double changePercentage;

  const ReportData({
    required this.period,
    required this.type,
    required this.periodType,
    required this.categories,
    required this.totalAmount,
    required this.totalTransactions,
    required this.previousPeriodAmount,
    required this.changePercentage,
  });

  ReportData copyWith({
    DateTime? period,
    ReportType? type,
    ReportPeriod? periodType,
    List<CategoryReportItem>? categories,
    double? totalAmount,
    int? totalTransactions,
    double? previousPeriodAmount,
    double? changePercentage,
  }) {
    return ReportData(
      period: period ?? this.period,
      type: type ?? this.type,
      periodType: periodType ?? this.periodType,
      categories: categories ?? this.categories,
      totalAmount: totalAmount ?? this.totalAmount,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      previousPeriodAmount: previousPeriodAmount ?? this.previousPeriodAmount,
      changePercentage: changePercentage ?? this.changePercentage,
    );
  }
}

class CategoryReportItem {
  final String id;
  final String name;
  final IconData icon;
  final CategoryType type; // colour is resolved in the UI for light/dark
  final double amount;
  final double percentage;
  final int transactionCount;
  final String? parentId;
  final List<CategoryReportItem>? children;

  const CategoryReportItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
    required this.amount,
    required this.percentage,
    required this.transactionCount,
    this.parentId,
    this.children,
  });

  bool get isParent => parentId == null;
  bool get hasChildren => children != null && children!.isNotEmpty;

  CategoryReportItem copyWith({
    String? id,
    String? name,
    IconData? icon,
    CategoryType? type,
    double? amount,
    double? percentage,
    int? transactionCount,
    String? parentId,
    List<CategoryReportItem>? children,
  }) {
    return CategoryReportItem(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      percentage: percentage ?? this.percentage,
      transactionCount: transactionCount ?? this.transactionCount,
      parentId: parentId ?? this.parentId,
      children: children ?? this.children,
    );
  }
}

const _keep = Object();

class ReportState {
  final DateTime selectedMonth;
  final ReportPeriod period;
  final ReportType type;
  final bool showDetailCategories;
  final String? walletId; // null = all wallets
  final bool isLoading;
  final String? error;

  const ReportState({
    required this.selectedMonth,
    required this.period,
    required this.type,
    required this.showDetailCategories,
    this.walletId,
    this.isLoading = false,
    this.error,
  });

  ReportState copyWith({
    DateTime? selectedMonth,
    ReportPeriod? period,
    ReportType? type,
    bool? showDetailCategories,
    Object? walletId = _keep,
    bool? isLoading,
    String? error,
  }) {
    return ReportState(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      period: period ?? this.period,
      type: type ?? this.type,
      showDetailCategories: showDetailCategories ?? this.showDetailCategories,
      walletId: walletId == _keep ? this.walletId : walletId as String?,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}
