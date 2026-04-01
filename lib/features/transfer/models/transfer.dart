class Transfer {
  final String id;
  final String userId;
  final String fromWalletId;
  final String toWalletId;
  final double amount;
  final double fee;
  final String? notes;
  final DateTime date;

  const Transfer({
    required this.id,
    required this.userId,
    required this.fromWalletId,
    required this.toWalletId,
    required this.amount,
    this.fee = 0.0,
    required this.date,
    this.notes,
  });

  factory Transfer.fromMap(Map<String, dynamic> map) {
    return Transfer(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      fromWalletId: map['from_wallet_id'] as String,
      toWalletId: map['to_wallet_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      fee: map['fee'] != null ? (map['fee'] as num).toDouble() : 0.0,
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
    );
  }
}
