import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../models/app_user.dart';
import 'auth_repository.dart';

class PbAuthRepository implements AuthRepository {
  PbAuthRepository(this._client, this._prefs);

  final ApiClient _client;
  final SharedPreferences _prefs;

  static const _tokenKey = 'pb_auth_token';
  static const _recordKey = 'pb_auth_record';

  static const _authPath = '/api/collections/users/auth-with-password';
  static const _usersPath = '/api/collections/users/records';
  static const _refreshPath = '/api/collections/users/auth-refresh';

  @override
  Future<AppUser> login({
    required String identity,
    required String password,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      _authPath,
      data: {'identity': identity, 'password': password},
    );
    return await _persistAuthResponse(response.data ?? {});
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required String name,
    UserRole role = UserRole.customer,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      _usersPath,
      data: {
        'email': email,
        'password': password,
        'passwordConfirm': passwordConfirm,
        'name': name,
        'role': userRoleToString(role),
      },
    );
    final record = response.data ?? {};
    // PocketBase does not return a token on record creation: sign in so the
    // session (token + record) is persisted and requests are authorised.
    final token = record['token'] as String?;
    if (token != null) {
      await _client.saveAuth(token: token, recordJson: jsonEncode(record));
      return AppUser.fromJson(record);
    }
    return login(identity: email, password: password);
  }

  @override
  Future<AppUser?> restoreSession() async {
    final token = _prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      return null;
    }
    final recordJson = _prefs.getString(_recordKey);
    if (recordJson != null && recordJson.isNotEmpty) {
      try {
        final map = jsonDecode(recordJson) as Map<String, dynamic>;
        return AppUser.fromJson(map);
      } catch (_) {
        // fall through to refresh
      }
    }
    try {
      return await refreshUser();
    } catch (_) {
      await logout();
      return null;
    }
  }

  @override
  Future<AppUser> refreshUser() async {
    final response = await _client.post<Map<String, dynamic>>(_refreshPath);
    return await _persistAuthResponse(response.data ?? {});
  }

  @override
  Future<void> logout() async {
    await _client.clearAuth();
  }

  Future<AppUser> fetchUserById(String id) async {
    final response = await _client.get<Map<String, dynamic>>('$_usersPath/$id');
    return AppUser.fromJson(response.data ?? {});
  }

  Future<AppUser> _persistAuthResponse(Map<String, dynamic> data) async {
    final token = data['token'] as String?;
    final record = data['record'] as Map<String, dynamic>? ?? data;
    if (token != null) {
      await _client.saveAuth(token: token, recordJson: jsonEncode(record));
    }
    return AppUser.fromJson(record);
  }
}
