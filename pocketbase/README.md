# PocketBase для FitShop

## Запуск локально

```powershell
cd pocketbase
.\pocketbase.exe serve --http=127.0.0.1:8090
```

Админка: http://127.0.0.1:8090/_/

Суперпользователь (после первого setup):

- email: `admin@fitshop.local`
- пароль: `FitshopAdmin123!`

## Инициализация схемы и данных

В другом терминале:

```powershell
.\pocketbase.exe superuser upsert admin@fitshop.local FitshopAdmin123!
node setup.mjs
```

Скрипт создаёт коллекции, правила доступа, тестовые товары и пользователей.

## Учётные записи приложения

Пароль у всех: `Fitshop123!`

| Email | Роль |
| --- | --- |
| admin@fitshop.ru | admin |
| manager@fitshop.ru | manager |
| customer@fitshop.ru | customer |

## Hook остатков

Файл `pb_hooks/orders.pb.js` отклоняет создание `order_items` с кодом 409, если `stock < quantity`, и уменьшает остаток после успешного создания.

## Клиент Flutter

```powershell
cd ..
flutter run -d chrome --web-port=5555 --dart-define=API_BASE_URL=http://127.0.0.1:8090
```
