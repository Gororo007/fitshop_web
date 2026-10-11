import '../models/app_user.dart';
import '../models/customer.dart';
import '../models/list_query.dart';
import '../repositories/catalog_repositories.dart';

/// Maps an authenticated user to its `customers` record.
class CustomerResolver {
  CustomerResolver(this._customers);

  final CustomerRepository _customers;

  /// Finds the customer record of [user], or null when none exists yet.
  Future<Customer?> find(AppUser user) async {
    final linked = user.customerId;
    if (linked != null && linked.isNotEmpty) {
      final byId = await _customers.getById(linked);
      if (byId != null) return byId;
    }
    final page = await _customers.list(
      ListQuery(perPage: 1, filter: 'user = "${user.id}"', sort: '-created'),
    );
    return page.items.isEmpty ? null : page.items.first;
  }

  /// Finds the customer record or creates one linked to [user].
  Future<Customer> ensure(AppUser user) async {
    final existing = await find(user);
    if (existing != null) return existing;
    return _customers.create(
      Customer(
        id: '',
        fullName: user.name.isEmpty ? user.email : user.name,
        email: user.email,
        userId: user.id,
      ),
    );
  }
}
