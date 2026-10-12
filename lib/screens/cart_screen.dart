import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
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
import '../state/cart_notifier.dart';
import '../widgets/async_body.dart';

/// Корзина покупателя: позиции из каталога + расчёт + оформление.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  LoadStatus _status = LoadStatus.loading;
  String? _error;

  final Map<String, Product> _products = {};
  List<Promotion> _promotions = const [];
  Customer? _customer;
  LoyaltyTier? _tier;

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthNotifier>().user;
    final products = context.read<ProductRepository>();
    final promotions = context.read<PromotionRepository>();
    final loyalty = context.read<LoyaltyCardRepository>();
    final cart = context.read<CartNotifier>();
    final resolver = CustomerResolver(
      context.read<CustomerRepository>(),
      apiClient: context.read<ApiClient>(),
    );

    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    try {
      if (user == null) throw const UnauthorizedException();
      cart.bindUser(user.id);

      final productPage = await products.find(
        const ProductListQuery(size: 200, sort: 'name'),
      );
      final byId = {for (final p in productPage.items) p.id: p};

      // Подтянуть товары из корзины, которых нет на первой странице.
      for (final id in cart.items.keys) {
        if (byId.containsKey(id)) continue;
        try {
          final p = await products.getById(id);
          if (p != null) byId[id] = p;
        } catch (_) {}
      }

      // Убрать недоступные / без остатка.
      for (final id in cart.items.keys.toList()) {
        final p = byId[id];
        if (p == null || p.isDeleted || p.stock <= 0) {
          cart.remove(id);
        } else if (cart.quantityOf(id) > p.stock) {
          cart.setQuantity(id, p.stock, maxStock: p.stock);
        }
      }

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
        tier = null;
      }

      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addAll(byId);
        _promotions = promoPage.items;
        _customer = customer;
        _tier = tier;
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

  PricingResult _pricing(CartNotifier cart) {
    final lines = <OrderLineInput>[];
    for (final e in cart.items.entries) {
      final p = _products[e.key];
      if (p == null || p.isDeleted) continue;
      lines.add(OrderLineInput(product: p, quantity: e.value));
    }
    return OrderPricingEngine().calculate(
      lines: lines,
      promotions: _promotions,
      loyaltyTier: _tier,
    );
  }

  Future<void> _submit(CartNotifier cart, PricingResult pricing) async {
    if (cart.isEmpty || _customer == null) return;
    final orders = context.read<ShopOrderRepository>();
    final items = context.read<OrderItemRepository>();
    final products = context.read<ProductRepository>();
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    ShopOrder? created;
    try {
      for (final line in pricing.lines) {
        final fresh = await products.getById(line.productId);
        if (fresh == null || fresh.isDeleted) {
          throw ConflictException('Товар «${line.productName}» недоступен');
        }
        if (fresh.stock < line.quantity) {
          throw ConflictException(
            'Недостаточно «${line.productName}» '
            '(остаток ${fresh.stock}, в корзине ${line.quantity})',
          );
        }
      }

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
      cart.clear();
      if (!mounted) return;
      await context.read<AuthNotifier>().refreshProfile();
      if (!mounted) return;
      showSnack(context, 'Заказ оформлен');
      context.go('/my-orders');
    } catch (e) {
      if (created != null) {
        try {
          await orders.update(
            created.id,
            created.copyWith(status: OrderStatus.cancelled),
          );
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
    final cart = context.watch<CartNotifier>();
    return AsyncBody(
      status: _status,
      error: _error,
      onRetry: _load,
      builder: (context) {
        final pricing = _pricing(cart);
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final left = _buildCart(context, cart);
            final right = _buildSummary(context, cart, pricing);
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
                  : Column(
                      children: [
                        left,
                        const SizedBox(height: 16),
                        right,
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildCart(BuildContext context, CartNotifier cart) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Корзина', style: theme.textTheme.headlineSmall),
                ),
                TextButton.icon(
                  onPressed: () => context.go('/products'),
                  icon: const Icon(Icons.storefront),
                  label: const Text('В каталог'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Добавляйте товары из каталога — они сохранятся здесь.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            if (cart.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 48,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    const Text('Корзина пуста'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => context.go('/products'),
                      icon: const Icon(Icons.storefront),
                      label: const Text('Перейти в каталог'),
                    ),
                  ],
                ),
              )
            else ...[
              for (final e in cart.items.entries)
                if (_products[e.key] != null)
                  _cartRow(_products[e.key]!, e.value, cart),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    final ok = await confirmDialog(
                      context,
                      title: 'Очистить корзину?',
                      message: 'Все товары будут удалены из корзины.',
                      confirmLabel: 'Очистить',
                    );
                    if (ok) cart.clear();
                  },
                  child: const Text('Очистить корзину'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cartRow(Product p, int qty, CartNotifier cart) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: InkWell(
        onTap: () => context.go('/products/${p.id}'),
        child: Text(p.name),
      ),
      subtitle: Text(
        '${formatMoney(p.price)} · на складе ${p.stock} шт.',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Меньше',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => cart.setQuantity(p.id, qty - 1, maxStock: p.stock),
          ),
          Text('$qty', style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            tooltip: 'Больше',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: qty < p.stock
                ? () => cart.setQuantity(p.id, qty + 1, maxStock: p.stock)
                : null,
          ),
          IconButton(
            tooltip: 'Убрать',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => cart.remove(p.id),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(
    BuildContext context,
    CartNotifier cart,
    PricingResult r,
  ) {
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
            Text('Оформление', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              _tier == null
                  ? 'Карта лояльности: нет'
                  : 'Карта лояльности: ${loyaltyTierLabel(_tier!)}',
              style: theme.textTheme.bodySmall,
            ),
            const Divider(),
            if (cart.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Добавьте товары, чтобы оформить заказ.'),
              )
            else ...[
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
              const Divider(),
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
            ],
            const SizedBox(height: 16),
            if (_submitError != null) ...[
              Text(
                _submitError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: (cart.isEmpty || _submitting)
                  ? null
                  : () => _submit(cart, r),
              icon: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(
                cart.isEmpty
                    ? 'Корзина пуста'
                    : 'Оформить заказ · ${formatMoney(r.grandTotal)}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
