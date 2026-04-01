class CreateWalletTransferRequest {
  final String fromWalletId;
  final String toWalletId;
  final double amount;
  final String? notes;
  final DateTime date;

  const CreateWalletTransferRequest({
    required this.fromWalletId,
    required this.toWalletId,
    required this.amount,
    this.notes,
    required this.date,
  });

  Map<String, dynamic> toJson(String userId) => {
    'p_user_id': userId,
    'p_from_wallet_id': fromWalletId,
    'p_to_wallet_id': toWalletId,
    'p_amount': amount,
    'p_notes': notes,
    'p_date': date.toIso8601String().split('T')[0],
  };
}
