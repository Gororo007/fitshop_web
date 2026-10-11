import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ui_helpers.dart';
import '../models/list_query.dart';
import '../models/load_status.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../repositories/catalog_repositories.dart';
import '../widgets/async_body.dart';

class _TopProduct {
  _TopProduct(this.name);
  final String name;
  int quantity = 0;
  double revenue = 0;
}

/// Admin dashboard computed client-side from orders and order items.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const _pageSize = 200;
  static const _maxPages = 10;

  LoadStatus _status = LoadStatus.loading;
  String? _error;

  int _orderCount = 0;
  double _revenue = 0;
  double _discounts = 0;
  Map<OrderStatus, int> _byStatus = {};
  List<_TopProduct> _top = const [];
  bool _truncated = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final orderRepo = context.read<ShopOrderRepository>();
    final itemRepo = context.read<OrderItemRepository>();
    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    try {
      final orders = <ShopOrder>[];
      var truncated = false;
      for (var page = 1; page <= _maxPages; page++) {
        final res = await orderRepo.list(
          ListQuery(page: page, perPage: _pageSize),
        );
        orders.addAll(res.items);
        if (page >= res.totalPages) break;
        if (page == _maxPages) truncated = true;
      }

      final validOrderIds = {
        for (final o in orders)
          if (o.status != OrderStatus.cancelled) o.id,
      };

      final items = <OrderItem>[];
      for (var page = 1; page <= _maxPages; page++) {
        final res = await itemRepo.list(
          ListQuery(page: page, perPage: _pageSize),
        );
        items.addAll(res.items);
        if (page >= res.totalPages) break;
        if (page == _maxPages) truncated = true;
      }

      final byStatus = {for (final s in OrderStatus.values) s: 0};
      var revenue = 0.0;
      var discounts = 0.0;
      for (final o in orders) {
        byStatus[o.status] = (byStatus[o.status] ?? 0) + 1;
        if (o.status != OrderStatus.cancelled) {
          revenue += o.total;
          discounts += o.discount;
        }
      }

      final top = <String, _TopProduct>{};
      for (final i in items) {
        if (!validOrderIds.contains(i.orderId)) continue;
        final t = top.putIfAbsent(
          i.productId,
          () => _TopProduct(i.productName ?? i.productId),
        );
        t.quantity += i.quantity;
        t.revenue += i.lineTotal;
      }
      final topList = top.values.toList()
        ..sort((a, b) => b.quantity.compareTo(a.quantity));

      if (!mounted) return;
      setState(() {
        _orderCount = orders.length;
        _revenue = revenue;
        _discounts = discounts;
        _byStatus = byStatus;
        _top = topList.take(10).toList();
        _truncated = truncated;
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
    return AsyncBody(
      status: _status,
      error: _error,
      onRetry: _load,
      isEmpty: false,
      builder: (context) {
        final counted = _orderCount - (_byStatus[OrderStatus.cancelled] ?? 0);
        final avg = counted == 0 ? 0.0 : _revenue / counted;
        final maxStatus = _byStatus.values.fold<int>(
          1,
          (m, v) => v > m ? v : m,
        );
        final maxQty = _top.isEmpty ? 1 : _top.first.quantity;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Аналитика',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Обновить',
                  icon: const Icon(Icons.refresh),
                  onPressed: _load,
                ),
              ],
            ),
            if (_truncated)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Данные ограничены первыми 2000 записей.'),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _stat(
                  context,
                  'Выручка (без отменённых)',
                  formatMoney(_revenue),
                ),
                _stat(context, 'Всего заказов', '$_orderCount'),
                _stat(context, 'Средний чек', formatMoney(avg)),
                _stat(context, 'Скидок выдано', formatMoney(_discounts)),
              ],
            ),
            const SizedBox(height: 32),
            Text('Заказы по статусам', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final s in OrderStatus.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 130, child: Text(orderStatusLabel(s))),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (_byStatus[s] ?? 0) / maxStatus,
                        minHeight: 14,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${_byStatus[s] ?? 0}',
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            Text(
              'Топ-10 товаров по количеству',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_top.isEmpty)
              const Text('Нет данных о продажах')
            else
              for (var i = 0; i < _top.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 28, child: Text('${i + 1}.')),
                      SizedBox(
                        width: 200,
                        child: Text(
                          _top[i].name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: _top[i].quantity / maxQty,
                          minHeight: 14,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: Text(
                          '${_top[i].quantity} шт · ${formatMoney(_top[i].revenue)}',
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(value, style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}
