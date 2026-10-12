import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/cart_actions.dart';
import '../core/permissions.dart';
import '../core/ui_helpers.dart';
import '../models/category.dart';
import '../models/list_query.dart';
import '../models/load_status.dart';
import '../models/product.dart';
import '../models/review.dart';
import '../repositories/catalog_repositories.dart';
import '../state/auth_notifier.dart';
import '../widgets/async_body.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  Product? _product;
  List<Category> _categories = const [];
  List<Review> _reviews = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) _load();
  }

  Future<void> _load() async {
    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    final productRepo = context.read<ProductRepository>();
    final categoryRepo = context.read<CategoryRepository>();
    final reviewRepo = context.read<ReviewRepository>();
    try {
      final product = await productRepo.getById(widget.productId);
      if (product == null) throw const NotFoundException('Товар не найден');

      var categories = <Category>[];
      try {
        final cats = await categoryRepo.list(
          const ListQuery(perPage: 200, sort: 'name'),
        );
        categories = cats.items
            .where((c) => product.categoryIds.contains(c.id))
            .toList();
      } catch (_) {
        // Карточка товара важнее справочника категорий.
      }

      var reviews = <Review>[];
      try {
        final page = await reviewRepo.list(
          ListQuery(
            perPage: 50,
            sort: '-id',
            filter: 'product = "${widget.productId}"',
            expand: 'customer',
          ),
        );
        reviews = page.items;
      } catch (_) {
        // Отзывы необязательны для показа карточки.
      }

      if (!mounted) return;
      setState(() {
        _product = product;
        _categories = categories;
        _reviews = reviews;
        _status = LoadStatus.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _status = LoadStatus.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthNotifier>().user;
    final canManage = Permissions.can(user, AppPermission.manageCatalog);
    final isCustomer = !Permissions.isStaff(user);
    final theme = Theme.of(context);

    return AsyncBody(
      status: _status,
      error: _error,
      onRetry: _load,
      builder: (context) {
        final p = _product!;
        final avg = _reviews.isEmpty
            ? null
            : _reviews.fold<int>(0, (s, r) => s + r.rating) / _reviews.length;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'К списку',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/products'),
                ),
                Expanded(
                  child: Text(p.name, style: theme.textTheme.headlineSmall),
                ),
                if (isCustomer && !p.isDeleted && p.stock > 0)
                  FilledButton.icon(
                    onPressed: () => addProductToCart(context, p),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('В корзину'),
                  ),
                if (canManage) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/products/${p.id}/edit'),
                    icon: const Icon(Icons.edit),
                    label: const Text('Редактировать'),
                  ),
                ],
              ],
            ),
            if (p.isDeleted)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Chip(
                  avatar: const Icon(Icons.delete, size: 16),
                  label: Text('Удалён ${formatDate(p.deleted)}'),
                ),
              ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Цена', formatMoney(p.price)),
                    _row('Остаток', '${p.stock} шт.'),
                    _row('Бренд', p.brandName ?? '—'),
                    _row(
                      'Категории',
                      _categories.isEmpty
                          ? '—'
                          : _categories.map((c) => c.name).join(', '),
                    ),
                    if ((p.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(p.description!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Отзывы', style: theme.textTheme.titleLarge),
                const SizedBox(width: 12),
                if (avg != null)
                  Text('★ ${avg.toStringAsFixed(1)} (${_reviews.length})'),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/reviews'),
                  child: const Text('Все отзывы'),
                ),
              ],
            ),
            if (_reviews.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Отзывов пока нет'),
              )
            else
              for (final r in _reviews)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${r.rating}')),
                    title: Text(r.customerName ?? 'Клиент'),
                    subtitle: Text(r.comment ?? ''),
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
