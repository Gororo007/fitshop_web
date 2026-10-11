import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../screens/analytics_screen.dart';
import '../screens/checkout_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/entity_screens.dart';
import '../screens/forbidden_screen.dart';
import '../screens/fulfillment_screen.dart';
import '../screens/login_screen.dart';
import '../screens/my_orders_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/order_list_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/product_form_screen.dart';
import '../screens/product_list_screen.dart';
import '../screens/register_screen.dart';
import '../screens/users_screen.dart';
import '../state/auth_notifier.dart';
import '../widgets/app_shell.dart';
import 'permissions.dart';

const _staffOnlyPrefixes = [
  '/categories',
  '/brands',
  '/suppliers',
  '/customers',
  '/promotions',
  '/fulfillment',
];

bool _matches(String path, String prefix) =>
    path == prefix || path.startsWith('$prefix/');

/// Role guard for a location. Builds on [Permissions.canAccessPath] and adds
/// route-level rules for pages that exist only for some roles.
bool canAccessLocation(AppUser? user, String path) {
  if (user == null) return path == '/login' || path == '/register';
  if (!Permissions.canAccessPath(user, path)) return false;
  if (_staffOnlyPrefixes.any((p) => _matches(path, p))) {
    return Permissions.isStaff(user);
  }
  if (_matches(path, '/checkout')) return user.role == UserRole.customer;
  return true;
}

String? _safeFrom(String? from) {
  if (from == null || from.isEmpty) return null;
  if (!from.startsWith('/') || from.startsWith('//')) return null;
  if (from.startsWith('/login') || from.startsWith('/register')) return null;
  return from;
}

GoRouter createRouter(AuthNotifier auth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    errorBuilder: (context, state) =>
        NotFoundScreen(location: state.uri.toString()),
    redirect: (context, state) {
      final path = state.uri.path;
      final user = auth.user;
      final isPublic = path == '/login' || path == '/register';

      if (user == null) {
        if (isPublic) return null;
        final from = state.uri.toString();
        return from == '/'
            ? '/login'
            : '/login?from=${Uri.encodeQueryComponent(from)}';
      }
      if (isPublic) {
        return _safeFrom(state.uri.queryParameters['from']) ?? '/';
      }
      if (path == '/forbidden') return null;
      if (!canAccessLocation(user, path)) return '/forbidden';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            LoginScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forbidden',
        builder: (context, state) => const ForbiddenScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            _ShellScaffold(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/products',
            builder: (context, state) =>
                ProductListScreen(params: state.uri.queryParameters),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const ProductFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    ProductDetailScreen(productId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => ProductFormScreen(
                      productId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/categories',
            builder: (context, state) => const CategoriesScreen(),
          ),
          GoRoute(
            path: '/brands',
            builder: (context, state) => const BrandsScreen(),
          ),
          GoRoute(
            path: '/suppliers',
            builder: (context, state) => const SuppliersScreen(),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const CustomersScreen(),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrderListScreen(),
          ),
          GoRoute(
            path: '/promotions',
            builder: (context, state) => const PromotionsScreen(),
          ),
          GoRoute(
            path: '/reviews',
            builder: (context, state) => const ReviewsScreen(),
          ),
          GoRoute(
            path: '/my-orders',
            builder: (context, state) => const MyOrdersScreen(),
          ),
          GoRoute(
            path: '/checkout',
            builder: (context, state) => CheckoutScreen(
              initialProductId: state.uri.queryParameters['add'],
            ),
          ),
          GoRoute(
            path: '/fulfillment',
            builder: (context, state) => const FulfillmentScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersScreen(),
          ),
        ],
      ),
    ],
  );
}

/// Authenticated layout: navigation rail / bottom bar + app bar.
class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.location, required this.child});

  final String location;
  final Widget child;

  int _selectedIndex(List<AppShellDestination> items) {
    // Pages that live under another top-level destination.
    var path = location;
    if (_matches(path, '/checkout')) path = '/products';
    if (_matches(path, '/fulfillment')) path = '/orders';

    var best = 0;
    var bestLen = -1;
    for (var i = 0; i < items.length; i++) {
      final p = items[i].path;
      final hit = p == '/' ? path == '/' : _matches(path, p);
      if (hit && p.length > bestLen) {
        best = i;
        bestLen = p.length;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;
    final items = destinationsForUser(user);

    return AppShell(
      user: user,
      destinations: items,
      selectedIndex: _selectedIndex(items),
      onDestinationSelected: (i) => context.go(items[i].path),
      title: 'FitShop',
      actions: [
        if (user != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${user.name} · ${userRoleLabel(user.role)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        IconButton(
          tooltip: 'Выйти',
          icon: const Icon(Icons.logout),
          onPressed: () => context.read<AuthNotifier>().logout(),
        ),
      ],
      child: child,
    );
  }
}
