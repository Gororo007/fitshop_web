/// <reference path="../pb_data/types.d.ts" />

/**
 * После создания клиента привязываем users.customer.
 */
onRecordAfterCreateSuccess((e) => {
  try {
    const userId = `${e.record.get("user") || ""}`;
    if (!userId) return;
    const user = $app.findRecordById("users", userId);
    user.set("customer", e.record.id);
    $app.save(user);
  } catch (_) {
    // ignore
  }
}, "customers");
