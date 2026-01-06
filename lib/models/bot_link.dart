/// Model for bot link configuration
class BotLink {
  final String id;
  final String userId;
  final String platform;
  final String platformUserId;
  final String? platformUsername;
  final bool isActive;
  final String aiProvider;
  final String? aiApiKey;
  final String parserMode;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BotLink({
    required this.id,
    required this.userId,
    required this.platform,
    required this.platformUserId,
    this.platformUsername,
    this.isActive = true,
    this.aiProvider = 'none',
    this.aiApiKey,
    this.parserMode = 'regex',
    required this.createdAt,
    required this.updatedAt,
  });

  factory BotLink.fromJson(Map<String, dynamic> json) {
    return BotLink(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      platform: json['platform'] as String,
      platformUserId: json['platform_user_id'] as String,
      platformUsername: json['platform_username'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      aiProvider: json['ai_provider'] as String? ?? 'none',
      aiApiKey: json['ai_api_key'] as String?,
      parserMode: json['parser_mode'] as String? ?? 'regex',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'platform': platform,
      'platform_user_id': platformUserId,
      'platform_username': platformUsername,
      'is_active': isActive,
      'ai_provider': aiProvider,
      'ai_api_key': aiApiKey,
      'parser_mode': parserMode,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  BotLink copyWith({
    String? id,
    String? userId,
    String? platform,
    String? platformUserId,
    String? platformUsername,
    bool? isActive,
    String? aiProvider,
    String? aiApiKey,
    String? parserMode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BotLink(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      platform: platform ?? this.platform,
      platformUserId: platformUserId ?? this.platformUserId,
      platformUsername: platformUsername ?? this.platformUsername,
      isActive: isActive ?? this.isActive,
      aiProvider: aiProvider ?? this.aiProvider,
      aiApiKey: aiApiKey ?? this.aiApiKey,
      parserMode: parserMode ?? this.parserMode,
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
  gemini('gemini', 'Google Gemini'),
  openai('openai', 'OpenAI');

  final String value;
  final String displayName;

  const AIProvider(this.value, this.displayName);

  static AIProvider fromValue(String value) {
    return AIProvider.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AIProvider.gemini,
    );
  }
}

/// Parser mode options
enum ParserMode {
  regex(
    'regex',
    'RegEx (Tanpa AI)',
    'Parsing sederhana dengan aturan kata kunci',
  ),
  serverKey('server_key', 'AI (Server)', 'Pakai AI dari server, gratis'),
  userKey('user_key', 'AI (Key Sendiri)', 'Pakai API key AI Anda sendiri');

  final String value;
  final String displayName;
  final String description;

  const ParserMode(this.value, this.displayName, this.description);

  static ParserMode fromValue(String value) {
    return ParserMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ParserMode.regex,
    );
  }
}
