/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_2456927940")

  // update collection data
  unmarshal({
    "listRule": "@request.auth.id != \"\" && (@request.auth.role = \"manager\" || @request.auth.role = \"admin\") || order.customer.user = @request.auth.id || order.customer = @request.auth.customer",
    "viewRule": "@request.auth.id != \"\" && (@request.auth.role = \"manager\" || @request.auth.role = \"admin\") || order.customer.user = @request.auth.id || order.customer = @request.auth.customer"
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_2456927940")

  // update collection data
  unmarshal({
    "listRule": "@request.auth.id != \"\"",
    "viewRule": "@request.auth.id != \"\""
  }, collection)

  return app.save(collection)
})
