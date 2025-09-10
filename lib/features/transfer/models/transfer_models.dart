class CreateWalletTransferRequest {
  final String fromWalletId;
  final String toWalletId;
  final double amount;
  final double fee;
  final String? notes;
  final DateTime date;
  final String? feeCategoryId; // optional, expense

  const CreateWalletTransferRequest({
    required this.fromWalletId,
    required this.toWalletId,
    required this.amount,
    this.fee = 0,
    this.notes,
    required this.date,
    this.feeCategoryId,
  });

  Map<String, dynamic> toJson(String userId) => {
        'p_user_id': userId,
        'p_from_wallet_id': fromWalletId,
        'p_to_wallet_id': toWalletId,
        'p_amount': amount,
        'p_fee': fee,
        'p_notes': notes,
        'p_date': date.toIso8601String().split('T')[0],
        'p_fee_category_id': feeCategoryId,
      };
}
