/**
 * Инициализация коллекций и тестовых данных FitShop.
 * Запуск: node setup.mjs
 * Перед этим: .\pocketbase.exe serve
 */
const BASE = process.env.PB_URL || 'http://127.0.0.1:8090';
const ADMIN_EMAIL = process.env.PB_ADMIN_EMAIL || 'admin@fitshop.local';
const ADMIN_PASS = process.env.PB_ADMIN_PASS || 'FitshopAdmin123!';

async function req(path, { method = 'GET', body, token } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = token;
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  if (!res.ok) {
    const err = new Error(`${method} ${path} → ${res.status}: ${text}`);
    err.status = res.status;
    err.data = data;
    throw err;
  }
  return data;
}

async function ensureAdmin() {
  try {
    const auth = await req('/api/collections/_superusers/auth-with-password', {
      method: 'POST',
      body: { identity: ADMIN_EMAIL, password: ADMIN_PASS },
    });
    return auth.token;
  } catch {
    await req('/api/collections/_superusers/records', {
      method: 'POST',
      body: {
        email: ADMIN_EMAIL,
        password: ADMIN_PASS,
        passwordConfirm: ADMIN_PASS,
      },
    });
    const auth = await req('/api/collections/_superusers/auth-with-password', {
      method: 'POST',
      body: { identity: ADMIN_EMAIL, password: ADMIN_PASS },
    });
    return auth.token;
  }
}

function textField(name, opts = {}) {
  return {
    name,
    type: 'text',
    required: !!opts.required,
    max: opts.max || 0,
  };
}

function numberField(name, opts = {}) {
  return {
    name,
    type: 'number',
    required: !!opts.required,
    min: opts.min,
    max: opts.max,
  };
}

function boolField(name) {
  return { name, type: 'bool' };
}

function dateField(name) {
  return { name, type: 'date' };
}

function emailField(name) {
  return { name, type: 'email' };
}

function selectField(name, values, opts = {}) {
  return {
    name,
    type: 'select',
    required: !!opts.required,
    maxSelect: 1,
    values,
  };
}

function relationField(name, collectionId, opts = {}) {
  return {
    name,
    type: 'relation',
    required: !!opts.required,
    collectionId,
    maxSelect: opts.maxSelect ?? 1,
    cascadeDelete: false,
  };
}

async function upsertCollection(token, body) {
  try {
    const existing = await req(`/api/collections/${body.name}`, { token });
    await req(`/api/collections/${existing.id}`, {
      method: 'PATCH',
      token,
      body: { ...body, id: existing.id },
    });
    console.log('updated', body.name);
    return (await req(`/api/collections/${body.name}`, { token })).id;
  } catch (e) {
    if (e.status !== 404) throw e;
    const created = await req('/api/collections', {
      method: 'POST',
      token,
      body,
    });
    console.log('created', body.name);
    return created.id;
  }
}

async function setRules(token, name, rules) {
  const col = await req(`/api/collections/${name}`, { token });
  await req(`/api/collections/${col.id}`, {
    method: 'PATCH',
    token,
    body: {
      listRule: rules.list,
      viewRule: rules.view,
      createRule: rules.create,
      updateRule: rules.update,
      deleteRule: rules.delete,
    },
  });
}

async function main() {
  console.log('FitShop PocketBase setup →', BASE);
  const token = await ensureAdmin();
  console.log('admin ok');

  const catId = await upsertCollection(token, {
    name: 'categories',
    type: 'base',
    fields: [
      textField('name', { required: true }),
      textField('description'),
      dateField('deleted'),
    ],
  });

  const brandId = await upsertCollection(token, {
    name: 'brands',
    type: 'base',
    fields: [
      textField('name', { required: true }),
      textField('country'),
      dateField('deleted'),
    ],
  });

  const supplierId = await upsertCollection(token, {
    name: 'suppliers',
    type: 'base',
    fields: [
      textField('name', { required: true }),
      textField('contact'),
      textField('phone'),
      dateField('deleted'),
    ],
  });

  const productId = await upsertCollection(token, {
    name: 'products',
    type: 'base',
    fields: [
      textField('name', { required: true }),
      numberField('price', { required: true, min: 0 }),
      numberField('stock', { required: true, min: 0 }),
      textField('description'),
      relationField('brand', brandId),
      relationField('supplier', supplierId),
      relationField('categories', catId, { maxSelect: 50 }),
      dateField('deleted'),
    ],
  });

  // users collection id
  const users = await req('/api/collections/users', { token });
  const usersId = users.id;

  // ensure role + customer on users
  const userFields = users.fields || users.schema || [];
  const hasRole = userFields.some((f) => f.name === 'role');
  const patchFields = [...userFields];
  if (!hasRole) {
    patchFields.push(selectField('role', ['customer', 'manager', 'admin']));
  }
  // customer relation added after customers collection

  const customerId = await upsertCollection(token, {
    name: 'customers',
    type: 'base',
    fields: [
      textField('full_name', { required: true }),
      textField('phone'),
      emailField('email'),
      relationField('user', usersId),
      dateField('deleted'),
    ],
  });

  if (!userFields.some((f) => f.name === 'customer')) {
    patchFields.push(relationField('customer', customerId));
  }
  if (!hasRole || !userFields.some((f) => f.name === 'customer')) {
    await req(`/api/collections/${usersId}`, {
      method: 'PATCH',
      token,
      body: { fields: patchFields },
    });
    console.log('updated users fields');
  }

  await upsertCollection(token, {
    name: 'loyalty_cards',
    type: 'base',
    fields: [
      relationField('customer', customerId, { required: true }),
      selectField('tier', ['bronze', 'silver', 'gold'], { required: true }),
      numberField('points', { min: 0 }),
      dateField('deleted'),
    ],
    indexes: ['CREATE UNIQUE INDEX idx_loyalty_customer ON loyalty_cards (customer)'],
  });

  await upsertCollection(token, {
    name: 'promotions',
    type: 'base',
    fields: [
      textField('name', { required: true }),
      numberField('discount_percent', { required: true, min: 0, max: 100 }),
      boolField('active'),
      dateField('start_date'),
      dateField('end_date'),
      relationField('products', productId, { maxSelect: 200 }),
      dateField('deleted'),
    ],
  });

  const orderId = await upsertCollection(token, {
    name: 'orders',
    type: 'base',
    fields: [
      relationField('customer', customerId, { required: true }),
      selectField(
        'status',
        ['pending', 'processing', 'shipped', 'delivered', 'cancelled'],
        { required: true },
      ),
      numberField('subtotal'),
      numberField('discount'),
      numberField('shipping'),
      numberField('total'),
      dateField('deleted'),
    ],
  });

  await upsertCollection(token, {
    name: 'order_items',
    type: 'base',
    fields: [
      relationField('order', orderId, { required: true }),
      relationField('product', productId, { required: true }),
      numberField('quantity', { required: true, min: 1 }),
      numberField('unit_price', { required: true, min: 0 }),
      numberField('line_total', { required: true, min: 0 }),
      dateField('deleted'),
    ],
  });

  await upsertCollection(token, {
    name: 'reviews',
    type: 'base',
    fields: [
      relationField('product', productId, { required: true }),
      relationField('customer', customerId, { required: true }),
      numberField('rating', { required: true, min: 1, max: 5 }),
      textField('comment'),
      dateField('deleted'),
    ],
  });

  // API rules
  const staff = '@request.auth.id != "" && (@request.auth.role = "manager" || @request.auth.role = "admin")';
  const admin = '@request.auth.role = "admin"';
  const auth = '@request.auth.id != ""';

  const openReadStaffWrite = {
    list: '',
    view: '',
    create: staff,
    update: staff,
    delete: admin,
  };

  for (const name of [
    'categories',
    'brands',
    'suppliers',
    'products',
    'promotions',
  ]) {
    await setRules(token, name, openReadStaffWrite);
  }

  await setRules(token, 'customers', {
    list: `${staff} || user = @request.auth.id`,
    view: `${staff} || user = @request.auth.id`,
    create: auth,
    update: `${staff} || user = @request.auth.id`,
    delete: admin,
  });

  await setRules(token, 'loyalty_cards', {
    list: `${staff} || @request.auth.customer = customer`,
    view: `${staff} || @request.auth.customer = customer`,
    create: staff,
    update: staff,
    delete: admin,
  });

  await setRules(token, 'orders', {
    list: `${staff} || @request.auth.customer = customer`,
    view: `${staff} || @request.auth.customer = customer`,
    create: auth,
    update: staff,
    delete: admin,
  });

  await setRules(token, 'order_items', {
    list: auth,
    view: auth,
    create: auth,
    update: staff,
    delete: admin,
  });

  await setRules(token, 'reviews', {
    list: '',
    view: '',
    create: auth,
    update: `${staff} || @request.auth.customer = customer`,
    delete: admin,
  });

  // Seed if empty
  const existingProducts = await req(
    '/api/collections/products/records?perPage=1',
    { token },
  );
  if (existingProducts.totalItems > 0) {
    console.log('seed skipped (data exists)');
  } else {
    await seed(token);
  }

  await ensureDemoUsers(token);
  console.log('DONE');
}

async function createRecord(token, collection, body) {
  return req(`/api/collections/${collection}/records`, {
    method: 'POST',
    token,
    body,
  });
}

async function seed(token) {
  console.log('seeding...');
  const cats = [];
  for (const name of [
    'Протеин',
    'Креатин',
    'Витамины',
    'Аксессуары',
    'Напитки',
  ]) {
    cats.push(await createRecord(token, 'categories', { name }));
  }

  const brands = [];
  for (const [name, country] of [
    ['Optimum Nutrition', 'USA'],
    ['MyProtein', 'UK'],
    ['Scitec', 'HU'],
    ['Bombbar', 'RU'],
  ]) {
    brands.push(await createRecord(token, 'brands', { name, country }));
  }

  const suppliers = [];
  for (const [name, contact, phone] of [
    ['СпортОпт', 'Иванов', '+79001112233'],
    ['FitWholesale', 'Petrov', '+79005556677'],
    ['NutriSupply', 'Sidorova', '+79008889900'],
  ]) {
    suppliers.push(
      await createRecord(token, 'suppliers', { name, contact, phone }),
    );
  }

  const productNames = [
    ['Whey Gold 2kg', 4590, 40],
    ['Creatine Monohydrate 500g', 1890, 80],
    ['BCAA 2:1:1', 2100, 55],
    ['Omega-3 90 caps', 990, 120],
    ['Shaker Pro 700ml', 650, 200],
    ['Pre-Workout Ignite', 2490, 35],
    ['Casein Night', 3290, 25],
    ['Vitamin D3', 790, 150],
    ['Resistance Band Set', 1190, 60],
    ['Gym Gloves', 890, 70],
    ['Iso Whey Zero', 5190, 30],
    ['Mass Gainer 5kg', 5890, 18],
    ['Electrolyte Drink', 490, 90],
    ['Protein Bar Box', 1590, 45],
    ['Collagen Peptides', 2290, 40],
    ['L-Carnitine Liquid', 1390, 50],
    ['Yoga Mat', 1790, 33],
    ['Foam Roller', 1490, 28],
    ['Multivitamin Men', 1090, 65],
    ['ZMA Caps', 1290, 42],
    ['Hydro Whey', 6290, 22],
    ['Creatine HCl', 1990, 38],
  ];

  const products = [];
  for (let i = 0; i < productNames.length; i++) {
    const [name, price, stock] = productNames[i];
    products.push(
      await createRecord(token, 'products', {
        name,
        price,
        stock,
        description: `${name} — фитнес-продукция`,
        brand: brands[i % brands.length].id,
        supplier: suppliers[i % suppliers.length].id,
        categories: [cats[i % cats.length].id, cats[(i + 1) % cats.length].id],
      }),
    );
  }

  await createRecord(token, 'promotions', {
    name: 'Весенняя скидка на протеин',
    discount_percent: 15,
    active: true,
    start_date: '2026-01-01 00:00:00.000Z',
    end_date: '2026-12-31 23:59:59.000Z',
    products: products.slice(0, 5).map((p) => p.id),
  });

  console.log('seeded', products.length, 'products');
}

async function ensureDemoUsers(token) {
  const demos = [
    {
      email: 'admin@fitshop.ru',
      password: 'Fitshop123!',
      name: 'Администратор',
      role: 'admin',
    },
    {
      email: 'manager@fitshop.ru',
      password: 'Fitshop123!',
      name: 'Менеджер магазина',
      role: 'manager',
    },
    {
      email: 'customer@fitshop.ru',
      password: 'Fitshop123!',
      name: 'Иван Покупатель',
      role: 'customer',
      withCustomer: true,
    },
  ];

  for (const d of demos) {
    const found = await req(
      `/api/collections/users/records?filter=${encodeURIComponent(`email="${d.email}"`)}`,
      { token },
    );
    let user;
    if (found.items?.length) {
      user = found.items[0];
      await req(`/api/collections/users/records/${user.id}`, {
        method: 'PATCH',
        token,
        body: { name: d.name, role: d.role, password: d.password, passwordConfirm: d.password },
      });
    } else {
      user = await createRecord(token, 'users', {
        email: d.email,
        password: d.password,
        passwordConfirm: d.password,
        name: d.name,
        role: d.role,
        emailVisibility: true,
      });
    }

    if (d.withCustomer) {
      const custFound = await req(
        `/api/collections/customers/records?filter=${encodeURIComponent(`email="${d.email}"`)}`,
        { token },
      );
      let customer;
      if (custFound.items?.length) {
        customer = custFound.items[0];
      } else {
        customer = await createRecord(token, 'customers', {
          full_name: d.name,
          email: d.email,
          phone: '+79001234567',
          user: user.id,
        });
        await createRecord(token, 'loyalty_cards', {
          customer: customer.id,
          tier: 'gold',
          points: 1200,
        });
      }
      await req(`/api/collections/users/records/${user.id}`, {
        method: 'PATCH',
        token,
        body: { customer: customer.id },
      });
    }
    console.log('user', d.email, d.role);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
