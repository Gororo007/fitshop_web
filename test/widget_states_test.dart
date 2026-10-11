import 'package:fitshop_web/core/permissions.dart';
import 'package:fitshop_web/models/app_user.dart';
import 'package:fitshop_web/models/load_status.dart';
import 'package:fitshop_web/widgets/async_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('AsyncBody shows loading indicator', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AsyncBody(
          status: LoadStatus.loading,
          error: null,
          isEmpty: false,
          emptyMessage: 'Пусто',
          onRetry: () {},
          builder: (_) => const Text('DATA'),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('DATA'), findsNothing);
  });

  testWidgets('AsyncBody shows empty message without spinner', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AsyncBody(
          status: LoadStatus.success,
          error: null,
          isEmpty: true,
          emptyMessage: 'Товаров не найдено',
          onRetry: () {},
          builder: (_) => const Text('DATA'),
        ),
      ),
    );
    expect(find.text('Товаров не найдено'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('DATA'), findsNothing);
  });

  testWidgets('AsyncBody shows error with retry button', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _wrap(
        AsyncBody(
          status: LoadStatus.error,
          error: 'Сервер недоступен',
          isEmpty: false,
          emptyMessage: 'Пусто',
          onRetry: () => retried = true,
          builder: (_) => const Text('DATA'),
        ),
      ),
    );
    expect(find.text('Сервер недоступен'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    expect(retried, isTrue);
  });

  testWidgets('AsyncBody shows child on success with data', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AsyncBody(
          status: LoadStatus.success,
          error: null,
          isEmpty: false,
          emptyMessage: 'Пусто',
          onRetry: () {},
          builder: (_) => const Text('КАТАЛОГ'),
        ),
      ),
    );
    expect(find.text('КАТАЛОГ'), findsOneWidget);
  });

  testWidgets('manage catalog button hidden for customer role', (tester) async {
    const customer = AppUser(
      id: '1',
      email: 'c@x.ru',
      name: 'C',
      role: UserRole.customer,
    );
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) {
            final canManage = Permissions.can(
              customer,
              AppPermission.manageCatalog,
            );
            return Column(
              children: [
                if (canManage)
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Добавить товар'),
                  ),
                const Text('Каталог'),
              ],
            );
          },
        ),
      ),
    );
    expect(find.text('Добавить товар'), findsNothing);
    expect(find.text('Каталог'), findsOneWidget);
  });
}
