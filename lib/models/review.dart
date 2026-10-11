import 'brand.dart';

class Review {
  const Review({
    required this.id,
    required this.productId,
    required this.customerId,
    required this.rating,
    this.comment,
    this.productName,
    this.customerName,
    this.deleted,
  });

  final String id;
  final String productId;
  final String customerId;
  final int rating;
  final String? comment;
  final String? productName;
  final String? customerName;
  final DateTime? deleted;

  factory Review.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>?;
    final product = expand?['product'] as Map<String, dynamic>?;
    final customer = expand?['customer'] as Map<String, dynamic>?;
    return Review(
      id: json['id'] as String,
      productId: json['product'] as String? ?? '',
      customerId: json['customer'] as String? ?? '',
      rating: json['rating'] as int? ?? 0,
      comment: json['comment'] as String?,
      productName: product?['name'] as String?,
      customerName: customer?['full_name'] as String?,
      deleted: CategoryDate.parse(json['deleted']),
    );
  }

  Map<String, dynamic> toJson() => {
    'product': productId,
    'customer': customerId,
    'rating': rating,
    if (comment != null) 'comment': comment,
  };
}
