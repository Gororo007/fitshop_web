import 'package:fitshop_web/core/config.dart';
import 'package:fitshop_web/core/permissions.dart';
import 'package:fitshop_web/core/validators.dart';
import 'package:fitshop_web/features/pricing/order_pricing_engine.dart';
import 'package:fitshop_web/models/app_user.dart';
import 'package:fitshop_web/models/loyalty_card.dart';
import 'package:fitshop_web/models/product.dart';
import 'package:fitshop_web/models/promotion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    test('requiredField rejects empty', () {
      expect(Validators.requiredField(''), isNotNull);
      expect(Validators.requiredField('   '), isNotNull);
      expect(Validators.requiredField('ok'), isNull);
    });

    test('email validates format', () {
      expect(Validators.email('bad'), isNotNull);
      expect(Validators.email('user@fitshop.ru'), isNull);
    });

    test('password requires digit and special char', () {
      expect(Validators.password('short'), isNotNull);
      expect(Validators.password('longenough'), isNotNull);
      expect(Validators.password('Longenough1'), isNotNull);
      expect(Validators.password('Fitshop123!'), isNull);
    });

    test('positiveNumber rejects zero and negative', () {
      expect(Validators.positiveNumber('0'), isNotNull);
      expect(Validators.positiveNumber('-1'), isNotNull);
      expect(Validators.positiveNumber('12.5'), isNull);
    });
  });

  group('Permissions', () {
    const customer = AppUser(
      id: '1',
      email: 'c@x.ru',
      name: 'C',
      role: UserRole.customer,
    );
    const manager = AppUser(
      id: '2',
      email: 'm@x.ru',
      name: 'M',
      role: UserRole.manager,
    );
    const admin = AppUser(
      id: '3',
      email: 'a@x.ru',
      name: 'A',
      role: UserRole.admin,
    );

    test('customer can view my orders but not users', () {
      expect(Permissions.can(customer, AppPermission.viewMyOrders), isTrue);
      expect(Permissions.can(customer, AppPermission.manageUsers), isFalse);
      expect(Permissions.canAccessPath(customer, '/my-orders'), isTrue);
      expect(Permissions.canAccessPath(customer, '/users'), isFalse);
    });

    test('manager can manage catalog but not analytics', () {
      expect(Permissions.can(manager, AppPermission.manageCatalog), isTrue);
      expect(Permissions.can(manager, AppPermission.viewAnalytics), isFalse);
      expect(Permissions.canAccessPath(manager, '/fulfillment'), isTrue);
      expect(Permissions.canAccessPath(manager, '/analytics'), isFalse);
      expect(Permissions.canAccessPath(customer, '/fulfillment'), isFalse);
      expect(Permissions.canAccessPath(customer, '/cart'), isTrue);
      expect(Permissions.canAccessPath(customer, '/checkout'), isTrue);
    });

    test('admin has hard delete and analytics', () {
      expect(Permissions.can(admin, AppPermission.hardDelete), isTrue);
      expect(Permissions.can(admin, AppPermission.viewAnalytics), isTrue);
      expect(Permissions.canAccessPath(admin, '/users'), isTrue);
    });
  });

  group('Product.fromJson', () {
    test('missing fields do not throw', () {
      final p = Product.fromJson({'id': 'abc'});
      expect(p.id, 'abc');
      expect(p.name, '');
      expect(p.price, 0);
      expect(p.categoryIds, isEmpty);
    });

    test('parses expand brand name', () {
      final p = Product.fromJson({
        'id': '1',
        'name': 'Whey',
        'price': 100,
        'stock': 5,
        'brand': 'b1',
        'categories': ['c1', 'c2'],
        'expand': {
          'brand': {'name': 'ON'},
        },
      });
      expect(p.brandName, 'ON');
      expect(p.categoryIds, ['c1', 'c2']);
    });
  });

  group('OrderPricingEngine', () {
    final whey = const Product(id: 'p1', name: 'Whey', price: 1000, stock: 10);
    final shaker = const Product(
      id: 'p2',
      name: 'Shaker',
      price: 500,
      stock: 10,
    );

    test('empty lines give zero total with shipping', () {
      final r = OrderPricingEngine().calculate(
        lines: const [],
        promotions: const [],
      );
      expect(r.subtotal, 0);
      expect(r.shippingCost, AppConfig.defaultShippingCost);
      expect(r.grandTotal, AppConfig.defaultShippingCost);
    });

    test('applies best promotion percent', () {
      final promo = Promotion(
        id: 'pr1',
        name: 'Sale',
        discountPercent: 10,
        active: true,
        startDate: DateTime(2020),
        endDate: DateTime(2030),
        productIds: const ['p1'],
      );
      final r = OrderPricingEngine(now: DateTime(2026, 1, 1)).calculate(
        lines: [OrderLineInput(product: whey, quantity: 2)],
        promotions: [promo],
      );
      expect(r.subtotal, 2000);
      expect(r.promotionDiscountTotal, 200);
    });

    test('applies gold loyalty after promotions', () {
      final r = OrderPricingEngine().calculate(
        lines: [OrderLineInput(product: whey, quantity: 1)],
        promotions: const [],
        loyaltyTier: LoyaltyTier.gold,
      );
      expect(r.loyaltyDiscountPercent, AppConfig.loyaltyGoldPercent);
      expect(r.loyaltyDiscountAmount, 120);
    });

    test('free shipping above threshold', () {
      final r = OrderPricingEngine().calculate(
        lines: [
          OrderLineInput(product: whey, quantity: 6), // 6000
        ],
        promotions: const [],
      );
      expect(r.freeShippingApplied, isTrue);
      expect(r.shippingCost, 0);
      expect(r.grandTotal, 6000);
    });

    test('skips non-positive quantities', () {
      final r = OrderPricingEngine().calculate(
        lines: [
          OrderLineInput(product: whey, quantity: 0),
          OrderLineInput(product: shaker, quantity: -1),
        ],
        promotions: const [],
      );
      expect(r.subtotal, 0);
      expect(r.lines, isEmpty);
    });
  });
}
