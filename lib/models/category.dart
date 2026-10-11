class Category {
  const Category({
    required this.id,
    required this.name,
    this.description,
    this.deleted,
  });

  final String id;
  final String name;
  final String? description;
  final DateTime? deleted;

  bool get isDeleted => deleted != null;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      deleted: _parseDate(json['deleted']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
  };

  static DateTime? _parseDate(Object? value) {
    if (value == null || value == '') return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
