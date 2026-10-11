import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/ui_helpers.dart';
import '../features/customer_resolver.dart';
import '../models/list_query.dart';
import '../models/load_status.dart';
import '../models/order.dart';
import '../repositories/catalog_repositories.dart';
import '../state/auth_notifier.dart';
import '../widgets/async_body.dart';
import '../widgets/order_widgets.dart';
import '../widgets/pagination_bar.dart';

/// Orders of the current customer.
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  List<ShopOrder> _orders = const [];
  int _page = 1;
  int _perPage = 10;
  int _totalPages = 1;
  int _totalItems = 0;
  String? _customerId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? page}) async {
    final user = context.read<AuthNotifier>().user;
    final customers = context.read<CustomerRepository>();
    final orders = context.read<ShopOrderRepository>();
    final nextPage = page ?? _page;
    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    try {
      if (user == null) throw StateError('Требуется авторизация');
      _customerId ??= (await CustomerResolver(customers).find(user))?.id;
      if (_customerId == null) {
        if (!mounted) return;
        setState(() {
          _orders = const [];
          _totalItems = 0;
          _totalPages = 1;
          _status = LoadStatus.success;
        });
        return;
      }
      final result = await orders.list(
        ListQuery(
          page: nextPage,
          perPage: _perPage,
          filter: 'customer = "$_customerId"',
        ),
      );
      if (!mounted) return;
      setState(() {
        _orders = result.items;
        _page = result.page;
        _totalPages = result.totalPages;
        _totalItems = result.totalItems;
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
    final theme = Theme.of(context);
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
              Text('Мои заказы', style: theme.textTheme.headlineSmall),
              FilledButton.icon(
                onPressed: () => context.go('/checkout'),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Новый заказ'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncBody(
              status: _status,
              error: _error,
              onRetry: _load,
              isEmpty: _orders.isEmpty,
              emptyMessage: 'У вас пока нет заказов',
              builder: (context) => ListView(
                children: [
                  for (final o in _orders)
                    Card(
                      child: ExpansionTile(
                        title: Text(
                          'Заказ ${shortId(o.id)} · ${formatMoney(o.total)}',
                        ),
                        subtitle: Text(formatDateTime(o.created)),
                        trailing: OrderStatusChip(status: o.status),
                        childrenPadding: const EdgeInsets.all(16),
                        children: [OrderItemsView(order: o)],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_status == LoadStatus.success)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: PaginationBar(
                page: _page,
                totalPages: _totalPages,
                totalItems: _totalItems,
                pageSize: _perPage,
                onPageChanged: (p) => _load(page: p),
                onPageSizeChanged: (s) {
                  _perPage = s;
                  _load(page: 1);
                },
              ),
            ),
        ],
      ),
    );
  }
}
