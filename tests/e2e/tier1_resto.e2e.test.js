'use strict';

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  FLUTTER_POS_DIR,
  PRISMA_SQLITE_PATH,
  PRISMA_PG_PATH,
  DEFAULT_POS_USER,
  DEFAULT_POS_PASS,
  startTestServer,
  loginAdmin,
  loginTenant,
  computeTva16,
  buildXlsxBuffer,
  decodeJwt,
  withReadOnlyDb,
  withWritableDb,
  listTables,
  getTableColumns,
  parsePrismaSchema,
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
// Area A1 (F01, F02): POS Auth Summary, Catalog & Rich FT-1041 Seeding
// ---------------------------------------------------------------------------
describe('Tier 1 · Area A1: POS Auth, Catalog Bootstrap & Rich FT-1041 Seeding', () => {
  let ctx;
  let tenantAuth;

  before(async () => {
    ctx = await startTestServer();
    tenantAuth = await loginTenant(ctx, {
      username: DEFAULT_POS_USER,
      password: DEFAULT_POS_PASS,
    });
  });

  after(async () => {
    await ctx?.stop();
  });

  it('T1-A1-01: POST /api/auth/login issues tenant JWT and summary with 5 themes (incl. 04) and 7+ payMethods', async () => {
    const decoded = decodeJwt(tenantAuth.token);
    assert.equal(decoded.header.alg, 'HS256');
    assert.equal(decoded.payload.tenantId, 1);
    assert.equal(decoded.payload.tenantCode, 'FT-1041');
    assert.equal(decoded.payload.module, 'resto');
    assert.equal(decoded.payload.role, 'OWNER');

    const t = tenantAuth.tenant;
    assert.equal(t.tenantId ?? t.code, 'FT-1041');
    assert.equal(t.module, 'resto');
    assert.ok(Array.isArray(t.enabledThemes), 'enabledThemes must be an array');
    for (const theme of ['01', '04', '06', '07', '11']) {
      assert.ok(t.enabledThemes.includes(theme), `Missing theme ${theme} in ${JSON.stringify(t.enabledThemes)}`);
    }

    assert.ok(Array.isArray(t.payMethods), 'payMethods must be an array');
    assert.ok(t.payMethods.length >= 7, `Expected >= 7 payMethods, got ${t.payMethods.length}`);
    for (const pm of ['Cash', 'Bankily', 'Masrivi', 'Sedad', 'Bimbank', 'Click', 'Karni']) {
      assert.ok(
        t.payMethods.some((m) => String(m).toLowerCase() === pm.toLowerCase()),
        `Missing payment method ${pm} in ${JSON.stringify(t.payMethods)}`,
      );
    }
  });

  it('T1-A1-02: GET /api/pos/catalog returns Nouakchott deliveryZones and freeDeliveryAboveMru === 1500', async () => {
    const res = await ctx.request('GET', '/api/pos/catalog', { token: tenantAuth.token });
    assert.equal(res.status, 200, res.text);
    assert.equal(res.json.ok, true);
    assert.equal(res.json.tenantId, 1);

    const tenant = res.json.tenant;
    assert.ok(tenant, 'tenant missing from catalog');
    assert.equal(tenant.freeDeliveryAboveMru, 1500);
    assert.ok(Array.isArray(tenant.deliveryZones), 'deliveryZones must be an array');
    assert.ok(tenant.deliveryZones.length >= 4, `Expected >= 4 Nouakchott deliveryZones, got ${tenant.deliveryZones.length}`);

    const fees = tenant.deliveryZones.map((z) => Number(z.feeMru));
    assert.ok(fees.includes(50), `Expected 50 MRU zone in ${JSON.stringify(tenant.deliveryZones)}`);
    assert.ok(fees.includes(100), `Expected 100 MRU zone in ${JSON.stringify(tenant.deliveryZones)}`);
    assert.ok(fees.includes(150), `Expected 150 MRU zone in ${JSON.stringify(tenant.deliveryZones)}`);
    for (const z of tenant.deliveryZones) {
      assert.ok(z.id, 'deliveryZone missing id');
      assert.ok(z.nameFr, 'deliveryZone missing nameFr');
      assert.ok(z.nameAr, 'deliveryZone missing nameAr');
      assert.ok(Number.isFinite(Number(z.feeMru)), 'deliveryZone missing numeric feeMru');
    }
  });

  it('T1-A1-03: GET /api/pos/catalog returns >= 5 categories and >= 15 Mauritanian dishes with FR/AR/EN, icons, stations, isTop & modifiers', async () => {
    const res = await ctx.request('GET', '/api/pos/catalog', { token: tenantAuth.token });
    assert.equal(res.status, 200, res.text);

    const { categories, products } = res.json;
    assert.ok(Array.isArray(categories) && categories.length >= 5, `Expected >= 5 categories, got ${categories?.length}`);
    for (const cat of categories) {
      assert.ok(cat.nameFr || cat.name_fr, 'Category missing nameFr');
      assert.ok(cat.nameAr || cat.name_ar, 'Category missing nameAr');
      assert.ok(typeof cat.icon === 'string' && cat.icon.length > 0, `Category ${cat.nameFr} missing icon`);
    }

    assert.ok(Array.isArray(products) && products.length >= 15, `Expected >= 15 seeded dishes, got ${products?.length}`);
    const stations = new Set();
    let topCount = 0;
    let modCount = 0;
    for (const p of products) {
      assert.ok(p.sku, 'Product missing sku');
      assert.ok(p.nameFr, `Product ${p.sku} missing nameFr`);
      assert.ok(p.nameAr, `Product ${p.sku} missing nameAr`);
      assert.ok(p.nameEn, `Product ${p.sku} missing nameEn`);
      assert.ok(typeof p.icon === 'string' && p.icon.length > 0, `Product ${p.sku} missing icon`);
      assert.ok(Number(p.priceMru ?? p.priceRetail) > 0, `Product ${p.sku} missing positive priceMru`);
      assert.ok(['GRILL', 'KITCHEN', 'BAR'].includes(String(p.kitchenStation).toUpperCase()), `Unexpected station: ${p.kitchenStation}`);
      stations.add(String(p.kitchenStation).toUpperCase());
      assert.equal(typeof p.isTop, 'boolean', `Product ${p.sku} isTop should be boolean`);
      assert.equal(typeof p.isOutOfStock, 'boolean', `Product ${p.sku} isOutOfStock should be boolean`);
      assert.equal(typeof p.available, 'boolean', `Product ${p.sku} available should be boolean`);
      assert.equal(p.available, !p.isOutOfStock, `available must equal !isOutOfStock for ${p.sku}`);
      if (p.isTop) topCount += 1;
      if (Array.isArray(p.modifiers) && p.modifiers.length > 0) modCount += 1;
    }

    assert.ok(stations.has('GRILL'), 'Expected at least 1 GRILL dish');
    assert.ok(stations.has('KITCHEN'), 'Expected at least 1 KITCHEN dish');
    assert.ok(stations.has('BAR'), 'Expected at least 1 BAR item');
    assert.ok(topCount >= 1, 'Expected at least 1 TOP dish');
    assert.ok(modCount >= 1, 'Expected at least 1 dish with modifiers');
  });

  it('T1-A1-04: GET /api/pos/catalog returns diningZones (incl. VIP Khaima), reservationsVip, ingredients, recipesBom, and karniCustomers', async () => {
    const res = await ctx.request('GET', '/api/pos/catalog', { token: tenantAuth.token });
    assert.equal(res.status, 200, res.text);

    const { diningZones, reservationsVip, ingredients, recipesBom, karniCustomers } = res.json;
    assert.ok(Array.isArray(diningZones) && diningZones.length >= 2, 'Expected >= 2 diningZones');
    const vipZone = diningZones.find((z) => z.isVip === true || z.is_vip === 1);
    assert.ok(vipZone, 'Expected a VIP Khaima diningZone');
    assert.ok(Number(vipZone.minSpendMru ?? vipZone.min_spend_mru) >= 3000, 'VIP Khaima should have minSpendMru >= 3000');
    assert.ok(Array.isArray(vipZone.tables) && vipZone.tables.length >= 1, 'VIP zone must expose 2D tables');
    for (const tbl of vipZone.tables) {
      assert.ok(tbl.id || tbl.code, 'Table missing id/code');
      assert.ok(typeof tbl.x === 'number' && typeof tbl.y === 'number', 'Table missing 2D x/y coordinates');
    }

    assert.ok(Array.isArray(reservationsVip) && reservationsVip.length >= 1, 'Expected seeded reservationsVip');
    assert.ok(Array.isArray(ingredients) && ingredients.length >= 2, 'Expected seeded ingredients');
    for (const ing of ingredients) {
      assert.ok(ing.sku, 'Ingredient missing sku');
      assert.ok(Number(ing.pmpCostMru ?? ing.pmp_cost_mru) >= 0, 'Ingredient missing pmpCostMru');
      assert.ok(Number.isFinite(getIngredientStock(ing)), 'Ingredient missing currentStock');
      assert.ok(Number.isFinite(Number(ing.minStock ?? ing.min_stock)), 'Ingredient missing minStock');
    }

    assert.ok(Array.isArray(recipesBom) && recipesBom.length >= 2, 'Expected seeded recipesBom');
    assert.ok(Array.isArray(karniCustomers) && karniCustomers.length >= 1, 'Expected seeded karniCustomers for FT-1041');
    for (const kc of karniCustomers) {
      assert.ok(kc.name || kc.customerName || kc.customer_name, 'Karni customer missing name');
      assert.ok(getCustomerLimit(kc) > 0, 'Karni customer missing positive creditLimitMru');
    }
  });

  it('T1-A1-05: Extended CSV & XLSX import (icon, kitchen_station, is_top, is_out_of_stock, modifiers_json) surfaces in GET /api/pos/catalog', async () => {
    const { token: adminToken } = await loginAdmin(ctx);
    const modifiers = [
      {
        id: 'mg-cuisson',
        nameFr: 'Cuisson',
        nameAr: 'درجة الطهي',
        nameEn: 'Cooking',
        required: false,
        multiSelect: false,
        options: [
          { id: 'opt-bien', nameFr: 'Bien cuit', nameAr: 'ناضج', nameEn: 'Well done', extraPriceMru: 0, bomKey: '' },
          { id: 'opt-mozz', nameFr: 'Extra Mozzarella', nameAr: 'جبنة إضافية', nameEn: 'Extra Mozzarella', extraPriceMru: 60, bomKey: '+Mozzarella' },
        ],
      },
    ];
    const modJson = JSON.stringify(modifiers);

    const csv = [
      'sku;name_fr;name_ar;name_en;category;price_retail;icon;kitchen_station;is_top;is_out_of_stock;modifiers_json',
      `IMP-PIZ-01;Pizza Royale;بيتزا ملكية;Royal Pizza;Pizzas;600;🍕;GRILL;1;0;"${modJson.replace(/"/g, '""')}"`,
    ].join('\n');

    const impCsv = await ctx.request('POST', '/api/admin/tenants/1/catalog/import', {
      token: adminToken,
      body: { filename: 'extended.csv', format: 'csv', csvText: csv },
    });
    assert.equal(impCsv.status, 200, impCsv.text);
    assert.equal(impCsv.json.created, 1);

    const xlsxBuf = buildXlsxBuffer([
      ['sku', 'name_fr', 'name_ar', 'name_en', 'category', 'price_retail', 'icon', 'kitchen_station', 'is_top', 'is_out_of_stock', 'modifiers_json'],
      ['IMP-JUS-01', 'Jus Mangue', 'عصير مانجو', 'Mango Juice', 'Boissons', 180, '🥭', 'BAR', 0, 1, '[]'],
    ]);
    const impXlsx = await ctx.request('POST', '/api/admin/tenants/1/catalog/import', {
      token: adminToken,
      body: { filename: 'extended.xlsx', format: 'xlsx', contentBase64: xlsxBuf.toString('base64') },
    });
    assert.equal(impXlsx.status, 200, impXlsx.text);
    assert.equal(impXlsx.json.created, 1);

    const catRes = await ctx.request('GET', '/api/pos/catalog', { token: tenantAuth.token });
    assert.equal(catRes.status, 200, catRes.text);

    const pizza = catRes.json.products.find((p) => p.sku === 'IMP-PIZ-01');
    assert.ok(pizza, 'Imported CSV product IMP-PIZ-01 missing from /api/pos/catalog');
    assert.equal(pizza.icon, '🍕');
    assert.equal(pizza.kitchenStation, 'GRILL');
    assert.equal(pizza.isTop, true);
    assert.equal(pizza.isOutOfStock, false);
    assert.equal(pizza.available, true);
    assert.ok(Array.isArray(pizza.modifiers) && pizza.modifiers.length === 1);
    assert.equal(pizza.modifiers[0].options[1].extraPriceMru, 60);

    const mango = catRes.json.products.find((p) => p.sku === 'IMP-JUS-01');
    assert.ok(mango, 'Imported XLSX product IMP-JUS-01 missing from /api/pos/catalog');
    assert.equal(mango.icon, '🥭');
    assert.equal(mango.kitchenStation, 'BAR');
    assert.equal(mango.isTop, false);
    assert.equal(mango.isOutOfStock, true);
    assert.equal(mango.available, false);
  });
});

// ---------------------------------------------------------------------------
// Area A2 (F03): Transactional POST /api/pos/sync
// ---------------------------------------------------------------------------
describe('Tier 1 · Area A2: Transactional POST /api/pos/sync', () => {
  let ctx;
  let token;
  let catalog;

  before(async () => {
    ctx = await startTestServer();
    token = (await loginTenant(ctx)).token;
    const catRes = await ctx.request('GET', '/api/pos/catalog', { token });
    assert.equal(catRes.status, 200, catRes.text);
    catalog = catRes.json;
  });

  after(async () => {
    await ctx?.stop();
  });

  it('T1-A2-01: POST /api/pos/sync materializes dine-in order with TVA 16% and Mixte payments in SQLite', async () => {
    const prod = catalog.products[0];
    const netTotal = 1610;
    const tva = computeTva16(netTotal); // 222
    assert.equal(tva, 222);

    const orderCode = `ORD-T1-A2-01-${Date.now()}`;
    const syncRes = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `sync-${orderCode}`,
            entity_type: 'order',
            payload: {
              orderCode,
              order_code: orderCode,
              tableName: 'T-04',
              serviceMode: 'dine_in',
              channel: 'DINE_IN',
              status: 'PAID',
              totalMru: netTotal,
              tvaAmountMru: tva,
              payMethod: 'Mixte',
              payments: [
                { method: 'Cash', amountMru: 610 },
                { method: 'Bankily', amountMru: 500, ref: 'BK-101' },
                { method: 'Bimbank', amountMru: 300, ref: 'BM-102' },
                { method: 'Click', amountMru: 200, ref: 'CK-103' },
              ],
              isTraining: false,
              items: [
                {
                  productId: prod.id,
                  sku: prod.sku,
                  nameFr: prod.nameFr,
                  qty: 2,
                  unitPriceMru: 805,
                  kitchenStation: prod.kitchenStation || 'GRILL',
                  modifiers: [{ nameFr: 'Bien cuit', extraPriceMru: 0, bomKey: '' }],
                },
              ],
            },
          },
        ],
      },
    });

    assert.equal(syncRes.status, 200, syncRes.text);
    assert.equal(syncRes.json.ok, true);
    assert.equal(syncRes.json.tenantId, 1);
    assert.equal(syncRes.json.synced, 1);

    withReadOnlyDb(ctx.dbPath, (db) => {
      const ord = db.prepare('SELECT * FROM orders WHERE tenant_id = 1 AND order_code = ?').get(orderCode);
      assert.ok(ord, 'Order was not materialized in orders table');
      assert.equal(ord.total_mru, 1610);
      assert.equal(ord.tva_mru, 222);
      assert.equal(ord.is_training, 0);
      const payments = JSON.parse(ord.payments_json || '[]');
      assert.equal(payments.length, 4);

      const items = db.prepare('SELECT * FROM order_items WHERE order_id = ?').all(ord.id);
      assert.equal(items.length, 1);
      assert.equal(items[0].qty, 2);

      const audits = db.prepare("SELECT * FROM audit_logs WHERE tenant_id = 1 AND action LIKE 'POS_SYNC_ORDER%'").all();
      assert.ok(audits.length >= 1, 'audit_logs entry missing for POS sync');
    });
  });

  it('T1-A2-02: POST /api/pos/sync deducts base (ALL) and modifier BOM from ingredients.current_stock', async () => {
    // Ensure we have a deterministic product with BOTH an ALL base BOM line and a +Mozzarella modifier BOM line
    let targetProd = catalog.products.find((p) =>
      catalog.recipesBom.some((b) => (b.productId === p.id || b.productSku === p.sku) && (b.conditionChannel ?? 'ALL') === 'ALL' && !b.modifierKey),
    );
    assert.ok(targetProd, 'Expected at least one seeded product with an ALL BOM rule');

    const baseBom = catalog.recipesBom.find(
      (b) => (b.productId === targetProd.id || b.productSku === targetProd.sku) && (b.conditionChannel ?? 'ALL') === 'ALL' && !b.modifierKey,
    );
    const baseIng = catalog.ingredients.find((i) => i.id === baseBom.ingredientId || i.sku === baseBom.ingredientSku);
    assert.ok(baseIng, 'Matching base ingredient missing from catalog');

    // Check if modifier BOM exists; if not, seed +Mozzarella BOM on isolated test DB
    let modBom = catalog.recipesBom.find(
      (b) => (b.productId === targetProd.id || b.productSku === targetProd.sku) && b.modifierKey === '+Mozzarella',
    );
    let modIng;
    if (!modBom) {
      withWritableDb(ctx.dbPath, (db) => {
        db.prepare(`
          INSERT OR IGNORE INTO ingredients (tenant_id, sku, name_fr, name_ar, unit, pmp_cost_mru, current_stock, min_stock)
          VALUES (1, 'ING-MOZZ-T1', 'Mozzarella', 'موزاريلا', 'kg', 400, 10.0, 2.0)
        `).run();
        const ingRow = db.prepare("SELECT * FROM ingredients WHERE tenant_id = 1 AND sku = 'ING-MOZZ-T1'").get();
        db.prepare(`
          INSERT OR IGNORE INTO recipes_bom (tenant_id, product_id, ingredient_id, qty_per_unit, unit, condition_channel, modifier_key)
          VALUES (1, ?, ?, 0.05, 'kg', 'ALL', '+Mozzarella')
        `).run(Number(targetProd.id), Number(ingRow.id));
        modIng = ingRow;
        modBom = { productId: targetProd.id, ingredientId: ingRow.id, qtyPerUnit: 0.05, modifierKey: '+Mozzarella' };
      });
    } else {
      modIng = catalog.ingredients.find((i) => i.id === modBom.ingredientId || i.sku === modBom.ingredientSku);
    }

    const beforeCatalog = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    const beforeBaseStock = getIngredientStock(beforeCatalog.ingredients.find((i) => i.sku === baseIng.sku));
    const beforeModStock = getIngredientStock(beforeCatalog.ingredients.find((i) => i.sku === modIng.sku));

    const qty = 3;
    const orderCode = `ORD-T1-BOM-${Date.now()}`;
    const res = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `sync-${orderCode}`,
            entity_type: 'order',
            payload: {
              orderCode,
              serviceMode: 'dine_in',
              channel: 'DINE_IN',
              totalMru: 900,
              tvaAmountMru: computeTva16(900),
              payments: [{ method: 'Cash', amountMru: 900 }],
              items: [
                {
                  productId: targetProd.id,
                  sku: targetProd.sku,
                  qty,
                  unitPriceMru: 300,
                  modifiers: [{ nameFr: 'Mozzarella', extraPriceMru: 60, bomKey: '+Mozzarella' }],
                },
              ],
            },
          },
        ],
      },
    });
    assert.equal(res.status, 200, res.text);

    const afterCatalog = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    const afterBaseStock = getIngredientStock(afterCatalog.ingredients.find((i) => i.sku === baseIng.sku));
    const afterModStock = getIngredientStock(afterCatalog.ingredients.find((i) => i.sku === modIng.sku));

    const expectedBaseDelta = Number(baseBom.qtyPerUnit ?? baseBom.qty_per_unit) * qty;
    const expectedModDelta = Number(modBom.qtyPerUnit ?? modBom.qty_per_unit) * qty;

    assert.ok(
      Math.abs((beforeBaseStock - afterBaseStock) - expectedBaseDelta) < 1e-6,
      `Expected base stock delta ${expectedBaseDelta}, got ${beforeBaseStock - afterBaseStock}`,
    );
    assert.ok(
      Math.abs((beforeModStock - afterModStock) - expectedModDelta) < 1e-6,
      `Expected modifier stock delta ${expectedModDelta}, got ${beforeModStock - afterModStock}`,
    );
  });

  it('T1-A2-03: TAKEAWAY & DELIVERY orders deduct TAKEAWAY_DELIVERY packaging BOM and persist delivery zone/fee', async () => {
    const prod = catalog.products[0];
    let pkgBom = catalog.recipesBom.find(
      (b) => (b.productId === prod.id || b.productSku === prod.sku) && (b.conditionChannel ?? b.condition_channel) === 'TAKEAWAY_DELIVERY',
    );
    let pkgIng;
    if (!pkgBom) {
      withWritableDb(ctx.dbPath, (db) => {
        db.prepare(`
          INSERT OR IGNORE INTO ingredients (tenant_id, sku, name_fr, name_ar, unit, pmp_cost_mru, current_stock, min_stock)
          VALUES (1, 'ING-BOX-T1', 'Boîte Emporter', 'علبة سفري', 'unit', 15, 200.0, 20.0)
        `).run();
        const ingRow = db.prepare("SELECT * FROM ingredients WHERE tenant_id = 1 AND sku = 'ING-BOX-T1'").get();
        db.prepare(`
          INSERT OR IGNORE INTO recipes_bom (tenant_id, product_id, ingredient_id, qty_per_unit, unit, condition_channel, modifier_key)
          VALUES (1, ?, ?, 1.0, 'unit', 'TAKEAWAY_DELIVERY', '')
        `).run(Number(prod.id), Number(ingRow.id));
        pkgIng = ingRow;
        pkgBom = { productId: prod.id, ingredientId: ingRow.id, qtyPerUnit: 1.0, conditionChannel: 'TAKEAWAY_DELIVERY' };
      });
    } else {
      pkgIng = catalog.ingredients.find((i) => i.id === pkgBom.ingredientId || i.sku === pkgBom.ingredientSku);
    }

    const beforeCat = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    const beforePkgStock = getIngredientStock(beforeCat.ingredients.find((i) => i.sku === pkgIng.sku));

    const delivCode = `ORD-DELIV-${Date.now()}`;
    const res = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `sync-${delivCode}`,
            entity_type: 'order',
            payload: {
              orderCode: delivCode,
              serviceMode: 'delivery',
              channel: 'DELIVERY',
              deliveryZone: 'Tevragh Zeina',
              deliveryFeeMru: 100,
              customerName: 'Moussa',
              customerPhone: '+222 46 99 88 77',
              deliveryAddress: 'Ilot C Rue 12',
              totalMru: 1000,
              tvaAmountMru: computeTva16(1000),
              payments: [{ method: 'Bankily', amountMru: 1000, ref: 'BK-DEL-1' }],
              items: [{ productId: prod.id, sku: prod.sku, qty: 2, unitPriceMru: 450 }],
            },
          },
        ],
      },
    });
    assert.equal(res.status, 200, res.text);

    const afterCat = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    const afterPkgStock = getIngredientStock(afterCat.ingredients.find((i) => i.sku === pkgIng.sku));
    const expectedDelta = Number(pkgBom.qtyPerUnit ?? pkgBom.qty_per_unit) * 2;
    assert.ok(
      Math.abs((beforePkgStock - afterPkgStock) - expectedDelta) < 1e-6,
      `Expected packaging BOM delta ${expectedDelta}, got ${beforePkgStock - afterPkgStock}`,
    );

    withReadOnlyDb(ctx.dbPath, (db) => {
      const ord = db.prepare('SELECT * FROM orders WHERE tenant_id = 1 AND order_code = ?').get(delivCode);
      assert.ok(ord, 'Delivery order not persisted');
      assert.equal(ord.delivery_zone, 'Tevragh Zeina');
      assert.equal(ord.delivery_fee_mru, 100);
    });
  });

  it('T1-A2-04: entity_type remake (REMAKE) persists returns_remakes_comps and double-deducts BOM waste without double revenue', async () => {
    const prod = catalog.products.find((p) =>
      catalog.recipesBom.some((b) => (b.productId === p.id || b.productSku === p.sku) && (b.conditionChannel ?? 'ALL') === 'ALL' && !b.modifierKey),
    );
    const bom = catalog.recipesBom.find(
      (b) => (b.productId === prod.id || b.productSku === prod.sku) && (b.conditionChannel ?? 'ALL') === 'ALL' && !b.modifierKey,
    );
    const ing = catalog.ingredients.find((i) => i.id === bom.ingredientId || i.sku === bom.ingredientSku);

    const beforeStock = getIngredientStock((await ctx.request('GET', '/api/pos/catalog', { token })).json.ingredients.find((i) => i.sku === ing.sku));
    const beforeKpi = (await ctx.request('GET', '/api/pos/kpis', { token })).json;

    const remakeRes = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `sync-remake-${Date.now()}`,
            entity_type: 'remake',
            payload: {
              actionType: 'REMAKE',
              action_type: 'REMAKE',
              productId: prod.id,
              sku: prod.sku,
              qty: 1,
              reason: 'Cuisson insuffisante',
              approvedBy: 'Mariem (9999)',
              amountMru: 0,
            },
          },
        ],
      },
    });
    assert.equal(remakeRes.status, 200, remakeRes.text);

    const afterStock = getIngredientStock((await ctx.request('GET', '/api/pos/catalog', { token })).json.ingredients.find((i) => i.sku === ing.sku));
    const afterKpi = (await ctx.request('GET', '/api/pos/kpis', { token })).json;

    const expectedWaste = Number(bom.qtyPerUnit ?? bom.qty_per_unit);
    assert.ok(Math.abs((beforeStock - afterStock) - expectedWaste) < 1e-6, `Expected remake waste ${expectedWaste}, got ${beforeStock - afterStock}`);
    assert.equal(afterKpi.todayRevenueMru, beforeKpi.todayRevenueMru, 'REMAKE must NOT increase revenue');

    withReadOnlyDb(ctx.dbPath, (db) => {
      const rows = db.prepare("SELECT * FROM returns_remakes_comps WHERE tenant_id = 1 AND reason = 'Cuisson insuffisante'").all();
      assert.equal(rows.length, 1);
      assert.equal(rows[0].type, 'REMAKE');
    });
  });

  it('T1-A2-05: entity_type closing_z and karni (CHARGE & REPAYMENT) persist closings and update Karni debt', async () => {
    const cust = catalog.karniCustomers[0];
    const startDebt = getCustomerDebt(cust);

    const res = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `sync-karni-chg-${Date.now()}`,
            entity_type: 'karni',
            payload: {
              customerId: cust.id,
              customer_id: cust.id,
              txType: 'CHARGE',
              tx_type: 'CHARGE',
              amountMru: 500,
              payMethod: 'Karni',
              notes: 'Crédit table T-02',
            },
          },
          {
            id: `sync-karni-rep-${Date.now()}`,
            entity_type: 'karni',
            payload: {
              customerId: cust.id,
              customer_id: cust.id,
              txType: 'REPAYMENT',
              tx_type: 'REPAYMENT',
              amountMru: 200,
              payMethod: 'Bankily',
              ref: 'BK-KARNI-200',
              notes: 'Acompte reçu',
            },
          },
          {
            id: `sync-z-${Date.now()}`,
            entity_type: 'closing_z',
            payload: {
              expectedCashMru: 1510,
              countedCashMru: 1500,
              digitalMru: 2000,
              varianceMru: -10,
              approvedBy: 'Ahmed Ould Salem',
              notes: 'Clôture soir',
            },
          },
        ],
      },
    });
    assert.equal(res.status, 200, res.text);
    assert.equal(res.json.synced, 3);

    const afterCat = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    const updatedCust = afterCat.karniCustomers.find((c) => Number(c.id) === Number(cust.id));
    assert.equal(getCustomerDebt(updatedCust), startDebt + 300);

    withReadOnlyDb(ctx.dbPath, (db) => {
      const closings = db.prepare("SELECT * FROM cash_closings_z WHERE tenant_id = 1 AND notes = 'Clôture soir'").all();
      assert.equal(closings.length, 1);
      assert.equal(closings[0].counted_mru, 1500);
      assert.equal(closings[0].expected_mru, 1510);

      const txs = db.prepare('SELECT * FROM karni_transactions WHERE tenant_id = 1 AND customer_id = ?').all(Number(cust.id));
      assert.ok(txs.length >= 2);
    });
  });
});

// ---------------------------------------------------------------------------
// Area A3 (F04, R4, R5): KDS, 86 Rupture, KPIs, Training Isolation & Web Assets
// ---------------------------------------------------------------------------
describe('Tier 1 · Area A3: Cloud KDS, 86 Rupture, Owner KPIs, Training Isolation & Web Assets', () => {
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

  it('T1-A3-01: PATCH /api/pos/products/:id/availability toggles 86 out-of-stock by id and updates catalog', async () => {
    const prod = catalog.products[0];
    const patchRes = await ctx.request('PATCH', `/api/pos/products/${prod.id}/availability`, {
      token,
      body: { available: false },
    });
    assert.equal(patchRes.status, 200, patchRes.text);
    assert.equal(patchRes.json.ok, true);
    assert.equal(patchRes.json.available, false);
    assert.equal(patchRes.json.isOutOfStock, true);

    const catRes = await ctx.request('GET', '/api/pos/catalog', { token });
    const updated = catRes.json.products.find((p) => String(p.id) === String(prod.id));
    assert.equal(updated.available, false);
    assert.equal(updated.isOutOfStock, true);
  });

  it('T1-A3-02: PATCH /api/pos/products/:sku/availability restores availability by SKU', async () => {
    const prod = catalog.products[0];
    const patchRes = await ctx.request('PATCH', `/api/pos/products/${encodeURIComponent(prod.sku)}/availability`, {
      token,
      body: { isOutOfStock: false },
    });
    assert.equal(patchRes.status, 200, patchRes.text);
    assert.equal(patchRes.json.ok, true);
    assert.equal(patchRes.json.available, true);
    assert.equal(patchRes.json.isOutOfStock, false);

    const catRes = await ctx.request('GET', '/api/pos/catalog', { token });
    const restored = catRes.json.products.find((p) => p.sku === prod.sku);
    assert.equal(restored.available, true);
    assert.equal(restored.isOutOfStock, false);
  });

  it('T1-A3-03: GET /api/pos/kds filters by station and computes GREEN/ORANGE/RED urgency timers', async () => {
    const grillProd = catalog.products.find((p) => p.kitchenStation === 'GRILL') || catalog.products[0];
    const barProd = catalog.products.find((p) => p.kitchenStation === 'BAR') || catalog.products[1];
    const now = Date.now();
    const orderGreen = `ORD-KDS-GRN-${now}`;
    const orderRed = `ORD-KDS-RED-${now}`;

    const syncRes = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `sync-${orderGreen}`,
            entity_type: 'order',
            payload: {
              orderCode: orderGreen,
              tableName: 'T-08',
              serviceMode: 'dine_in',
              channel: 'DINE_IN',
              status: 'KDS_PREP',
              totalMru: 600,
              tvaAmountMru: computeTva16(600),
              payMethod: 'Cash',
              payments: [{ method: 'Cash', amountMru: 600 }],
              kdsSentAt: new Date(now - 3 * 60_000).toISOString(),
              items: [
                { productId: grillProd.id, sku: grillProd.sku, qty: 1, unitPriceMru: 450, kitchenStation: 'GRILL' },
                { productId: barProd.id, sku: barProd.sku, qty: 1, unitPriceMru: 150, kitchenStation: 'BAR' },
              ],
            },
          },
          {
            id: `sync-${orderRed}`,
            entity_type: 'order',
            payload: {
              orderCode: orderRed,
              tableName: 'T-09',
              serviceMode: 'dine_in',
              status: 'KDS_PREP',
              totalMru: 450,
              tvaAmountMru: computeTva16(450),
              kdsSentAt: new Date(now - 25 * 60_000).toISOString(),
              items: [{ productId: grillProd.id, sku: grillProd.sku, qty: 1, unitPriceMru: 450, kitchenStation: 'GRILL' }],
            },
          },
        ],
      },
    });
    assert.equal(syncRes.status, 200, syncRes.text);

    const kdsAll = await ctx.request('GET', '/api/pos/kds?station=ALL', { token });
    assert.equal(kdsAll.status, 200, kdsAll.text);
    const tickets = kdsAll.json.tickets || kdsAll.json.orders || [];
    const greenTkt = tickets.find((t) => (t.orderCode || t.order_code) === orderGreen);
    const redTkt = tickets.find((t) => (t.orderCode || t.order_code) === orderRed);
    assert.ok(greenTkt, `KDS ticket ${orderGreen} not returned in GET /api/pos/kds`);
    assert.ok(redTkt, `KDS ticket ${orderRed} not returned in GET /api/pos/kds`);
    assert.equal(greenTkt.urgency, 'GREEN');
    assert.equal(redTkt.urgency, 'RED');

    const kdsGrill = await ctx.request('GET', '/api/pos/kds?station=GRILL', { token });
    assert.equal(kdsGrill.status, 200, kdsGrill.text);
    const grillTicket = (kdsGrill.json.tickets || kdsGrill.json.orders || []).find(
      (t) => (t.orderCode || t.order_code) === orderGreen,
    );
    assert.ok(grillTicket, 'Ticket missing when filtering ?station=GRILL');
    for (const li of grillTicket.items || []) {
      assert.equal(String(li.station || li.kitchenStation || li.kitchen_station).toUpperCase(), 'GRILL');
    }

    // Clear both so subsequent tests start clean
    await ctx.request('PATCH', `/api/pos/kds/${greenTkt.orderId ?? greenTkt.id}`, { token, body: { status: 'READY', station: 'ALL' } });
    await ctx.request('PATCH', `/api/pos/kds/${redTkt.orderId ?? redTkt.id}`, { token, body: { status: 'READY', station: 'ALL' } });
  });

  it('T1-A3-04: PATCH /api/pos/kds/:orderId marks station READY incrementally then clears active queue', async () => {
    const grillProd = catalog.products.find((p) => p.kitchenStation === 'GRILL') || catalog.products[0];
    const barProd = catalog.products.find((p) => p.kitchenStation === 'BAR') || catalog.products[1];
    const orderCode = `ORD-KDS-RDY-${Date.now()}`;

    const syncRes = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `sync-${orderCode}`,
            entity_type: 'order',
            payload: {
              orderCode,
              tableName: 'T-10',
              serviceMode: 'dine_in',
              status: 'KDS_PREP',
              totalMru: 600,
              tvaAmountMru: computeTva16(600),
              items: [
                { productId: grillProd.id, sku: grillProd.sku, qty: 1, unitPriceMru: 450, kitchenStation: 'GRILL' },
                { productId: barProd.id, sku: barProd.sku, qty: 1, unitPriceMru: 150, kitchenStation: 'BAR' },
              ],
            },
          },
        ],
      },
    });
    assert.equal(syncRes.status, 200, syncRes.text);

    const kdsAll = await ctx.request('GET', '/api/pos/kds?station=ALL', { token });
    const ticket = (kdsAll.json.tickets || kdsAll.json.orders || []).find(
      (t) => (t.orderCode || t.order_code) === orderCode,
    );
    assert.ok(ticket, `KDS ticket ${orderCode} not found`);
    const orderId = ticket.orderId ?? ticket.id;

    // Mark GRILL ready -> BAR still active
    const readyGrill = await ctx.request('PATCH', `/api/pos/kds/${orderId}`, {
      token,
      body: { status: 'READY', station: 'GRILL' },
    });
    assert.equal(readyGrill.status, 200, readyGrill.text);
    assert.equal(readyGrill.json.ok, true);
    assert.equal(readyGrill.json.remainingPendingItems, 1);

    // Mark BAR ready -> ticket fully cleared from active KDS
    const readyBar = await ctx.request('PATCH', `/api/pos/kds/${orderId}`, {
      token,
      body: { status: 'READY', station: 'BAR' },
    });
    assert.equal(readyBar.status, 200, readyBar.text);

    const kdsAfter = await ctx.request('GET', '/api/pos/kds?station=ALL', { token });
    const stillActive = (kdsAfter.json.tickets || kdsAfter.json.orders || []).find(
      (t) => (t.orderCode || t.order_code) === orderCode,
    );
    assert.equal(stillActive, undefined, 'Fully READY KDS ticket should leave active queue');
  });

  it('T1-A3-05: GET /api/pos/kpis returns live metrics + 27 SQLite tables + Prisma schema parity', async () => {
    const res = await ctx.request('GET', '/api/pos/kpis', { token });
    assert.equal(res.status, 200, res.text);
    assert.equal(res.json.ok, true);
    assert.ok(Number.isFinite(Number(res.json.todayRevenueMru)));
    assert.ok(Number.isInteger(Number(res.json.todayTicketsCount)));
    assert.ok(Number.isFinite(Number(res.json.averageBasketMru)));
    assert.ok(Number.isFinite(Number(res.json.foodCostMru)));
    assert.ok(Number.isFinite(Number(res.json.grossMarginPercent)));
    assert.ok(Array.isArray(res.json.lowStockAlerts));
    assert.ok(res.json.paymentBreakdown && typeof res.json.paymentBreakdown === 'object');
    for (const key of ['cash', 'bankily', 'masrivi', 'sedad', 'bimbank', 'click', 'karni']) {
      assert.ok(key in res.json.paymentBreakdown, `paymentBreakdown missing ${key}`);
    }

    // 27-table SQLite parity & Prisma parity
    withReadOnlyDb(ctx.dbPath, (db) => {
      const tables = listTables(db);
      assert.equal(tables.length, 27, `Expected 27 SQLite tables, got ${tables.length}: ${tables.join(', ')}`);

      const sqliteSchema = parsePrismaSchema(PRISMA_SQLITE_PATH);
      const pgSchema = parsePrismaSchema(PRISMA_PG_PATH);
      assert.equal(sqliteSchema.balancedBraces, true);
      assert.equal(pgSchema.balancedBraces, true);
      assert.equal(sqliteSchema.models.size, 27);
      assert.equal(pgSchema.models.size, 27);

      const orderCols = new Set(getTableColumns(db, 'orders').map((c) => c.name));
      for (const col of ['service_mode', 'delivery_zone', 'delivery_fee_mru', 'tva_mru', 'payments_json', 'is_training']) {
        assert.ok(orderCols.has(col), `orders table missing column ${col}`);
      }
    });
  });

  it('T1-A3-06: isTraining: true sync logs audit trail while keeping real orders, BOM, KPIs, KDS & Karni 100% isolated', async () => {
    const beforeKpis = (await ctx.request('GET', '/api/pos/kpis', { token })).json;
    const beforeCat = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    const prod = beforeCat.products[0];
    const karniCust = beforeCat.karniCustomers[0];
    const beforeKarniDebt = getCustomerDebt(karniCust);
    const beforeStocks = new Map(beforeCat.ingredients.map((i) => [i.sku, getIngredientStock(i)]));

    const trainCode = `ORD-TRAIN-${Date.now()}`;
    const res = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `sync-${trainCode}`,
            entity_type: 'order',
            payload: {
              orderCode: trainCode,
              serviceMode: 'dine_in',
              status: 'KDS_PREP',
              totalMru: 5000,
              tvaAmountMru: computeTva16(5000),
              payMethod: 'Cash',
              payments: [{ method: 'Cash', amountMru: 5000 }],
              isTraining: true,
              items: [{ productId: prod.id, sku: prod.sku, qty: 10, unitPriceMru: 500 }],
            },
          },
          {
            id: `sync-train-karni-${Date.now()}`,
            entity_type: 'karni',
            payload: {
              customerId: karniCust.id,
              txType: 'CHARGE',
              amountMru: 2000,
              isTraining: true,
            },
          },
          {
            id: `sync-train-z-${Date.now()}`,
            entity_type: 'closing_z',
            payload: {
              expectedCashMru: 5000,
              countedCashMru: 5000,
              digitalMru: 0,
              varianceMru: 0,
              is_training: true,
              notes: 'TRAINING_Z_ISOLATED',
            },
          },
        ],
      },
    });
    assert.equal(res.status, 200, res.text);
    assert.equal(res.json.ok, true);

    const afterKpis = (await ctx.request('GET', '/api/pos/kpis', { token })).json;
    assert.equal(afterKpis.todayRevenueMru, beforeKpis.todayRevenueMru, 'Training order mutated todayRevenueMru');
    assert.equal(afterKpis.todayTicketsCount, beforeKpis.todayTicketsCount, 'Training order mutated todayTicketsCount');
    assert.equal(afterKpis.foodCostMru, beforeKpis.foodCostMru, 'Training order mutated foodCostMru');

    const afterKds = (await ctx.request('GET', '/api/pos/kds?station=ALL', { token })).json;
    const leakedKds = (afterKds.tickets || afterKds.orders || []).find(
      (t) => (t.orderCode || t.order_code) === trainCode,
    );
    assert.equal(leakedKds, undefined, 'Training order leaked into /api/pos/kds');

    const afterCat = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    for (const ing of afterCat.ingredients) {
      assert.equal(getIngredientStock(ing), beforeStocks.get(ing.sku), `Training order mutated ingredient ${ing.sku}`);
    }
    const afterKarni = afterCat.karniCustomers.find((c) => Number(c.id) === Number(karniCust.id));
    assert.equal(getCustomerDebt(afterKarni), beforeKarniDebt, 'Training Karni charge mutated real balanceDueMru');

    withReadOnlyDb(ctx.dbPath, (db) => {
      const realTrainOrd = db.prepare('SELECT * FROM orders WHERE tenant_id = 1 AND order_code = ?').get(trainCode);
      assert.equal(realTrainOrd, undefined, 'Training order must NOT be inserted into real orders table');
      const trainZ = db.prepare("SELECT * FROM cash_closings_z WHERE tenant_id = 1 AND notes = 'TRAINING_Z_ISOLATED'").get();
      assert.equal(trainZ, undefined, 'Training Z-closing must NOT be inserted into cash_closings_z');
    });
  });

  it('T1-A3-07: Static check — apps/fulltek_pos pubspec.yaml has zero third-party deps and web assets use Full·Tek with zero CDN links', () => {
    const pubspec = fs.readFileSync(path.join(FLUTTER_POS_DIR, 'pubspec.yaml'), 'utf8');
    // Parse dependencies block cleanly
    const depsBlock = pubspec.split(/^dependencies:\s*$/m)[1]?.split(/^dev_dependencies:\s*$/m)[0] || '';
    assert.ok(depsBlock.includes('flutter:'), 'pubspec.yaml missing flutter SDK dependency');
    for (const forbidden of ['http:', 'dio:', 'provider:', 'riverpod:', 'bloc:', 'sqflite:', 'playwright', 'puppeteer', 'selenium']) {
      assert.equal(depsBlock.includes(forbidden), false, `Forbidden third-party dep found in pubspec.yaml: ${forbidden}`);
    }

    const indexHtml = fs.readFileSync(path.join(FLUTTER_POS_DIR, 'web', 'index.html'), 'utf8');
    const manifestJson = JSON.parse(fs.readFileSync(path.join(FLUTTER_POS_DIR, 'web', 'manifest.json'), 'utf8'));

    assert.ok(indexHtml.includes('Full·Tek'), 'web/index.html missing Full·Tek branding');
    assert.ok(String(manifestJson.name || '').includes('Full·Tek'), 'web/manifest.json missing Full·Tek branding');
    assert.equal(/https?:\/\/[^\s"'<>]+\.(js|css)/i.test(indexHtml), false, 'web/index.html must not reference external CDN scripts/stylesheets');
  });
});
