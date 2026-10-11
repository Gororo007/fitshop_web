import '../models/app_user.dart';

enum AppPermission {
  viewDashboard,
  viewCatalog,
  manageCatalog,
  manageCustomers,
  manageOrders,
  viewAllOrders,
  viewMyOrders,
  managePromotions,
  manageReviews,
  manageUsers,
  viewAnalytics,
  hardDelete,
  restoreDeleted,
}

class Permissions {
  Permissions._();

  static bool hasRole(AppUser? user, UserRole role) => user?.role == role;

  static bool isStaff(AppUser? user) {
    final r = user?.role;
    return r == UserRole.manager || r == UserRole.admin;
  }

  static bool can(AppUser? user, AppPermission permission) {
    if (user == null) return false;
    switch (permission) {
      case AppPermission.viewDashboard:
        return true;
      case AppPermission.viewCatalog:
        return true;
      case AppPermission.manageCatalog:
        return isStaff(user);
      case AppPermission.manageCustomers:
        return isStaff(user);
      case AppPermission.manageOrders:
        return isStaff(user);
      case AppPermission.viewAllOrders:
        return isStaff(user);
      case AppPermission.viewMyOrders:
        return user.role == UserRole.customer;
      case AppPermission.managePromotions:
        return isStaff(user);
      case AppPermission.manageReviews:
        return true;
      case AppPermission.manageUsers:
      case AppPermission.viewAnalytics:
      case AppPermission.hardDelete:
      case AppPermission.restoreDeleted:
        return user.role == UserRole.admin;
    }
  }

  static bool canAccessPath(AppUser? user, String path) {
    if (user == null) {
      return path == '/login' || path == '/register';
    }
    if (path.startsWith('/users')) {
      return can(user, AppPermission.manageUsers);
    }
    if (path.startsWith('/analytics')) {
      return can(user, AppPermission.viewAnalytics);
    }
    if (path.startsWith('/fulfillment')) {
      return can(user, AppPermission.manageOrders);
    }
    if (path.startsWith('/checkout')) {
      return user.role == UserRole.customer;
    }
    if (path.startsWith('/my-orders')) {
      return can(user, AppPermission.viewMyOrders);
    }
    if (path.contains('/new') || path.contains('/edit')) {
      if (path.startsWith('/products') ||
          path.startsWith('/categories') ||
          path.startsWith('/brands') ||
          path.startsWith('/suppliers')) {
        return can(user, AppPermission.manageCatalog);
      }
      if (path.startsWith('/customers')) {
        return can(user, AppPermission.manageCustomers);
      }
      if (path.startsWith('/orders')) {
        return can(user, AppPermission.manageOrders);
      }
      if (path.startsWith('/promotions')) {
        return can(user, AppPermission.managePromotions);
      }
    }
    if (path.startsWith('/orders') && !path.startsWith('/my-orders')) {
      return can(user, AppPermission.viewAllOrders);
    }
    return true;
  }
}
