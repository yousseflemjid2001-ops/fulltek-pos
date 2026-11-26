const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const singletonTmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'fulltek-qr-singleton-'));
process.env.DB_PATH = path.join(singletonTmpDir, 'singleton.db');
delete process.env.DATABASE_URL;

const { db: singletonDb } = require('../src/db');
const { signJwt } = require('../src/auth');
const { startServer } = require('../src/server');

test.after(() => {
  try {
    singletonDb.close();
  } catch {}
  fs.rmSync(singletonTmpDir, { recursive: true, force: true, maxRetries: 10, retryDelay: 50 });
});

test('QR Menu Public Web App, Online Order, Waiter Call & POS Incoming Flow', async (t) => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'fulltek-qr-'));
  const dbPath = path.join(tmpDir, 'test.db');
  const { server, db, close } = await startServer({ port: 0, host: '127.0.0.1', dbPath, quiet: true });
  const { port } = server.address();
  const baseUrl = `http://127.0.0.1:${port}`;

  t.after(async () => {
    await close();
    fs.rmSync(tmpDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 50 });
  });

  // 1. Seed a test resto tenant, category & product in the isolated test DB
  const nowIso = new Date().toISOString();
  const insTenant = db.prepare(`
    INSERT INTO tenants (tenant_code, name, module, city, phone, username, password_hash, status, created_at)
    VALUES ('TNT-QR1', 'Restaurant Test QR', 'resto', 'Nouakchott', '+222 45 00 00 00', 'qrtest', 'hash', 'active', ?)
  `).run(nowIso);
  const tenantId = Number(insTenant.lastInsertRowid);
  const insCat = db.prepare(`
    INSERT INTO categories (tenant_id, name_fr, name_ar, name_en, icon, sort_order, active, created_at)
    VALUES (?, 'Grillades', 'مشويات', 'Grills', '🔥', 1, 1, ?)
  `).run(tenantId, nowIso);
  const catId = Number(insCat.lastInsertRowid);
  db.prepare(`
    INSERT INTO products (tenant_id, category_id, sku, name_fr, name_ar, name_en, price_retail, kitchen_station, is_out_of_stock, active, created_at)
    VALUES (?, ?, 'SKU-CHW', 'Sandwich Chawarma', 'ساندويتش شاورما', 'Shawarma', 150, 'GRILL', 0, 1, ?)
  `).run(tenantId, catId, nowIso);

  const tenant = { id: tenantId, tenantCode: 'TNT-QR1' };
  const token = signJwt({ tenantId, tenantCode: 'TNT-QR1', module: 'resto', role: 'OWNER' });
  assert.ok(token);
  assert.ok(tenant.tenantCode);

  // 2. Public HTML Mobile Menu (/m/:tenantCode?table=T1)
  const htmlRes = await fetch(`${baseUrl}/m/${tenant.tenantCode}?table=T1`);
  assert.equal(htmlRes.status, 200);
  const html = await htmlRes.text();
  assert.match(html, /Table : T1/);
  assert.match(html, /Menu QR/);

  // 3. Public JSON Menu (/public/menu/:tenantCode)
  const menuRes = await fetch(`${baseUrl}/public/menu/${tenant.tenantCode}`);
  assert.equal(menuRes.status, 200);
  const menuData = await menuRes.json();
  assert.ok(menuData.products.length > 0);
  const firstProd = menuData.products.find((p) => p.available);
  assert.ok(firstProd);

  // 4. Customer places QR Table order
  const orderRes = await fetch(`${baseUrl}/public/orders/${tenant.tenantCode}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      serviceMode: 'dine_in',
      tableName: 'T1',
      notes: 'Bien chaud',
      items: [{ productId: firstProd.id, qty: 2 }],
    }),
  });
  assert.equal(orderRes.status, 201);
  const created = await orderRes.json();
  assert.equal(created.ok, true);
  assert.equal(created.status, 'QR_PENDING');
  assert.equal(created.totalMru, firstProd.priceMru * 2);

  // 5. Customer calls waiter
  const callRes = await fetch(`${baseUrl}/public/call-waiter/${tenant.tenantCode}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ tableName: 'T1', kind: 'bill' }),
  });
  assert.equal(callRes.status, 201);
  const alertCreated = await callRes.json();
  assert.equal(alertCreated.ok, true);

  // 6. POS fetches incoming QR orders + alerts
  const incRes = await fetch(`${baseUrl}/api/pos/qr/incoming`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(incRes.status, 200);
  const inc = await incRes.json();
  assert.equal(inc.orders.length, 1);
  assert.equal(inc.orders[0].orderCode, created.orderCode);
  assert.equal(inc.alerts.length, 1);
  assert.equal(inc.alerts[0].kind, 'bill');

  // 7. POS accepts order + acks alert
  const accRes = await fetch(
    `${baseUrl}/api/pos/qr/orders/${created.orderCode}/accept`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    }
  );
  assert.equal(accRes.status, 200);

  const ackRes = await fetch(
    `${baseUrl}/api/pos/qr/alerts/${alertCreated.id}/ack`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    }
  );
  assert.equal(ackRes.status, 200);

  // 8. Customer tracks updated status -> OPEN -> KDS_PREP -> READY -> PAID
  const trackRes = await fetch(
    `${baseUrl}/public/orders/${tenant.tenantCode}/${created.orderCode}`
  );
  assert.equal(trackRes.status, 200);
  const tracked = await trackRes.json();
  assert.equal(tracked.status, 'OPEN');

  for (const nextStatus of ['KDS_PREP', 'READY', 'PAID']) {
    const stRes = await fetch(
      `${baseUrl}/api/pos/qr/orders/${created.orderCode}/status`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ status: nextStatus }),
      }
    );
    assert.equal(stRes.status, 200);
    const tr = await (
      await fetch(`${baseUrl}/public/orders/${tenant.tenantCode}/${created.orderCode}`)
    ).json();
    assert.equal(tr.status, nextStatus);
  }

  // 8b. Customer places Delivery order with GPS Geolocation sharing (lat/lng)
  const delivRes = await fetch(`${baseUrl}/public/orders/${tenant.tenantCode}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      serviceMode: 'delivery',
      customerName: 'Sidi GPS',
      customerPhone: '46112233',
      deliveryZone: 'Tevragh Zeina',
      deliveryAddress: 'Près Pharmacie',
      deliveryLat: 18.094512,
      deliveryLng: -15.978421,
      items: [{ productId: firstProd.id, qty: 1 }],
    }),
  });
  assert.equal(delivRes.status, 201);
  const delivCreated = await delivRes.json();
  const incDeliv = await (
    await fetch(`${baseUrl}/api/pos/qr/incoming`, {
      headers: { Authorization: `Bearer ${token}` },
    })
  ).json();
  const foundDeliv = incDeliv.orders.find((o) => o.orderCode === delivCreated.orderCode);
  assert.ok(foundDeliv);
  assert.equal(foundDeliv.gpsUrl, 'https://maps.google.com/?q=18.094512,-15.978421');
  assert.match(foundDeliv.deliveryAddress, /https:\/\/maps\.google\.com\/\?q=18\.094512,-15\.978421/);

  // 9. POS toggles allowOrdering = false -> public order returns 403
  const setRes = await fetch(`${baseUrl}/api/pos/qr/settings`, {
    method: 'PUT',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ allowOrdering: false }),
  });
  assert.equal(setRes.status, 200);
  const blockedRes = await fetch(`${baseUrl}/public/orders/${tenant.tenantCode}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      serviceMode: 'takeaway',
      items: [{ productId: firstProd.id, qty: 1 }],
    }),
  });
  assert.equal(blockedRes.status, 403);
});
