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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'BotLink(platform: $platform, username: $platformUsername, aiProvider: $aiProvider)';
  }
}

/// Available AI providers
enum AIProvider {
  none('none', 'Tanpa AI'),
  gemini('gemini', 'Google Gemini'),
  openai('openai', 'OpenAI');

  final String value;
  final String displayName;

  const AIProvider(this.value, this.displayName);

  static AIProvider fromValue(String value) {
    return AIProvider.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AIProvider.none,
    );
  }
}
