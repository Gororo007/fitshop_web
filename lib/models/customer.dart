import 'brand.dart';

class Customer {
  const Customer({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.userId,
    this.deleted,
  });

  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final String? userId;
  final DateTime? deleted;

  bool get isDeleted => deleted != null;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      fullName:
          json['full_name'] as String? ?? json['fullName'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      userId: json['user'] as String?,
      deleted: CategoryDate.parse(json['deleted']),
    );
  }

  Map<String, dynamic> toJson() => {
    'full_name': fullName,
    if (phone != null) 'phone': phone,
    if (email != null) 'email': email,
    if (userId != null) 'user': userId,
  };
}
