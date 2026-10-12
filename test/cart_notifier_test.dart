import 'package:fitshop_web/state/cart_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CartNotifier persists and restores by user', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final a = CartNotifier(prefs, userId: 'u1');
    a.add('p1', qty: 2, maxStock: 10);
    a.add('p2', qty: 1, maxStock: 5);
    expect(a.totalUnits, 3);

    final b = CartNotifier(prefs, userId: 'u1');
    expect(b.quantityOf('p1'), 2);
    expect(b.quantityOf('p2'), 1);

    final other = CartNotifier(prefs, userId: 'u2');
    expect(other.isEmpty, isTrue);

    b.bindUser('u2');
    expect(b.isEmpty, isTrue);
    b.bindUser('u1');
    expect(b.quantityOf('p1'), 2);
  });

  test('CartNotifier respects maxStock', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cart = CartNotifier(prefs, userId: 'u');
    cart.add('p', qty: 5, maxStock: 3);
    expect(cart.quantityOf('p'), 3);
    cart.setQuantity('p', 0);
    expect(cart.isEmpty, isTrue);
  });
}
