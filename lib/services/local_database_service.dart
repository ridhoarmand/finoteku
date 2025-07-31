import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final walletsJson = prefs.getStringList('wallets_$userId') ?? [];
      
      final wallets = walletsJson.map((json) {
        try {
          return Wallet.fromJson(jsonDecode(json));
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error parsing wallet JSON: $e');
          }
          // Skip invalid wallet data
          return null;
        }
      }).whereType<Wallet>().where((wallet) => !wallet.isDeleted).toList();

      // Migration: Fix wallets with invalid icons
      bool needsSave = false;
      final fixedWallets = <Wallet>[];
      
      for (final wallet in wallets) {
        Wallet fixedWallet = wallet;
        
        // Fix invalid icon paths
        if (wallet.icon == 'wallet' || (wallet.icon != null && !_isValidIcon(wallet.icon!))) {
          if (kDebugMode) {
            print('🔧 Migrating wallet "${wallet.name}" with invalid icon: ${wallet.icon}');
          }
          
          // If it's Main Wallet, change to Cash with cash icon
          if (wallet.name == 'Main Wallet') {
            fixedWallet = wallet.copyWith(
              name: 'Cash',
              icon: 'cash',
              needsSync: true,
              updatedAt: DateTime.now(),
            );
          } else {
            // For other wallets, set icon to null (use default)
            fixedWallet = wallet.copyWith(
              icon: null,
              needsSync: true,
              updatedAt: DateTime.now(),
            );
          }
          needsSave = true;
        }
        
        fixedWallets.add(fixedWallet);
      }

      // Save migrated wallets
      if (needsSave) {
        final fixedWalletsJson = fixedWallets.map((w) => jsonEncode(w.toJson())).toList();
        await prefs.setStringList('wallets_$userId', fixedWalletsJson);
        if (kDebugMode) {
          print('✅ Migrated wallets saved successfully');
        }
      }

      return fixedWallets;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting wallets for user $userId: $e');
      }
      // Return empty list on error to prevent crashes
      return [];
    }
  }

  // Helper method to check if icon is valid
  bool _isValidIcon(String icon) {
    // List of valid icon names/paths
    const validIcons = [
      'cash',
      'assets/wallets/cash.svg',
      'assets/banks/bca.svg',
      'assets/banks/blu.svg',
      'assets/banks/bni.svg',
      'assets/banks/bri.svg',
      'assets/banks/bsi.svg',
      'assets/banks/btn.svg',
      'assets/banks/mandiri.svg',
      'assets/banks/sea.svg',
      'assets/ewallets/dana.svg',
      'assets/ewallets/doku.svg',
      'assets/ewallets/gopay.svg',
      'assets/ewallets/linkaja.svg',
      'assets/ewallets/ovo.svg',
      'assets/ewallets/sopay.svg',
    ];
    
    return validIcons.contains(icon);
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
    
    // Clear user-specific data
    await prefs.remove('wallets_$userId');
    await prefs.remove('categories_$userId');
    await prefs.remove('transactions_$userId');
    
    // Also clear any cache or temporary data that might exist
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.contains(userId)) {
        await prefs.remove(key);
      }
    }
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
    
    // Get existing transaction to compare for wallet balance update
    Transaction? existingTransaction;
    try {
      existingTransaction = transactions.firstWhere((t) => t.id == transaction.id);
    } catch (e) {
      // Transaction doesn't exist yet
    }
    
    // Remove existing transaction with same ID
    transactions.removeWhere((t) => t.id == transaction.id);
    // Add updated transaction
    transactions.add(transaction);

    final transactionsJson = transactions.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList('transactions_${transaction.userId}', transactionsJson);
    
    // Update wallet balance locally
    await _updateWalletBalanceForTransaction(transaction, existingTransaction);
  }

  Future<void> _updateWalletBalanceForTransaction(Transaction newTransaction, Transaction? oldTransaction) async {
    try {
      // Get the wallet
      final wallet = await getWallet(newTransaction.walletId, newTransaction.userId);
      if (wallet == null) return;
      
      double balanceChange = 0;
      
      if (oldTransaction == null) {
        // New transaction - add the amount
        balanceChange = newTransaction.amount;
      } else {
        // Update transaction - calculate the difference
        if (oldTransaction.walletId == newTransaction.walletId) {
          // Same wallet - just update the difference
          balanceChange = newTransaction.amount - oldTransaction.amount;
        } else {
          // Different wallet - remove from old wallet and add to new wallet
          final oldWallet = await getWallet(oldTransaction.walletId, oldTransaction.userId);
          if (oldWallet != null) {
            final updatedOldWallet = oldWallet.copyWith(
              balance: oldWallet.balance - oldTransaction.amount,
              needsSync: true,
              updatedAt: DateTime.now(),
            );
            await saveWallet(updatedOldWallet);
          }
          balanceChange = newTransaction.amount;
        }
      }
      
      // Update wallet balance
      final updatedWallet = wallet.copyWith(
        balance: wallet.balance + balanceChange,
        needsSync: true,
        updatedAt: DateTime.now(),
      );
      await saveWallet(updatedWallet);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating wallet balance: $e');
      }
    }
  }

  Future<void> deleteTransaction(String transactionId, String userId) async {
    final transaction = await getTransaction(transactionId, userId);
    if (transaction != null) {
      // Update wallet balance before marking as deleted
      await _updateWalletBalanceForTransactionDeletion(transaction);
      
      final deletedTransaction = transaction.copyWith(
        isDeleted: true,
        needsSync: true,
        updatedAt: DateTime.now(),
      );
      
      // Save the deleted transaction (for sync purposes)
      final prefs = await SharedPreferences.getInstance();
      final transactions = await getTransactions(userId);
      transactions.removeWhere((t) => t.id == transactionId);
      transactions.add(deletedTransaction);
      
      final transactionsJson = transactions.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList('transactions_$userId', transactionsJson);
    }
  }

  Future<void> _updateWalletBalanceForTransactionDeletion(Transaction transaction) async {
    try {
      // Get the wallet
      final wallet = await getWallet(transaction.walletId, transaction.userId);
      if (wallet == null) return;
      
      // Remove the transaction amount from wallet balance
      final updatedWallet = wallet.copyWith(
        balance: wallet.balance - transaction.amount,
        needsSync: true,
        updatedAt: DateTime.now(),
      );
      await saveWallet(updatedWallet);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating wallet balance for deletion: $e');
      }
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

  // =============================================
  // ADVANCED WALLET/CATEGORY OPERATIONS
  // =============================================

  // Check if wallet has transactions before deletion
  Future<bool> walletHasTransactions(String walletId, String userId) async {
    final transactions = await getTransactions(userId, walletId: walletId);
    return transactions.isNotEmpty;
  }

  // Check if category has transactions before deletion
  Future<bool> categoryHasTransactions(String categoryId, String userId) async {
    final transactions = await getTransactions(userId, categoryId: categoryId);
    return transactions.isNotEmpty;
  }

  // Transfer all transactions from one wallet to another
  Future<int> transferTransactionsToWallet(String fromWalletId, String toWalletId, String userId) async {
    final transactions = await getTransactions(userId, walletId: fromWalletId);
    
    for (final transaction in transactions) {
      final updatedTransaction = transaction.copyWith(
        walletId: toWalletId,
        needsSync: true,
        updatedAt: DateTime.now(),
      );
      await saveTransaction(updatedTransaction);
    }
    
    // Recalculate balances for both wallets
    await _recalculateWalletBalance(fromWalletId, userId);
    await _recalculateWalletBalance(toWalletId, userId);
    
    return transactions.length;
  }

  // Transfer all transactions from one category to another
  Future<int> transferTransactionsToCategory(String fromCategoryId, String toCategoryId, String userId) async {
    final transactions = await getTransactions(userId, categoryId: fromCategoryId);
    
    // Get category types to determine if amount should be flipped
    final fromCategory = await getCategory(fromCategoryId, userId);
    final toCategory = await getCategory(toCategoryId, userId);
    
    if (fromCategory == null || toCategory == null) {
      throw Exception('Category not found');
    }
    
    final shouldFlipAmount = fromCategory.type != toCategory.type;
    
    for (final transaction in transactions) {
      final updatedTransaction = transaction.copyWith(
        categoryId: toCategoryId,
        amount: shouldFlipAmount ? -transaction.amount : transaction.amount,
        needsSync: true,
        updatedAt: DateTime.now(),
      );
      await saveTransaction(updatedTransaction);
    }
    
    // If amounts were flipped, recalculate all wallet balances
    if (shouldFlipAmount) {
      await _recalculateAllWalletBalances(userId);
    }
    
    return transactions.length;
  }

  // Recalculate wallet balance from transactions
  Future<void> _recalculateWalletBalance(String walletId, String userId) async {
    try {
      final wallet = await getWallet(walletId, userId);
      if (wallet == null) return;
      
      final transactions = await getTransactions(userId, walletId: walletId);
      final calculatedBalance = transactions.fold<double>(0, (sum, transaction) => sum + transaction.amount);
      
      final updatedWallet = wallet.copyWith(
        balance: calculatedBalance,
        needsSync: true,
        updatedAt: DateTime.now(),
      );
      await saveWallet(updatedWallet);
    } catch (e) {
      if (kDebugMode) {
        print('Error recalculating wallet balance: $e');
      }
    }
  }

  // Recalculate all wallet balances for a user
  Future<void> _recalculateAllWalletBalances(String userId) async {
    try {
      final wallets = await getWallets(userId);
      for (final wallet in wallets) {
        await _recalculateWalletBalance(wallet.id, userId);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error recalculating all wallet balances: $e');
      }
    }
  }

  // Public method to recalculate wallet balance (useful for fixing inconsistencies)
  Future<void> recalculateWalletBalance(String walletId, String userId) async {
    await _recalculateWalletBalance(walletId, userId);
  }

  // Public method to recalculate all wallet balances
  Future<void> recalculateAllWalletBalances(String userId) async {
    await _recalculateAllWalletBalances(userId);
  }

  // Safe delete wallet with transaction transfer
  Future<void> safeDeleteWallet(String walletId, String userId, {String? transferToWalletId}) async {
    // Check if wallet has transactions
    final hasTransactions = await walletHasTransactions(walletId, userId);
    
    if (hasTransactions) {
      if (transferToWalletId == null) {
        throw Exception('Wallet has transactions. Please specify a wallet to transfer transactions to.');
      }
      
      // Transfer transactions to another wallet
      await transferTransactionsToWallet(walletId, transferToWalletId, userId);
    }
    
    // Now safe to delete wallet
    await deleteWallet(walletId, userId);
  }

  // Safe delete category with transaction transfer
  Future<void> safeDeleteCategory(String categoryId, String userId, {String? transferToCategoryId}) async {
    // Check if category has transactions
    final hasTransactions = await categoryHasTransactions(categoryId, userId);
    
    if (hasTransactions) {
      if (transferToCategoryId == null) {
        throw Exception('Category has transactions. Please specify a category to transfer transactions to.');
      }
      
      // Transfer transactions to another category
      await transferTransactionsToCategory(categoryId, transferToCategoryId, userId);
    }
    
    // Now safe to delete category
    await deleteCategory(categoryId, userId);
  }
}
