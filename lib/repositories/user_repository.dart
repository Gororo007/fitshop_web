import 'dart:math';

import '../core/api_client.dart';
import '../models/app_user.dart';
import '../models/customer.dart';
import '../models/loyalty_card.dart';
import '../models/page_result.dart';
import 'catalog_repositories.dart';

abstract interface class UserRepository {
  Future<PageResult<AppUser>> list({
    int page,
    int perPage,
    String? search,
    String sort,
  });

  Future<AppUser> updateRole(String id, UserRole role);

  /// Creates an auth user. [password] is required by PocketBase (min 8 chars).
  /// For [UserRole.customer] also creates linked customer + loyalty card.
  Future<AppUser> create({
    required String email,
    required String name,
    required String password,
    required UserRole role,
  });
}

/// Admin-only access to the PocketBase `users` auth collection.
class PbUserRepository implements UserRepository {
  PbUserRepository(
    this._client, {
    CustomerRepository? customers,
    LoyaltyCardRepository? loyaltyCards,
  }) : _customers = customers,
       _loyaltyCards = loyaltyCards;

  final ApiClient _client;
  final CustomerRepository? _customers;
  final LoyaltyCardRepository? _loyaltyCards;

  static const _path = '/api/collections/users/records';

  @override
  Future<PageResult<AppUser>> list({
    int page = 1,
    int perPage = 20,
    String? search,
    String sort = '-created',
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'perPage': perPage,
      'sort': sort,
    };
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim().replaceAll('"', '\\"');
      params['filter'] = '(name~"$s" || email~"$s")';
    }
    final response = await _client.get<Map<String, dynamic>>(
      _path,
      queryParameters: params,
    );
    return PageResult.fromJson(response.data ?? {}, AppUser.fromJson);
  }

  @override
  Future<AppUser> updateRole(String id, UserRole role) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '$_path/$id',
      data: {'role': userRoleToString(role)},
    );
    return AppUser.fromJson(response.data ?? {});
  }

  @override
  Future<AppUser> create({
    required String email,
    required String name,
    required String password,
    required UserRole role,
  }) async {
    final trimmedEmail = email.trim();
    final trimmedName = name.trim();
    if (password.trim().isEmpty) {
      throw ArgumentError('Пароль обязателен');
    }

    final response = await _client.post<Map<String, dynamic>>(
      _path,
      data: {
        'email': trimmedEmail,
        'emailVisibility': true,
        'name': trimmedName,
        'password': password,
        'passwordConfirm': password,
        'role': userRoleToString(role),
      },
    );
    var user = AppUser.fromJson(response.data ?? {});

    // Покупателю сразу нужен профиль customer + карта лояльности.
    final customers = _customers;
    final loyaltyCards = _loyaltyCards;
    if (role == UserRole.customer && customers != null) {
      final customer = await customers.create(
        Customer(
          id: '',
          fullName: trimmedName.isEmpty ? trimmedEmail : trimmedName,
          email: trimmedEmail,
          userId: user.id,
        ),
      );
      if (loyaltyCards != null) {
        await loyaltyCards.create(
          LoyaltyCard(
            id: '',
            customerId: customer.id,
            tier: LoyaltyTier.bronze,
          ),
        );
      }
      final patched = await _client.patch<Map<String, dynamic>>(
        '$_path/${user.id}',
        data: {'customer': customer.id},
      );
      user = AppUser.fromJson(patched.data ?? {});
    }

    return user;
  }

  /// Генерирует учебный пароль, проходящий Validators.password.
  static String generatePassword({int length = 12}) {
    const lower = 'abcdefghijkmnopqrstuvwxyz';
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const digits = '23456789';
    const special = '!@#\$%&*';
    final all = lower + upper + digits + special;
    final rnd = Random.secure();
    final chars = <String>[
      lower[rnd.nextInt(lower.length)],
      upper[rnd.nextInt(upper.length)],
      digits[rnd.nextInt(digits.length)],
      special[rnd.nextInt(special.length)],
    ];
    for (var i = chars.length; i < length; i++) {
      chars.add(all[rnd.nextInt(all.length)]);
    }
    chars.shuffle(rnd);
    return chars.join();
  }
}
