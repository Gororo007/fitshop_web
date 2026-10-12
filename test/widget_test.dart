import 'package:fitshop_web/core/api_client.dart';
import 'package:fitshop_web/main.dart';
import 'package:fitshop_web/repositories/pb_auth_repository.dart';
import 'package:fitshop_web/state/auth_notifier.dart';
import 'package:fitshop_web/state/cart_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('unauthenticated user is redirected to login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final client = ApiClient(prefs: prefs);
    final repo = PbAuthRepository(client, prefs);
    final auth = AuthNotifier(repo);
    await auth.restore();

    await tester.pumpWidget(
      FitShopApp(
        prefs: prefs,
        apiClient: client,
        authRepository: repo,
        authNotifier: auth,
        cartNotifier: CartNotifier(prefs),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Вход в систему'), findsOneWidget);
  });
}
