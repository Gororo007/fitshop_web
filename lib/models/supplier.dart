import 'brand.dart';

class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    this.contact,
    this.email,
    this.deleted,
  });

  final String id;
  final String name;
  final String? contact;
  final String? email;
  final DateTime? deleted;

  bool get isDeleted => deleted != null;

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      contact: json['contact'] as String?,
      email: json['email'] as String?,
      deleted: CategoryDate.parse(json['deleted']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (contact != null) 'contact': contact,
    if (email != null) 'email': email,
  };
}
