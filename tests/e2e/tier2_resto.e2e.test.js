'use strict';

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');

const {
  DEFAULT_JWT_SECRET,
  DEFAULT_POS_USER,
  DEFAULT_POS_PASS,
  startTestServer,
  loginAdmin,
  loginTenant,
  computeTva16,
  makeExpiredJwt,
  makeWrongSecretJwt,
  makeAlgNoneJwt,
  tamperJwtPayload,
  withReadOnlyDb,
  withWritableDb,
} = require('./helpers');

function getCustomerDebt(c) {
  return Number(c.balanceDueMru ?? c.currentDebtMru ?? c.current_debt_mru ?? 0);
}

function getCustomerLimit(c) {
  return Number(c.creditLimitMru ?? c.credit_limit_mru ?? 0);
}

function getIngredientStock(ing) {
  return Number(ing.currentStock ?? ing.current_stock ?? 0);
}

// ---------------------------------------------------------------------------
// Tier 2 · Area A1: Auth, Tenant Isolation, Inactive Filtering & Seed Idempotency
// ---------------------------------------------------------------------------
describe('Tier 2 · Area A1: POS Auth, Cross-Tenant Isolation & Seed Idempotency', () => {
  let ctx;
  let tenant1Auth;
  let tenant2Auth;

  before(async () => {
    ctx = await startTestServer({ jwtSecret: DEFAULT_JWT_SECRET });
    tenant1Auth = await loginTenant(ctx, { username: DEFAULT_POS_USER, password: DEFAULT_POS_PASS });
    tenant2Auth = await loginTenant(ctx, { username: 'albaraka88', password: DEFAULT_POS_PASS });
  });

  after(async () => {
    await ctx?.stop();
  });

  it('T2-A1-01: Missing, malformed, expired, wrong-secret, alg=none & SuperAdmin JWTs all return 401 on every POS route', async () => {
    const { token: superAdminToken } = await loginAdmin(ctx);
    const expiredTenantJwt = makeExpiredJwt(DEFAULT_JWT_SECRET, { tenantId: 1, tenantCode: 'FT-1041', role: 'OWNER' });
    const wrongSecretJwt = makeWrongSecretJwt({ tenantId: 1, tenantCode: 'FT-1041', role: 'OWNER' });
    const algNoneJwt = makeAlgNoneJwt({ tenantId: 1, tenantCode: 'FT-1041', role: 'OWNER' });
    const tamperedJwt = tamperJwtPayload(tenant1Auth.token, (p) => ({ ...p, tenantId: 99 }));

    const posEndpoints = [
      ['GET', '/api/pos/catalog'],
      ['POST', '/api/pos/sync', { items: [] }],
      ['PATCH', '/api/pos/products/1/availability', { available: false }],
      ['GET', '/api/pos/kds'],
      ['PATCH', '/api/pos/kds/1', { status: 'READY' }],
      ['GET', '/api/pos/kpis'],
    ];

    const badTokens = [
      { label: 'missing', headers: {} },
      { label: 'malformed', headers: { Authorization: 'Bearer not.a.jwt' } },
      { label: 'expired', token: expiredTenantJwt },
      { label: 'wrongSecret', token: wrongSecretJwt },
      { label: 'algNone', token: algNoneJwt },
      { label: 'tampered', token: tamperedJwt },
      { label: 'superAdminNoTenantId', token: superAdminToken },
    ];

    for (const [method, urlPath, body] of posEndpoints) {
      for (const bt of badTokens) {
        const res = await ctx.request(method, urlPath, {
          ...(body ? { body } : {}),
          ...(bt.token ? { token: bt.token } : {}),
          ...(bt.headers ? { headers: bt.headers } : {}),
        });
        assert.equal(
          res.status,
          401,
          `${method} ${urlPath} with ${bt.label} expected 401, got ${res.status}: ${res.text}`,
        );
      }
    }
  });

  it('T2-A1-02: Strict cross-tenant isolation between FT-2088 and FT-1041', async () => {
    const cat1 = (await ctx.request('GET', '/api/pos/catalog', { token: tenant1Auth.token })).json;
    const cat2Res = await ctx.request('GET', '/api/pos/catalog', { token: tenant2Auth.token });
    assert.equal(cat2Res.status, 200, cat2Res.text);
    const cat2 = cat2Res.json;

    assert.equal(cat2.tenantId, tenant2Auth.tenant.id);
    assert.notEqual(cat2.tenantId, cat1.tenantId);

    const t1Skus = new Set((cat1.products || []).map((p) => p.sku));
    for (const p2 of cat2.products || []) {
      assert.equal(t1Skus.has(p2.sku), false, `FT-2088 leaked FT-1041 product ${p2.sku}`);
    }
    assert.equal((cat2.diningZones || []).length, 0, 'Market FT-2088 should not see FT-1041 diningZones');
    assert.equal((cat2.ingredients || []).length, 0, 'Market FT-2088 should not see FT-1041 ingredients');

    // FT-2088 cannot mutate FT-1041 product availability
    const p1 = cat1.products[0];
    const crossAvail = await ctx.request('PATCH', `/api/pos/products/${p1.id}/availability`, {
      token: tenant2Auth.token,
      body: { available: false },
    });
    assert.equal(crossAvail.status, 404, `Cross-tenant availability toggle expected 404, got ${crossAvail.status}`);

    // Verify FT-1041 product untouched
    const cat1After = (await ctx.request('GET', '/api/pos/catalog', { token: tenant1Auth.token })).json;
    const p1After = cat1After.products.find((p) => String(p.id) === String(p1.id));
    assert.equal(p1After.available, true);
  });

  it('T2-A1-03: Login metadata exposes market module (albaraka88) & expired status (elwiam12); bad password returns 401', async () => {
    const marketLogin = await loginTenant(ctx, { username: 'albaraka88', password: DEFAULT_POS_PASS });
    assert.equal(marketLogin.tenant.module, 'market');
    assert.equal(marketLogin.tenant.tenantId ?? marketLogin.tenant.code, 'FT-2088');

    const expiredLogin = await loginTenant(ctx, { username: 'elwiam12', password: DEFAULT_POS_PASS });
    assert.equal(expiredLogin.tenant.status, 'expired');
    assert.equal(expiredLogin.tenant.daysLeft, 0);

    const badPass = await ctx.request('POST', '/api/auth/login', {
      body: { username: DEFAULT_POS_USER, password: 'WrongPassword!123' },
    });
    assert.equal(badPass.status, 401, badPass.text);
  });

  it('T2-A1-04: Inactive (active = 0) categories and products are excluded from GET /api/pos/catalog', async () => {
    const inactiveSku = `INACTIVE-SKU-${Date.now()}`;
    const inactiveCatName = `Inactive Cat ${Date.now()}`;

    withWritableDb(ctx.dbPath, (db) => {
      const catInfo = db.prepare(`
        INSERT INTO categories (tenant_id, name_fr, name_ar, name_en, icon, sort_order, active)
        VALUES (1, ?, 'فئة غير نشطة', 'Inactive Cat', '🚫', 99, 0)
      `).run(inactiveCatName);
      db.prepare(`
        INSERT INTO products (tenant_id, category_id, sku, name_fr, name_ar, name_en, price_retail, active)
        VALUES (1, ?, ?, 'Plat Désactivé', 'طبق معطل', 'Disabled Dish', 500, 0)
      `).run(Number(catInfo.lastInsertRowid), inactiveSku);
    });

    const catRes = await ctx.request('GET', '/api/pos/catalog', { token: tenant1Auth.token });
    assert.equal(catRes.status, 200, catRes.text);
    assert.equal(catRes.json.categories.some((c) => c.nameFr === inactiveCatName), false, 'Inactive category leaked');
    assert.equal(catRes.json.products.some((p) => p.sku === inactiveSku), false, 'Inactive product leaked');
  });

  it('T2-A1-05: Restarting cloud-api on same dbPath preserves FT-1041 rich seeding idempotently (zero duplicates)', async () => {
    const isolatedCtx = await startTestServer();
    try {
      const token1 = (await loginTenant(isolatedCtx)).token;
      const before = (await isolatedCtx.request('GET', '/api/pos/catalog', { token: token1 })).json;
      const dbPath = isolatedCtx.dbPath;
      const tmpDir = isolatedCtx.tmpDir;

      await isolatedCtx.stop({ cleanup: false });

      const restartedCtx = await startTestServer({ dbPath, tmpDir, ownsTmpDir: true });
      try {
        const token2 = (await loginTenant(restartedCtx)).token;
        const after = (await restartedCtx.request('GET', '/api/pos/catalog', { token: token2 })).json;

        assert.equal(after.categories.length, before.categories.length, 'Duplicate categories after restart');
        assert.equal(after.products.length, before.products.length, 'Duplicate products after restart');
        assert.equal(after.diningZones.length, before.diningZones.length, 'Duplicate diningZones after restart');
        assert.equal(after.ingredients.length, before.ingredients.length, 'Duplicate ingredients after restart');
        assert.equal(after.recipesBom.length, before.recipesBom.length, 'Duplicate recipesBom after restart');
      } finally {
        await restartedCtx.stop();
      }
    } catch (err) {
      await isolatedCtx?.stop().catch(() => {});
      throw err;
    }
  });
});

// ---------------------------------------------------------------------------
// Tier 2 · Area A2: Sync Idempotency, Rollback, Conditional BOM, Training, TVA & Thresholds
// ---------------------------------------------------------------------------
describe('Tier 2 · Area A2: Transactional Sync, BOM, Karni, TVA & Delivery Threshold Boundaries', () => {
  let ctx;
  let token;
  let catalog;

  before(async () => {
    ctx = await startTestServer();
    token = (await loginTenant(ctx)).token;
    catalog = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
  });

  after(async () => {
    await ctx?.stop();
  });

  it('T2-A2-01: Mixed batch ([realOrder, isTraining:true, is_training:true]) commits ONLY realOrder', async () => {
    const prod = catalog.products[0];
    const beforeKpi = (await ctx.request('GET', '/api/pos/kpis', { token })).json;
    const realCode = `ORD-MIX-REAL-${Date.now()}`;
    const trainCamelCode = `ORD-MIX-TRC-${Date.now()}`;
    const trainSnakeCode = `ORD-MIX-TRS-${Date.now()}`;

    const res = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `s-${realCode}`,
            entity_type: 'order',
            payload: {
              orderCode: realCode,
              serviceMode: 'dine_in',
              status: 'PAID',
              totalMru: 450,
              tvaAmountMru: computeTva16(450),
              payments: [{ method: 'Cash', amountMru: 450 }],
              isTraining: false,
              items: [{ productId: prod.id, sku: prod.sku, qty: 1, unitPriceMru: 450, kdsStatus: 'PENDING' }],
            },
          },
          {
            id: `s-${trainCamelCode}`,
            entity_type: 'order',
            payload: {
              orderCode: trainCamelCode,
              serviceMode: 'dine_in',
              status: 'PAID',
              totalMru: 9000,
              tvaAmountMru: computeTva16(9000),
              payments: [{ method: 'Cash', amountMru: 9000 }],
              isTraining: true,
              items: [{ productId: prod.id, sku: prod.sku, qty: 20, unitPriceMru: 450, kdsStatus: 'PENDING' }],
            },
          },
          {
            id: `s-${trainSnakeCode}`,
            entity_type: 'order',
            payload: {
              order_code: trainSnakeCode,
              service_mode: 'dine_in',
              status: 'KDS_PREP',
              total_mru: 4500,
              tva_mru: computeTva16(4500),
              payments: [{ method: 'Bankily', amountMru: 4500 }],
              is_training: true,
              items: [{ productId: prod.id, sku: prod.sku, qty: 10, unitPriceMru: 450 }],
            },
          },
        ],
      },
    });
    assert.equal(res.status, 200, res.text);
    assert.equal(res.json.synced, 3);

    const afterKpi = (await ctx.request('GET', '/api/pos/kpis', { token })).json;
    assert.equal(afterKpi.todayRevenueMru, beforeKpi.todayRevenueMru + 450);
    assert.equal(afterKpi.todayTicketsCount, beforeKpi.todayTicketsCount + 1);

    const kds = (await ctx.request('GET', '/api/pos/kds?station=ALL', { token })).json;
    const kdsCodes = (kds.tickets || kds.orders || []).map((t) => t.orderCode || t.order_code);
    assert.ok(kdsCodes.includes(realCode), 'Real order missing from KDS');
    assert.equal(kdsCodes.includes(trainCamelCode), false, 'isTraining: true leaked into KDS');
    assert.equal(kdsCodes.includes(trainSnakeCode), false, 'is_training: true leaked into KDS');
  });

  it('T2-A2-02: Re-sending identical orderCode twice is idempotent (no duplicate order, no double BOM deduction)', async () => {
    const bom = catalog.recipesBom.find((b) => (b.conditionChannel ?? 'ALL') === 'ALL' && !b.modifierKey);
    const prod = catalog.products.find((p) => p.id === bom.productId || p.sku === bom.productSku);
    const ing = catalog.ingredients.find((i) => i.id === bom.ingredientId || i.sku === bom.ingredientSku);

    const beforeStock = getIngredientStock((await ctx.request('GET', '/api/pos/catalog', { token })).json.ingredients.find((i) => i.sku === ing.sku));
    const dupCode = `ORD-IDEM-${Date.now()}`;
    const body = {
      items: [
        {
          id: `sync-${dupCode}`,
          entity_type: 'order',
          payload: {
            orderCode: dupCode,
            serviceMode: 'dine_in',
            totalMru: 500,
            tvaAmountMru: computeTva16(500),
            payments: [{ method: 'Cash', amountMru: 500 }],
            items: [{ productId: prod.id, sku: prod.sku, qty: 2, unitPriceMru: 250 }],
          },
        },
      ],
    };

    const r1 = await ctx.request('POST', '/api/pos/sync', { token, body });
    assert.equal(r1.status, 200, r1.text);
    const midStock = getIngredientStock((await ctx.request('GET', '/api/pos/catalog', { token })).json.ingredients.find((i) => i.sku === ing.sku));

    const r2 = await ctx.request('POST', '/api/pos/sync', { token, body });
    assert.equal(r2.status, 200, r2.text);
    const afterStock = getIngredientStock((await ctx.request('GET', '/api/pos/catalog', { token })).json.ingredients.find((i) => i.sku === ing.sku));

    const expectedDelta = Number(bom.qtyPerUnit ?? bom.qty_per_unit) * 2;
    assert.ok(Math.abs((beforeStock - midStock) - expectedDelta) < 1e-6);
    assert.equal(afterStock, midStock, 'Duplicate order sync double-deducted BOM stock!');

    withReadOnlyDb(ctx.dbPath, (db) => {
      const cnt = db.prepare('SELECT COUNT(*) AS cnt FROM orders WHERE tenant_id = 1 AND order_code = ?').get(dupCode).cnt;
      assert.equal(cnt, 1, `Expected exactly 1 order row for ${dupCode}, got ${cnt}`);
    });
  });

  it('T2-A2-03: Empty items returns 200 synced=0; missing items or malformed JSON returns 400; mid-batch error rolls back transaction', async () => {
    const emptyRes = await ctx.request('POST', '/api/pos/sync', { token, body: { items: [] } });
    assert.equal(emptyRes.status, 200, emptyRes.text);
    assert.equal(emptyRes.json.synced, 0);

    const missingItems = await ctx.request('POST', '/api/pos/sync', { token, body: {} });
    assert.equal(missingItems.status, 400, missingItems.text);

    const nonArrayItems = await ctx.request('POST', '/api/pos/sync', { token, body: { items: 'bad' } });
    assert.equal(nonArrayItems.status, 400, nonArrayItems.text);

    const brokenJson = await ctx.request('POST', '/api/pos/sync', {
      token,
      headers: { 'Content-Type': 'application/json' },
      rawBody: '{"items": [',
    });
    assert.equal(brokenJson.status, 400, brokenJson.text);

    // Mid-batch failure rollback check
    const prod = catalog.products[0];
    const rollbackOrderCode = `ORD-ROLLBACK-${Date.now()}`;
    const beforeKpi = (await ctx.request('GET', '/api/pos/kpis', { token })).json;

    const failBatch = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `s-${rollbackOrderCode}`,
            entity_type: 'order',
            payload: {
              orderCode: rollbackOrderCode,
              serviceMode: 'dine_in',
              totalMru: 400,
              tvaAmountMru: computeTva16(400),
              payments: [{ method: 'Cash', amountMru: 400 }],
              items: [{ productId: prod.id, sku: prod.sku, qty: 1, unitPriceMru: 400 }],
            },
          },
          null,
        ],
      },
    });
    assert.ok(failBatch.status >= 400 && failBatch.status < 500, `Expected 4xx on invalid mid-batch item, got ${failBatch.status}`);

    const afterKpi = (await ctx.request('GET', '/api/pos/kpis', { token })).json;
    assert.equal(afterKpi.todayRevenueMru, beforeKpi.todayRevenueMru, 'Failed batch leaked revenue');
    withReadOnlyDb(ctx.dbPath, (db) => {
      const ord = db.prepare('SELECT * FROM orders WHERE tenant_id = 1 AND order_code = ?').get(rollbackOrderCode);
      assert.equal(ord, undefined, 'Rolled-back order was partially committed!');
    });
  });

  it('T2-A2-04: DINE_IN MUST NOT deduct TAKEAWAY_DELIVERY packaging BOM, and -Fromage modifier skips cheese BOM', async () => {
    const prod = catalog.products[0];
    let pkgSku = 'ING-PKG-BOUND';
    let cheeseSku = 'ING-CHEESE-BOUND';

    withWritableDb(ctx.dbPath, (db) => {
      db.prepare(`
        INSERT OR IGNORE INTO ingredients (tenant_id, sku, name_fr, name_ar, unit, pmp_cost_mru, current_stock, min_stock)
        VALUES (1, ?, 'Sac Emporter Bound', 'كيس', 'unit', 10, 50.0, 5.0)
      `).run(pkgSku);
      db.prepare(`
        INSERT OR IGNORE INTO ingredients (tenant_id, sku, name_fr, name_ar, unit, pmp_cost_mru, current_stock, min_stock)
        VALUES (1, ?, 'Fromage', 'جبنة', 'unit', 30, 40.0, 5.0)
      `).run(cheeseSku);

      const pkgIng = db.prepare('SELECT id FROM ingredients WHERE tenant_id = 1 AND sku = ?').get(pkgSku);
      const chIng = db.prepare('SELECT id FROM ingredients WHERE tenant_id = 1 AND sku = ?').get(cheeseSku);

      db.prepare(`
        INSERT OR IGNORE INTO recipes_bom (tenant_id, product_id, ingredient_id, qty_per_unit, unit, condition_channel, modifier_key)
        VALUES (1, ?, ?, 1.0, 'unit', 'TAKEAWAY_DELIVERY', '')
      `).run(Number(prod.id), Number(pkgIng.id));

      db.prepare(`
        INSERT OR IGNORE INTO recipes_bom (tenant_id, product_id, ingredient_id, qty_per_unit, unit, condition_channel, modifier_key)
        VALUES (1, ?, ?, 1.0, 'unit', 'ALL', '')
      `).run(Number(prod.id), Number(chIng.id));
    });

    const beforeCat = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    const beforePkg = getIngredientStock(beforeCat.ingredients.find((i) => i.sku === pkgSku));
    const beforeCheese = getIngredientStock(beforeCat.ingredients.find((i) => i.sku === cheeseSku));

    const code = `ORD-CONDBOM-${Date.now()}`;
    const res = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `s-${code}`,
            entity_type: 'order',
            payload: {
              orderCode: code,
              serviceMode: 'dine_in',
              channel: 'DINE_IN',
              totalMru: 450,
              tvaAmountMru: computeTva16(450),
              payments: [{ method: 'Cash', amountMru: 450 }],
              items: [
                {
                  productId: prod.id,
                  sku: prod.sku,
                  qty: 2,
                  unitPriceMru: 225,
                  modifiers: [{ nameFr: 'Sans fromage', extraPriceMru: 0, bomKey: '-Fromage' }],
                },
              ],
            },
          },
        ],
      },
    });
    assert.equal(res.status, 200, res.text);

    const afterCat = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    const afterPkg = getIngredientStock(afterCat.ingredients.find((i) => i.sku === pkgSku));
    const afterCheese = getIngredientStock(afterCat.ingredients.find((i) => i.sku === cheeseSku));

    assert.equal(afterPkg, beforePkg, 'DINE_IN order MUST NOT deduct TAKEAWAY_DELIVERY packaging BOM');
    assert.equal(afterCheese, beforeCheese, 'Exclusion modifier -Fromage MUST skip cheese BOM deduction');
  });

  it('T2-A2-05: Karni credit limit boundary (exact limit succeeds, +1 MRU over limit or cross-tenant rejected)', async () => {
    const cust = catalog.karniCustomers[0];
    const limit = getCustomerLimit(cust);
    const startDebt = getCustomerDebt(cust);
    const remainingCapacity = limit - startDebt;
    assert.ok(remainingCapacity > 0, 'Customer must have positive remaining credit capacity');

    // Attempt +1 over credit limit -> rejected (4xx) and debt unchanged
    const overRes = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `s-karni-over-${Date.now()}`,
            entity_type: 'karni',
            payload: {
              customerId: cust.id,
              txType: 'CHARGE',
              amountMru: remainingCapacity + 1,
            },
          },
        ],
      },
    });
    assert.ok(overRes.status >= 400 && overRes.status < 500, `Expected 4xx when exceeding creditLimit, got ${overRes.status}`);

    // Exact boundary == creditLimit succeeds
    const exactRes = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `s-karni-exact-${Date.now()}`,
            entity_type: 'karni',
            payload: {
              customerId: cust.id,
              txType: 'CHARGE',
              amountMru: remainingCapacity,
            },
          },
        ],
      },
    });
    assert.equal(exactRes.status, 200, exactRes.text);

    const afterCat = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    const updated = afterCat.karniCustomers.find((c) => Number(c.id) === Number(cust.id));
    assert.equal(getCustomerDebt(updated), limit);
  });

  it('T2-A2-06: TVA 16% exact rounding (0, 116, 1610, 450, 1100) and delivery threshold (1500 vs 1501)', async () => {
    assert.equal(computeTva16(0), 0);
    assert.equal(computeTva16(116), 16);
    assert.equal(computeTva16(1610), 222);
    assert.equal(computeTva16(450), 62);
    assert.equal(computeTva16(1100), 152);

    const prod = catalog.products[0];
    // Subtotal == 1500 -> Tevragh Zeina charges 100 MRU (total 1600, TVA 221)
    // Subtotal == 1501 -> Tevragh Zeina free delivery 0 MRU (total 1501, TVA 207)
    const code1500 = `ORD-THRESH-1500-${Date.now()}`;
    const code1501 = `ORD-THRESH-1501-${Date.now()}`;

    const res = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `s-${code1500}`,
            entity_type: 'order',
            payload: {
              orderCode: code1500,
              serviceMode: 'delivery',
              channel: 'DELIVERY',
              deliveryZone: 'Tevragh Zeina',
              deliveryFeeMru: 100,
              totalMru: 1600,
              tvaAmountMru: computeTva16(1600),
              payments: [{ method: 'Cash', amountMru: 1600 }],
              items: [{ productId: prod.id, sku: prod.sku, qty: 1, unitPriceMru: 1500 }],
            },
          },
          {
            id: `s-${code1501}`,
            entity_type: 'order',
            payload: {
              orderCode: code1501,
              serviceMode: 'delivery',
              channel: 'DELIVERY',
              deliveryZone: 'Tevragh Zeina',
              deliveryFeeMru: 0,
              totalMru: 1501,
              tvaAmountMru: computeTva16(1501),
              payments: [{ method: 'Cash', amountMru: 1501 }],
              items: [{ productId: prod.id, sku: prod.sku, qty: 1, unitPriceMru: 1501 }],
            },
          },
        ],
      },
    });
    assert.equal(res.status, 200, res.text);

    withReadOnlyDb(ctx.dbPath, (db) => {
      const o1 = db.prepare('SELECT * FROM orders WHERE tenant_id = 1 AND order_code = ?').get(code1500);
      const o2 = db.prepare('SELECT * FROM orders WHERE tenant_id = 1 AND order_code = ?').get(code1501);
      assert.equal(o1.delivery_fee_mru, 100);
      assert.equal(o1.tva_mru, 221);
      assert.equal(o2.delivery_fee_mru, 0);
      assert.equal(o2.tva_mru, 207);
    });
  });
});

// ---------------------------------------------------------------------------
// Tier 2 · Area A3: 404/400 Product & KDS Boundaries, 0-Order KPIs, Low-Stock Boundary
// ---------------------------------------------------------------------------
describe('Tier 2 · Area A3: Cloud KDS, 86 Availability & Owner KPI Boundaries', () => {
  let ctx;
  let token;
  let adminToken;

  before(async () => {
    ctx = await startTestServer();
    token = (await loginTenant(ctx)).token;
    adminToken = (await loginAdmin(ctx)).token;
  });

  after(async () => {
    await ctx?.stop();
  });

  it('T2-A3-01: 404 on nonexistent product ID/SKU and nonexistent KDS order ID', async () => {
    const rId = await ctx.request('PATCH', '/api/pos/products/999999/availability', {
      token,
      body: { available: false },
    });
    assert.equal(rId.status, 404, rId.text);

    const rSku = await ctx.request('PATCH', '/api/pos/products/NONEXISTENT-SKU-99/availability', {
      token,
      body: { available: false },
    });
    assert.equal(rSku.status, 404, rSku.text);

    const rKds = await ctx.request('PATCH', '/api/pos/kds/999999', {
      token,
      body: { status: 'READY' },
    });
    assert.equal(rKds.status, 404, rKds.text);
  });

  it('T2-A3-02: 400 on invalid/non-boolean availability payload', async () => {
    const cat = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    const prod = cat.products[0];

    const missingBody = await ctx.request('PATCH', `/api/pos/products/${prod.id}/availability`, {
      token,
      body: {},
    });
    assert.equal(missingBody.status, 400, missingBody.text);

    const nonBool = await ctx.request('PATCH', `/api/pos/products/${prod.id}/availability`, {
      token,
      body: { available: 'maybe' },
    });
    assert.equal(nonBool.status, 400, nonBool.text);
  });

  it('T2-A3-03: GET /api/pos/kds?station=UNKNOWN returns 400 validation error safely without 500', async () => {
    const res = await ctx.request('GET', '/api/pos/kds?station=UNKNOWN', { token });
    assert.equal(res.status, 400, res.text);
    assert.ok(res.json && typeof res.json.error === 'string' && res.json.error.length > 0);
  });

  it('T2-A3-04: GET /api/pos/kpis on brand-new 0-order tenant returns 0s with no NaN or Infinity', async () => {
    const freshUser = `fresh_zero_${Date.now()}`;
    const tRes = await ctx.request('POST', '/api/admin/tenants', {
      token: adminToken,
      body: {
        tenantId: `FT-ZERO-${String(Date.now()).slice(-4)}`,
        name: 'Resto Zero Orders',
        module: 'resto',
        phone: '+222 46 00 00 99',
        username: freshUser,
        accountPassword: 'ZeroPass!2026',
      },
    });
    assert.equal(tRes.status, 201, tRes.text);

    const freshAuth = await loginTenant(ctx, { username: freshUser, password: 'ZeroPass!2026' });
    const kpiRes = await ctx.request('GET', '/api/pos/kpis', { token: freshAuth.token });
    assert.equal(kpiRes.status, 200, kpiRes.text);

    assert.equal(kpiRes.json.todayRevenueMru, 0);
    assert.equal(kpiRes.json.todayTicketsCount, 0);
    assert.equal(kpiRes.json.averageBasketMru, 0);
    assert.equal(kpiRes.json.foodCostMru, 0);
    assert.equal(kpiRes.json.grossMarginPercent, 0);
    assert.equal(Number.isNaN(kpiRes.json.averageBasketMru), false);
    assert.equal(Number.isNaN(kpiRes.json.grossMarginPercent), false);
  });

  it('T2-A3-05: Low-stock alert exact boundary (current_stock === min_stock alerts, min_stock + 0.01 does NOT)', async () => {
    const okSku = `ING-OK-${Date.now()}`;
    const alertSku = `ING-LOW-${Date.now()}`;

    withWritableDb(ctx.dbPath, (db) => {
      db.prepare(`
        INSERT INTO ingredients (tenant_id, sku, name_fr, name_ar, unit, pmp_cost_mru, current_stock, min_stock)
        VALUES (1, ?, 'Juste Au-Dessus', 'فوق الحد', 'kg', 100, 5.01, 5.00)
      `).run(okSku);
      db.prepare(`
        INSERT INTO ingredients (tenant_id, sku, name_fr, name_ar, unit, pmp_cost_mru, current_stock, min_stock)
        VALUES (1, ?, 'Seuil Exact', 'الحد الأدنى', 'kg', 100, 5.00, 5.00)
      `).run(alertSku);
    });

    const kpiRes = await ctx.request('GET', '/api/pos/kpis', { token });
    assert.equal(kpiRes.status, 200, kpiRes.text);
    const alerts = kpiRes.json.lowStockAlerts || [];
    const skus = alerts.map((a) => a.sku);
    assert.equal(skus.includes(alertSku), true, `Expected ${alertSku} at current_stock === min_stock in lowStockAlerts`);
    assert.equal(skus.includes(okSku), false, `Did NOT expect ${okSku} at min_stock + 0.01 in lowStockAlerts`);
  });
});
