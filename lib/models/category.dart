enum CategoryType { income, expense }

class Category {
  final String id;
  final String userId;
  final String name;
  final CategoryType type;
  final String? parentId;
  final int? iconCodePoint; // Store Material Icons codePoint for custom icons
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool needsSync;

  const Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.parentId,
    this.iconCodePoint,
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
      'type': type.name,
      'parent_id': parentId,
      'icon_code_point': iconCodePoint,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
      'needs_sync': needsSync,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      type: CategoryType.values.byName(json['type'] as String),
      parentId: json['parent_id'] as String?,
      iconCodePoint: json['icon_code_point'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
      needsSync: json['needs_sync'] as bool? ?? false,
    );
  }

  Category copyWith({
    String? id,
    String? userId,
    String? name,
    CategoryType? type,
    String? parentId,
    int? iconCodePoint,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? needsSync,
  }) {
    return Category(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
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
    return other is Category && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Category(id: $id, name: $name, type: ${type.name})';
  }
}

class CreateCategoryRequest {
  final String name;
  final CategoryType type;
  final String? parentId;
  final int? iconCodePoint;

  const CreateCategoryRequest({
    required this.name,
    required this.type,
    this.parentId,
    this.iconCodePoint,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.name,
      'parent_id': parentId,
      'icon_code_point': iconCodePoint,
    };
  }
}

class UpdateCategoryRequest {
  final String? name;
  final CategoryType? type;
  final String? parentId;
  final int? iconCodePoint;
  final bool? isActive;

  const UpdateCategoryRequest({
    this.name,
    this.type,
    this.parentId,
    this.iconCodePoint,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    if (name != null) result['name'] = name;
    if (type != null) result['type'] = type!.name;
    if (parentId != null) result['parent_id'] = parentId;
    if (iconCodePoint != null) result['icon_code_point'] = iconCodePoint;
    if (isActive != null) result['is_active'] = isActive;
    return result;
  }
}
