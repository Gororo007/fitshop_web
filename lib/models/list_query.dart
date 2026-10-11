import '../core/config.dart';

class ListQuery {
  const ListQuery({
    this.page = 1,
    this.perPage = AppConfig.defaultPageSize,
    this.sort = '-created',
    this.search,
    this.filter,
    this.expand,
    this.includeDeleted = false,
  });

  final int page;
  final int perPage;
  final String sort;
  final String? search;
  final String? filter;
  final String? expand;
  final bool includeDeleted;

  ListQuery copyWith({
    int? page,
    int? perPage,
    String? sort,
    String? search,
    String? filter,
    String? expand,
    bool? includeDeleted,
  }) {
    return ListQuery(
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      sort: sort ?? this.sort,
      search: search ?? this.search,
      filter: filter ?? this.filter,
      expand: expand ?? this.expand,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  Map<String, dynamic> toQueryParams({String? searchField}) {
    final parts = <String>[];
    if (!includeDeleted) {
      parts.add('deleted=null');
    }
    if (filter != null && filter!.isNotEmpty) {
      parts.add('($filter)');
    }
    if (search != null && search!.isNotEmpty && searchField != null) {
      parts.add('$searchField~"${_escapeFilter(search!)}"');
    }
    final combined = parts.isEmpty ? null : parts.join(' && ');

    return {
      'page': page,
      'perPage': perPage,
      'sort': sort,
      'filter': ?combined,
      if (expand != null && expand!.isNotEmpty) 'expand': expand,
    };
  }

  static String _escapeFilter(String value) {
    return value.replaceAll('"', '\\"');
  }

  static ListQuery fromUri(Map<String, String> params) {
    return ListQuery(
      page: int.tryParse(params['page'] ?? '') ?? 1,
      perPage:
          int.tryParse(params['perPage'] ?? '') ?? AppConfig.defaultPageSize,
      sort: params['sort'] ?? '-created',
      search: params['q'],
      filter: params['filter'],
      expand: params['expand'],
      includeDeleted: params['deleted'] == '1',
    );
  }

  Map<String, String> toUriParams() {
    return {
      'page': '$page',
      'perPage': '$perPage',
      'sort': sort,
      if (search != null && search!.isNotEmpty) 'q': search!,
      if (filter != null && filter!.isNotEmpty) 'filter': filter!,
      if (expand != null && expand!.isNotEmpty) 'expand': expand!,
      if (includeDeleted) 'deleted': '1',
    };
  }
}
