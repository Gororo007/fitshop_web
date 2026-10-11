import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/ui_helpers.dart';
import '../features/customer_resolver.dart';
import '../features/pricing/order_pricing_engine.dart';
import '../models/customer.dart';
import '../models/list_query.dart';
import '../models/load_status.dart';
import '../models/loyalty_card.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/pricing_result.dart';
import '../models/product.dart';
import '../models/promotion.dart';
import '../repositories/catalog_repositories.dart';
import '../state/auth_notifier.dart';
import '../widgets/async_body.dart';

/// Customer checkout: pick products + quantities, see the price breakdown
/// (promotions, loyalty tier, shipping) and submit order with its items.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, this.initialProductId});

  final String? initialProductId;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  LoadStatus _status = LoadStatus.loading;
  String? _error;

  List<Product> _products = const [];
  List<Promotion> _promotions = const [];
  Customer? _customer;
  LoyaltyTier? _tier;

  final Map<String, int> _cart = {};
  String? _pickedProductId;
  final _qtyController = TextEditingController(text: '1');
  String? _pickError;
  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Product? _productById(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> _load() async {
    final user = context.read<AuthNotifier>().user;
    final products = context.read<ProductRepository>();
    final promotions = context.read<PromotionRepository>();
    final loyalty = context.read<LoyaltyCardRepository>();
    final resolver = CustomerResolver(context.read<CustomerRepository>());

    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    try {
      if (user == null) throw const UnauthorizedException();
      final productPage = await products.find(
        const ProductListQuery(size: 200, sort: 'name'),
      );
      final promoPage = await promotions.list(
        const ListQuery(perPage: 200, filter: 'active = true'),
      );
      final customer = await resolver.ensure(user);
      LoyaltyTier? tier;
      try {
        final cards = await loyalty.list(
          ListQuery(perPage: 1, filter: 'customer = "${customer.id}"'),
        );
        if (cards.items.isNotEmpty) tier = cards.items.first.tier;
      } on ApiException {
        tier = null; // loyalty is optional; checkout works without it
      }
      if (!mounted) return;
      setState(() {
        _products = productPage.items.where((p) => p.stock > 0).toList();
        _promotions = promoPage.items;
        _customer = customer;
        _tier = tier;
        final initial = widget.initialProductId;
        if (initial != null && _productById(initial) != null) {
          _cart[initial] = 1;
        }
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

  void _addPicked() {
    final id = _pickedProductId;
    final qty = int.tryParse(_qtyController.text.trim());
    if (id == null) {
      setState(() => _pickError = 'Выберите товар');
      return;
    }
    if (qty == null || qty <= 0) {
      setState(() => _pickError = 'Количество должно быть больше 0');
      return;
    }
    final product = _productById(id)!;
    final total = (_cart[id] ?? 0) + qty;
    if (total > product.stock) {
      setState(() => _pickError = 'На складе только ${product.stock} шт.');
      return;
    }
    setState(() {
      _cart[id] = total;
      _pickError = null;
      _submitError = null;
      _qtyController.text = '1';
    });
  }

  void _changeQty(String id, int delta) {
    final product = _productById(id);
    if (product == null) return;
    final next = (_cart[id] ?? 0) + delta;
    setState(() {
      if (next <= 0) {
        _cart.remove(id);
      } else if (next <= product.stock) {
        _cart[id] = next;
      }
    });
  }

  PricingResult _pricing() {
    final lines = [
      for (final e in _cart.entries)
        if (_productById(e.key) != null)
          OrderLineInput(product: _productById(e.key)!, quantity: e.value),
    ];
    return OrderPricingEngine().calculate(
      lines: lines,
      promotions: _promotions,
      loyaltyTier: _tier,
    );
  }

  Future<void> _submit(PricingResult pricing) async {
    if (_cart.isEmpty || _customer == null) return;
    final orders = context.read<ShopOrderRepository>();
    final items = context.read<OrderItemRepository>();
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    ShopOrder? created;
    try {
      created = await orders.create(
        ShopOrder(
          id: '',
          customerId: _customer!.id,
          status: OrderStatus.pending,
          subtotal: pricing.subtotal,
          discount: double.parse(
            (pricing.promotionDiscountTotal + pricing.loyaltyDiscountAmount)
                .toStringAsFixed(2),
          ),
          shipping: pricing.shippingCost,
          total: pricing.grandTotal,
        ),
      );
      for (final line in pricing.lines) {
        await items.create(
          OrderItem(
            id: '',
            orderId: created.id,
            productId: line.productId,
            quantity: line.quantity,
            unitPrice: line.unitPrice,
            lineTotal: double.parse(line.lineTotal.toStringAsFixed(2)),
          ),
        );
      }
      if (!mounted) return;
      showSnack(context, 'Заказ оформлен');
      context.go('/my-orders');
    } catch (e) {
      // Best-effort rollback of a partially created order.
      if (created != null) {
        try {
          await orders.hardDelete(created.id);
        } catch (_) {}
      }
      if (!mounted) return;
      String message = errorMessage(e);
      if (e is ValidationException) {
        final data = e.details['data'];
        if (data is Map && data.isNotEmpty) {
          message = data.entries
              .map((en) => '${en.key}: ${(en.value as Map)['message']}')
              .join('; ');
        }
      }
      setState(() {
        _submitting = false;
        _submitError = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncBody(
      status: _status,
      error: _error,
      onRetry: _load,
      builder: (context) {
        final pricing = _pricing();
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final left = _buildPicker(context);
            final right = _buildSummary(context, pricing);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: left),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: right),
                      ],
                    )
                  : Column(children: [left, const SizedBox(height: 16), right]),
            );
          },
        );
      },
    );
  }

  Widget _buildPicker(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Оформление заказа', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                SizedBox(
                  width: 320,
                  child: DropdownButtonFormField<String>(
                    initialValue: _pickedProductId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Товар',
                      border: const OutlineInputBorder(),
                      errorText: _pickError,
                    ),
                    items: [
                      for (final p in _products)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '${p.name} — ${formatMoney(p.price)} (в наличии ${p.stock})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _pickedProductId = v;
                      _pickError = null;
                    }),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Кол-во',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addPicked(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton.icon(
                    onPressed: _addPicked,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Корзина', style: theme.textTheme.titleMedium),
            const Divider(),
            if (_cart.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Корзина пуста. Добавьте товары.'),
              )
            else
              for (final e in _cart.entries)
                if (_productById(e.key) != null)
                  _cartRow(_productById(e.key)!, e.value),
          ],
        ),
      ),
    );
  }

  Widget _cartRow(Product p, int qty) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(p.name),
      subtitle: Text('${formatMoney(p.price)} × $qty'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Меньше',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => _changeQty(p.id, -1),
          ),
          Text('$qty'),
          IconButton(
            tooltip: 'Больше',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: qty < p.stock ? () => _changeQty(p.id, 1) : null,
          ),
          IconButton(
            tooltip: 'Убрать',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _cart.remove(p.id)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, PricingResult r) {
    final theme = Theme.of(context);
    Widget line(String label, String value, {bool bold = false, Color? color}) {
      final style = TextStyle(
        fontWeight: bold ? FontWeight.bold : null,
        color: color,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(label, style: style)),
            Text(value, style: style),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Расчёт стоимости', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              _tier == null
                  ? 'Карта лояльности: нет'
                  : 'Карта лояльности: ${loyaltyTierLabel(_tier!)}',
              style: theme.textTheme.bodySmall,
            ),
            const Divider(),
            for (final l in r.lines) ...[
              line(
                '${l.productName} × ${l.quantity}',
                formatMoney(l.lineTotal),
              ),
              if (l.promotionDiscount > 0)
                line(
                  '   акция',
                  '− ${formatMoney(l.promotionDiscount)}',
                  color: Colors.green.shade700,
                ),
            ],
            if (r.lines.isNotEmpty) const Divider(),
            line('Сумма товаров', formatMoney(r.subtotal)),
            line(
              'Скидки по акциям',
              '− ${formatMoney(r.promotionDiscountTotal)}',
            ),
            line(
              'Лояльность (${r.loyaltyDiscountPercent.toStringAsFixed(0)}%)',
              '− ${formatMoney(r.loyaltyDiscountAmount)}',
            ),
            line(
              r.freeShippingApplied ? 'Доставка (бесплатно)' : 'Доставка',
              formatMoney(r.shippingCost),
            ),
            const Divider(),
            line('Итого', formatMoney(r.grandTotal), bold: true),
            const SizedBox(height: 16),
            if (_submitError != null) ...[
              Text(
                _submitError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: (_cart.isEmpty || _submitting)
                  ? null
                  : () => _submit(r),
              icon: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Оформить заказ'),
            ),
          ],
        ),
      ),
    );
  }
}
