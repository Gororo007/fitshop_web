import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/inactivity_watcher.dart';
import 'core/router.dart';
import 'repositories/auth_repository.dart';
import 'repositories/catalog_repositories.dart';
import 'repositories/pb_auth_repository.dart';
import 'repositories/user_repository.dart';
import 'state/auth_notifier.dart';
import 'state/cart_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final prefs = await SharedPreferences.getInstance();
  final apiClient = ApiClient(prefs: prefs);
  final authRepository = PbAuthRepository(apiClient, prefs);
  final authNotifier = AuthNotifier(authRepository);
  await authNotifier.restore();
  final cartNotifier = CartNotifier(prefs, userId: authNotifier.user?.id);

  runApp(
    FitShopApp(
      prefs: prefs,
      apiClient: apiClient,
      authRepository: authRepository,
      authNotifier: authNotifier,
      cartNotifier: cartNotifier,
    ),
  );
}

class FitShopApp extends StatefulWidget {
  const FitShopApp({
    super.key,
    required this.prefs,
    required this.apiClient,
    required this.authRepository,
    required this.authNotifier,
    required this.cartNotifier,
  });

  final SharedPreferences prefs;
  final ApiClient apiClient;
  final AuthRepository authRepository;
  final AuthNotifier authNotifier;
  final CartNotifier cartNotifier;

  @override
  State<FitShopApp> createState() => _FitShopAppState();
}

class _FitShopAppState extends State<FitShopApp> {
  late final GoRouter _router = createRouter(widget.authNotifier);

  @override
  void initState() {
    super.initState();
    widget.authNotifier.addListener(_syncCartUser);
  }

  void _syncCartUser() {
    widget.cartNotifier.bindUser(widget.authNotifier.user?.id);
  }

  @override
  void dispose() {
    widget.authNotifier.removeListener(_syncCartUser);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.apiClient;
    return MultiProvider(
      providers: [
        Provider<SharedPreferences>.value(value: widget.prefs),
        Provider<ApiClient>.value(value: client),
        Provider<AuthRepository>.value(value: widget.authRepository),
        ChangeNotifierProvider<AuthNotifier>.value(value: widget.authNotifier),
        ChangeNotifierProvider<CartNotifier>.value(value: widget.cartNotifier),
        Provider<ProductRepository>(create: (_) => PbProductRepository(client)),
        Provider<CategoryRepository>(
          create: (_) => PbCategoryRepository(client),
        ),
        Provider<BrandRepository>(create: (_) => PbBrandRepository(client)),
        Provider<SupplierRepository>(
          create: (_) => PbSupplierRepository(client),
        ),
        Provider<CustomerRepository>(
          create: (_) => PbCustomerRepository(client),
        ),
        Provider<LoyaltyCardRepository>(
          create: (_) => PbLoyaltyCardRepository(client),
        ),
        Provider<PromotionRepository>(
          create: (_) => PbPromotionRepository(client),
        ),
        Provider<ReviewRepository>(create: (_) => PbReviewRepository(client)),
        Provider<ShopOrderRepository>(
          create: (_) => PbShopOrderRepository(client),
        ),
        Provider<OrderItemRepository>(
          create: (_) => PbOrderItemRepository(client),
        ),
        ProxyProvider2<CustomerRepository, LoyaltyCardRepository,
            UserRepository>(
          update: (_, customers, loyalty, previous) => PbUserRepository(
            client,
            customers: customers,
            loyaltyCards: loyalty,
          ),
        ),
      ],
      child: MaterialApp.router(
        title: 'FitShop',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        routerConfig: _router,
        builder: (context, child) => ListenableBuilder(
          listenable: widget.authNotifier,
          builder: (context, _) => InactivityWatcher(
            enabled: widget.authNotifier.isAuthenticated,
            onTimeout: () => widget.authNotifier.logout(),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
