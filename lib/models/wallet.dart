class Wallet {
  final String id;
  final String userId;
  final String name;
  final double balance;
  final String currency;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool needsSync;

  const Wallet({
    required this.id,
    required this.userId,
    required this.name,
    required this.balance,
    this.currency = 'IDR',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.needsSync = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'balance': balance,
      'currency': currency,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
      'needs_sync': needsSync,
    };
  }

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      balance: (json['balance'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'IDR',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
      needsSync: json['needs_sync'] as bool? ?? false,
    );
  }

  Wallet copyWith({
    String? id,
    String? userId,
    String? name,
    double? balance,
    String? currency,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? needsSync,
  }) {
    return Wallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      needsSync: needsSync ?? this.needsSync,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Wallet && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Wallet(id: $id, name: $name, balance: $balance, currency: $currency)';
  }
}

class CreateWalletRequest {
  final String name;
  final double initialBalance;
  final String currency;

  const CreateWalletRequest({
    required this.name,
    required this.initialBalance,
    this.currency = 'IDR',
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'initial_balance': initialBalance,
      'currency': currency,
    };
  }
}

class UpdateWalletRequest {
  final String? name;
  final double? balance;
  final String? currency;
  final bool? isActive;

  const UpdateWalletRequest({
    this.name,
    this.balance,
    this.currency,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    if (name != null) result['name'] = name;
    if (balance != null) result['balance'] = balance;
    if (currency != null) result['currency'] = currency;
    if (isActive != null) result['is_active'] = isActive;
    return result;
  }
}
