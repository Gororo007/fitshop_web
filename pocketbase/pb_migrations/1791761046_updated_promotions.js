/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_346751140")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.id != \"\" && (@request.auth.role = \"manager\" || @request.auth.role = \"admin\")",
    "deleteRule": "@request.auth.role = \"admin\"",
    "listRule": "",
    "updateRule": "@request.auth.id != \"\" && (@request.auth.role = \"manager\" || @request.auth.role = \"admin\")",
    "viewRule": ""
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_346751140")

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
