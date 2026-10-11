import 'order.dart';

class OrderItem {
  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.productName,
  });

  final String id;
  final String orderId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? productName;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>?;
    final product = expand?['product'] as Map<String, dynamic>?;
    return OrderItem(
      id: json['id'] as String,
      orderId: json['order'] as String? ?? '',
      productId: json['product'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      unitPrice: ProductNum.toDouble(json['unit_price'] ?? json['unitPrice']),
      lineTotal: ProductNum.toDouble(json['line_total'] ?? json['lineTotal']),
      productName: product?['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'order': orderId,
    'product': productId,
    'quantity': quantity,
    'unit_price': unitPrice,
    'line_total': lineTotal,
  };
}
