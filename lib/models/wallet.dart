class Wallet {
  final String id;
  final String userId;
  final String name;
  final double balance;
  final String currency;
  final String? icon; // Icon path
  final bool isHidden;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Wallet({
    required this.id,
    required this.userId,
    required this.name,
    required this.balance,
    this.currency = 'IDR',
    this.icon,
    this.isHidden = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'balance': balance,
      'currency': currency,
      'icon': icon,
      'is_hidden': isHidden,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      balance: (json['balance'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'IDR',
      icon: json['icon'] as String?,
      isHidden: json['is_hidden'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Wallet copyWith({
    String? id,
    String? userId,
    String? name,
    double? balance,
    String? currency,
    String? icon,
    bool? isHidden,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Wallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      icon: icon ?? this.icon,
      isHidden: isHidden ?? this.isHidden,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
  final String? icon;

  const CreateWalletRequest({
    required this.name,
    required this.initialBalance,
    this.currency = 'IDR',
    this.icon,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'initial_balance': initialBalance,
      'currency': currency,
      'icon': icon,
    };
  }
}

class UpdateWalletRequest {
  final String? name;
  final double? balance;
  final String? currency;
  final String? icon;
  final bool? isHidden;

  const UpdateWalletRequest({
    this.name,
    this.balance,
    this.currency,
    this.icon,
    this.isHidden,
  });

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    if (name != null) result['name'] = name;
    if (balance != null) result['balance'] = balance;
    if (currency != null) result['currency'] = currency;
    if (icon != null) result['icon'] = icon;
    if (isHidden != null) result['is_hidden'] = isHidden;
    return result;
  }
}
