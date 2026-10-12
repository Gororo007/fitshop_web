/// <reference path="../pb_data/types.d.ts" />

/**
 * Перед созданием позиции заказа проверяем остаток на складе.
 * При нехватке — HTTP 409.
 */
onRecordCreateRequest((e) => {
  const productId = e.record.get("product");
  const qty = e.record.getInt("quantity");
  if (!productId || qty <= 0) {
    e.next();
    return;
  }

  try {
    const product = $app.findRecordById("products", productId);
    const stock = product.getInt("stock");
    if (stock < qty) {
      throw new ApiError(
        409,
        `Недостаточно товара на складе (остаток ${stock}, запрошено ${qty})`,
        {},
      );
    }
  } catch (err) {
    if (err instanceof ApiError) throw err;
    throw new ApiError(400, "Ошибка проверки остатка", {});
  }

  e.next();
}, "order_items");

/**
 * После создания позиции уменьшаем остаток.
 */
onRecordAfterCreateSuccess((e) => {
  try {
    const productId = e.record.get("product");
    const qty = e.record.getInt("quantity");
    if (!productId || qty <= 0) return;
    const product = $app.findRecordById("products", productId);
    product.set("stock", product.getInt("stock") - qty);
    $app.save(product);
  } catch (_) {}
}, "order_items");

/**
 * Транзакционный update: originalCopy здесь надёжен.
 * После e.next() при переходе в cancelled возвращаем остатки.
 */
onRecordUpdate((e) => {
  var was = "";
  try {
    was = "" + (e.record.originalCopy().get("status") || "");
  } catch (_) {
    was = "";
  }

  e.next();

  try {
    var now = "" + (e.record.get("status") || "");
    if (was === "cancelled" || now !== "cancelled") return;

    var items = $app.findRecordsByFilter(
      "order_items",
      'order = "' + e.record.id + '"',
      "",
      200,
      0,
    );
    for (var i = 0; i < items.length; i++) {
      var item = items[i];
      var productId = item.get("product");
      var qty = item.getInt("quantity");
      if (!productId || qty <= 0) continue;
      try {
        var product = $app.findRecordById("products", productId);
        product.set("stock", product.getInt("stock") + qty);
        $app.save(product);
      } catch (_) {}
    }
  } catch (_) {}
}, "orders");
