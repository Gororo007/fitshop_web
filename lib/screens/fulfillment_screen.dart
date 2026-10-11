import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ui_helpers.dart';
import '../models/list_query.dart';
import '../models/load_status.dart';
import '../models/order.dart';
import '../repositories/catalog_repositories.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/async_body.dart';
import '../widgets/entity_table.dart';
import '../widgets/order_widgets.dart';
import '../widgets/pagination_bar.dart';

/// Manager workflow: move orders through pending → processing → shipped →
/// delivered (or cancel them).
class FulfillmentScreen extends StatefulWidget {
  const FulfillmentScreen({super.key});

  @override
  State<FulfillmentScreen> createState() => _FulfillmentScreenState();
}

/// Filter modes of the fulfillment list.
enum _Scope { active, all, pending, processing, shipped, delivered, cancelled }

class _FulfillmentScreenState extends State<FulfillmentScreen> {
  late final EntityListNotifier<ShopOrder> _notifier;
  _Scope _scope = _Scope.active;
  final Set<String> _busy = {};

  static const _activeFilter = 'status != "delivered" && status != "cancelled"';

  @override
  void initState() {
    super.initState();
    _notifier = EntityListNotifier<ShopOrder>(
      context.read<ShopOrderRepository>(),
      initialQuery: const ListQuery(
        expand: 'customer',
        sort: 'created',
        filter: _activeFilter,
      ),
    )..idExtractor = (o) => o.id;
    _notifier.load();
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  String? _filterFor(_Scope s) {
    switch (s) {
      case _Scope.active:
        return _activeFilter;
      case _Scope.all:
        return null;
      case _Scope.pending:
        return 'status = "pending"';
      case _Scope.processing:
        return 'status = "processing"';
      case _Scope.shipped:
        return 'status = "shipped"';
      case _Scope.delivered:
        return 'status = "delivered"';
      case _Scope.cancelled:
        return 'status = "cancelled"';
    }
  }

  String _scopeLabel(_Scope s) {
    switch (s) {
      case _Scope.active:
        return 'Активные';
      case _Scope.all:
        return 'Все';
      case _Scope.pending:
        return orderStatusLabel(OrderStatus.pending);
      case _Scope.processing:
        return orderStatusLabel(OrderStatus.processing);
      case _Scope.shipped:
        return orderStatusLabel(OrderStatus.shipped);
      case _Scope.delivered:
        return orderStatusLabel(OrderStatus.delivered);
      case _Scope.cancelled:
        return orderStatusLabel(OrderStatus.cancelled);
    }
  }

  void _setScope(_Scope s) {
    setState(() => _scope = s);
    final q = _notifier.query;
    _notifier.applyQuery(
      ListQuery(
        perPage: q.perPage,
        sort: q.sort,
        filter: _filterFor(s),
        expand: q.expand,
      ),
    );
  }

  List<OrderStatus> _nextStatuses(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return const [OrderStatus.processing, OrderStatus.cancelled];
      case OrderStatus.processing:
        return const [OrderStatus.shipped, OrderStatus.cancelled];
      case OrderStatus.shipped:
        return const [OrderStatus.delivered];
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return const [];
    }
  }

  Future<void> _change(ShopOrder o, OrderStatus next) async {
    if (next == OrderStatus.cancelled) {
      final ok = await confirmDialog(
        context,
        title: 'Отменить заказ?',
        message: 'Заказ ${shortId(o.id)} будет отменён.',
        confirmLabel: 'Отменить заказ',
      );
      if (!ok || !mounted) return;
    }
    final repo = context.read<ShopOrderRepository>();
    setState(() => _busy.add(o.id));
    try {
      await repo.update(
        o.id,
        ShopOrder(
          id: o.id,
          customerId: o.customerId,
          status: next,
          subtotal: o.subtotal,
          discount: o.discount,
          shipping: o.shipping,
          total: o.total,
        ),
      );
      if (mounted) {
        showSnack(context, 'Статус: ${orderStatusLabel(next)}');
      }
      await _notifier.load();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(o.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) {
        final result = _notifier.result;
        final query = _notifier.query;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Выполнение заказов',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _Scope.values)
                    ChoiceChip(
                      label: Text(_scopeLabel(s)),
                      selected: _scope == s,
                      onSelected: (_) => _setScope(s),
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
                  emptyMessage: 'Заказов в этой категории нет',
                  builder: (context) => EntityTable<ShopOrder>(
                    items: result.items,
                    idOf: (o) => o.id,
                    columns: [
                      TableColumnSpec<ShopOrder>(
                        label: '№',
                        build: (o) => Text(shortId(o.id)),
                      ),
                      TableColumnSpec<ShopOrder>(
                        label: 'Клиент',
                        build: (o) => Text(o.customerName ?? o.customerId),
                      ),
                      TableColumnSpec<ShopOrder>(
                        label: 'Сумма',
                        numeric: true,
                        build: (o) => Text(formatMoney(o.total)),
                      ),
                      TableColumnSpec<ShopOrder>(
                        label: 'Создан',
                        build: (o) => Text(formatDateTime(o.created)),
                      ),
                      TableColumnSpec<ShopOrder>(
                        label: 'Статус',
                        build: (o) => OrderStatusChip(status: o.status),
                      ),
                    ],
                    actions: (o) => [
                      IconButton(
                        tooltip: 'Состав заказа',
                        icon: const Icon(Icons.list_alt),
                        onPressed: () => showOrderDetailsDialog(context, o),
                      ),
                      if (_busy.contains(o.id))
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        for (final next in _nextStatuses(o.status))
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: next == OrderStatus.cancelled
                                ? OutlinedButton(
                                    onPressed: () => _change(o, next),
                                    child: const Text('Отменить'),
                                  )
                                : FilledButton.tonal(
                                    onPressed: () => _change(o, next),
                                    child: Text('→ ${orderStatusLabel(next)}'),
                                  ),
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
                    pageSize: query.perPage,
                    onPageChanged: _notifier.setPage,
                    onPageSizeChanged: _notifier.setPageSize,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
