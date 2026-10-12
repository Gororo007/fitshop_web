import '../core/api_client.dart';
import '../models/app_user.dart';
import '../models/customer.dart';
import '../models/list_query.dart';
import '../repositories/catalog_repositories.dart';

/// Maps an authenticated user to its `customers` record.
class CustomerResolver {
  CustomerResolver(this._customers, {ApiClient? apiClient}) : _api = apiClient;

  final CustomerRepository _customers;
  final ApiClient? _api;

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
  /// Also patches `users.customer` so API rules based on
  /// `@request.auth.customer` work for "Мои заказы" and loyalty.
  Future<Customer> ensure(AppUser user) async {
    final existing = await find(user);
    if (existing != null) {
      await _linkUserCustomer(user.id, existing.id);
      return existing;
    }
    final created = await _customers.create(
      Customer(
        id: '',
        fullName: user.name.isEmpty ? user.email : user.name,
        email: user.email,
        userId: user.id,
      ),
    );
    await _linkUserCustomer(user.id, created.id);
    return created;
  }

  Future<void> _linkUserCustomer(String userId, String customerId) async {
    final api = _api;
    if (api == null) return;
    try {
      await api.patch(
        '/api/collections/users/records/$userId',
        data: {'customer': customerId},
      );
    } catch (_) {
      // Hook may already have linked; rules may block — ignore.
    }
  }
}
