/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = new Collection({
    "createRule": null,
    "deleteRule": null,
    "fields": [
      {
        "autogeneratePattern": "[a-z0-9]{15}",
        "hidden": false,
        "id": "text3208210256",
        "max": 15,
        "min": 15,
        "name": "id",
        "pattern": "^[a-z0-9]+$",
        "presentable": false,
        "primaryKey": true,
        "required": true,
        "system": true,
        "type": "text"
      },
      {
        "cascadeDelete": false,
        "collectionId": "pbc_108570809",
        "hidden": false,
        "id": "relation2168032777",
        "maxSelect": 1,
        "minSelect": 0,
        "name": "customer",
        "presentable": false,
        "required": true,
        "system": false,
        "type": "relation"
      },
      {
        "hidden": false,
        "id": "select614373258",
        "maxSelect": 1,
        "name": "tier",
        "presentable": false,
        "required": true,
        "system": false,
        "type": "select",
        "values": [
          "bronze",
          "silver",
          "gold"
        ]
      },
      {
        "hidden": false,
        "id": "number666537513",
        "max": null,
        "min": 0,
        "name": "points",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "date3946532403",
        "max": "",
        "min": "",
        "name": "deleted",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "date"
      }
    ],
    "id": "pbc_1191216631",
    "indexes": [
      "CREATE UNIQUE INDEX idx_loyalty_customer ON loyalty_cards (customer)"
    ],
    "listRule": null,
    "name": "loyalty_cards",
    "system": false,
    "type": "base",
    "updateRule": null,
    "viewRule": null
  });

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_1191216631");

  return app.delete(collection);
})
