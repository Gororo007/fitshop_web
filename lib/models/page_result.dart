class PageResult<T> {
  const PageResult({
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
    required this.items,
  });

  final int page;
  final int perPage;
  final int totalItems;
  final int totalPages;
  final List<T> items;

  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromMap,
  ) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return PageResult(
      page: json['page'] as int? ?? 1,
      perPage: json['perPage'] as int? ?? rawItems.length,
      totalItems: json['totalItems'] as int? ?? rawItems.length,
      totalPages: json['totalPages'] as int? ?? 1,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(fromMap)
          .toList(growable: false),
    );
  }
}
