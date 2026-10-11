import '../core/api_client.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';

/// Generic PocketBase records helper for a single collection.
class PbCollectionRepository<T> {
  PbCollectionRepository({
    required ApiClient client,
    required this.collection,
    required this.fromJson,
  }) : _client = client;

  final ApiClient _client;
  final String collection;
  final T Function(Map<String, dynamic> json) fromJson;

  String get _recordsPath => '/api/collections/$collection/records';

  Future<PageResult<T>> list(
    ListQuery query, {
    String? searchField,
    Map<String, dynamic>? extraQuery,
  }) async {
    final params = <String, dynamic>{
      ...query.toQueryParams(searchField: searchField),
      if (extraQuery != null) ...extraQuery,
    };
    final response = await _client.get<Map<String, dynamic>>(
      _recordsPath,
      queryParameters: params,
    );
    final data = response.data ?? {};
    return PageResult.fromJson(data, fromJson);
  }

  Future<T> getById(String id, {String? expand}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '$_recordsPath/$id',
      queryParameters: {
        if (expand != null && expand.isNotEmpty) 'expand': expand,
      },
    );
    return fromJson(response.data ?? {});
  }

  Future<T> create(Map<String, dynamic> body) async {
    final response = await _client.post<Map<String, dynamic>>(
      _recordsPath,
      data: body,
    );
    return fromJson(response.data ?? {});
  }

  Future<T> update(String id, Map<String, dynamic> body) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '$_recordsPath/$id',
      data: body,
    );
    return fromJson(response.data ?? {});
  }

  Future<void> hardDelete(String id) async {
    await _client.delete('$_recordsPath/$id');
  }

  Future<T> softDelete(String id) async {
    return update(id, {'deleted': DateTime.now().toUtc().toIso8601String()});
  }

  Future<T> restore(String id) async {
    return update(id, {'deleted': null});
  }

  Future<int> bulkSoftDelete(Iterable<String> ids) async {
    var count = 0;
    for (final id in ids) {
      await softDelete(id);
      count++;
    }
    return count;
  }
}
