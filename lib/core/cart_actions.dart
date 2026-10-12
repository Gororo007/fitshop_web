import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../state/cart_notifier.dart';
import 'ui_helpers.dart';

/// Добавляет товар в корзину и показывает snack с переходом в корзину.
void addProductToCart(BuildContext context, Product product, {int qty = 1}) {
  if (product.isDeleted || product.stock <= 0) {
    showSnack(context, 'Товар недоступен', error: true);
    return;
  }
  final cart = context.read<CartNotifier>();
  final inCart = cart.add(
    product.id,
    qty: qty,
    maxStock: product.stock,
  );
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          inCart == qty
              ? '«${product.name}» добавлен в корзину'
              : 'В корзине: «${product.name}» × $inCart',
        ),
        action: SnackBarAction(
          label: 'Корзина',
          onPressed: () => context.go('/cart'),
        ),
      ),
    );
}
