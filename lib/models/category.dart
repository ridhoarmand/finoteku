enum CategoryType { income, expense }

class Category {
  final String id;
  final String userId;
  final String name;
  final CategoryType type;
  final String? parentId;
  final int? iconCodePoint; // Nullable sesuai kolom
  final int? color; // Nullable sesuai kolom
  final bool isActive;
  final bool isHidden; // Kolom baru di skema
  final DateTime createdAt;
  final DateTime updatedAt;

  const Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.parentId,
    this.iconCodePoint,
    this.color,
    this.isActive = true,
    this.isHidden = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'type': type.name,
      'parent_id': parentId,
      'icon_code_point': iconCodePoint,
      'color': color,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
  'is_hidden': isHidden,
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
      color: json['color'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
  isHidden: json['is_hidden'] as bool? ?? false,
    );
  }

  Category copyWith({
    String? id,
    String? userId,
    String? name,
    CategoryType? type,
    String? parentId,
    int? iconCodePoint,
    int? color,
    bool? isActive,
    bool? isHidden,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      isHidden: isHidden ?? this.isHidden,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
  return 'Category(id: $id, name: $name, type: ${type.name}, hidden: $isHidden)';
  }
}

class CreateCategoryRequest {
  final String name;
  final CategoryType type;
  final String? parentId;
  final int? iconCodePoint;
  final int? color;

  const CreateCategoryRequest({
    required this.name,
    required this.type,
    this.parentId,
    this.iconCodePoint,
    this.color,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.name,
      'parent_id': parentId,
      'icon_code_point': iconCodePoint,
      'color': color,
    };
  }
}

class UpdateCategoryRequest {
  final String? name;
  final CategoryType? type;
  final String? parentId;
  final int? iconCodePoint;
  final int? color;
  final bool? isActive;

  const UpdateCategoryRequest({
    this.name,
    this.type,
    this.parentId,
    this.iconCodePoint,
    this.color,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    if (name != null) result['name'] = name;
    if (type != null) result['type'] = type!.name;
    if (parentId != null) result['parent_id'] = parentId;
    if (iconCodePoint != null) result['icon_code_point'] = iconCodePoint;
    if (color != null) result['color'] = color;
    if (isActive != null) result['is_active'] = isActive;
    return result;
  }
}
