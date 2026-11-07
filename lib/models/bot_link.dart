/// Model for bot link configuration
class BotLink {
  final String id;
  final String? linkToken;
  final String userId;
  final String platform;
  final String? platformUserId;
  final Map<String, dynamic> metadata; // Flexible JSONB storage
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BotLink({
    required this.id,
    this.linkToken,
    required this.userId,
    required this.platform,
    this.platformUserId,
    this.metadata = const {},
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BotLink.fromJson(Map<String, dynamic> json) {
    // Support both 'id' column and fallback to 'link_token' for compatibility
    final id = json['id'] as String? ?? json['link_token'] as String;
    return BotLink(
      id: id,
      linkToken: json['link_token'] as String?,
      userId: json['user_id'] as String,
      platform: json['platform'] as String,
      platformUserId: json['platform_user_id'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'link_token': linkToken,
      'user_id': userId,
      'platform': platform,
      'platform_user_id': platformUserId,
      'metadata': metadata,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Convenience getters untuk metadata fields
  String? get platformUsername => metadata['username'] as String?;
  String? get chatId => metadata['chat_id'] as String?;
  String get aiProvider => metadata['ai_provider'] as String? ?? 'none';
  String? get aiApiKey => metadata['ai_api_key'] as String?;
  String get parserMode => metadata['parser_mode'] as String? ?? 'server_key';

  BotLink copyWith({
    String? id,
    String? linkToken,
    String? userId,
    String? platform,
    String? platformUserId,
    Map<String, dynamic>? metadata,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BotLink(
      id: id ?? this.id,
      linkToken: linkToken ?? this.linkToken,
      userId: userId ?? this.userId,
      platform: platform ?? this.platform,
      platformUserId: platformUserId ?? this.platformUserId,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if API key is configured (for user_key mode)
  bool get hasApiKey => aiApiKey != null && aiApiKey!.isNotEmpty;

  /// Get masked API key for display
  String get maskedApiKey {
    if (!hasApiKey) return '';
    final key = aiApiKey!;
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 4)}••••${key.substring(key.length - 4)}';
  }

  @override
  String toString() {
    return 'BotLink(platform: $platform, username: $platformUsername, parserMode: $parserMode)';
  }
}

/// Available AI providers (for user_key mode)
enum AIProvider {
  router9('9router', '9Router / OpenAI'),
  openai('openai', 'OpenAI');

  final String value;
  final String displayName;

  const AIProvider(this.value, this.displayName);

  static AIProvider fromValue(String value) {
    return AIProvider.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AIProvider.router9,
    );
  }
}

/// Parser mode options
enum ParserMode {
  regex('regex', 'Tanpa AI', 'Aturan + belajar dari riwayat transaksi Anda'),
  serverKey('server_key', 'AI (Server)', 'Pakai AI dari server, gratis'),
  userKey('user_key', 'AI (Key Sendiri)', 'Pakai API key AI Anda sendiri');

  final String value;
  final String displayName;
  final String description;

  const ParserMode(this.value, this.displayName, this.description);

  static ParserMode fromValue(String value) {
    return ParserMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ParserMode.serverKey,
    );
  }
}
