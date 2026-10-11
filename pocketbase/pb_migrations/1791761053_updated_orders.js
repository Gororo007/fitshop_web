/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3527180448")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.id != \"\"",
    "deleteRule": "@request.auth.role = \"admin\"",
    "listRule": "@request.auth.id != \"\" && (@request.auth.role = \"manager\" || @request.auth.role = \"admin\") || @request.auth.customer = customer",
    "updateRule": "@request.auth.id != \"\" && (@request.auth.role = \"manager\" || @request.auth.role = \"admin\")",
    "viewRule": "@request.auth.id != \"\" && (@request.auth.role = \"manager\" || @request.auth.role = \"admin\") || @request.auth.customer = customer"
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3527180448")

  // update collection data
  unmarshal({
    "createRule": null,
    "deleteRule": null,
    "listRule": null,
    "updateRule": null,
    "viewRule": null
  }, collection)

  return app.save(collection)
})
