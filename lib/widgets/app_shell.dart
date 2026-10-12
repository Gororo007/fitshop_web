import 'package:flutter/material.dart';

import '../core/breakpoints.dart';
import '../models/app_user.dart';

class AppShellDestination {
  const AppShellDestination({
    required this.label,
    required this.icon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final String path;
}

List<AppShellDestination> destinationsForUser(AppUser? user) {
  if (user == null) {
    return const [
      AppShellDestination(
        label: 'Каталог',
        icon: Icons.storefront,
        path: '/products',
      ),
    ];
  }

  switch (user.role) {
    case UserRole.admin:
      return const [
        AppShellDestination(label: 'Главная', icon: Icons.dashboard, path: '/'),
        AppShellDestination(
          label: 'Товары',
          icon: Icons.inventory_2,
          path: '/products',
        ),
        AppShellDestination(
          label: 'Категории',
          icon: Icons.category,
          path: '/categories',
        ),
        AppShellDestination(
          label: 'Бренды',
          icon: Icons.branding_watermark,
          path: '/brands',
        ),
        AppShellDestination(
          label: 'Поставщики',
          icon: Icons.local_shipping,
          path: '/suppliers',
        ),
        AppShellDestination(
          label: 'Клиенты',
          icon: Icons.people,
          path: '/customers',
        ),
        AppShellDestination(
          label: 'Заказы',
          icon: Icons.receipt_long,
          path: '/orders',
        ),
        AppShellDestination(
          label: 'Сборка',
          icon: Icons.local_shipping_outlined,
          path: '/fulfillment',
        ),
        AppShellDestination(
          label: 'Акции',
          icon: Icons.local_offer,
          path: '/promotions',
        ),
        AppShellDestination(
          label: 'Отзывы',
          icon: Icons.rate_review,
          path: '/reviews',
        ),
        AppShellDestination(
          label: 'Пользователи',
          icon: Icons.admin_panel_settings,
          path: '/users',
        ),
        AppShellDestination(
          label: 'Аналитика',
          icon: Icons.analytics,
          path: '/analytics',
        ),
      ];
    case UserRole.manager:
      return const [
        AppShellDestination(label: 'Главная', icon: Icons.dashboard, path: '/'),
        AppShellDestination(
          label: 'Товары',
          icon: Icons.inventory_2,
          path: '/products',
        ),
        AppShellDestination(
          label: 'Категории',
          icon: Icons.category,
          path: '/categories',
        ),
        AppShellDestination(
          label: 'Бренды',
          icon: Icons.branding_watermark,
          path: '/brands',
        ),
        AppShellDestination(
          label: 'Поставщики',
          icon: Icons.local_shipping,
          path: '/suppliers',
        ),
        AppShellDestination(
          label: 'Клиенты',
          icon: Icons.people,
          path: '/customers',
        ),
        AppShellDestination(
          label: 'Заказы',
          icon: Icons.receipt_long,
          path: '/orders',
        ),
        AppShellDestination(
          label: 'Сборка',
          icon: Icons.local_shipping_outlined,
          path: '/fulfillment',
        ),
        AppShellDestination(
          label: 'Акции',
          icon: Icons.local_offer,
          path: '/promotions',
        ),
        AppShellDestination(
          label: 'Отзывы',
          icon: Icons.rate_review,
          path: '/reviews',
        ),
      ];
    case UserRole.customer:
      return const [
        AppShellDestination(
          label: 'Каталог',
          icon: Icons.storefront,
          path: '/products',
        ),
        AppShellDestination(
          label: 'Корзина',
          icon: Icons.shopping_cart,
          path: '/cart',
        ),
        AppShellDestination(
          label: 'Мои заказы',
          icon: Icons.shopping_bag,
          path: '/my-orders',
        ),
        AppShellDestination(
          label: 'Отзывы',
          icon: Icons.rate_review,
          path: '/reviews',
        ),
      ];
  }
}

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.user,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    this.destinations,
    this.title,
    this.actions,
  });

  final AppUser? user;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;
  final List<AppShellDestination>? destinations;
  final String? title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final items = destinations ?? destinationsForUser(user);
    final safeIndex = selectedIndex.clamp(0, items.length - 1);
    final mobile = Breakpoints.isMobile(context);

    if (mobile) {
      return Scaffold(
        appBar: title == null
            ? null
            : AppBar(title: Text(title!), actions: actions),
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: safeIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: [
            for (final d in items)
              NavigationDestination(icon: Icon(d.icon), label: d.label),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: title == null
          ? null
          : AppBar(title: Text(title!), actions: actions),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: safeIndex,
            onDestinationSelected: onDestinationSelected,
            extended: MediaQuery.sizeOf(context).width >= 1200,
            labelType: MediaQuery.sizeOf(context).width >= 1200
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: [
              for (final d in items)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
