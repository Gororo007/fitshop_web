import '../core/api_client.dart';
import '../models/app_user.dart';
import '../models/page_result.dart';

abstract interface class UserRepository {
  Future<PageResult<AppUser>> list({
    int page,
    int perPage,
    String? search,
    String sort,
  });

  Future<AppUser> updateRole(String id, UserRole role);
}

/// Admin-only access to the PocketBase `users` auth collection.
class PbUserRepository implements UserRepository {
  PbUserRepository(this._client);

  final ApiClient _client;

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
}
