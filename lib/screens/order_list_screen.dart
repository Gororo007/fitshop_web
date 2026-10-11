import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/permissions.dart';
import '../core/ui_helpers.dart';
import '../models/list_query.dart';
import '../models/load_status.dart';
import '../models/order.dart';
import '../repositories/catalog_repositories.dart';
import '../state/auth_notifier.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/async_body.dart';
import '../widgets/entity_table.dart';
import '../widgets/order_widgets.dart';
import '../widgets/pagination_bar.dart';

/// All orders for staff (manager/admin). Admin can soft/hard delete/restore.
class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  late final EntityListNotifier<ShopOrder> _notifier;
  OrderStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _notifier = EntityListNotifier<ShopOrder>(
      context.read<ShopOrderRepository>(),
      initialQuery: const ListQuery(expand: 'customer'),
    )..idExtractor = (o) => o.id;
    _notifier.load();
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  ListQuery _query({OrderStatus? status, bool? includeDeleted, int? page}) {
    final q = _notifier.query;
    return ListQuery(
      page: page ?? 1,
      perPage: q.perPage,
      sort: q.sort,
      filter: status == null
          ? null
          : 'status = "${orderStatusToString(status)}"',
      expand: q.expand,
      includeDeleted: includeDeleted ?? q.includeDeleted,
    );
  }

  void _setStatus(OrderStatus? status) {
    setState(() => _statusFilter = status);
    _notifier.applyQuery(_query(status: status));
  }

  Future<void> _act(Future<void> Function() action, String ok) async {
    try {
      await action();
      if (mounted) showSnack(context, ok);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthNotifier>().user;
    final canRestore = Permissions.can(user, AppPermission.restoreDeleted);
    final canHard = Permissions.can(user, AppPermission.hardDelete);
    final canDelete = canRestore;

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
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Заказы',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/fulfillment'),
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Выполнение заказов'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<OrderStatus?>(
                      initialValue: _statusFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Статус',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<OrderStatus?>(
                          value: null,
                          child: Text('Все'),
                        ),
                        for (final s in OrderStatus.values)
                          DropdownMenuItem<OrderStatus?>(
                            value: s,
                            child: Text(orderStatusLabel(s)),
                          ),
                      ],
                      onChanged: _setStatus,
                    ),
                  ),
                  if (canRestore)
                    FilterChip(
                      label: const Text('Показать удалённые'),
                      selected: query.includeDeleted,
                      onSelected: (v) => _notifier.applyQuery(
                        _query(status: _statusFilter, includeDeleted: v),
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
                  emptyMessage: 'Заказов нет',
                  builder: (context) => EntityTable<ShopOrder>(
                    items: result.items,
                    idOf: (o) => o.id,
                    sortField: _notifier.sortField,
                    sortAscending: _notifier.sortAscending,
                    onSort: _notifier.toggleSort,
                    columns: [
                      TableColumnSpec<ShopOrder>(
                        label: '№',
                        build: (o) => Text(
                          shortId(o.id),
                          style: o.deleted != null
                              ? const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                )
                              : null,
                        ),
                      ),
                      TableColumnSpec<ShopOrder>(
                        label: 'Клиент',
                        build: (o) => Text(o.customerName ?? o.customerId),
                      ),
                      TableColumnSpec<ShopOrder>(
                        label: 'Статус',
                        sortField: 'status',
                        build: (o) => OrderStatusChip(status: o.status),
                      ),
                      TableColumnSpec<ShopOrder>(
                        label: 'Сумма',
                        sortField: 'total',
                        numeric: true,
                        build: (o) => Text(formatMoney(o.total)),
                      ),
                      TableColumnSpec<ShopOrder>(
                        label: 'Создан',
                        sortField: 'created',
                        build: (o) => Text(formatDateTime(o.created)),
                      ),
                    ],
                    actions: (o) => [
                      IconButton(
                        tooltip: 'Состав заказа',
                        icon: const Icon(Icons.list_alt),
                        onPressed: () => showOrderDetailsDialog(context, o),
                      ),
                      if (canDelete && o.deleted == null)
                        IconButton(
                          tooltip: 'Удалить',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await confirmDialog(
                              context,
                              title: 'Удалить заказ?',
                              message: 'Заказ будет помечен удалённым.',
                              confirmLabel: 'Удалить',
                            );
                            if (ok) {
                              await _act(
                                () => _notifier.softDelete(o.id),
                                'Заказ удалён',
                              );
                            }
                          },
                        ),
                      if (canRestore && o.deleted != null)
                        IconButton(
                          tooltip: 'Восстановить',
                          icon: const Icon(Icons.restore),
                          onPressed: () => _act(
                            () => _notifier.restore(o.id),
                            'Заказ восстановлен',
                          ),
                        ),
                      if (canHard)
                        IconButton(
                          tooltip: 'Удалить навсегда',
                          icon: Icon(
                            Icons.delete_forever,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () async {
                            final ok = await confirmDialog(
                              context,
                              title: 'Удалить навсегда?',
                              message: 'Действие необратимо.',
                              confirmLabel: 'Удалить навсегда',
                            );
                            if (ok) {
                              await _act(
                                () => _notifier.hardDelete(o.id),
                                'Заказ удалён навсегда',
                              );
                            }
                          },
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
