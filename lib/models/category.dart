enum CategoryType { income, expense }

class Category {
  final String id;
  final String userId;
  final String name;
  final CategoryType type;
  final String? parentId;
  final int? iconCodePoint; // Nullable sesuai kolom
  // color removed from DB; keep nullable for backward compatibility but unused
  final int? color; // Deprecated
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
  // 'color': color, // deprecated/removed
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
  color: null, // color column removed
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
  color: this.color, // ignore updates to color
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
  // color removed
  final int? color; // deprecated

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
      // 'color': color, // deprecated
    };
  }
}

class UpdateCategoryRequest {
  final String? name;
  final CategoryType? type;
  final String? parentId;
  final int? iconCodePoint;
  // color removed
  final int? color; // deprecated
  final bool? isHidden;

  const UpdateCategoryRequest({
    this.name,
    this.type,
    this.parentId,
    this.iconCodePoint,
    this.color,
    this.isHidden,
  });

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    if (name != null) result['name'] = name;
    if (type != null) result['type'] = type!.name;
    if (parentId != null) result['parent_id'] = parentId;
    if (iconCodePoint != null) result['icon_code_point'] = iconCodePoint;
  // if (color != null) result['color'] = color; // deprecated
    if (isHidden != null) result['is_hidden'] = isHidden;
    return result;
  }
}
