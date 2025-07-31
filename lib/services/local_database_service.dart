import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wallet.dart';
import '../models/category.dart';
import '../models/transaction.dart';

// Provider untuk LocalDatabaseService
final localDatabaseServiceProvider = Provider<LocalDatabaseService>((ref) {
  return LocalDatabaseService();
});

class LocalDatabaseService {
  static LocalDatabaseService? _instance;

  LocalDatabaseService._internal();

  factory LocalDatabaseService() {
    _instance ??= LocalDatabaseService._internal();
    return _instance!;
  }

  // Wallet operations
  Future<List<Wallet>> getWallets(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final walletsJson = prefs.getStringList('wallets_$userId') ?? [];
    return walletsJson
        .map((json) => Wallet.fromJson(jsonDecode(json)))
        .where((wallet) => !wallet.isDeleted)
        .toList();
  }

  Future<Wallet?> getWallet(String walletId, String userId) async {
    final wallets = await getWallets(userId);
    try {
      return wallets.firstWhere((wallet) => wallet.id == walletId);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveWallet(Wallet wallet) async {
    final prefs = await SharedPreferences.getInstance();
    final wallets = await getWallets(wallet.userId);
    
    // Remove existing wallet with same ID
    wallets.removeWhere((w) => w.id == wallet.id);
    // Add updated wallet
    wallets.add(wallet);

    final walletsJson = wallets.map((w) => jsonEncode(w.toJson())).toList();
    await prefs.setStringList('wallets_${wallet.userId}', walletsJson);
  }

  Future<void> deleteWallet(String walletId, String userId) async {
    final wallet = await getWallet(walletId, userId);
    if (wallet != null) {
      final deletedWallet = wallet.copyWith(
        isDeleted: true,
        needsSync: true,
        updatedAt: DateTime.now(),
      );
      await saveWallet(deletedWallet);
    }
  }

  Future<List<Wallet>> getUnsyncedWallets(String userId) async {
    final wallets = await getWallets(userId);
    return wallets.where((wallet) => wallet.needsSync).toList();
  }

  // Category operations
  Future<List<Category>> getCategories(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = prefs.getStringList('categories_$userId') ?? [];
    return categoriesJson
        .map((json) => Category.fromJson(jsonDecode(json)))
        .where((category) => !category.isDeleted)
        .toList();
  }

  Future<List<Category>> getCategoriesByType(String userId, CategoryType type) async {
    final categories = await getCategories(userId);
    return categories.where((category) => category.type == type).toList();
  }

  Future<Category?> getCategory(String categoryId, String userId) async {
    final categories = await getCategories(userId);
    try {
      return categories.firstWhere((category) => category.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveCategory(Category category) async {
    final prefs = await SharedPreferences.getInstance();
    final categories = await getCategories(category.userId);
    
    // Remove existing category with same ID
    categories.removeWhere((c) => c.id == category.id);
    // Add updated category
    categories.add(category);

    final categoriesJson = categories.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList('categories_${category.userId}', categoriesJson);
  }

  Future<void> deleteCategory(String categoryId, String userId) async {
    final category = await getCategory(categoryId, userId);
    if (category != null) {
      final deletedCategory = category.copyWith(
        isDeleted: true,
        needsSync: true,
        updatedAt: DateTime.now(),
      );
      await saveCategory(deletedCategory);
    }
  }

  Future<List<Category>> getUnsyncedCategories(String userId) async {
    final categories = await getCategories(userId);
    return categories.where((category) => category.needsSync).toList();
  }

  // Mark as synced
  Future<void> markWalletSynced(String walletId, String userId) async {
    final wallet = await getWallet(walletId, userId);
    if (wallet != null) {
      final syncedWallet = wallet.copyWith(
        needsSync: false,
      );
      await saveWallet(syncedWallet);
    }
  }

  Future<void> markCategorySynced(String categoryId, String userId) async {
    final category = await getCategory(categoryId, userId);
    if (category != null) {
      final syncedCategory = category.copyWith(
        needsSync: false,
      );
      await saveCategory(syncedCategory);
    }
  }

  // Utility methods
  Future<void> clearAllData(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wallets_$userId');
    await prefs.remove('categories_$userId');
    await prefs.remove('transactions_$userId');
  }

  // Transaction operations
  Future<List<Transaction>> getTransactions(String userId, {
    String? walletId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final transactionsJson = prefs.getStringList('transactions_$userId') ?? [];
    var transactions = transactionsJson
        .map((json) => Transaction.fromJson(jsonDecode(json)))
        .where((transaction) => !transaction.isDeleted)
        .toList();

    // Apply filters
    if (walletId != null) {
      transactions = transactions.where((t) => t.walletId == walletId).toList();
    }
    if (categoryId != null) {
      transactions = transactions.where((t) => t.categoryId == categoryId).toList();
    }
    if (startDate != null) {
      transactions = transactions.where((t) => !t.date.isBefore(startDate)).toList();
    }
    if (endDate != null) {
      transactions = transactions.where((t) => !t.date.isAfter(endDate)).toList();
    }

    // Sort by date descending
    transactions.sort((a, b) => b.date.compareTo(a.date));
    return transactions;
  }

  Future<Transaction?> getTransaction(String transactionId, String userId) async {
    final transactions = await getTransactions(userId);
    try {
      return transactions.firstWhere((transaction) => transaction.id == transactionId);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveTransaction(Transaction transaction) async {
    final prefs = await SharedPreferences.getInstance();
    final transactions = await getTransactions(transaction.userId);
    
    // Remove existing transaction with same ID
    transactions.removeWhere((t) => t.id == transaction.id);
    // Add updated transaction
    transactions.add(transaction);

    final transactionsJson = transactions.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList('transactions_${transaction.userId}', transactionsJson);
  }

  Future<void> deleteTransaction(String transactionId, String userId) async {
    final transaction = await getTransaction(transactionId, userId);
    if (transaction != null) {
      final deletedTransaction = transaction.copyWith(
        isDeleted: true,
        needsSync: true,
        updatedAt: DateTime.now(),
      );
      await saveTransaction(deletedTransaction);
    }
  }

  Future<List<Transaction>> getUnsyncedTransactions(String userId) async {
    final transactions = await getTransactions(userId);
    return transactions.where((transaction) => transaction.needsSync).toList();
  }

  Future<void> markTransactionSynced(String transactionId, String userId) async {
    final transaction = await getTransaction(transactionId, userId);
    if (transaction != null) {
      final syncedTransaction = transaction.copyWith(
        needsSync: false,
      );
      await saveTransaction(syncedTransaction);
    }
  }
}
