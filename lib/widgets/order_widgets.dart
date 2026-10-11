import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ui_helpers.dart';
import '../models/load_status.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../repositories/catalog_repositories.dart';
import 'async_body.dart';

Color orderStatusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return Colors.blueGrey;
    case OrderStatus.processing:
      return Colors.orange;
    case OrderStatus.shipped:
      return Colors.indigo;
    case OrderStatus.delivered:
      return Colors.green;
    case OrderStatus.cancelled:
      return Colors.red;
  }
}

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(status);
    return Chip(
      label: Text(
        orderStatusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      side: BorderSide(color: color),
      backgroundColor: color.withValues(alpha: 0.1),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Loads and renders the line items of one order.
class OrderItemsView extends StatefulWidget {
  const OrderItemsView({super.key, required this.order});

  final ShopOrder order;

  @override
  State<OrderItemsView> createState() => _OrderItemsViewState();
}

class _OrderItemsViewState extends State<OrderItemsView> {
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  List<OrderItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    try {
      final page = await context.read<OrderItemRepository>().listByOrder(
        widget.order.id,
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
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
    final o = widget.order;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60, maxHeight: 280),
          child: AsyncBody(
            status: _status,
            error: _error,
            onRetry: _load,
            isEmpty: _items.isEmpty,
            emptyMessage: 'В заказе нет позиций',
            builder: (context) => ListView(
              shrinkWrap: true,
              children: [
                for (final i in _items)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(i.productName ?? i.productId),
                    subtitle: Text(
                      '${i.quantity} × ${formatMoney(i.unitPrice)}',
                    ),
                    trailing: Text(formatMoney(i.lineTotal)),
                  ),
              ],
            ),
          ),
        ),
        const Divider(),
        _line('Сумма товаров', formatMoney(o.subtotal)),
        _line('Скидка', '− ${formatMoney(o.discount)}'),
        _line('Доставка', formatMoney(o.shipping)),
        _line('Итого', formatMoney(o.total), bold: true),
      ],
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

Future<void> showOrderDetailsDialog(BuildContext context, ShopOrder order) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Заказ ${shortId(order.id)}'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Клиент: ${order.customerName ?? order.customerId}'),
            Text('Создан: ${formatDateTime(order.created)}'),
            const SizedBox(height: 4),
            OrderStatusChip(status: order.status),
            const SizedBox(height: 8),
            OrderItemsView(order: order),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
}
