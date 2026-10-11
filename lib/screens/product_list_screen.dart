import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/permissions.dart';
import '../core/ui_helpers.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/list_query.dart';
import '../models/load_status.dart';
import '../models/product.dart';
import '../repositories/catalog_repositories.dart';
import '../state/auth_notifier.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/async_body.dart';
import '../widgets/entity_table.dart';
import '../widgets/pagination_bar.dart';

/// Product catalog. All filters/sort/pagination live in the URL query string
/// (`q`, `brand`, `category`, `min`, `max`, `sort`, `page`, `size`, `deleted`).
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key, this.params = const {}});

  final Map<String, String> params;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late final ProductListNotifier _notifier;
  final _search = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  String? _brandId;
  String? _categoryId;
  List<Brand> _brands = const [];
  List<Category> _categories = const [];

  @override
  void initState() {
    super.initState();
    final query = _parse(widget.params);
    _notifier = ProductListNotifier(
      context.read<ProductRepository>(),
      initialQuery: query,
    );
    _syncControllers(query);
    _notifier.load();
    _loadLookups();
  }

  @override
  void didUpdateWidget(covariant ProductListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.params, widget.params)) {
      final query = _parse(widget.params);
      _syncControllers(query);
      _notifier.applyQuery(query);
    }
  }

  @override
  void dispose() {
    _notifier.dispose();
    _search.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    final brandRepo = context.read<BrandRepository>();
    final categoryRepo = context.read<CategoryRepository>();
    try {
      const lookup = ListQuery(perPage: 200, sort: 'name');
      final brands = await brandRepo.list(lookup);
      final cats = await categoryRepo.list(lookup);
      if (!mounted) return;
      setState(() {
        _brands = brands.items;
        _categories = cats.items;
      });
    } catch (_) {
      // Filters simply stay empty; list itself reports its own errors.
    }
  }

  ProductListQuery _parse(Map<String, String> p) {
    final admin = Permissions.can(
      context.read<AuthNotifier>().user,
      AppPermission.restoreDeleted,
    );
    return ProductListQuery(
      search: nullIfBlank(p['q']),
      brandId: nullIfBlank(p['brand']),
      categoryId: nullIfBlank(p['category']),
      minPrice: double.tryParse(p['min'] ?? ''),
      maxPrice: double.tryParse(p['max'] ?? ''),
      includeDeleted: admin && p['deleted'] == '1',
      sort: nullIfBlank(p['sort']) ?? '-created',
      page: int.tryParse(p['page'] ?? '') ?? 1,
      size: int.tryParse(p['size'] ?? '') ?? AppConfig.defaultPageSize,
    );
  }

  void _syncControllers(ProductListQuery q) {
    _search.text = q.search ?? '';
    _min.text = q.minPrice?.toString() ?? '';
    _max.text = q.maxPrice?.toString() ?? '';
    _brandId = q.brandId;
    _categoryId = q.categoryId;
  }

  Map<String, String> _toParams(ProductListQuery q) => {
    if (q.search != null) 'q': q.search!,
    if (q.brandId != null) 'brand': q.brandId!,
    if (q.categoryId != null) 'category': q.categoryId!,
    if (q.minPrice != null) 'min': '${q.minPrice}',
    if (q.maxPrice != null) 'max': '${q.maxPrice}',
    if (q.includeDeleted) 'deleted': '1',
    if (q.sort != '-created') 'sort': q.sort,
    if (q.page != 1) 'page': '${q.page}',
    if (q.size != AppConfig.defaultPageSize) 'size': '${q.size}',
  };

  void _navigate(ProductListQuery q) {
    final params = _toParams(q);
    final uri = Uri(
      path: '/products',
      queryParameters: params.isEmpty ? null : params,
    );
    context.go(uri.toString());
  }

  void _applyFilters() {
    final cur = _notifier.query;
    _navigate(
      ProductListQuery(
        search: nullIfBlank(_search.text),
        brandId: _brandId,
        categoryId: _categoryId,
        minPrice: double.tryParse(_min.text.replaceAll(',', '.')),
        maxPrice: double.tryParse(_max.text.replaceAll(',', '.')),
        includeDeleted: cur.includeDeleted,
        sort: cur.sort,
        size: cur.size,
      ),
    );
  }

  void _resetFilters() {
    final cur = _notifier.query;
    _navigate(ProductListQuery(includeDeleted: cur.includeDeleted));
  }

  void _toggleSort(String field) {
    final cur = _notifier.query;
    final active = cur.sort.replaceFirst(RegExp(r'^[-+]'), '');
    final asc = active == field ? cur.sort.startsWith('-') : true;
    _navigate(cur.copyWith(sort: asc ? field : '-$field', page: 1));
  }

  Future<void> _act(Future<void> Function() action, String ok) async {
    try {
      await action();
      if (mounted) showSnack(context, ok);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _softDelete(Product p) async {
    if (!await confirmDialog(
      context,
      title: 'Удалить товар?',
      message: '«${p.name}» будет скрыт из каталога (можно восстановить).',
      confirmLabel: 'Удалить',
    )) {
      return;
    }
    await _act(() => _notifier.softDelete(p.id), 'Товар удалён');
  }

  Future<void> _hardDelete(Product p) async {
    if (!await confirmDialog(
      context,
      title: 'Удалить навсегда?',
      message: '«${p.name}» будет удалён без возможности восстановления.',
      confirmLabel: 'Удалить навсегда',
    )) {
      return;
    }
    if (!mounted) return;
    final repo = context.read<ProductRepository>();
    await _act(() async {
      await repo.hardDelete(p.id);
      await _notifier.load();
    }, 'Товар удалён навсегда');
  }

  Future<void> _restore(Product p) async {
    final repo = context.read<ProductRepository>();
    await _act(() async {
      await repo.restore(p.id);
      await _notifier.load();
    }, 'Товар восстановлен');
  }

  Future<void> _bulkDelete() async {
    if (!await confirmDialog(
      context,
      title: 'Удалить выбранные?',
      message: 'Выбрано товаров: ${_notifier.selected.length}.',
      confirmLabel: 'Удалить',
    )) {
      return;
    }
    await _act(() async {
      await _notifier.bulkSoftDeleteSelected();
    }, 'Выбранные товары удалены');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthNotifier>().user;
    final canManage = Permissions.can(user, AppPermission.manageCatalog);
    final canHard = Permissions.can(user, AppPermission.hardDelete);
    final canRestore = Permissions.can(user, AppPermission.restoreDeleted);
    final isCustomer = !Permissions.isStaff(user);

    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) {
        final query = _notifier.query;
        final result = _notifier.result;
        final sortField = query.sort.replaceFirst(RegExp(r'^[-+]'), '');

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    isCustomer ? 'Каталог' : 'Товары',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (canManage)
                    FilledButton.icon(
                      onPressed: () => context.go('/products/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Новый товар'),
                    ),
                  if (canManage && _notifier.selected.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: _bulkDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(
                        'Удалить выбранные (${_notifier.selected.length})',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        labelText: 'Поиск по названию',
                        isDense: true,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (_) => _applyFilters(),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey('brand-$_brandId-${_brands.length}'),
                      initialValue: _brands.any((b) => b.id == _brandId)
                          ? _brandId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Бренд',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Все бренды'),
                        ),
                        for (final b in _brands)
                          DropdownMenuItem<String?>(
                            value: b.id,
                            child: Text(b.name),
                          ),
                      ],
                      onChanged: (v) => _brandId = v,
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey('cat-$_categoryId-${_categories.length}'),
                      initialValue: _categories.any((c) => c.id == _categoryId)
                          ? _categoryId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Категория',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Все категории'),
                        ),
                        for (final c in _categories)
                          DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(c.name),
                          ),
                      ],
                      onChanged: (v) => _categoryId = v,
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _min,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Цена от',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _applyFilters(),
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _max,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Цена до',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _applyFilters(),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _applyFilters,
                    icon: const Icon(Icons.filter_alt),
                    label: const Text('Применить'),
                  ),
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Сбросить'),
                  ),
                  if (canRestore)
                    FilterChip(
                      label: const Text('Показать удалённые'),
                      selected: query.includeDeleted,
                      onSelected: (v) => _navigate(
                        ProductListQuery(
                          search: query.search,
                          brandId: query.brandId,
                          categoryId: query.categoryId,
                          minPrice: query.minPrice,
                          maxPrice: query.maxPrice,
                          includeDeleted: v,
                          sort: query.sort,
                          size: query.size,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AsyncBody(
                  status: _notifier.status,
                  error: _notifier.error,
                  onRetry: _notifier.load,
                  isEmpty: result.items.isEmpty,
                  emptyMessage: 'Товары не найдены',
                  builder: (context) => EntityTable<Product>(
                    items: result.items,
                    idOf: (p) => p.id,
                    selected: _notifier.selected,
                    onToggleSelect: canManage
                        ? _notifier.toggleSelection
                        : null,
                    sortField: sortField,
                    sortAscending: !query.sort.startsWith('-'),
                    onSort: _toggleSort,
                    columns: [
                      TableColumnSpec<Product>(
                        label: 'Название',
                        sortField: 'name',
                        build: (p) => InkWell(
                          onTap: () => context.go('/products/${p.id}'),
                          child: Text(
                            p.name,
                            style: TextStyle(
                              color: p.isDeleted
                                  ? Colors.grey
                                  : Theme.of(context).colorScheme.primary,
                              decoration: p.isDeleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      TableColumnSpec<Product>(
                        label: 'Бренд',
                        build: (p) => Text(p.brandName ?? '—'),
                      ),
                      TableColumnSpec<Product>(
                        label: 'Цена',
                        sortField: 'price',
                        numeric: true,
                        build: (p) => Text(formatMoney(p.price)),
                      ),
                      TableColumnSpec<Product>(
                        label: 'Остаток',
                        sortField: 'stock',
                        numeric: true,
                        build: (p) => Text('${p.stock}'),
                      ),
                    ],
                    actions: (p) => [
                      IconButton(
                        tooltip: 'Подробнее',
                        icon: const Icon(Icons.visibility),
                        onPressed: () => context.go('/products/${p.id}'),
                      ),
                      if (isCustomer && !p.isDeleted && p.stock > 0)
                        IconButton(
                          tooltip: 'В заказ',
                          icon: const Icon(Icons.add_shopping_cart),
                          onPressed: () => context.go('/checkout?add=${p.id}'),
                        ),
                      if (canManage && !p.isDeleted)
                        IconButton(
                          tooltip: 'Редактировать',
                          icon: const Icon(Icons.edit),
                          onPressed: () => context.go('/products/${p.id}/edit'),
                        ),
                      if (canManage && !p.isDeleted)
                        IconButton(
                          tooltip: 'Удалить',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _softDelete(p),
                        ),
                      if (canRestore && p.isDeleted)
                        IconButton(
                          tooltip: 'Восстановить',
                          icon: const Icon(Icons.restore),
                          onPressed: () => _restore(p),
                        ),
                      if (canHard)
                        IconButton(
                          tooltip: 'Удалить навсегда',
                          icon: Icon(
                            Icons.delete_forever,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () => _hardDelete(p),
                        ),
                    ],
                  ),
                ),
              ),
              if (_notifier.status == LoadStatus.success)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: PaginationBar(
                    page: result.page,
                    totalPages: result.totalPages,
                    totalItems: result.totalItems,
                    pageSize: query.size,
                    onPageChanged: (p) => _navigate(query.copyWith(page: p)),
                    onPageSizeChanged: (s) =>
                        _navigate(query.copyWith(size: s, page: 1)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
