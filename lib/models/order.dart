import 'brand.dart';

enum OrderStatus { pending, processing, shipped, delivered, cancelled }

OrderStatus orderStatusFromString(String? value) {
  switch (value) {
    case 'processing':
      return OrderStatus.processing;
    case 'shipped':
      return OrderStatus.shipped;
    case 'delivered':
      return OrderStatus.delivered;
    case 'cancelled':
      return OrderStatus.cancelled;
    default:
      return OrderStatus.pending;
  }
}

String orderStatusToString(OrderStatus status) {
  switch (status) {
    case OrderStatus.processing:
      return 'processing';
    case OrderStatus.shipped:
      return 'shipped';
    case OrderStatus.delivered:
      return 'delivered';
    case OrderStatus.cancelled:
      return 'cancelled';
    case OrderStatus.pending:
      return 'pending';
  }
}

String orderStatusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.processing:
      return 'В обработке';
    case OrderStatus.shipped:
      return 'Отправлен';
    case OrderStatus.delivered:
      return 'Доставлен';
    case OrderStatus.cancelled:
      return 'Отменён';
    case OrderStatus.pending:
      return 'Новый';
  }
}

class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.customerId,
    required this.status,
    required this.subtotal,
    required this.discount,
    required this.shipping,
    required this.total,
    this.created,
    this.customerName,
    this.deleted,
  });

  final String id;
  final String customerId;
  final OrderStatus status;
  final double subtotal;
  final double discount;
  final double shipping;
  final double total;
  final DateTime? created;
  final String? customerName;
  final DateTime? deleted;

  factory ShopOrder.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>?;
    final customer = expand?['customer'] as Map<String, dynamic>?;
    return ShopOrder(
      id: json['id'] as String,
      customerId: json['customer'] as String? ?? '',
      status: orderStatusFromString(json['status'] as String?),
      subtotal: ProductNum.toDouble(json['subtotal']),
      discount: ProductNum.toDouble(json['discount']),
      shipping: ProductNum.toDouble(json['shipping']),
      total: ProductNum.toDouble(json['total']),
      created: CategoryDate.parse(json['created']),
      customerName: customer?['full_name'] as String?,
      deleted: CategoryDate.parse(json['deleted']),
    );
  }

  Map<String, dynamic> toJson() => {
    'customer': customerId,
    'status': orderStatusToString(status),
    'subtotal': subtotal,
    'discount': discount,
    'shipping': shipping,
    'total': total,
  };

  ShopOrder copyWith({
    OrderStatus? status,
    double? subtotal,
    double? discount,
    double? shipping,
    double? total,
    DateTime? deleted,
    bool clearDeleted = false,
  }) {
    return ShopOrder(
      id: id,
      customerId: customerId,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      shipping: shipping ?? this.shipping,
      total: total ?? this.total,
      created: created,
      customerName: customerName,
      deleted: clearDeleted ? null : (deleted ?? this.deleted),
    );
  }
}

class ProductNum {
  static double toDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}
