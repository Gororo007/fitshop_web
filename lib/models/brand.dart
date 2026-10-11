class Brand {
  const Brand({
    required this.id,
    required this.name,
    this.country,
    this.deleted,
  });

  final String id;
  final String name;
  final String? country;
  final DateTime? deleted;

  bool get isDeleted => deleted != null;

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      country: json['country'] as String?,
      deleted: CategoryDate.parse(json['deleted']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (country != null) 'country': country,
  };
}

class CategoryDate {
  static DateTime? parse(Object? value) {
    if (value == null || value == '') return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
