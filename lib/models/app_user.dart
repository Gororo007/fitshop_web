enum UserRole { customer, manager, admin }

UserRole userRoleFromString(String? value) {
  switch (value) {
    case 'manager':
      return UserRole.manager;
    case 'admin':
      return UserRole.admin;
    default:
      return UserRole.customer;
  }
}

String userRoleToString(UserRole role) {
  switch (role) {
    case UserRole.manager:
      return 'manager';
    case UserRole.admin:
      return 'admin';
    case UserRole.customer:
      return 'customer';
  }
}

String userRoleLabel(UserRole role) {
  switch (role) {
    case UserRole.manager:
      return 'Менеджер';
    case UserRole.admin:
      return 'Администратор';
    case UserRole.customer:
      return 'Покупатель';
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.verified = false,
    this.customerId,
  });

  final String id;
  final String email;
  final String name;
  final UserRole role;
  final bool verified;
  final String? customerId;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? json['email'] as String? ?? '',
      role: userRoleFromString(json['role'] as String?),
      verified: json['verified'] as bool? ?? false,
      customerId: json['customer'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'email': email,
    'name': name,
    'role': userRoleToString(role),
    if (customerId != null) 'customer': customerId,
  };

  AppUser copyWith({String? name, UserRole? role, String? customerId}) {
    return AppUser(
      id: id,
      email: email,
      name: name ?? this.name,
      role: role ?? this.role,
      verified: verified,
      customerId: customerId ?? this.customerId,
    );
  }
}
