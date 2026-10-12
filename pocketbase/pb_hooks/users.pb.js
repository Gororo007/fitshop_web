/// <reference path="../pb_data/types.d.ts" />

/**
 * Гостевая регистрация → role=customer.
 * Админ может задать любую роль.
 * Не бросаем исключения наружу — иначе PB отвечает пустым 400.
 */
onRecordCreateRequest((e) => {
  try {
    const auth = e.requestInfo().auth;
    let isAdmin = false;
    if (auth) {
      try {
        isAdmin = `${auth.get("role") || ""}` === "admin";
      } catch (_) {
        isAdmin = false;
      }
    }
    if (!isAdmin) {
      e.record.set("role", "customer");
    }
  } catch (_) {
    try {
      e.record.set("role", "customer");
    } catch (__) {}
  }
  e.next();
}, "users");

/**
 * Запрет эскалации роли: не-админ не может менять role.
 * Берём роль из БД ($app.findRecordById), а не originalCopy —
 * иначе PATCH role=admin иногда проходит.
 */
onRecordUpdateRequest((e) => {
  try {
    const auth = e.requestInfo().auth;
    let isAdmin = false;
    if (auth) {
      try {
        isAdmin = `${auth.get("role") || ""}` === "admin";
      } catch (_) {
        isAdmin = false;
      }
    }
    if (!isAdmin) {
      try {
        const db = $app.findRecordById("users", e.record.id);
        const keep = `${db.get("role") || "customer"}` || "customer";
        e.record.set("role", keep);
      } catch (_) {
        e.record.set("role", "customer");
      }
    }
  } catch (_) {
    try {
      e.record.set("role", "customer");
    } catch (__) {}
  }
  e.next();
}, "users");
