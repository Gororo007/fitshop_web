import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../models/list_query.dart';
import '../models/load_status.dart';
import '../models/page_result.dart';
import '../models/product.dart';
import '../repositories/catalog_repositories.dart';

class EntityListNotifier<T> extends ChangeNotifier {
  EntityListNotifier(this._repository, {ListQuery? initialQuery})
    : _query = initialQuery ?? const ListQuery();

  final EntityListRepository<T> _repository;

  ListQuery _query;
  PageResult<T> _result = PageResult<T>(
    page: 1,
    perPage: 20,
    totalItems: 0,
    totalPages: 1,
    items: [],
  );
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<String> _selected = {};

  ListQuery get query => _query;
  PageResult<T> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<String> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  String? get sortField {
    final s = _query.sort;
    if (s.startsWith('-') || s.startsWith('+')) {
      return s.substring(1);
    }
    return s.isEmpty ? null : s;
  }

  bool get sortAscending => !_query.sort.startsWith('-');

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _result = await _repository.list(_query);
      _status = LoadStatus.success;
    } on ApiException catch (e) {
      _error = e.message;
      _status = LoadStatus.error;
    } catch (e) {
      _error = 'Не удалось загрузить список: $e';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> applyQuery(ListQuery next) async {
    _query = next;
    _selected.clear();
    await load();
  }

  Future<void> setPage(int page) => applyQuery(_query.copyWith(page: page));

  Future<void> setPageSize(int perPage) =>
      applyQuery(_query.copyWith(page: 1, perPage: perPage));

  Future<void> toggleSort(String field) async {
    final current = sortField;
    final ascending = current == field ? !sortAscending : true;
    final sort = ascending ? field : '-$field';
    await applyQuery(_query.copyWith(sort: sort));
  }

  void toggleSelection(String id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    notifyListeners();
  }

  void selectAllVisible() {
    for (final item in _result.items) {
      _selected.add(_idOf(item));
    }
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }

  String Function(T item)? idExtractor;

  String _idOf(T item) {
    if (idExtractor != null) {
      return idExtractor!(item);
    }
    final dynamic value = item;
    if (value is Map && value['id'] is String) {
      return value['id'] as String;
    }
    throw StateError(
      'Задайте idExtractor для ${T.toString()} в EntityListNotifier',
    );
  }

  Future<void> softDelete(String id) async {
    await _repository.softDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<void> hardDelete(String id) async {
    await _repository.hardDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<void> restore(String id) async {
    await _repository.restore(id);
    await load();
  }

  Future<int> bulkSoftDeleteSelected() async {
    if (_selected.isEmpty) return 0;
    final count = await _repository.bulkSoftDelete(_selected.toList());
    _selected.clear();
    await load();
    return count;
  }
}

/// Product catalog list with extended filters.
class ProductListNotifier extends ChangeNotifier {
  ProductListNotifier(this._repository, {ProductListQuery? initialQuery})
    : _query = initialQuery ?? const ProductListQuery();

  final ProductRepository _repository;

  ProductListQuery _query;
  PageResult<Product> _result = PageResult<Product>(
    page: 1,
    perPage: 20,
    totalItems: 0,
    totalPages: 1,
    items: [],
  );
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<String> _selected = {};

  ProductListQuery get query => _query;
  PageResult<Product> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<String> get selected => Set.unmodifiable(_selected);

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _result = await _repository.find(_query);
      _status = LoadStatus.success;
    } on ApiException catch (e) {
      _error = e.message;
      _status = LoadStatus.error;
    } catch (e) {
      _error = '$e';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> applyQuery(ProductListQuery next) async {
    _query = next;
    _selected.clear();
    await load();
  }

  void toggleSelection(String id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    notifyListeners();
  }

  Future<void> softDelete(String id) async {
    await _repository.softDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<int> bulkSoftDeleteSelected() async {
    if (_selected.isEmpty) return 0;
    final count = await _repository.bulkSoftDelete(_selected.toList());
    _selected.clear();
    await load();
    return count;
  }
}
