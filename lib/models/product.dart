import 'brand.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.description,
    this.brandId,
    this.supplierId,
    this.categoryIds = const [],
    this.brandName,
    this.deleted,
  });

  final String id;
  final String name;
  final double price;
  final int stock;
  final String? description;
  final String? brandId;
  final String? supplierId;
  final List<String> categoryIds;
  final String? brandName;
  final DateTime? deleted;

  bool get isDeleted => deleted != null;

  factory Product.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>?;
    final brandExpand = expand?['brand'] as Map<String, dynamic>?;
    return Product(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      price: _toDouble(json['price']),
      stock: json['stock'] as int? ?? 0,
      description: json['description'] as String?,
      brandId: json['brand'] as String?,
      supplierId: json['supplier'] as String?,
      categoryIds: _relationList(json['categories']),
      brandName: brandExpand?['name'] as String?,
      deleted: CategoryDate.parse(json['deleted']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
    'stock': stock,
    if (description != null) 'description': description,
    if (brandId != null) 'brand': brandId,
    if (supplierId != null) 'supplier': supplierId,
    'categories': categoryIds,
  };

  static double _toDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static List<String> _relationList(Object? v) {
    if (v is List) {
      return v.map((e) => '$e').toList(growable: false);
    }
    return const [];
  }
}
