import 'package:flutter/material.dart';

enum FAQCategory {
  gettingStarted,
  transactions,
  categories,
  wallets,
  reports,
  transfers,
  notifications,
  settings,
  troubleshooting;

  String get displayName {
    switch (this) {
      case FAQCategory.gettingStarted:
        return 'Memulai';
      case FAQCategory.transactions:
        return 'Transaksi';
      case FAQCategory.categories:
        return 'Kategori';
      case FAQCategory.wallets:
        return 'Dompet';
      case FAQCategory.reports:
        return 'Laporan';
      case FAQCategory.transfers:
        return 'Transfer';
      case FAQCategory.notifications:
        return 'Notifikasi';
      case FAQCategory.settings:
        return 'Pengaturan';
      case FAQCategory.troubleshooting:
        return 'Pemecahan Masalah';
    }
  }

  IconData get icon {
    switch (this) {
      case FAQCategory.gettingStarted:
        return Icons.rocket_launch;
      case FAQCategory.transactions:
        return Icons.receipt_long;
      case FAQCategory.categories:
        return Icons.category;
      case FAQCategory.wallets:
        return Icons.account_balance_wallet;
      case FAQCategory.reports:
        return Icons.analytics;
      case FAQCategory.transfers:
        return Icons.swap_horiz;
      case FAQCategory.notifications:
        return Icons.notifications;
      case FAQCategory.settings:
        return Icons.settings;
      case FAQCategory.troubleshooting:
        return Icons.build;
    }
  }

  Color get color {
    switch (this) {
      case FAQCategory.gettingStarted:
        return Colors.green;
      case FAQCategory.transactions:
        return Colors.blue;
      case FAQCategory.categories:
        return Colors.orange;
      case FAQCategory.wallets:
        return Colors.purple;
      case FAQCategory.reports:
        return Colors.teal;
      case FAQCategory.transfers:
        return Colors.indigo;
      case FAQCategory.notifications:
        return Colors.amber;
      case FAQCategory.settings:
        return Colors.grey;
      case FAQCategory.troubleshooting:
        return Colors.red;
    }
  }
}

class FAQItem {
  final String id;
  final String question;
  final String answer;
  final FAQCategory category;
  final List<String> keywords;
  final int priority; // Higher number = higher priority in search results

  const FAQItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    this.keywords = const [],
    this.priority = 0,
  });

  bool matchesSearch(String query) {
    final lowercaseQuery = query.toLowerCase();
    return question.toLowerCase().contains(lowercaseQuery) ||
        answer.toLowerCase().contains(lowercaseQuery) ||
        keywords.any(
          (keyword) => keyword.toLowerCase().contains(lowercaseQuery),
        );
  }

  FAQItem copyWith({
    String? id,
    String? question,
    String? answer,
    FAQCategory? category,
    List<String>? keywords,
    int? priority,
  }) {
    return FAQItem(
      id: id ?? this.id,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      category: category ?? this.category,
      keywords: keywords ?? this.keywords,
      priority: priority ?? this.priority,
    );
  }
}

class FAQSection {
  final FAQCategory category;
  final List<FAQItem> items;

  const FAQSection({required this.category, required this.items});

  FAQSection copyWith({FAQCategory? category, List<FAQItem>? items}) {
    return FAQSection(
      category: category ?? this.category,
      items: items ?? this.items,
    );
  }
}
