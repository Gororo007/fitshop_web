import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/permissions.dart';
import '../models/app_user.dart';
import '../models/list_query.dart';
import '../models/load_status.dart';
import '../repositories/catalog_repositories.dart';
import '../state/auth_notifier.dart';
import '../widgets/async_body.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Map<String, int> _counts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthNotifier>().user;
    if (!Permissions.isStaff(user)) {
      setState(() => _status = LoadStatus.success);
      return;
    }
    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    try {
      const one = ListQuery(perPage: 1);
      final products = context.read<ProductRepository>();
      final orders = context.read<ShopOrderRepository>();
      final customers = context.read<CustomerRepository>();
      final results = await Future.wait([
        products.find(const ProductListQuery(size: 1)),
        orders.list(one),
        customers.list(one),
      ]);
      if (!mounted) return;
      setState(() {
        _counts['Товары'] = results[0].totalItems;
        _counts['Заказы'] = results[1].totalItems;
        _counts['Клиенты'] = results[2].totalItems;
        _status = LoadStatus.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _status = LoadStatus.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthNotifier>().user;
    final theme = Theme.of(context);

    final links = <_QuickLink>[
      const _QuickLink('Каталог товаров', Icons.storefront, '/products'),
      if (user?.role == UserRole.customer) ...const [
        _QuickLink('Оформить заказ', Icons.shopping_cart_checkout, '/checkout'),
        _QuickLink('Мои заказы', Icons.shopping_bag, '/my-orders'),
      ],
      if (Permissions.isStaff(user)) ...const [
        _QuickLink('Заказы', Icons.receipt_long, '/orders'),
        _QuickLink('Выполнение заказов', Icons.local_shipping, '/fulfillment'),
        _QuickLink('Клиенты', Icons.people, '/customers'),
        _QuickLink('Акции', Icons.local_offer, '/promotions'),
      ],
      if (user?.role == UserRole.admin) ...const [
        _QuickLink('Аналитика', Icons.analytics, '/analytics'),
        _QuickLink('Пользователи', Icons.admin_panel_settings, '/users'),
      ],
      const _QuickLink('Отзывы', Icons.rate_review, '/reviews'),
    ];

    return AsyncBody(
      status: _status,
      error: _error,
      onRetry: _load,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Добро пожаловать, ${user?.name ?? ''}!',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Роль: ${user == null ? '—' : userRoleLabel(user.role)}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          if (_counts.isNotEmpty) ...[
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final e in _counts.entries)
                  SizedBox(
                    width: 200,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.key, style: theme.textTheme.labelLarge),
                            const SizedBox(height: 8),
                            Text(
                              '${e.value}',
                              style: theme.textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          Text('Быстрые действия', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final l in links)
                ActionChip(
                  avatar: Icon(l.icon, size: 18),
                  label: Text(l.label),
                  onPressed: () => context.go(l.path),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickLink {
  const _QuickLink(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;
}
