import 'brand.dart';
import 'order.dart';

class Promotion {
  const Promotion({
    required this.id,
    required this.name,
    required this.discountPercent,
    required this.active,
    this.startDate,
    this.endDate,
    this.productIds = const [],
    this.deleted,
  });

  final String id;
  final String name;
  final double discountPercent;
  final bool active;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> productIds;
  final DateTime? deleted;

  bool isActiveOn(DateTime at) {
    if (!active) return false;
    if (startDate != null && at.isBefore(startDate!)) return false;
    if (endDate != null && at.isAfter(endDate!)) return false;
    return true;
  }

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      discountPercent: ProductNum.toDouble(
        json['discount_percent'] ?? json['discountPercent'],
      ),
      active: json['active'] as bool? ?? false,
      startDate: CategoryDate.parse(json['start_date'] ?? json['startDate']),
      endDate: CategoryDate.parse(json['end_date'] ?? json['endDate']),
      productIds: _relationList(json['products']),
      deleted: CategoryDate.parse(json['deleted']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'discount_percent': discountPercent,
    'active': active,
    if (startDate != null) 'start_date': startDate!.toIso8601String(),
    if (endDate != null) 'end_date': endDate!.toIso8601String(),
    'products': productIds,
  };
}

List<String> _relationList(Object? v) {
  if (v is List) {
    return v.map((e) => '$e').toList(growable: false);
  }
  return const [];
}
