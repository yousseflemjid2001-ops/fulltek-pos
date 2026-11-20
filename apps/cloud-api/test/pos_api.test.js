const { describe, it, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const http = require('node:http');

// Isolate module-load singleton DB away from apps/cloud-api/data/fulltek.db
const singletonTmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'fulltek-pos-singleton-'));
process.env.DB_PATH = path.join(singletonTmpDir, 'singleton.db');

const { db: singletonDb, createDb } = require('../src/db');
const { signJwt } = require('../src/auth');
const { startServer } = require('../src/server');

after(() => {
  try {
    singletonDb.close();
  } catch {
    // ignore
  }
  fs.rmSync(singletonTmpDir, { recursive: true, force: true, maxRetries: 10, retryDelay: 50 });
});

function httpRequest(baseUrl, reqPath, options = {}) {
  return new Promise((resolve, reject) => {
    const target = new URL(reqPath, baseUrl);
    const method = options.method || 'GET';
    const headers = { ...(options.headers || {}) };
    let bodyBuf = null;

    if (options.json !== undefined) {
      bodyBuf = Buffer.from(JSON.stringify(options.json), 'utf8');
      if (!headers['Content-Type'] && !headers['content-type']) {
        headers['Content-Type'] = 'application/json; charset=utf-8';
      }
    } else if (Buffer.isBuffer(options.body)) {
      bodyBuf = options.body;
    } else if (typeof options.body === 'string') {
      bodyBuf = Buffer.from(options.body, 'utf8');
    }

    if (bodyBuf !== null) {
      headers['Content-Length'] = String(bodyBuf.length);
    }

    const req = http.request(
      target,
      { method, headers, agent: false },
      (res) => {
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => {
          const raw = Buffer.concat(chunks);
          const text = raw.toString('utf8');
          let json = null;
          try {
            json = text ? JSON.parse(text) : null;
          } catch {
            json = null;
          }
          resolve({ status: res.statusCode, headers: res.headers, raw, text, json });
        });
      },
    );

    req.on('error', reject);
    if (bodyBuf !== null) req.write(bodyBuf);
    req.end();
  });
}

async function withIsolatedServer(opts, fn) {
  if (typeof opts === 'function') {
    fn = opts;
    opts = {};
  }
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'fulltek-pos-srv-'));
  const dbPath = path.join(tmpDir, 'test.db');
  const jwtSecret = opts.jwtSecret || 'test-jwt-secret-pos';
  const srv = await startServer({
    port: 0,
    host: '127.0.0.1',
    dbPath,
    jwtSecret,
    quiet: true,
  });

  const request = (reqPath, reqOpts) => httpRequest(srv.url, reqPath, reqOpts);

  try {
    return await fn({ ...srv, dbPath, jwtSecret, tmpDir, request });
  } finally {
    await srv.close();
    fs.rmSync(tmpDir, { recursive: true, force: true, maxRetries: 10, retryDelay: 50 });
  }
}

async function loginTenant(request, username, password = 'FullTek@2026') {
  const res = await request('/api/auth/login', {
    method: 'POST',
    json: { username, password },
  });
  assert.equal(res.status, 200, res.text);
  return res.json;
}

async function loginAdmin(request) {
  const res = await request('/api/admin/login', {
    method: 'POST',
    json: { username: 'taha', password: 'FullTekAdmin@2026' },
  });
  assert.equal(res.status, 200, res.text);
  return res.json.token;
}

function parsePrismaModels(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  let depth = 0;
  let balanced = true;
  for (let i = 0; i < raw.length; i++) {
    if (raw[i] === '{') depth++;
    else if (raw[i] === '}') {
      depth--;
      if (depth < 0) {
        balanced = false;
        break;
      }
    }
  }
  if (depth !== 0) balanced = false;

  const dsMatch = raw.match(/datasource\s+\w+\s*\{([\s\S]*?)\}/);
  const providerMatch = dsMatch ? dsMatch[1].match(/provider\s*=\s*"([^"]+)"/) : null;
  const models = new Map();
  const modelRe = /model\s+(\w+)\s*\{([\s\S]*?)\}/g;
  let m;
  while ((m = modelRe.exec(raw)) !== null) {
    const fields = [];
    for (const rawLine of m[2].split(/\r?\n/)) {
      const line = rawLine.replace(/\/\/.*$/, '').trim();
      if (!line || line.startsWith('@@')) continue;
      const fm = line.match(/^(\w+)\s+(.+)$/);
      if (fm) fields.push(fm[1]);
    }
    models.set(m[1], fields);
  }
  return { provider: providerMatch ? providerMatch[1] : null, balanced, models };
}

describe('POS Suite 1 — Auth, GET /api/pos/catalog, Multi-Tenant Isolation & Extended Import', () => {
  it('POST /api/auth/login returns 5 themes (incl. 04), 7 pay methods, and 4 delivery zones for FT-1041', async () => {
    await withIsolatedServer(async ({ request }) => {
      const bad = await request('/api/auth/login', {
        method: 'POST',
        json: { username: 'darelkram41', password: 'WrongPassword' },
      });
      assert.equal(bad.status, 401);

      const data = await loginTenant(request, 'darelkram41');
      assert.ok(data.token);
      assert.equal(data.tenant.tenantId, 'FT-1041');
      assert.equal(data.tenant.ownerPin, '7410');
      assert.deepEqual(data.tenant.enabledThemes, ['01', '04', '06', '07', '11']);
      for (const pm of ['Cash', 'Bankily', 'Masrivi', 'Sedad', 'Bimbank', 'Click', 'Karni']) {
        assert.ok(data.tenant.payMethods.includes(pm), `Missing payMethod ${pm}`);
      }
      assert.equal(data.tenant.deliveryZones.length, 4);
      assert.equal(data.tenant.freeDeliveryAboveMru, 1500);
    });
  });

  it('enforces requireTenantAuth (401/403) across all /api/pos/* routes', async () => {
    await withIsolatedServer(async ({ request, db, jwtSecret }) => {
      const { token: ftToken, tenant } = await loginTenant(request, 'darelkram41');
      const adminToken = await loginAdmin(request);

      const expiredJwt = signJwt({ tenantId: tenant.id, role: 'OWNER' }, -60, jwtSecret);
      const wrongSecretJwt = signJwt({ tenantId: tenant.id, role: 'OWNER' }, 3600, 'wrong-secret');
      const ghostTenantJwt = signJwt({ tenantId: 999999, role: 'OWNER' }, 3600, jwtSecret);

      const badHeaders = [
        {},
        { Authorization: 'Basic abc' },
        { Authorization: 'Bearer not.a.jwt' },
        { Authorization: `Bearer ${expiredJwt}` },
        { Authorization: `Bearer ${wrongSecretJwt}` },
        { Authorization: `Bearer ${adminToken}` },
        { Authorization: `Bearer ${ghostTenantJwt}` },
      ];

      const posRoutes = [
        ['GET', '/api/pos/catalog'],
        ['POST', '/api/pos/sync'],
        ['PATCH', '/api/pos/products/1/availability'],
        ['GET', '/api/pos/kds'],
        ['PATCH', '/api/pos/kds/1'],
        ['GET', '/api/pos/kpis'],
      ];

      for (const [method, route] of posRoutes) {
        for (const headers of badHeaders) {
          const r = await request(route, { method, headers, json: {} });
          assert.equal(r.status, 401, `Expected 401 for ${method} ${route} with ${JSON.stringify(headers)}`);
        }
      }

      // Locked tenant -> 403 on all /api/pos/* routes
      db.prepare("UPDATE tenants SET status = 'locked' WHERE id = ?").run(tenant.id);
      for (const [method, route] of posRoutes) {
        const r = await request(route, {
          method,
          headers: { Authorization: `Bearer ${ftToken}` },
          json: {},
        });
        assert.equal(r.status, 403, `Expected 403 for locked tenant on ${method} ${route}`);
      }
    });
  });

  it('GET /api/pos/catalog returns rich FT-1041 data and isolates FT-2088', async () => {
    await withIsolatedServer(async ({ request }) => {
      const ft1041 = await loginTenant(request, 'darelkram41');
      const cat1 = await request('/api/pos/catalog', {
        headers: { Authorization: `Bearer ${ft1041.token}` },
      });
      assert.equal(cat1.status, 200);
      assert.equal(cat1.json.ok, true);
      assert.equal(cat1.json.tenant.code, 'FT-1041');
      assert.deepEqual(cat1.json.tenant.enabledThemes, ['01', '04', '06', '07', '11']);
      assert.equal(cat1.json.tenant.deliveryZones.length, 4);
      assert.equal(cat1.json.tenant.freeDeliveryAboveMru, 1500);

      // 5 categories (non-colliding with E2E T1-CAT-01)
      assert.equal(cat1.json.categories.length, 5);
      for (const c of cat1.json.categories) {
        assert.ok(c.icon, `Category ${c.nameFr} missing icon`);
        assert.ok(!['Grillades', 'Boissons', 'Fast-Food'].includes(c.nameFr));
      }

      // 19 products (non-colliding with RST-001..003)
      assert.equal(cat1.json.products.length, 19);
      const burger = cat1.json.products.find((p) => p.sku === 'RST-BRG-01');
      assert.ok(burger);
      assert.equal(burger.kitchenStation, 'GRILL');
      assert.equal(burger.available, true);
      assert.equal(burger.isOutOfStock, false);
      assert.ok(Array.isArray(burger.modifiers) && burger.modifiers.length >= 2);
      const mechoui = cat1.json.products.find((p) => p.sku === 'RIM-002');
      assert.equal(mechoui.isTop, true);
      for (const sku of ['RST-001', 'RST-002', 'RST-003']) {
        assert.equal(cat1.json.products.some((p) => p.sku === sku), false);
      }

      // 3 2D dining zones + Khaima VIP + reservations
      assert.equal(cat1.json.diningZones.length, 3);
      const vip = cat1.json.diningZones.find((z) => z.isVip);
      assert.ok(vip);
      assert.equal(vip.zoneType, 'KHAIMA_VIP');
      assert.ok(vip.tables.some((t) => t.shape === 'khaima' && typeof t.x === 'number'));
      assert.ok(cat1.json.reservationsVip.length >= 1);

      // 12 ingredients + BOM (ALL, TAKEAWAY_DELIVERY, modifier_key) + 3 karni customers
      assert.equal(cat1.json.ingredients.length, 12);
      assert.ok(cat1.json.recipesBom.some((b) => b.conditionChannel === 'TAKEAWAY_DELIVERY'));
      assert.ok(cat1.json.recipesBom.some((b) => b.modifierKey === 'opt-cheddar'));
      assert.equal(cat1.json.karniCustomers.length, 3);

      // Multi-tenant isolation: FT-2088 sees 0 FT-1041 items
      const ft2088 = await loginTenant(request, 'albaraka88');
      const cat2 = await request('/api/pos/catalog', {
        headers: { Authorization: `Bearer ${ft2088.token}` },
      });
      assert.equal(cat2.status, 200);
      assert.equal(cat2.json.tenant.code, 'FT-2088');
      assert.equal(cat2.json.products.length, 0);
      assert.equal(cat2.json.ingredients.length, 0);
      assert.equal(cat2.json.diningZones.length, 0);
      assert.equal(cat2.json.karniCustomers.length, 2);
    });
  });

  it('catalogImport supports icon, kitchen_station, is_top, is_out_of_stock, and modifiers_json', async () => {
    await withIsolatedServer(async ({ request }) => {
      const adminToken = await loginAdmin(request);
      const tRes = await request('/api/admin/tenants', {
        method: 'POST',
        headers: { Authorization: `Bearer ${adminToken}` },
        json: {
          name: 'Resto Import Ext',
          module: 'resto',
          phone: '+222 44 00 11 22',
          username: 'imp_ext_owner',
          accountPassword: 'Pass@123',
        },
      });
      assert.equal(tRes.status, 201);
      assert.deepEqual(tRes.json.enabledThemes, ['01', '04', '06', '07', '11']);
      assert.equal(tRes.json.payMethods.length, 7);

      const mods = [{ id: 'mg-1', nameFr: 'Sauce', options: [{ id: 'o1', nameFr: 'Harissa', extraPriceMru: 0 }] }];
      const impRes = await request(`/api/admin/tenants/${tRes.json.id}/catalog/import`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${adminToken}` },
        json: {
          rows: [
            {
              sku: 'IMP-GRL-1',
              name_fr: 'Brochette Spéciale',
              name_ar: 'أسياخ خاصة',
              category: 'Grillades',
              price_retail: 600,
              icon: '🍢',
              kitchen_station: 'grill',
              is_top: true,
              is_out_of_stock: false,
              modifiers_json: mods,
            },
          ],
        },
      });
      assert.equal(impRes.status, 200);
      assert.equal(impRes.json.created, 1);

      // Invalid kitchen_station rolls back cleanly with 400
      const badImp = await request(`/api/admin/tenants/${tRes.json.id}/catalog/import`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${adminToken}` },
        json: {
          rows: [{ sku: 'IMP-BAD', name_fr: 'Bad', price_retail: 100, kitchen_station: 'SPACE_STATION' }],
        },
      });
      assert.equal(badImp.status, 400);

      const { token } = await loginTenant(request, 'imp_ext_owner', 'Pass@123');
      const cat = await request('/api/pos/catalog', {
        headers: { Authorization: `Bearer ${token}` },
      });
      assert.equal(cat.status, 200);
      assert.equal(cat.json.products.length, 1);
      const p = cat.json.products[0];
      assert.equal(p.icon, '🍢');
      assert.equal(p.kitchenStation, 'GRILL');
      assert.equal(p.isTop, true);
      assert.equal(p.isOutOfStock, false);
      assert.deepEqual(p.modifiers, mods);
    });
  });
});

describe('POS Suite 2 — Transactional POST /api/pos/sync, Idempotency & Rollback', () => {
  it('validates items array and handles empty items: []', async () => {
    await withIsolatedServer(async ({ request }) => {
      const { token } = await loginTenant(request, 'darelkram41');
      const bad = await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: { items: 'not-array' },
      });
      assert.equal(bad.status, 400);

      const empty = await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: { items: [] },
      });
      assert.equal(empty.status, 200);
      assert.equal(empty.json.ok, true);
      assert.equal(empty.json.synced, 0);
    });
  });

  it('materializes Mixte/Bimbank/Click orders, TVA 16%, delivery metadata, idempotency, KDS_PREP->PAID & rollback', async () => {
    await withIsolatedServer(async ({ request, db }) => {
      const { token, tenant } = await loginTenant(request, 'darelkram41');
      const today = new Date().toISOString().slice(0, 10);

      // 1. Delivery Mixte order (Cash 700 incl. 90 change -> net 610 + Bankily 500 + Click 500 = 1610 total, TVA = round(1610*16/116) = 222)
      const sync1 = await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: {
          items: [
            {
              id: 'SYNC-ORD-1',
              entity_type: 'order',
              payload: {
                id: 'ORD-DEL-101',
                ticket_number: 'FT-101',
                serviceMode: 'delivery',
                deliveryZone: { id: 'zone-tz', nameFr: 'Tevragh Zeina', feeMru: 100 },
                customerName: 'Oumar Sy',
                customerPhone: '+222 44 55 66 77',
                deliveryAddress: 'Îlot K, Rue 12',
                staff_name: 'Aïcha',
                subtotal_mru: 1510,
                total_mru: 1610,
                status: 'paid',
                created_at: `${today}T12:00:00.000Z`,
                items: [
                  {
                    sku: 'GRL-001',
                    qty: 2,
                    unit_price: 755,
                    modifiers: [{ id: 'opt-mozzarella', nameFr: 'Supplément Mozzarella', bomKey: 'opt-mozzarella' }],
                    kitchen_note: 'Bien chaud',
                  },
                ],
                payments: [
                  { method: 'CASH', amount_mru: 700 },
                  { method: 'Bankily', amount_mru: 500 },
                  { method: 'Click', amount_mru: 500 },
                ],
              },
            },
            {
              id: 'SYNC-ORD-2',
              entity_type: 'order',
              payload: {
                orderCode: 'FT-102',
                service_mode: 'takeaway',
                status: 'PAID',
                created_at: `${today}T12:15:00.000Z`,
                items: [{ sku: 'DRK-001', qty: 2, unit_price: 150 }],
                payments: [{ method: 'Bimbank', amount_mru: 300 }],
              },
            },
          ],
        },
      });
      assert.equal(sync1.status, 200, sync1.text);
      assert.equal(sync1.json.synced, 2);

      const ord1 = db.prepare("SELECT * FROM orders WHERE tenant_id = ? AND order_code = 'FT-101'").get(tenant.id);
      assert.ok(ord1);
      assert.equal(ord1.service_mode, 'delivery');
      assert.equal(ord1.channel, 'DELIVERY');
      assert.equal(ord1.delivery_zone, 'Tevragh Zeina');
      assert.equal(ord1.delivery_fee_mru, 100);
      assert.equal(ord1.pay_method, 'Mixte');
      assert.equal(ord1.total_mru, 1610);
      assert.equal(ord1.tva_mru, 222);
      assert.equal(ord1.customer_name, 'Oumar Sy');
      assert.equal(ord1.is_training, 0);

      const ordItems1 = db.prepare('SELECT * FROM order_items WHERE order_id = ?').all(ord1.id);
      assert.equal(ordItems1.length, 1);
      assert.equal(ordItems1[0].kitchen_note, 'Bien chaud');
      assert.equal(ordItems1[0].kitchen_station, 'GRILL');
      assert.equal(ordItems1[0].kds_status, 'READY');

      // Audit logs created cleanly (details bug fixed)
      const audCount = db.prepare("SELECT COUNT(*) AS cnt FROM audit_logs WHERE tenant_id = ? AND action = 'POS_SYNC_ORDER'").get(tenant.id).cnt;
      assert.equal(audCount, 2);

      // Stock snapshot before duplicate sync
      const beefBeforeDup = db.prepare("SELECT current_stock FROM ingredients WHERE tenant_id = ? AND sku = 'ING-BEEF'").get(tenant.id).current_stock;

      // 2. Idempotency: re-posting FT-101 with new sync item id must NOT duplicate order or re-deduct BOM
      const dupSync = await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: {
          items: [
            {
              id: 'SYNC-ORD-1-RETRY',
              entity_type: 'order',
              payload: {
                ticket_number: 'FT-101',
                total_mru: 1610,
                status: 'PAID',
                items: [{ sku: 'GRL-001', qty: 2, unit_price: 755 }],
                payments: [{ method: 'Cash', amount_mru: 1610 }],
              },
            },
          ],
        },
      });
      assert.equal(dupSync.status, 200);
      assert.equal(db.prepare("SELECT COUNT(*) AS cnt FROM orders WHERE tenant_id = ? AND order_code = 'FT-101'").get(tenant.id).cnt, 1);
      const beefAfterDup = db.prepare("SELECT current_stock FROM ingredients WHERE tenant_id = ? AND sku = 'ING-BEEF'").get(tenant.id).current_stock;
      assert.equal(beefAfterDup, beefBeforeDup);

      // 3. KDS_PREP -> PAID order transition updates status without double-deducting BOM
      await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: {
          items: [
            {
              id: 'SYNC-KDS-1',
              entity_type: 'order',
              payload: {
                order_code: 'FT-103',
                status: 'KDS_PREP',
                table_name: 'T-02',
                total_mru: 250,
                created_at: `${today}T12:30:00.000Z`,
                items: [{ sku: 'RST-BRG-01', qty: 1, unit_price: 250 }],
              },
            },
          ],
        },
      });
      const beefAfterPrep = db.prepare("SELECT current_stock FROM ingredients WHERE tenant_id = ? AND sku = 'ING-BEEF'").get(tenant.id).current_stock;
      await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: {
          items: [
            {
              id: 'SYNC-KDS-1-PAID',
              entity_type: 'order',
              payload: {
                order_code: 'FT-103',
                status: 'PAID',
                total_mru: 250,
                payments: [{ method: 'Cash', amount_mru: 250 }],
              },
            },
          ],
        },
      });
      const ord103 = db.prepare("SELECT status, pay_method FROM orders WHERE tenant_id = ? AND order_code = 'FT-103'").get(tenant.id);
      assert.equal(ord103.status, 'PAID');
      assert.equal(ord103.pay_method, 'Cash');
      const beefAfterPaid = db.prepare("SELECT current_stock FROM ingredients WHERE tenant_id = ? AND sku = 'ING-BEEF'").get(tenant.id).current_stock;
      assert.equal(beefAfterPaid, beefAfterPrep);

      // 4. Atomic rollback: invalid item mid-batch rolls back earlier order & BOM in same batch
      const rollbackRes = await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: {
          items: [
            {
              id: 'SYNC-RB-OK',
              entity_type: 'order',
              payload: {
                order_code: 'FT-RB-999',
                status: 'PAID',
                total_mru: 250,
                items: [{ sku: 'RST-BRG-01', qty: 1, unit_price: 250 }],
              },
            },
            null,
          ],
        },
      });
      assert.equal(rollbackRes.status, 400);
      assert.equal(db.prepare("SELECT COUNT(*) AS cnt FROM orders WHERE tenant_id = ? AND order_code = 'FT-RB-999'").get(tenant.id).cnt, 0);
      assert.equal(db.prepare("SELECT current_stock FROM ingredients WHERE tenant_id = ? AND sku = 'ING-BEEF'").get(tenant.id).current_stock, beefAfterPaid);
    });
  });
});

describe('POS Suite 3 — BOM Deduction (ALL, TAKEAWAY_DELIVERY, modifier_key, REMAKE)', () => {
  it('deducts channel-aware, modifier-aware, and remake BOM accurately', async () => {
    await withIsolatedServer(async ({ request, db }) => {
      const { token, tenant } = await loginTenant(request, 'darelkram41');
      const getStock = (sku) =>
        db.prepare('SELECT current_stock FROM ingredients WHERE tenant_id = ? AND sku = ?').get(tenant.id, sku).current_stock;

      // 1. DINE_IN order: 2x RST-BRG-01 (no modifiers) -> ING-BEEF -0.30 (25 -> 24.7), ING-BUN -2 (100 -> 98), ING-BOX untouched (250)
      await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: {
          items: [
            {
              id: 'BOM-1',
              entity_type: 'order',
              payload: {
                order_code: 'BOM-DINE-1',
                service_mode: 'dine_in',
                status: 'PAID',
                total_mru: 500,
                items: [{ sku: 'RST-BRG-01', qty: 2, unit_price: 250 }],
              },
            },
          ],
        },
      });
      assert.equal(getStock('ING-BEEF'), 24.7);
      assert.equal(getStock('ING-BUN'), 98);
      assert.equal(getStock('ING-BOX'), 250);
      assert.equal(getStock('ING-BAG'), 250);
      assert.equal(getStock('ING-CHEESE'), 10);

      // 2. TAKEAWAY order with modifiers (opt-cheddar + opt-double-meat):
      // ING-BEEF: -(0.15 + 0.15) = -0.30 (24.7 -> 24.4)
      // ING-CHEESE: -0.04 (10 -> 9.96)
      // ING-BOX: -1 (250 -> 249), ING-BAG: -1 (250 -> 249)
      await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: {
          items: [
            {
              id: 'BOM-2',
              entity_type: 'order',
              payload: {
                order_code: 'BOM-TAKE-2',
                service_mode: 'takeaway',
                status: 'PAID',
                total_mru: 400,
                items: [
                  {
                    sku: 'RST-BRG-01',
                    qty: 1,
                    unit_price: 400,
                    modifiers: [
                      { id: 'opt-cheddar', bomKey: 'opt-cheddar' },
                      { id: 'opt-double-meat', bomKey: 'opt-double-meat' },
                    ],
                  },
                ],
              },
            },
          ],
        },
      });
      assert.equal(getStock('ING-BEEF'), 24.4);
      assert.equal(getStock('ING-BUN'), 97);
      assert.equal(getStock('ING-CHEESE'), 9.96);
      assert.equal(getStock('ING-BOX'), 249);
      assert.equal(getStock('ING-BAG'), 249);

      // 3. REMAKE deducts BOM again; COMP does NOT deduct BOM; duplicate REMAKE is idempotent
      await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: {
          items: [
            {
              id: 'REM-1',
              entity_type: 'remake',
              payload: {
                id: 'REM-EXT-1',
                type: 'REMAKE',
                sku: 'RST-BRG-01',
                ticket: 'BOM-DINE-1',
                qty: 1,
                amount_mru: 250,
                reason: 'Brûlé',
                approved_by: 'Ahmed Ould Salem',
              },
            },
            {
              id: 'COMP-1',
              entity_type: 'remake',
              payload: {
                id: 'COMP-EXT-1',
                type: 'COMP',
                sku: 'RST-BRG-01',
                qty: 1,
                amount_mru: 250,
                reason: 'Geste commercial',
              },
            },
          ],
        },
      });
      assert.equal(getStock('ING-BEEF'), 24.25);
      assert.equal(getStock('ING-BUN'), 96);

      // Duplicate remake ignored
      await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: {
          items: [
            {
              id: 'REM-1-DUP',
              entity_type: 'remake',
              payload: { id: 'REM-EXT-1', type: 'REMAKE', sku: 'RST-BRG-01', qty: 1, amount_mru: 250 },
            },
          ],
        },
      });
      assert.equal(getStock('ING-BEEF'), 24.25);
      const remRows = db.prepare("SELECT * FROM returns_remakes_comps WHERE tenant_id = ? AND reason IN ('Brûlé', 'Geste commercial')").all(tenant.id);
      assert.equal(remRows.length, 2);
      assert.equal(remRows.find((r) => r.reason === 'Brûlé').type, 'REMAKE');
      assert.equal(remRows.find((r) => r.reason === 'Geste commercial').type, 'COMP');
    });
  });
});

describe('POS Suite 4 — Strict Training Mode Isolation', () => {
  it('isolates isTraining/is_training sync items and excludes is_training=1 from KDS and KPIs', async () => {
    await withIsolatedServer(async ({ request, db }) => {
      const { token, tenant } = await loginTenant(request, 'darelkram41');
      const today = new Date().toISOString().slice(0, 10);

      const beefBefore = db.prepare("SELECT current_stock FROM ingredients WHERE tenant_id = ? AND sku = 'ING-BEEF'").get(tenant.id).current_stock;
      const karniDebtBefore = db.prepare('SELECT SUM(current_debt_mru) AS s FROM customer_credits_karni WHERE tenant_id = ?').get(tenant.id).s;
      const remakesBefore = db.prepare('SELECT COUNT(*) AS c FROM returns_remakes_comps WHERE tenant_id = ?').get(tenant.id).c;

      const syncRes = await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: {
          items: [
            {
              id: 'TRN-1',
              entity_type: 'order',
              payload: {
                order_code: 'TRN-ORD-1',
                isTraining: true,
                status: 'PAID',
                total_mru: 5000,
                created_at: `${today}T10:00:00.000Z`,
                items: [{ sku: 'RST-BRG-01', qty: 5, unit_price: 1000 }],
                payments: [{ method: 'Cash', amount_mru: 5000 }],
              },
            },
            {
              id: 'TRN-2',
              entity_type: 'remake',
              payload: { id: 'TRN-REM-1', is_training: true, type: 'REMAKE', sku: 'RST-BRG-01', qty: 2, amount_mru: 500 },
            },
            {
              id: 'TRN-3',
              entity_type: 'closing_z',
              payload: { id: 'TRN-Z-1', isTraining: 1, expected_mru: 5000, counted_mru: 5000, digital_mru: 0 },
            },
            {
              id: 'TRN-4',
              entity_type: 'karni',
              payload: { id: 'TRN-KAR-1', is_training: 1, customer_name: 'Sidi Mohamed Ould Ahmed', paid_mru: 1500 },
            },
            {
              id: 'TRN-5',
              entity_type: 'stock_86',
              payload: { sku: 'RST-BRG-01', isTraining: true, available: false },
            },
          ],
        },
      });
      assert.equal(syncRes.status, 200);
      assert.equal(syncRes.json.synced, 5);

      // Zero mutations to domain tables
      assert.equal(db.prepare('SELECT COUNT(*) AS c FROM orders WHERE tenant_id = ?').get(tenant.id).c, 0);
      assert.equal(db.prepare('SELECT COUNT(*) AS c FROM cash_closings_z WHERE tenant_id = ?').get(tenant.id).c, 0);
      assert.equal(db.prepare('SELECT COUNT(*) AS c FROM returns_remakes_comps WHERE tenant_id = ?').get(tenant.id).c, remakesBefore);
      assert.equal(db.prepare("SELECT current_stock FROM ingredients WHERE tenant_id = ? AND sku = 'ING-BEEF'").get(tenant.id).current_stock, beefBefore);
      assert.equal(db.prepare('SELECT SUM(current_debt_mru) AS s FROM customer_credits_karni WHERE tenant_id = ?').get(tenant.id).s, karniDebtBefore);
      assert.equal(db.prepare("SELECT is_out_of_stock FROM products WHERE tenant_id = ? AND sku = 'RST-BRG-01'").get(tenant.id).is_out_of_stock, 0);

      // Training audit logs recorded
      const trnAudits = db.prepare('SELECT COUNT(*) AS c FROM audit_logs WHERE tenant_id = ? AND is_training = 1').get(tenant.id).c;
      assert.equal(trnAudits, 5);

      // Even if a training order exists directly in DB, KDS and KPIs strictly exclude it
      const burger = db.prepare("SELECT id FROM products WHERE tenant_id = ? AND sku = 'RST-BRG-01'").get(tenant.id);
      const insOrd = db.prepare(`
        INSERT INTO orders (tenant_id, order_code, status, pay_method, total_mru, is_training, created_at)
        VALUES (?, 'DIRECT-TRN', 'KDS_PREP', 'Cash', 9999, 1, ?)
      `).run(tenant.id, `${today}T11:00:00.000Z`);
      db.prepare("INSERT INTO order_items (order_id, product_id, qty, unit_price, kds_status) VALUES (?, ?, 1, 9999, 'PENDING')")
        .run(Number(insOrd.lastInsertRowid), burger.id);
      db.prepare(`
        INSERT INTO orders (tenant_id, order_code, status, pay_method, total_mru, is_training, created_at)
        VALUES (?, 'DIRECT-TRN-PAID', 'PAID', 'Cash', 8888, 1, ?)
      `).run(tenant.id, `${today}T11:05:00.000Z`);

      const kds = await request('/api/pos/kds', { headers: { Authorization: `Bearer ${token}` } });
      assert.equal(kds.status, 200);
      assert.equal(kds.json.tickets.length, 0);

      const kpis = await request(`/api/pos/kpis?date=${today}`, { headers: { Authorization: `Bearer ${token}` } });
      assert.equal(kpis.status, 200);
      assert.equal(kpis.json.todayRevenueMru, 0);
      assert.equal(kpis.json.todayTicketsCount, 0);
    });
  });
});

describe('POS Suite 5 — Stock-86, KDS, KPIs, Closing Z, Karni, Reservation & Prisma Parity', () => {
  it('PATCH /api/pos/products/:id/availability & stock_86 sync toggle availability with strict tenant isolation', async () => {
    await withIsolatedServer(async ({ request }) => {
      const ft1041 = await loginTenant(request, 'darelkram41');
      const ft2088 = await loginTenant(request, 'albaraka88');

      const catBefore = await request('/api/pos/catalog', {
        headers: { Authorization: `Bearer ${ft1041.token}` },
      });
      const burger = catBefore.json.products.find((p) => p.sku === 'RST-BRG-01');
      assert.equal(burger.available, true);

      // Toggle off by SKU
      const offRes = await request('/api/pos/products/RST-BRG-01/availability', {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${ft1041.token}` },
        json: { available: false },
      });
      assert.equal(offRes.status, 200);
      assert.equal(offRes.json.available, false);
      assert.equal(offRes.json.isOutOfStock, true);

      // Cross-tenant attempt -> 404
      const crossRes = await request(`/api/pos/products/${burger.id}/availability`, {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${ft2088.token}` },
        json: { available: true },
      });
      assert.equal(crossRes.status, 404);

      // Conflicting / missing body -> 400
      const conflictRes = await request(`/api/pos/products/${burger.id}/availability`, {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${ft1041.token}` },
        json: { available: true, isOutOfStock: true },
      });
      assert.equal(conflictRes.status, 400);

      // Toggle back on by numeric ID
      const onRes = await request(`/api/pos/products/${burger.id}/availability`, {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${ft1041.token}` },
        json: { isOutOfStock: false },
      });
      assert.equal(onRes.status, 200);
      assert.equal(onRes.json.available, true);

      // Also verify stock_86 via POST /api/pos/sync
      await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${ft1041.token}` },
        json: {
          items: [{ id: 'S86-1', entity_type: 'stock_86', payload: { sku: 'RST-BRG-01', available: false } }],
        },
      });
      const catAfter = await request('/api/pos/catalog', {
        headers: { Authorization: `Bearer ${ft1041.token}` },
      });
      const burgerAfter = catAfter.json.products.find((p) => p.sku === 'RST-BRG-01');
      assert.equal(burgerAfter.available, false);
      assert.equal(burgerAfter.isOutOfStock, true);
    });
  });

  it('GET /api/pos/kds & PATCH /api/pos/kds/:orderId support stations, urgency colors & kds_ready sync', async () => {
    await withIsolatedServer(async ({ request }) => {
      const ft1041 = await loginTenant(request, 'darelkram41');
      const ft2088 = await loginTenant(request, 'albaraka88');

      const now = Date.now();
      const iso5m = new Date(now - 5 * 60_000).toISOString();
      const iso15m = new Date(now - 15 * 60_000).toISOString();
      const iso25m = new Date(now - 25 * 60_000).toISOString();

      await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${ft1041.token}` },
        json: {
          items: [
            {
              id: 'KDS-ORD-1',
              entity_type: 'order',
              payload: {
                order_code: 'KDS-1',
                status: 'KDS_PREP',
                table_name: 'T-01',
                kds_sent_at: iso5m,
                total_mru: 650,
                items: [
                  { sku: 'GRL-003', qty: 1, unit_price: 500 }, // GRILL
                  { sku: 'DRK-001', qty: 1, unit_price: 150 }, // BAR
                ],
              },
            },
            {
              id: 'KDS-ORD-2',
              entity_type: 'order',
              payload: {
                order_code: 'KDS-2',
                status: 'OPEN',
                kds_sent_at: iso15m,
                total_mru: 450,
                items: [{ sku: 'RIM-001', qty: 1, unit_price: 450 }], // KITCHEN
              },
            },
            {
              id: 'KDS-ORD-3',
              entity_type: 'order',
              payload: {
                order_code: 'KDS-3',
                status: 'KDS_PREP',
                kds_sent_at: iso25m,
                total_mru: 250,
                items: [{ sku: 'RST-BRG-01', qty: 1, unit_price: 250 }], // GRILL
              },
            },
          ],
        },
      });

      const badStation = await request('/api/pos/kds?station=INVALID', {
        headers: { Authorization: `Bearer ${ft1041.token}` },
      });
      assert.equal(badStation.status, 400);

      const allKds = await request('/api/pos/kds', {
        headers: { Authorization: `Bearer ${ft1041.token}` },
      });
      assert.equal(allKds.status, 200);
      assert.equal(allKds.json.tickets.length, 3);
      assert.equal(allKds.json.tickets.find((t) => t.orderCode === 'KDS-1').urgency, 'GREEN');
      assert.equal(allKds.json.tickets.find((t) => t.orderCode === 'KDS-2').urgency, 'ORANGE');
      assert.equal(allKds.json.tickets.find((t) => t.orderCode === 'KDS-3').urgency, 'RED');

      const grillKds = await request('/api/pos/kds?station=GRILL', {
        headers: { Authorization: `Bearer ${ft1041.token}` },
      });
      assert.equal(grillKds.json.tickets.length, 2);

      // Cross-tenant PATCH -> 404
      const crossPatch = await request('/api/pos/kds/KDS-1', {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${ft2088.token}` },
        json: { status: 'READY' },
      });
      assert.equal(crossPatch.status, 404);

      // Partial station READY (GRILL only on KDS-1): order stays KDS_PREP because BAR item remains
      const partReady = await request('/api/pos/kds/KDS-1', {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${ft1041.token}` },
        json: { status: 'READY', station: 'GRILL' },
      });
      assert.equal(partReady.status, 200);
      assert.equal(partReady.json.orderStatus, 'KDS_PREP');
      assert.equal(partReady.json.remainingPendingItems, 1);

      // Finish BAR via kds_ready sync -> order transitions to READY
      await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${ft1041.token}` },
        json: {
          items: [{ id: 'KDS-RDY-1', entity_type: 'kds_ready', payload: { order_code: 'KDS-1', station: 'BAR' } }],
        },
      });

      const afterBar = await request('/api/pos/kds', {
        headers: { Authorization: `Bearer ${ft1041.token}` },
      });
      assert.equal(afterBar.json.tickets.some((t) => t.orderCode === 'KDS-1'), false);
    });
  });

  it('persists closing_z, karni, reservation and computes accurate GET /api/pos/kpis', async () => {
    await withIsolatedServer(async ({ request, db }) => {
      const { token, tenant } = await loginTenant(request, 'darelkram41');
      const today = new Date().toISOString().slice(0, 10);

      // Sync orders across all 7 payment methods, closing_z, karni repayment, reservation
      const syncRes = await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: {
          items: [
            {
              id: 'KPI-O1',
              entity_type: 'order',
              payload: {
                order_code: 'KPI-1',
                status: 'PAID',
                total_mru: 1000,
                created_at: `${today}T09:00:00.000Z`,
                items: [{ sku: 'RST-BRG-01', qty: 2, unit_price: 250 }, { sku: 'GRL-003', qty: 1, unit_price: 500 }],
                payments: [
                  { method: 'Cash', amount_mru: 500 }, // 100 change -> 400 net cash
                  { method: 'Bankily', amount_mru: 300 },
                  { method: 'Masrivi', amount_mru: 200 },
                  { method: 'Sedad', amount_mru: 200 },
                ],
              },
            },
            {
              id: 'KPI-O2',
              entity_type: 'order',
              payload: {
                order_code: 'KPI-2',
                status: 'PAID',
                total_mru: 1000,
                created_at: `${today}T10:00:00.000Z`,
                items: [{ sku: 'DRK-001', qty: 2, unit_price: 150 }],
                payments: [
                  { method: 'Bimbank', amount_mru: 350 },
                  { method: 'Click', amount_mru: 250 },
                  { method: 'Karni', amount_mru: 400, customer_name: 'Sidi Mohamed Ould Ahmed' },
                ],
              },
            },
            {
              id: 'KPI-KAR-REPAY',
              entity_type: 'karni',
              payload: {
                id: 'KAR-PAY-1',
                customer_name: 'Aminetou Mint Sidi',
                paid_mru: 500,
                pay_method: 'Bankily',
              },
            },
            {
              id: 'KPI-Z-1',
              entity_type: 'closing_z',
              payload: {
                id: 'Z-2026-1',
                closed_at: `${today}T23:00:00.000Z`,
                cashier_name: 'Aïcha',
                counted_cash_mru: 400,
                expected_cash_mru: 400,
                cash_variance_mru: 0,
                expected_bankily_mru: 300,
                expected_masrivi_mru: 200,
                expected_sedad_mru: 200,
                expected_bimbank_mru: 350,
                expected_click_mru: 250,
              },
            },
            {
              id: 'KPI-RES-1',
              entity_type: 'reservation',
              payload: {
                id: 'RES-SYNC-1',
                customer: 'Famille Ould Cheikh',
                table_id: 'KHAIMA-2',
                arboun_mru: 1500,
              },
            },
          ],
        },
      });
      assert.equal(syncRes.status, 200, syncRes.text);

      // Verify closing_z, karni debt updates, reservation
      const zRow = db.prepare('SELECT * FROM cash_closings_z WHERE tenant_id = ?').get(tenant.id);
      assert.ok(zRow);
      assert.equal(zRow.counted_mru, 400);
      assert.equal(zRow.digital_mru, 1300);

      const sidi = db.prepare("SELECT current_debt_mru FROM customer_credits_karni WHERE tenant_id = ? AND customer_name = 'Sidi Mohamed Ould Ahmed'").get(tenant.id);
      assert.equal(sidi.current_debt_mru, 1900); // 1500 + 400 charge

      const ami = db.prepare("SELECT current_debt_mru FROM customer_credits_karni WHERE tenant_id = ? AND customer_name = 'Aminetou Mint Sidi'").get(tenant.id);
      assert.equal(ami.current_debt_mru, 350); // 850 - 500 repayment

      const resVip = db.prepare("SELECT * FROM reservations_vip WHERE tenant_id = ? AND customer_name = 'Famille Ould Cheikh'").get(tenant.id);
      assert.ok(resVip);
      assert.equal(resVip.deposit_mru, 1500);

      // Trigger low stock alert on ING-TEA
      db.prepare("UPDATE ingredients SET current_stock = 1.0 WHERE tenant_id = ? AND sku = 'ING-TEA'").run(tenant.id);

      const kpis = await request(`/api/pos/kpis?date=${today}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      assert.equal(kpis.status, 200);
      assert.equal(kpis.json.todayRevenueMru, 2000);
      assert.equal(kpis.json.todayTicketsCount, 2);
      assert.equal(kpis.json.averageBasketMru, 1000);
      assert.deepEqual(kpis.json.paymentBreakdown, {
        cash: 300,
        bankily: 300,
        masrivi: 200,
        sedad: 200,
        bimbank: 350,
        click: 250,
        karni: 400,
      });
      // BOM food cost: 2*RST-BRG-01 (2*(0.15*250 + 1*12)=99) + 1*GRL-003 (0.28*250=70) + 2*DRK-001 (2*0.04*300=24) + seeded REMAKE (85) = 278
      assert.equal(kpis.json.foodCostMru, 278);
      assert.equal(kpis.json.grossMarginPercent, 86.1);
      assert.ok(kpis.json.lowStockAlerts.some((a) => a.sku === 'ING-TEA' && a.currentStock === 1));

      const badDate = await request('/api/pos/kpis?date=19-11-2026', {
        headers: { Authorization: `Bearer ${token}` },
      });
      assert.equal(badDate.status, 400);
    });
  });

  it('keeps prisma/schema.prisma and prisma/schema.postgresql.prisma strictly synchronized across all 43 models', () => {
    const sqlitePath = path.join(__dirname, '..', 'prisma', 'schema.prisma');
    const pgPath = path.join(__dirname, '..', 'prisma', 'schema.postgresql.prisma');
    const sq = parsePrismaModels(sqlitePath);
    const pg = parsePrismaModels(pgPath);

    assert.equal(sq.provider, 'sqlite');
    assert.equal(pg.provider, 'postgresql');
    assert.equal(sq.balanced, true);
    assert.equal(pg.balanced, true);
    assert.equal(sq.models.size, 43);
    assert.equal(pg.models.size, 43);

    for (const [model, fields] of sq.models.entries()) {
      assert.ok(pg.models.has(model), `PostgreSQL schema missing model ${model}`);
      assert.deepEqual(pg.models.get(model), fields, `Field parity mismatch on model ${model}`);
    }
  });
});

describe('POS Suite 6 — M1 Regression Tests (Karni Limits, Metadata Preservation, Exclusion BOM & Backfill)', () => {
  it('enforces Karni credit_limit_mru (over-limit 400 + rollback, exact boundary 200) and rejects cross-tenant/invalid customerId', async () => {
    await withIsolatedServer(async ({ request, db }) => {
      const ft1041 = await loginTenant(request, 'darelkram41');
      const ft2088 = await loginTenant(request, 'albaraka88');

      const cat1 = await request('/api/pos/catalog', {
        headers: { Authorization: `Bearer ${ft1041.token}` },
      });
      const cat2 = await request('/api/pos/catalog', {
        headers: { Authorization: `Bearer ${ft2088.token}` },
      });

      const cust1 = cat1.json.karniCustomers[0]; // limit 10000, debt 1500 -> remaining 8500
      const cust2 = cat2.json.karniCustomers[0]; // belongs to FT-2088
      const remaining = cust1.creditLimitMru - cust1.balanceDueMru;
      assert.ok(remaining > 0);

      const txCountBefore = db.prepare('SELECT COUNT(*) AS c FROM karni_transactions WHERE tenant_id = ?').get(ft1041.tenant.id).c;

      // 1. Over credit limit via entity_type='karni' -> 400 and atomic rollback (zero mutation)
      const overKarniRes = await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${ft1041.token}` },
        json: {
          items: [
            {
              id: 'KAR-OVER-1',
              entity_type: 'karni',
              payload: {
                customerId: cust1.id,
                txType: 'CHARGE',
                amountMru: remaining + 1,
              },
            },
          ],
        },
      });
      assert.equal(overKarniRes.status, 400);
      assert.equal(
        db.prepare('SELECT current_debt_mru FROM customer_credits_karni WHERE id = ?').get(cust1.id).current_debt_mru,
        cust1.balanceDueMru,
      );
      assert.equal(
        db.prepare('SELECT COUNT(*) AS c FROM karni_transactions WHERE tenant_id = ?').get(ft1041.tenant.id).c,
        txCountBefore,
      );

      // 2. Over credit limit via entity_type='order' (including split Karni entries summing over limit) -> 400 + rollback
      const overOrderRes = await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${ft1041.token}` },
        json: {
          items: [
            {
              id: 'ORD-KAR-OVER',
              entity_type: 'order',
              payload: {
                orderCode: 'FT-KAR-OVER-1',
                status: 'PAID',
                totalMru: remaining + 1,
                items: [{ sku: 'RST-BRG-01', qty: 1, unit_price: remaining + 1 }],
                payments: [
                  { method: 'Karni', amountMru: Math.floor(remaining / 2), karniCustomerId: cust1.id },
                  { method: 'Karni', amountMru: remaining - Math.floor(remaining / 2) + 1, karniCustomerId: cust1.id },
                ],
              },
            },
          ],
        },
      });
      assert.equal(overOrderRes.status, 400);
      assert.equal(
        db.prepare("SELECT COUNT(*) AS c FROM orders WHERE tenant_id = ? AND order_code = 'FT-KAR-OVER-1'").get(ft1041.tenant.id).c,
        0,
      );
      assert.equal(
        db.prepare('SELECT current_debt_mru FROM customer_credits_karni WHERE id = ?').get(cust1.id).current_debt_mru,
        cust1.balanceDueMru,
      );

      // 3. Cross-tenant customerId -> 404 (not falling through or mutating)
      const crossKarniRes = await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${ft1041.token}` },
        json: {
          items: [
            {
              id: 'KAR-CROSS-1',
              entity_type: 'karni',
              payload: {
                customerId: cust2.id,
                customerName: cust1.name, // must NOT fall back to name when customerId is provided
                txType: 'CHARGE',
                amountMru: 100,
              },
            },
          ],
        },
      });
      assert.equal(crossKarniRes.status, 404);
      assert.equal(
        db.prepare('SELECT current_debt_mru FROM customer_credits_karni WHERE id = ?').get(cust2.id).current_debt_mru,
        cust2.balanceDueMru,
      );
      assert.equal(
        db.prepare('SELECT current_debt_mru FROM customer_credits_karni WHERE id = ?').get(cust1.id).current_debt_mru,
        cust1.balanceDueMru,
      );

      // 4. Invalid customerId and negative amountMru -> 400
      const badIdRes = await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${ft1041.token}` },
        json: {
          items: [{ id: 'KAR-BAD-ID', entity_type: 'karni', payload: { customerId: 'abc', amountMru: 100 } }],
        },
      });
      assert.equal(badIdRes.status, 400);

      const negAmtRes = await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${ft1041.token}` },
        json: {
          items: [{ id: 'KAR-NEG', entity_type: 'karni', payload: { customerId: cust1.id, amountMru: -50 } }],
        },
      });
      assert.equal(negAmtRes.status, 400);

      // 5. Exact credit_limit_mru boundary -> 200
      const exactRes = await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${ft1041.token}` },
        json: {
          items: [
            {
              id: 'KAR-EXACT-1',
              entity_type: 'karni',
              payload: {
                customerId: cust1.id,
                txType: 'CHARGE',
                amountMru: remaining,
              },
            },
          ],
        },
      });
      assert.equal(exactRes.status, 200, exactRes.text);
      assert.equal(
        db.prepare('SELECT current_debt_mru FROM customer_credits_karni WHERE id = ?').get(cust1.id).current_debt_mru,
        cust1.creditLimitMru,
      );
    });
  });

  it('preserves delivery metadata & notes on KDS_PREP -> PAID and preserves pe.ref in payments_json', async () => {
    await withIsolatedServer(async ({ request, db }) => {
      const { token, tenant } = await loginTenant(request, 'darelkram41');
      const today = new Date().toISOString().slice(0, 10);

      // 1. Initial KDS_PREP delivery order with full delivery metadata and notes
      const prepRes = await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: {
          items: [
            {
              id: 'META-PREP-1',
              entity_type: 'order',
              payload: {
                orderCode: 'FT-DEL-META-1',
                status: 'KDS_PREP',
                serviceMode: 'delivery',
                deliveryZone: 'Tevragh Zeina',
                deliveryFeeMru: 100,
                customerName: 'Mariem Mint Ali',
                customerPhone: '+222 47 11 22 33',
                deliveryAddress: 'Carrefour BMD, Villa 8',
                notes: 'Arboun 200 MRU déduit',
                totalMru: 1100,
                createdAt: `${today}T14:00:00.000Z`,
                items: [{ sku: 'RST-BRG-01', qty: 4, unitPrice: 250 }],
              },
            },
          ],
        },
      });
      assert.equal(prepRes.status, 200, prepRes.text);

      // 2. Subsequent settlement omits serviceMode, delivery*, customer*, and notes, and uses `ref` on payment
      const paidRes = await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: {
          items: [
            {
              id: 'META-PAID-1',
              entity_type: 'order',
              payload: {
                orderCode: 'FT-DEL-META-1',
                status: 'PAID',
                totalMru: 1100,
                payMethod: 'Mixte',
                payments: [
                  { method: 'Cash', amountMru: 600 },
                  { method: 'Bankily', amountMru: 500, ref: 'BK-9012' },
                ],
              },
            },
          ],
        },
      });
      assert.equal(paidRes.status, 200, paidRes.text);

      const ord = db.prepare("SELECT * FROM orders WHERE tenant_id = ? AND order_code = 'FT-DEL-META-1'").get(tenant.id);
      assert.ok(ord);
      assert.equal(ord.status, 'PAID');
      assert.equal(ord.service_mode, 'delivery');
      assert.equal(ord.channel, 'DELIVERY');
      assert.equal(ord.delivery_zone, 'Tevragh Zeina');
      assert.equal(ord.delivery_fee_mru, 100);
      assert.equal(ord.customer_name, 'Mariem Mint Ali');
      assert.equal(ord.customer_phone, '+222 47 11 22 33');
      assert.equal(ord.delivery_address, 'Carrefour BMD, Villa 8');
      assert.equal(ord.notes, 'Arboun 200 MRU déduit');

      const payments = JSON.parse(ord.payments_json || '[]');
      assert.equal(payments.length, 2);
      assert.equal(payments[1].method, 'Bankily');
      assert.equal(payments[1].reference, 'BK-9012');
    });
  });

  it('skips excluded base BOM ingredients (-Fromage / -ING-BEEF) in both stock deduction and GET /api/pos/kpis foodCostMru', async () => {
    await withIsolatedServer(async ({ request, db }) => {
      const { token, tenant } = await loginTenant(request, 'darelkram41');
      const today = new Date().toISOString().slice(0, 10);

      // Add a base BOM ingredient "Fromage" on RST-BRG-01 (qty 1, pmp 30 MRU)
      const burger = db.prepare("SELECT id FROM products WHERE tenant_id = ? AND sku = 'RST-BRG-01'").get(tenant.id);
      const ingRes = db.prepare(`
        INSERT INTO ingredients (tenant_id, sku, name_fr, name_ar, unit, pmp_cost_mru, current_stock, min_stock)
        VALUES (?, 'ING-FROMAGE-EXCL', 'Fromage', 'جبنة', 'unit', 30, 50.0, 5.0)
      `).run(tenant.id);
      const fromageId = Number(ingRes.lastInsertRowid);
      db.prepare(`
        INSERT INTO recipes_bom (tenant_id, product_id, ingredient_id, qty_per_unit, unit, condition_channel, modifier_key)
        VALUES (?, ?, ?, 1.0, 'unit', 'ALL', '')
      `).run(tenant.id, burger.id, fromageId);

      // Zero out seeded REMAKE cost so foodCostMru reflects only this order
      db.prepare('DELETE FROM returns_remakes_comps WHERE tenant_id = ?').run(tenant.id);

      const beefBefore = db.prepare("SELECT current_stock FROM ingredients WHERE tenant_id = ? AND sku = 'ING-BEEF'").get(tenant.id).current_stock;
      const bunBefore = db.prepare("SELECT current_stock FROM ingredients WHERE tenant_id = ? AND sku = 'ING-BUN'").get(tenant.id).current_stock;

      // Sync 2x RST-BRG-01 with exclusion modifier -Fromage:
      // Expected BOM kept: ING-BEEF (0.15*250 = 37.5) + ING-BUN (1*12 = 12) = 49.5 per unit * 2 = 99 MRU
      // Excluded Fromage (30 * 2 = 60 MRU) must NOT be deducted and must NOT appear in foodCostMru
      const syncRes = await request('/api/pos/sync', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: {
          items: [
            {
              id: 'EXCL-ORD-1',
              entity_type: 'order',
              payload: {
                orderCode: 'FT-EXCL-1',
                serviceMode: 'dine_in',
                status: 'PAID',
                totalMru: 500,
                createdAt: `${today}T15:00:00.000Z`,
                items: [
                  {
                    sku: 'RST-BRG-01',
                    qty: 2,
                    unitPrice: 250,
                    modifiers: [{ nameFr: 'Sans fromage', extraPriceMru: 0, bomKey: '-Fromage' }],
                  },
                ],
                payments: [{ method: 'Cash', amountMru: 500 }],
              },
            },
          ],
        },
      });
      assert.equal(syncRes.status, 200, syncRes.text);

      assert.equal(db.prepare('SELECT current_stock FROM ingredients WHERE id = ?').get(fromageId).current_stock, 50.0);
      assert.equal(db.prepare("SELECT current_stock FROM ingredients WHERE tenant_id = ? AND sku = 'ING-BEEF'").get(tenant.id).current_stock, beefBefore - 0.3);
      assert.equal(db.prepare("SELECT current_stock FROM ingredients WHERE tenant_id = ? AND sku = 'ING-BUN'").get(tenant.id).current_stock, bunBefore - 2);

      const kpis = await request(`/api/pos/kpis?date=${today}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      assert.equal(kpis.status, 200);
      assert.equal(kpis.json.foodCostMru, 99);
    });
  });

  it('upgrades incomplete FT-1041 pay_methods arrays (even when Bimbank and Click are present) to all 7 canonical methods', () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'fulltek-backfill-'));
    try {
      const dbPath = path.join(tmpDir, 'backfill.db');
      const db1 = createDb(dbPath);
      db1.prepare("UPDATE tenants SET pay_methods = ? WHERE tenant_code = 'FT-1041'").run(
        JSON.stringify(['Cash', 'Bankily', 'Bimbank', 'Click']),
      );
      db1.close();

      const db2 = createDb(dbPath);
      const row = db2.prepare("SELECT pay_methods FROM tenants WHERE tenant_code = 'FT-1041'").get();
      db2.close();
      assert.deepEqual(JSON.parse(row.pay_methods), ['Cash', 'Bankily', 'Masrivi', 'Sedad', 'Bimbank', 'Click', 'Karni']);
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true, maxRetries: 10, retryDelay: 50 });
    }
  });
});

describe('POS Suite 7 — Tenant Menu & Stock CRUD (POST/PATCH/DELETE /api/pos/products & /api/pos/ingredients)', () => {
  it('creates, updates, soft-deletes menu items and restocks ingredients with weighted PMP', async () => {
    await withIsolatedServer(async ({ request }) => {
      const { token } = await loginTenant(request, 'darelkram41');

      // 1. Create product
      const cr = await request('/api/pos/products', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: {
          nameFr: 'Tacos Poulet Spécial',
          nameAr: 'تاكوس دجاج',
          categoryName: 'Tacos',
          priceMru: 240,
          kitchenStation: 'GRILL',
          isTop: true,
        },
      });
      assert.equal(cr.status, 201);
      assert.equal(cr.json.product.name_fr, 'Tacos Poulet Spécial');
      assert.equal(cr.json.product.price_retail, 240);
      const prodId = cr.json.product.id;

      // 2. Update price
      const up = await request(`/api/pos/products/${prodId}`, {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${token}` },
        json: { priceMru: 260, available: true },
      });
      assert.equal(up.status, 200);
      assert.equal(up.json.product.price_retail, 260);

      // 3. Create ingredient & restock with weighted PMP
      const ingRes = await request('/api/pos/ingredients', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: {
          nameFr: 'Blanc de Poulet',
          unit: 'kg',
          currentStock: 10,
          minStock: 3,
          pmpCostMru: 200,
        },
      });
      assert.equal(ingRes.status, 201);
      const ingId = ingRes.json.ingredient.id;

      const restockRes = await request(`/api/pos/ingredients/${ingId}/restock`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: { deltaQty: 10, unitCostMru: 300 },
      });
      assert.equal(restockRes.status, 200);
      assert.equal(restockRes.json.ingredient.current_stock, 20);
      assert.equal(restockRes.json.ingredient.pmp_cost_mru, 250);

      // 4. Delete (soft-deactivate) product
      const del = await request(`/api/pos/products/${prodId}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` },
      });
      assert.equal(del.status, 200);
      assert.equal(del.json.active, false);
    });
  });
});
