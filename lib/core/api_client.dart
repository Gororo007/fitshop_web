import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_exceptions.dart';
import 'config.dart';

typedef TokenRefreshCallback = Future<String?> Function();

class ApiClient {
  ApiClient({Dio? dio, SharedPreferences? prefs})
    : _prefs = prefs,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'Content-Type': 'application/json'},
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = token;
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final response = error.response;
          if (response?.statusCode == 401 &&
              error.requestOptions.extra['retried'] != true) {
            final refreshed = await _refreshToken();
            if (refreshed != null) {
              final opts = error.requestOptions;
              opts.extra['retried'] = true;
              opts.headers['Authorization'] = refreshed;
              try {
                final clone = await _dio.fetch(opts);
                return handler.resolve(clone);
              } catch (e) {
                return handler.next(error);
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  SharedPreferences? _prefs;

  static const _tokenKey = 'pb_auth_token';
  static const _recordKey = 'pb_auth_record';

  Dio get dio => _dio;

  Future<void> attachPrefs(SharedPreferences prefs) async {
    _prefs = prefs;
  }

  Future<String?> _readToken() async {
    return _prefs?.getString(_tokenKey);
  }

  Future<void> saveAuth({required String token, String? recordJson}) async {
    await _prefs?.setString(_tokenKey, token);
    if (recordJson != null) {
      await _prefs?.setString(_recordKey, recordJson);
    }
  }

  Future<void> clearAuth() async {
    await _prefs?.remove(_tokenKey);
    await _prefs?.remove(_recordKey);
  }

  Future<String?> _refreshToken() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/collections/users/auth-refresh',
        options: Options(extra: {'retried': true}),
      );
      final token = response.data?['token'] as String?;
      if (token != null) {
        await saveAuth(token: token);
      }
      return token;
    } catch (_) {
      await clearAuth();
      return null;
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get<T>(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.delete<T>(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  static ApiException mapDioException(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const NetworkException();
    }
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final message = _extractMessage(data) ?? e.message ?? 'Ошибка запроса';

    switch (status) {
      case 401:
        return UnauthorizedException(message);
      case 403:
        return ForbiddenException(message);
      case 404:
        return NotFoundException(message);
      case 409:
        return ConflictException(message);
      case 400:
      case 422:
        // PocketBase отдаёт ошибки полей как 400; учебный контракт — 422.
        if (data is Map<String, dynamic>) {
          return ValidationException(data, message);
        }
        if (data is Map) {
          return ValidationException(Map<String, dynamic>.from(data), message);
        }
        return ValidationException({}, message);
      case 500:
      case 502:
      case 503:
        return ServerException(message);
      default:
        if (status != null && status >= 500) {
          return ServerException(message);
        }
        return ServerException(message);
    }
  }

  static String? _extractMessage(Object? data) {
    if (data is Map) {
      final m = data['message'];
      if (m is String) return m;
      if (data['data'] is Map) {
        final inner = data['data'] as Map;
        for (final v in inner.values) {
          if (v is Map && v['message'] is String) {
            return v['message'] as String;
          }
        }
      }
    }
    return null;
  }
}
