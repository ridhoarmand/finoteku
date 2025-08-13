class Transaction {
  final String id;
  final String userId;
  final String walletId;
  final String? categoryId;
  final double amount;
  final String? notes;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Transaction({
    required this.id,
    required this.userId,
    required this.walletId,
    this.categoryId,
    required this.amount,
    this.notes,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'wallet_id': walletId,
      'category_id': categoryId,
      'amount': amount,
      'notes': notes,
      'date': date.toIso8601String().split('T')[0], // Store as date only
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
  // Offline flags removed
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      walletId: json['wallet_id'] as String,
      categoryId: json['category_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      notes: json['notes'] as String?,
      date: DateTime.parse(json['date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Transaction copyWith({
    String? id,
    String? userId,
    String? walletId,
    String? categoryId,
    double? amount,
    String? notes,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    // offline flags removed
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      walletId: walletId ?? this.walletId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction &&
        other.id == id &&
        other.userId == userId &&
        other.walletId == walletId &&
        other.categoryId == categoryId &&
        other.amount == amount &&
        other.notes == notes &&
        other.date == date &&
        other.createdAt == createdAt &&
  other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      walletId,
      categoryId,
      amount,
      notes,
      date,
      createdAt,
  updatedAt,
    );
  }

  @override
  String toString() {
  return 'Transaction(id: $id, userId: $userId, walletId: $walletId, categoryId: $categoryId, amount: $amount, notes: $notes, date: $date, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

class CreateTransactionRequest {
  final String walletId;
  final String? categoryId;
  final double amount;
  final String? notes;
  final DateTime date;

  const CreateTransactionRequest({
    required this.walletId,
    this.categoryId,
    required this.amount,
    this.notes,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'wallet_id': walletId,
      'category_id': categoryId,
      'amount': amount,
      'notes': notes,
      'date': date.toIso8601String().split('T')[0],
    };
  }

  factory CreateTransactionRequest.fromJson(Map<String, dynamic> json) {
    return CreateTransactionRequest(
      walletId: json['wallet_id'] as String,
      categoryId: json['category_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      notes: json['notes'] as String?,
      date: DateTime.parse(json['date'] as String),
    );
  }
}

class UpdateTransactionRequest {
  final String? walletId;
  final String? categoryId;
  final double? amount;
  final String? notes;
  final DateTime? date;

  const UpdateTransactionRequest({
    this.walletId,
    this.categoryId,
    this.amount,
    this.notes,
    this.date,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (walletId != null) json['wallet_id'] = walletId;
    if (categoryId != null) json['category_id'] = categoryId;
    if (amount != null) json['amount'] = amount;
    if (notes != null) json['notes'] = notes;
    if (date != null) json['date'] = date!.toIso8601String().split('T')[0];
    return json;
  }

  factory UpdateTransactionRequest.fromJson(Map<String, dynamic> json) {
    return UpdateTransactionRequest(
      walletId: json['wallet_id'] as String?,
      categoryId: json['category_id'] as String?,
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      notes: json['notes'] as String?,
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : null,
    );
  }
}
