class LedgerEntry {
  final String entryId;
  final String userId;
  final String walletId;
  final String? categoryId;
  final double amount; // absolute amount
  final double signedAmount; // + income/transfer_in, - expense/transfer_out
  final DateTime date;
  final String? notes;
  final String kind; // 'transaction' | 'transfer_in' | 'transfer_out'
  final String? transferId;
  final String? counterpartWalletId; // transfers: the wallet on the other side

  const LedgerEntry({
    required this.entryId,
    required this.userId,
    required this.walletId,
    this.categoryId,
    required this.amount,
    required this.signedAmount,
    required this.date,
    this.notes,
    required this.kind,
    this.transferId,
    this.counterpartWalletId,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      entryId: json['entry_id'] as String,
      userId: json['user_id'] as String,
      walletId: json['wallet_id'] as String,
      categoryId: json['category_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      signedAmount: (json['signed_amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      notes: json['notes'] as String?,
      kind: json['kind'] as String,
      transferId: json['transfer_id'] as String?,
      counterpartWalletId: json['counterpart_wallet_id'] as String?,
    );
  }
}
