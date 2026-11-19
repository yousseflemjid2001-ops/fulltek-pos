'use strict';

const { describe, it, afterEach } = require('node:test');
const assert = require('node:assert/strict');

const {
  DEFAULT_POS_USER,
  DEFAULT_POS_PASS,
  startTestServer,
  loginAdmin,
  loginTenant,
  computeTva16,
  buildXlsxBuffer,
  withReadOnlyDb,
  withWritableDb,
} = require('./helpers');

function getCustomerDebt(c) {
  return Number(c.balanceDueMru ?? c.currentDebtMru ?? c.current_debt_mru ?? 0);
}

function getIngredientStock(ing) {
  return Number(ing.currentStock ?? ing.current_stock ?? 0);
}

describe('Tier 3 · Resto POS Cross-Feature API Combinations', () => {
  let ctx = null;

  afterEach(async () => {
    if (ctx) {
      await ctx.stop();
      ctx = null;
    }
  });

  it('T3-06: Catalog + 86 toggle + POS sync + KDS station filter & READY + KPIs + SQLite consistency', async () => {
    ctx = await startTestServer();
    const { token } = await loginTenant(ctx);

    const cat0 = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    const grillDish = cat0.products.find((p) => p.kitchenStation === 'GRILL') || cat0.products[0];
    const barDish = cat0.products.find((p) => p.kitchenStation === 'BAR') || cat0.products[1];

    // 1. Mark grillDish out of stock (86) -> verify catalog reflects it -> restore it
    const offRes = await ctx.request('PATCH', `/api/pos/products/${grillDish.id}/availability`, {
      token,
      body: { available: false },
    });
    assert.equal(offRes.status, 200, offRes.text);
    const catOff = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    assert.equal(catOff.products.find((p) => String(p.id) === String(grillDish.id)).available, false);

    const onRes = await ctx.request('PATCH', `/api/pos/products/${encodeURIComponent(grillDish.sku)}/availability`, {
      token,
      body: { isOutOfStock: false },
    });
    assert.equal(onRes.status, 200, onRes.text);

    // 2. Sync multi-station order
    const orderCode = `ORD-T3-06-${Date.now()}`;
    const total = Number(grillDish.priceMru) + Number(barDish.priceMru);
    const tva = computeTva16(total);
    const syncRes = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `sync-${orderCode}`,
            entity_type: 'order',
            payload: {
              orderCode,
              tableName: 'T-05',
              serviceMode: 'dine_in',
              channel: 'DINE_IN',
              status: 'KDS_PREP',
              totalMru: total,
              tvaAmountMru: tva,
              payMethod: 'Bankily',
              payments: [{ method: 'Bankily', amountMru: total, ref: 'BK-T306' }],
              items: [
                { productId: grillDish.id, sku: grillDish.sku, qty: 1, unitPriceMru: grillDish.priceMru, kitchenStation: 'GRILL' },
                { productId: barDish.id, sku: barDish.sku, qty: 1, unitPriceMru: barDish.priceMru, kitchenStation: 'BAR' },
              ],
            },
          },
        ],
      },
    });
    assert.equal(syncRes.status, 200, syncRes.text);

    // 3. KDS station filter + mark READY per station
    const kdsRes = await ctx.request('GET', '/api/pos/kds?station=GRILL', { token });
    assert.equal(kdsRes.status, 200, kdsRes.text);
    const ticket = (kdsRes.json.tickets || kdsRes.json.orders || []).find(
      (t) => (t.orderCode || t.order_code) === orderCode,
    );
    assert.ok(ticket, 'Order missing from KDS GRILL');
    const orderId = ticket.orderId ?? ticket.id;

    assert.equal((await ctx.request('PATCH', `/api/pos/kds/${orderId}`, { token, body: { status: 'READY', station: 'GRILL' } })).status, 200);
    assert.equal((await ctx.request('PATCH', `/api/pos/kds/${orderId}`, { token, body: { status: 'READY', station: 'BAR' } })).status, 200);

    // Settle order to PAID after KDS completion
    const payRes = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `sync-pay-${orderCode}`,
            entity_type: 'order',
            payload: {
              orderCode,
              status: 'PAID',
              totalMru: total,
              tvaAmountMru: tva,
              payMethod: 'Bankily',
              payments: [{ method: 'Bankily', amountMru: total, ref: 'BK-T306' }],
            },
          },
        ],
      },
    });
    assert.equal(payRes.status, 200, payRes.text);

    // 4. KPIs + SQLite parity
    const kpis = (await ctx.request('GET', '/api/pos/kpis', { token })).json;
    assert.equal(kpis.todayRevenueMru, total);
    assert.equal(kpis.todayTicketsCount, 1);
    assert.equal(kpis.paymentBreakdown.bankily, total);

    withReadOnlyDb(ctx.dbPath, (db) => {
      const ord = db.prepare('SELECT * FROM orders WHERE order_code = ?').get(orderCode);
      assert.ok(ord);
      assert.equal(ord.tva_mru, tva);
      const items = db.prepare('SELECT * FROM order_items WHERE order_id = ?').all(ord.id);
      assert.equal(items.length, 2);
      assert.ok(items.every((i) => i.kds_status === 'READY'));
    });
  });

  it('T3-09: Mixed batch (real order + training order + REMAKE + Karni charge) preserves KPIs, KDS & waste BOM', async () => {
    ctx = await startTestServer();
    const { token } = await loginTenant(ctx);
    const cat = (await ctx.request('GET', '/api/pos/catalog', { token })).json;

    const bom = cat.recipesBom.find((b) => (b.conditionChannel ?? 'ALL') === 'ALL' && !b.modifierKey);
    const prod = cat.products.find((p) => p.id === bom.productId || p.sku === bom.productSku);
    const ing = cat.ingredients.find((i) => i.id === bom.ingredientId || i.sku === bom.ingredientSku);
    const karniCust = cat.karniCustomers[0];
    const karniCust2 = cat.karniCustomers[1] || karniCust;

    const startStock = getIngredientStock(ing);
    const startDebt = getCustomerDebt(karniCust2);

    const realCode = `ORD-T3-09-REAL-${Date.now()}`;
    const trainCode = `ORD-T3-09-TRN-${Date.now()}`;

    const syncRes = await ctx.request('POST', '/api/pos/sync', {
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
              totalMru: 500,
              tvaAmountMru: computeTva16(500),
              payments: [{ method: 'Cash', amountMru: 500 }],
              isTraining: false,
              items: [{ productId: prod.id, sku: prod.sku, qty: 2, unitPriceMru: 250, kdsStatus: 'PENDING' }],
            },
          },
          {
            id: `s-${trainCode}`,
            entity_type: 'order',
            payload: {
              orderCode: trainCode,
              serviceMode: 'dine_in',
              status: 'KDS_PREP',
              totalMru: 9900,
              tvaAmountMru: computeTva16(9900),
              payments: [{ method: 'Cash', amountMru: 9900 }],
              isTraining: true,
              items: [{ productId: prod.id, sku: prod.sku, qty: 20, unitPriceMru: 495 }],
            },
          },
          {
            id: `s-remake-${Date.now()}`,
            entity_type: 'remake',
            payload: {
              actionType: 'REMAKE',
              productId: prod.id,
              sku: prod.sku,
              qty: 1,
              reason: 'Tombé en cuisine',
              approvedBy: 'Mariem (9999)',
              amountMru: 0,
            },
          },
          {
            id: `s-karni-${Date.now()}`,
            entity_type: 'karni',
            payload: {
              customerId: karniCust2.id,
              txType: 'CHARGE',
              amountMru: 500,
            },
          },
        ],
      },
    });
    assert.equal(syncRes.status, 200, syncRes.text);
    assert.equal(syncRes.json.synced, 4);

    const kpis = (await ctx.request('GET', '/api/pos/kpis', { token })).json;
    assert.equal(kpis.todayRevenueMru, 500, 'KPI revenue must count only real order');
    assert.equal(kpis.todayTicketsCount, 1);
    assert.equal(kpis.paymentBreakdown.cash, 500);

    const kds = (await ctx.request('GET', '/api/pos/kds?station=ALL', { token })).json;
    const codes = (kds.tickets || kds.orders || []).map((t) => t.orderCode || t.order_code);
    assert.equal(codes.includes(realCode), true);
    assert.equal(codes.includes(trainCode), false);

    const catAfter = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    const afterStock = getIngredientStock(catAfter.ingredients.find((i) => i.sku === ing.sku));
    // 2 units from real order + 1 unit from REMAKE = 3 units * qtyPerUnit (training 20 units excluded!)
    const expectedUsed = Number(bom.qtyPerUnit ?? bom.qty_per_unit) * 3;
    assert.ok(Math.abs((startStock - afterStock) - expectedUsed) < 1e-6);

    const afterCust = catAfter.karniCustomers.find((c) => Number(c.id) === Number(karniCust2.id));
    assert.equal(getCustomerDebt(afterCust), startDebt + 500);
  });

  it('T3-11: Delivery threshold crossed via paid modifier (+60 Mozzarella: 1450 -> 1510 > 1500 drops Ksar 150 fee to 0)', async () => {
    ctx = await startTestServer();
    const { token } = await loginTenant(ctx);
    const cat = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    const prod = cat.products[0];

    const codeUnder = `ORD-T3-11-UNDER-${Date.now()}`;
    const codeOver = `ORD-T3-11-OVER-${Date.now()}`;

    // Order A: 1450 <= 1500 -> Ksar fee 150 -> total 1600, TVA = 221
    // Order B: 1450 + 60 modifier = 1510 > 1500 -> fee 0 -> total 1510, TVA = 208
    const res = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `s-${codeUnder}`,
            entity_type: 'order',
            payload: {
              orderCode: codeUnder,
              serviceMode: 'delivery',
              channel: 'DELIVERY',
              deliveryZone: 'Ksar / Socogim',
              deliveryFeeMru: 150,
              totalMru: 1600,
              tvaAmountMru: computeTva16(1600),
              payments: [{ method: 'Click', amountMru: 1600, ref: 'CLK-11A' }],
              items: [{ productId: prod.id, sku: prod.sku, qty: 1, unitPriceMru: 1450 }],
            },
          },
          {
            id: `s-${codeOver}`,
            entity_type: 'order',
            payload: {
              orderCode: codeOver,
              serviceMode: 'delivery',
              channel: 'DELIVERY',
              deliveryZone: 'Ksar / Socogim',
              deliveryFeeMru: 0,
              totalMru: 1510,
              tvaAmountMru: computeTva16(1510),
              payments: [{ method: 'Click', amountMru: 1510, ref: 'CLK-11B' }],
              items: [
                {
                  productId: prod.id,
                  sku: prod.sku,
                  qty: 1,
                  unitPriceMru: 1510,
                  modifiers: [{ nameFr: 'Mozzarella', extraPriceMru: 60, bomKey: '+Mozzarella' }],
                },
              ],
            },
          },
        ],
      },
    });
    assert.equal(res.status, 200, res.text);

    const kpis = (await ctx.request('GET', '/api/pos/kpis', { token })).json;
    assert.equal(kpis.todayRevenueMru, 3110);
    assert.equal(kpis.paymentBreakdown.click, 3110);

    withReadOnlyDb(ctx.dbPath, (db) => {
      const oUnder = db.prepare('SELECT * FROM orders WHERE order_code = ?').get(codeUnder);
      const oOver = db.prepare('SELECT * FROM orders WHERE order_code = ?').get(codeOver);
      assert.equal(oUnder.delivery_fee_mru, 150);
      assert.equal(oUnder.tva_mru, 221);
      assert.equal(oOver.delivery_fee_mru, 0);
      assert.equal(oOver.tva_mru, 208);
    });
  });

  it('T3-12: Offline queue catchup batch (order + remake + karni + closing_z + stock_86) reconciles KPIs & catalog', async () => {
    ctx = await startTestServer();
    const { token } = await loginTenant(ctx);
    const cat0 = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    const prod = cat0.products[0];
    const prod86 = cat0.products[1];
    const cust = cat0.karniCustomers[0];
    const startDebt = getCustomerDebt(cust);

    const batchRes = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `off-ord-1-${Date.now()}`,
            entity_type: 'order',
            payload: {
              orderCode: `ORD-OFF-1-${Date.now()}`,
              serviceMode: 'takeaway',
              channel: 'TAKEAWAY',
              totalMru: 800,
              tvaAmountMru: computeTva16(800),
              payments: [
                { method: 'Masrivi', amountMru: 500, ref: 'MS-OFF-1' },
                { method: 'Sedad', amountMru: 300, ref: 'SD-OFF-1' },
              ],
              items: [{ productId: prod.id, sku: prod.sku, qty: 2, unitPriceMru: 400 }],
            },
          },
          {
            id: `off-karni-${Date.now()}`,
            entity_type: 'karni',
            payload: {
              customerId: cust.id,
              txType: 'REPAYMENT',
              amountMru: 300,
              payMethod: 'Cash',
            },
          },
          {
            id: `off-86-${Date.now()}`,
            entity_type: 'stock_86',
            payload: {
              productId: prod86.id,
              sku: prod86.sku,
              available: false,
              isOutOfStock: true,
            },
          },
          {
            id: `off-z-${Date.now()}`,
            entity_type: 'closing_z',
            payload: {
              expectedCashMru: 0,
              countedCashMru: 0,
              digitalMru: 800,
              varianceMru: 0,
              approvedBy: 'Aïcha',
              notes: 'Reprise offline',
            },
          },
        ],
      },
    });
    assert.equal(batchRes.status, 200, batchRes.text);
    assert.equal(batchRes.json.synced, 4);

    const kpis = (await ctx.request('GET', '/api/pos/kpis', { token })).json;
    assert.equal(kpis.todayRevenueMru, 800);
    assert.equal(kpis.paymentBreakdown.masrivi, 500);
    assert.equal(kpis.paymentBreakdown.sedad, 300);

    const cat1 = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    assert.equal(cat1.products.find((p) => String(p.id) === String(prod86.id)).available, false);
    assert.equal(getCustomerDebt(cat1.karniCustomers.find((c) => Number(c.id) === Number(cust.id))), startDebt - 300);
  });

  it('T3-13: Extended XLSX import (icon, kitchen_station, is_top, modifiers_json) -> GET /api/pos/catalog -> order & KDS', async () => {
    ctx = await startTestServer();
    const { token: adminToken } = await loginAdmin(ctx);
    const { token: tenantToken } = await loginTenant(ctx);

    const modJson = JSON.stringify([
      {
        id: 'mg-sauce',
        nameFr: 'Sauce',
        nameAr: 'صلصة',
        nameEn: 'Sauce',
        required: false,
        multiSelect: true,
        options: [{ id: 'opt-alg', nameFr: 'Sauce Algérienne', nameAr: 'صلصة جزائرية', nameEn: 'Algerian Sauce', extraPriceMru: 20, bomKey: '' }],
      },
    ]);

    const xlsxBuf = buildXlsxBuffer([
      ['sku', 'name_fr', 'name_ar', 'name_en', 'category', 'price_retail', 'icon', 'kitchen_station', 'is_top', 'is_out_of_stock', 'modifiers_json'],
      ['T3-IMP-GRL', 'Brochette Impériale', 'أسياخ ملكية', 'Imperial Skewers', 'Grillades', 650, '🍢', 'GRILL', 1, 0, modJson],
    ]);

    const impRes = await ctx.request('POST', '/api/admin/tenants/1/catalog/import', {
      token: adminToken,
      body: { filename: 't3_13.xlsx', format: 'xlsx', contentBase64: xlsxBuf.toString('base64') },
    });
    assert.equal(impRes.status, 200, impRes.text);

    const cat = (await ctx.request('GET', '/api/pos/catalog', { token: tenantToken })).json;
    const imported = cat.products.find((p) => p.sku === 'T3-IMP-GRL');
    assert.ok(imported);
    assert.equal(imported.icon, '🍢');
    assert.equal(imported.kitchenStation, 'GRILL');
    assert.equal(imported.isTop, true);
    assert.equal(imported.modifiers.length, 1);

    const ordCode = `ORD-T3-13-${Date.now()}`;
    const syncRes = await ctx.request('POST', '/api/pos/sync', {
      token: tenantToken,
      body: {
        items: [
          {
            id: `s-${ordCode}`,
            entity_type: 'order',
            payload: {
              orderCode: ordCode,
              serviceMode: 'dine_in',
              status: 'KDS_PREP',
              totalMru: 670,
              tvaAmountMru: computeTva16(670),
              payments: [{ method: 'Bimbank', amountMru: 670, ref: 'BM-T313' }],
              items: [
                {
                  productId: imported.id,
                  sku: imported.sku,
                  qty: 1,
                  unitPriceMru: 670,
                  kitchenStation: 'GRILL',
                  modifiers: [{ nameFr: 'Sauce Algérienne', extraPriceMru: 20, bomKey: '' }],
                },
              ],
            },
          },
        ],
      },
    });
    assert.equal(syncRes.status, 200, syncRes.text);

    const kds = (await ctx.request('GET', '/api/pos/kds?station=GRILL', { token: tenantToken })).json;
    assert.ok((kds.tickets || kds.orders || []).some((t) => (t.orderCode || t.order_code) === ordCode));
  });

  it('T3-16: Atomic multi-item sync (order + kds_ready + stock_86) & strict isolation between FT-1041 and FT-5090', async () => {
    ctx = await startTestServer();
    const auth1 = await loginTenant(ctx, { username: DEFAULT_POS_USER, password: DEFAULT_POS_PASS });
    const auth5 = await loginTenant(ctx, { username: 'khaimandb90', password: DEFAULT_POS_PASS });
    const { token: adminToken } = await loginAdmin(ctx);

    // Seed 1 product for FT-5090 (Café Khaima Nouadhibou)
    const tid5 = auth5.tenant.id;
    await ctx.request('POST', `/api/admin/tenants/${tid5}/catalog/import`, {
      token: adminToken,
      body: {
        filename: 'ndb.csv',
        format: 'csv',
        csvText: 'sku,name_fr,name_ar,category,price_retail,kitchen_station\nNDB-CAF-01,Café Touba,قهوة طوبى,Boissons,100,BAR\n',
      },
    });

    const cat1 = (await ctx.request('GET', '/api/pos/catalog', { token: auth1.token })).json;
    const cat5 = (await ctx.request('GET', '/api/pos/catalog', { token: auth5.token })).json;

    const p1 = cat1.products[0];
    const p1b = cat1.products[1];
    const p5 = cat5.products.find((p) => p.sku === 'NDB-CAF-01');
    assert.ok(p5);

    const ord1Code = `ORD-T3-16-A-${Date.now()}`;
    const sync1 = await ctx.request('POST', '/api/pos/sync', {
      token: auth1.token,
      body: {
        items: [
          {
            id: `s-${ord1Code}`,
            entity_type: 'order',
            payload: {
              orderCode: ord1Code,
              serviceMode: 'dine_in',
              status: 'KDS_PREP',
              totalMru: 450,
              tvaAmountMru: computeTva16(450),
              payments: [{ method: 'Cash', amountMru: 450 }],
              items: [{ productId: p1.id, sku: p1.sku, qty: 1, unitPriceMru: 450, kitchenStation: 'GRILL' }],
            },
          },
          {
            id: `s-kds-${ord1Code}`,
            entity_type: 'kds_ready',
            payload: { orderCode: ord1Code, station: 'GRILL', status: 'READY' },
          },
          {
            id: `s-86-${ord1Code}`,
            entity_type: 'stock_86',
            payload: { productId: p1b.id, sku: p1b.sku, available: false, isOutOfStock: true },
          },
        ],
      },
    });
    assert.equal(sync1.status, 200, sync1.text);
    assert.equal(sync1.json.synced, 3);

    // Verify FT-5090 KPIs & KDS & Catalog remain completely isolated from FT-1041
    const kpi5 = (await ctx.request('GET', '/api/pos/kpis', { token: auth5.token })).json;
    assert.equal(kpi5.todayRevenueMru, 0);
    assert.equal(kpi5.todayTicketsCount, 0);

    const kds5 = (await ctx.request('GET', '/api/pos/kds?station=ALL', { token: auth5.token })).json;
    assert.equal((kds5.tickets || kds5.orders || []).length, 0);

    // Verify FT-1041 SQLite state atomicity
    withReadOnlyDb(ctx.dbPath, (db) => {
      const ord = db.prepare('SELECT * FROM orders WHERE tenant_id = 1 AND order_code = ?').get(ord1Code);
      assert.ok(ord);
      const items = db.prepare('SELECT * FROM order_items WHERE order_id = ?').all(ord.id);
      assert.equal(items[0].kds_status, 'READY');
      const p1bRow = db.prepare('SELECT is_out_of_stock FROM products WHERE id = ?').get(Number(p1b.id));
      assert.equal(p1bRow.is_out_of_stock, 1);
    });
  });
});
