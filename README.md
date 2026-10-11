# FitShop — магазин фитнес-продукции

Итоговый проект УП.04.01: Flutter Web + PocketBase.

## Быстрый старт

### 1. PocketBase

```powershell
cd pocketbase
.\pocketbase.exe serve --http=127.0.0.1:8090
```

В другом терминале (один раз):

```powershell
cd pocketbase
.\pocketbase.exe superuser upsert admin@fitshop.local FitshopAdmin123!
node setup.mjs
```

Подробности: [pocketbase/README.md](pocketbase/README.md), схема: [pocketbase/схема.md](pocketbase/схема.md).

### 2. Клиент

```powershell
flutter pub get
flutter run -d chrome --web-port=5555 --dart-define=API_BASE_URL=http://127.0.0.1:8090
```

### Учётные записи

| Email | Роль | Пароль |
| --- | --- | --- |
| admin@fitshop.ru | admin | Fitshop123! |
| manager@fitshop.ru | manager | Fitshop123! |
| customer@fitshop.ru | customer | Fitshop123! |

## Роли

- **customer** — каталог, оформление заказа с расчётом цены, «Мои заказы»
- **manager** — CRUD каталога, клиенты, акции, экран «Сборка» (статусы заказов)
- **admin** — пользователи, аналитика, физическое удаление / восстановление

## Доменная особенность (п. 20)

`OrderPricingEngine` — расчёт стоимости заказа с учётом акций, уровня лояльности и бесплатной доставки от 5000 ₽.

## Тесты

```powershell
flutter test
flutter analyze
```

## Сборка и публикация

```powershell
flutter build web --release --base-href /fitshop_web/ --dart-define=API_BASE_URL=https://YOUR-PB-HOST
cp build/web/index.html build/web/404.html
```

CI: `.github/workflows/deploy.yml` (нужен secret `API_BASE_URL` с публичным адресом PocketBase).
