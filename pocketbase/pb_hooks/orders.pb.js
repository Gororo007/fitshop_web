/// <reference path="../pb_data/types.d.ts" />

/**
 * Перед созданием позиции заказа проверяем остаток на складе.
 * При нехватке возвращаем 409 Conflict.
 */
onRecordCreateRequest((e) => {
  const productId = e.record.get("product");
  const qty = e.record.getInt("quantity");
  if (!productId || qty <= 0) {
    e.next();
    return;
  }

  const product = $app.findRecordById("products", productId);
  const stock = product.getInt("stock");
  if (stock < qty) {
    throw new ConflictError(
      `Недостаточно товара на складе (остаток ${stock}, запрошено ${qty})`,
    );
  }

  e.next();
}, "order_items");

/**
 * После создания позиции уменьшаем остаток.
 */
onRecordAfterCreateSuccess((e) => {
  const productId = e.record.get("product");
  const qty = e.record.getInt("quantity");
  if (!productId || qty <= 0) {
    return;
  }
  const product = $app.findRecordById("products", productId);
  product.set("stock", product.getInt("stock") - qty);
  $app.save(product);
}, "order_items");
