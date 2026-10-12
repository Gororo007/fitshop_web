import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Локальная корзина покупателя (persist в SharedPreferences по userId).
class CartNotifier extends ChangeNotifier {
  CartNotifier(this._prefs, {String? userId}) {
    _storageKey = _keyFor(userId);
    _items.addAll(_read());
  }

  static const _prefix = 'fitshop_cart_v1_';

  final SharedPreferences _prefs;
  late String _storageKey;
  final Map<String, int> _items = {};

  static String _keyFor(String? userId) =>
      '$_prefix${(userId == null || userId.isEmpty) ? 'guest' : userId}';

  /// productId → количество
  Map<String, int> get items => Map.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  int get totalUnits => _items.values.fold(0, (s, q) => s + q);

  int quantityOf(String productId) => _items[productId] ?? 0;

  /// Переключает корзину при входе/выходе.
  void bindUser(String? userId) {
    final next = _keyFor(userId);
    if (next == _storageKey) return;
    _storageKey = next;
    _items
      ..clear()
      ..addAll(_read());
    notifyListeners();
  }

  /// Добавляет [qty] шт. (с учётом [maxStock], если задан).
  /// Возвращает фактическое количество в корзине после добавления.
  int add(String productId, {int qty = 1, int? maxStock}) {
    if (productId.isEmpty || qty <= 0) return quantityOf(productId);
    var next = quantityOf(productId) + qty;
    if (maxStock != null && maxStock >= 0) {
      next = next.clamp(0, maxStock);
    }
    if (next <= 0) {
      _items.remove(productId);
    } else {
      _items[productId] = next;
    }
    _persist();
    notifyListeners();
    return quantityOf(productId);
  }

  void setQuantity(String productId, int qty, {int? maxStock}) {
    if (productId.isEmpty) return;
    var next = qty;
    if (maxStock != null && maxStock >= 0) {
      next = next.clamp(0, maxStock);
    }
    if (next <= 0) {
      _items.remove(productId);
    } else {
      _items[productId] = next;
    }
    _persist();
    notifyListeners();
  }

  void remove(String productId) {
    if (_items.remove(productId) == null) return;
    _persist();
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    _persist();
    notifyListeners();
  }

  Map<String, int> _read() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, int>{};
      decoded.forEach((k, v) {
        final q = v is int ? v : int.tryParse('$v') ?? 0;
        if (k is String && k.isNotEmpty && q > 0) out[k] = q;
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  void _persist() {
    _prefs.setString(_storageKey, jsonEncode(_items));
  }
}
