/// Model untuk summary data user yang akan dihapus saat delete account
class UserDataSummary {
  final int walletsCount;
  final int categoriesCount;
  final int transactionsCount;
  final int transfersCount;

  const UserDataSummary({
    required this.walletsCount,
    required this.categoriesCount,
    required this.transactionsCount,
    required this.transfersCount,
  });

  /// Check apakah user memiliki data yang akan dihapus
  bool get hasData =>
      walletsCount > 0 ||
      categoriesCount > 0 ||
      transactionsCount > 0 ||
      transfersCount > 0;

  /// Total activities (transactions + transfers)
  int get totalActivities => transactionsCount + transfersCount;

  /// Factory method untuk empty summary
  factory UserDataSummary.empty() => const UserDataSummary(
    walletsCount: 0,
    categoriesCount: 0,
    transactionsCount: 0,
    transfersCount: 0,
  );

  /// Factory method dari JSON response Supabase
  factory UserDataSummary.fromJson(Map<String, dynamic> json) =>
      UserDataSummary(
        walletsCount: (json['walletsCount'] as num?)?.toInt() ?? 0,
        categoriesCount: (json['categoriesCount'] as num?)?.toInt() ?? 0,
        transactionsCount: (json['transactionsCount'] as num?)?.toInt() ?? 0,
        transfersCount: (json['transfersCount'] as num?)?.toInt() ?? 0,
      );

  @override
  String toString() {
    return 'UserDataSummary(wallets: $walletsCount, categories: $categoriesCount, transactions: $transactionsCount, transfers: $transfersCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserDataSummary &&
        other.walletsCount == walletsCount &&
        other.categoriesCount == categoriesCount &&
        other.transactionsCount == transactionsCount &&
        other.transfersCount == transfersCount;
  }

  @override
  int get hashCode {
    return walletsCount.hashCode ^
        categoriesCount.hashCode ^
        transactionsCount.hashCode ^
        transfersCount.hashCode;
  }
}
