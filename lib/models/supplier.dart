import 'brand.dart';

class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    this.contact,
    this.phone,
    this.deleted,
  });

  final String id;
  final String name;
  final String? contact;
  final String? phone;
  final DateTime? deleted;

  bool get isDeleted => deleted != null;

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      contact: json['contact'] as String?,
      phone: json['phone'] as String? ?? json['email'] as String?,
      deleted: CategoryDate.parse(json['deleted']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'contact': contact ?? '',
    'phone': phone ?? '',
  };
}
