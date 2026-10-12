-- FitShop / PocketBase — логическая схема БД (экспорт для сдачи)
-- Реальная СУБД: SQLite (PocketBase). Коллекции = таблицы.
-- Автополя PocketBase: id (TEXT PK), created, updated.

PRAGMA foreign_keys = ON;

-- ========== users (auth collection) ==========
-- role: customer | manager | admin
-- customer: relation → customers

CREATE TABLE IF NOT EXISTS users (
  id              TEXT PRIMARY KEY,
  email           TEXT NOT NULL UNIQUE,
  emailVisibility INTEGER DEFAULT 0,
  verified        INTEGER DEFAULT 0,
  name            TEXT,
  role            TEXT CHECK (role IN ('customer', 'manager', 'admin')),
  customer        TEXT, -- FK customers.id
  created         TEXT,
  updated         TEXT
);

-- ========== categories ==========
CREATE TABLE IF NOT EXISTS categories (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  description TEXT,
  deleted     TEXT, -- soft-delete (datetime) или NULL
  created     TEXT,
  updated     TEXT
);

-- ========== brands ==========
CREATE TABLE IF NOT EXISTS brands (
  id       TEXT PRIMARY KEY,
  name     TEXT NOT NULL,
  country  TEXT,
  deleted  TEXT,
  created  TEXT,
  updated  TEXT
);

-- ========== suppliers ==========
CREATE TABLE IF NOT EXISTS suppliers (
  id       TEXT PRIMARY KEY,
  name     TEXT NOT NULL,
  contact  TEXT,
  phone    TEXT,
  email    TEXT,
  deleted  TEXT,
  created  TEXT,
  updated  TEXT
);

-- ========== products ==========
CREATE TABLE IF NOT EXISTS products (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  price       REAL NOT NULL,
  stock       INTEGER NOT NULL,
  description TEXT,
  brand       TEXT, -- FK brands.id
  supplier    TEXT, -- FK suppliers.id
  -- categories: many-to-many через junction / multi-relation PB
  deleted     TEXT,
  created     TEXT,
  updated     TEXT,
  FOREIGN KEY (brand) REFERENCES brands(id),
  FOREIGN KEY (supplier) REFERENCES suppliers(id)
);

-- products ↔ categories (многие ко многим)
CREATE TABLE IF NOT EXISTS products_categories (
  product_id  TEXT NOT NULL,
  category_id TEXT NOT NULL,
  PRIMARY KEY (product_id, category_id),
  FOREIGN KEY (product_id) REFERENCES products(id),
  FOREIGN KEY (category_id) REFERENCES categories(id)
);

-- ========== customers ==========
CREATE TABLE IF NOT EXISTS customers (
  id        TEXT PRIMARY KEY,
  full_name TEXT NOT NULL,
  phone     TEXT,
  email     TEXT,
  user      TEXT, -- FK users.id
  deleted   TEXT,
  created   TEXT,
  updated   TEXT,
  FOREIGN KEY (user) REFERENCES users(id)
);

-- ========== loyalty_cards (1:1 с customers) ==========
CREATE TABLE IF NOT EXISTS loyalty_cards (
  id        TEXT PRIMARY KEY,
  customer  TEXT NOT NULL UNIQUE,
  tier      TEXT CHECK (tier IN ('bronze', 'silver', 'gold')),
  points    INTEGER DEFAULT 0,
  deleted   TEXT,
  created   TEXT,
  updated   TEXT,
  FOREIGN KEY (customer) REFERENCES customers(id)
);

-- ========== promotions ==========
CREATE TABLE IF NOT EXISTS promotions (
  id               TEXT PRIMARY KEY,
  name             TEXT NOT NULL,
  discount_percent REAL NOT NULL,
  active           INTEGER DEFAULT 1,
  start_date       TEXT,
  end_date         TEXT,
  deleted          TEXT,
  created          TEXT,
  updated          TEXT
);

-- promotions ↔ products (многие ко многим)
CREATE TABLE IF NOT EXISTS promotions_products (
  promotion_id TEXT NOT NULL,
  product_id   TEXT NOT NULL,
  PRIMARY KEY (promotion_id, product_id),
  FOREIGN KEY (promotion_id) REFERENCES promotions(id),
  FOREIGN KEY (product_id) REFERENCES products(id)
);

-- ========== orders ==========
CREATE TABLE IF NOT EXISTS orders (
  id        TEXT PRIMARY KEY,
  customer  TEXT NOT NULL,
  status    TEXT NOT NULL CHECK (
              status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled')
            ),
  subtotal  REAL,
  discount  REAL,
  shipping  REAL,
  total     REAL,
  deleted   TEXT,
  created   TEXT,
  updated   TEXT,
  FOREIGN KEY (customer) REFERENCES customers(id)
);

-- ========== order_items ==========
CREATE TABLE IF NOT EXISTS order_items (
  id         TEXT PRIMARY KEY,
  "order"    TEXT NOT NULL,
  product    TEXT NOT NULL,
  quantity   INTEGER NOT NULL,
  unit_price REAL NOT NULL,
  line_total REAL NOT NULL,
  deleted    TEXT,
  created    TEXT,
  updated    TEXT,
  FOREIGN KEY ("order") REFERENCES orders(id),
  FOREIGN KEY (product) REFERENCES products(id)
);

-- ========== reviews ==========
CREATE TABLE IF NOT EXISTS reviews (
  id        TEXT PRIMARY KEY,
  product   TEXT NOT NULL,
  customer  TEXT NOT NULL,
  rating    INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment   TEXT,
  deleted   TEXT,
  created   TEXT,
  updated   TEXT,
  FOREIGN KEY (product) REFERENCES products(id),
  FOREIGN KEY (customer) REFERENCES customers(id)
);

-- Индексы (учебные)
CREATE INDEX IF NOT EXISTS idx_products_brand ON products(brand);
CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items("order");
CREATE INDEX IF NOT EXISTS idx_reviews_product ON reviews(product);
