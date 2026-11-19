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

describe('Tier 4 · Mauritanian Restaurant Production API Shift Scenarios', () => {
  let ctx = null;

  afterEach(async () => {
    if (ctx) {
      await ctx.stop();
      ctx = null;
    }
  });

  it('T4-01: Vendredi Soir au Salon Khaima VIP (Dar El-Karam: Arboun 2000, Mixte, Z-Close & restart persistence)', async () => {
    ctx = await startTestServer();
    const auth = await loginTenant(ctx, { username: DEFAULT_POS_USER, password: DEFAULT_POS_PASS });
    const token = auth.token;

    const cat = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    assert.ok(cat.diningZones.some((z) => z.isVip === true || z.is_vip === 1));
    assert.ok(cat.reservationsVip.length >= 1);
    const karniCust = cat.karniCustomers[0];
    const startDebt = getCustomerDebt(karniCust);

    const grillProd = cat.products.find((p) => p.kitchenStation === 'GRILL') || cat.products[0];
    const barProd = cat.products.find((p) => p.kitchenStation === 'BAR') || cat.products[1];

    // Khaima VIP order: 3100 subtotal - 2000 Arboun = 1100 netTotal (TVA 16% = 152)
    // Paid Mixte: 400 Cash (net of change) + 400 Bankily + 300 Karni
    const netTotal = 1100;
    const tva = computeTva16(netTotal);
    assert.equal(tva, 152);
    const ordCode = `ORD-T4-01-VIP-${Date.now()}`;

    const syncOrder = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `s-${ordCode}`,
            entity_type: 'order',
            payload: {
              orderCode: ordCode,
              tableName: 'Khaima 1',
              serviceMode: 'dine_in',
              channel: 'DINE_IN',
              status: 'KDS_PREP',
              totalMru: netTotal,
              tvaAmountMru: tva,
              discountMru: 0,
              payMethod: 'Mixte',
              payments: [
                { method: 'Cash', amountMru: 400 },
                { method: 'Bankily', amountMru: 400, ref: 'BK-9012' },
                { method: 'Karni', amountMru: 300 },
              ],
              notes: 'Arboun 2000 MRU déduit',
              items: [
                {
                  productId: grillProd.id,
                  sku: grillProd.sku,
                  qty: 2,
                  unitPriceMru: 1400,
                  kitchenStation: 'GRILL',
                  modifiers: [{ nameFr: 'Bien cuit', extraPriceMru: 0, bomKey: '' }],
                },
                {
                  productId: barProd.id,
                  sku: barProd.sku,
                  qty: 2,
                  unitPriceMru: 150,
                  kitchenStation: 'BAR',
                },
              ],
            },
          },
        ],
      },
    });
    assert.equal(syncOrder.status, 200, syncOrder.text);

    // KDS verify & complete GRILL + BAR
    const kds = (await ctx.request('GET', '/api/pos/kds?station=ALL', { token })).json;
    const ticket = (kds.tickets || kds.orders || []).find((t) => (t.orderCode || t.order_code) === ordCode);
    assert.ok(ticket);
    const orderId = ticket.orderId ?? ticket.id;
    assert.equal((await ctx.request('PATCH', `/api/pos/kds/${orderId}`, { token, body: { status: 'READY', station: 'GRILL' } })).status, 200);
    assert.equal((await ctx.request('PATCH', `/api/pos/kds/${orderId}`, { token, body: { status: 'READY', station: 'BAR' } })).status, 200);

    // Settle VIP table Mixte (400 Cash + 400 Bankily + 300 Karni) & Z-Close
    const syncZ = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `s-pay-${ordCode}`,
            entity_type: 'order',
            payload: {
              orderCode: ordCode,
              status: 'PAID',
              totalMru: netTotal,
              tvaAmountMru: tva,
              payMethod: 'Mixte',
              payments: [
                { method: 'Cash', amountMru: 400 },
                { method: 'Bankily', amountMru: 400, ref: 'BK-9012' },
                { method: 'Karni', amountMru: 300, karniCustomerId: karniCust.id },
              ],
            },
          },
          {
            id: `s-z-${ordCode}`,
            entity_type: 'closing_z',
            payload: {
              expectedCashMru: 400,
              countedCashMru: 400,
              digitalMru: 400,
              varianceMru: 0,
              approvedBy: 'Ahmed Ould Salem',
              notes: 'Vendredi Soir Khaima VIP',
            },
          },
        ],
      },
    });
    assert.equal(syncZ.status, 200, syncZ.text);

    // Restart server on same dbPath & verify persistence
    const { dbPath, tmpDir } = ctx;
    await ctx.stop({ cleanup: false });
    ctx = await startTestServer({ dbPath, tmpDir, ownsTmpDir: true });

    const tokenAfter = (await loginTenant(ctx)).token;
    const kpisAfter = (await ctx.request('GET', '/api/pos/kpis', { token: tokenAfter })).json;
    assert.equal(kpisAfter.todayRevenueMru, 1100);
    assert.equal(kpisAfter.todayTicketsCount, 1);
    assert.equal(kpisAfter.paymentBreakdown.cash, 400);
    assert.equal(kpisAfter.paymentBreakdown.bankily, 400);
    assert.equal(kpisAfter.paymentBreakdown.karni, 300);

    const catAfter = (await ctx.request('GET', '/api/pos/catalog', { token: tokenAfter })).json;
    assert.equal(getCustomerDebt(catAfter.karniCustomers.find((c) => Number(c.id) === Number(karniCust.id))), startDebt + 300);

    withReadOnlyDb(ctx.dbPath, (db) => {
      const z = db.prepare("SELECT * FROM cash_closings_z WHERE tenant_id = 1 AND notes = 'Vendredi Soir Khaima VIP'").get();
      assert.ok(z);
      assert.equal(z.expected_mru, 400);
      assert.equal(z.variance_mru, 0);
    });
  });

  it('T4-02: Rush du Midi Nouakchott (Sur place, Emporter packaging BOM, Livraison Ksar 150 vs Arafat > 1500 free, Bimbank & Click)', async () => {
    ctx = await startTestServer();
    const { token } = await loginTenant(ctx);
    const cat0 = (await ctx.request('GET', '/api/pos/catalog', { token })).json;

    const baseBom = cat0.recipesBom.find((b) => (b.conditionChannel ?? 'ALL') === 'ALL' && !b.modifierKey);
    const prod = cat0.products.find((p) => p.id === baseBom.productId || p.sku === baseBom.productSku);
    const baseIng = cat0.ingredients.find((i) => i.id === baseBom.ingredientId || i.sku === baseBom.ingredientSku);

    // Ensure TAKEAWAY_DELIVERY packaging BOM exists on prod for this scenario
    let pkgSku = 'ING-PACK-T402';
    withWritableDb(ctx.dbPath, (db) => {
      db.prepare(`
        INSERT OR IGNORE INTO ingredients (tenant_id, sku, name_fr, name_ar, unit, pmp_cost_mru, current_stock, min_stock)
        VALUES (1, ?, 'Pack Emporter', 'علبة', 'unit', 20, 100.0, 10.0)
      `).run(pkgSku);
      const pkgIng = db.prepare('SELECT id FROM ingredients WHERE tenant_id = 1 AND sku = ?').get(pkgSku);
      db.prepare(`
        INSERT OR IGNORE INTO recipes_bom (tenant_id, product_id, ingredient_id, qty_per_unit, unit, condition_channel, modifier_key)
        VALUES (1, ?, ?, 1.0, 'unit', 'TAKEAWAY_DELIVERY', '')
      `).run(Number(prod.id), Number(pkgIng.id));
    });

    const catBefore = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    const startBaseStock = getIngredientStock(catBefore.ingredients.find((i) => i.sku === baseIng.sku));
    const startPkgStock = getIngredientStock(catBefore.ingredients.find((i) => i.sku === pkgSku));

    const ts = Date.now();
    // 1) Sur place: 2 units, Cash 500
    // 2) Emporter: 2 units, Masrivi 600 (triggers packaging BOM)
    // 3) Livraison Ksar (<= 1500 -> +150 fee): 2 units @450 + 150 = 1050, Bimbank (TVA = 145)
    // 4) Livraison Arafat (> 1500 -> 0 fee): 2 units @805 = 1610, Click (TVA = 222)
    const res = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `rush-1-${ts}`,
            entity_type: 'order',
            payload: {
              orderCode: `RUSH-DINE-${ts}`,
              serviceMode: 'dine_in',
              channel: 'DINE_IN',
              totalMru: 500,
              tvaAmountMru: computeTva16(500),
              payments: [{ method: 'Cash', amountMru: 500 }],
              items: [{ productId: prod.id, sku: prod.sku, qty: 2, unitPriceMru: 250 }],
            },
          },
          {
            id: `rush-2-${ts}`,
            entity_type: 'order',
            payload: {
              orderCode: `RUSH-TAKE-${ts}`,
              serviceMode: 'takeaway',
              channel: 'TAKEAWAY',
              totalMru: 600,
              tvaAmountMru: computeTva16(600),
              payments: [{ method: 'Masrivi', amountMru: 600, ref: 'MS-RUSH-2' }],
              items: [{ productId: prod.id, sku: prod.sku, qty: 2, unitPriceMru: 300 }],
            },
          },
          {
            id: `rush-3-${ts}`,
            entity_type: 'order',
            payload: {
              orderCode: `RUSH-KSAR-${ts}`,
              serviceMode: 'delivery',
              channel: 'DELIVERY',
              deliveryZone: 'Ksar / Socogim',
              deliveryFeeMru: 150,
              totalMru: 1050,
              tvaAmountMru: computeTva16(1050),
              payments: [{ method: 'Bimbank', amountMru: 1050, ref: 'BM-RUSH-3' }],
              items: [{ productId: prod.id, sku: prod.sku, qty: 2, unitPriceMru: 450 }],
            },
          },
          {
            id: `rush-4-${ts}`,
            entity_type: 'order',
            payload: {
              orderCode: `RUSH-ARAFAT-${ts}`,
              serviceMode: 'delivery',
              channel: 'DELIVERY',
              deliveryZone: 'Arafat / Dar Naim',
              deliveryFeeMru: 0,
              totalMru: 1610,
              tvaAmountMru: computeTva16(1610),
              payments: [{ method: 'Click', amountMru: 1610, ref: 'CK-RUSH-4' }],
              items: [{ productId: prod.id, sku: prod.sku, qty: 2, unitPriceMru: 805 }],
            },
          },
        ],
      },
    });
    assert.equal(res.status, 200, res.text);
    assert.equal(res.json.synced, 4);

    const kpis = (await ctx.request('GET', '/api/pos/kpis', { token })).json;
    assert.equal(kpis.todayRevenueMru, 3760);
    assert.equal(kpis.todayTicketsCount, 4);
    assert.equal(kpis.paymentBreakdown.cash, 500);
    assert.equal(kpis.paymentBreakdown.masrivi, 600);
    assert.equal(kpis.paymentBreakdown.bimbank, 1050);
    assert.equal(kpis.paymentBreakdown.click, 1610);

    const catAfter = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    const endBaseStock = getIngredientStock(catAfter.ingredients.find((i) => i.sku === baseIng.sku));
    const endPkgStock = getIngredientStock(catAfter.ingredients.find((i) => i.sku === pkgSku));

    // Base BOM: 8 units total across 4 orders
    const expectedBaseDelta = Number(baseBom.qtyPerUnit ?? baseBom.qty_per_unit) * 8;
    assert.ok(Math.abs((startBaseStock - endBaseStock) - expectedBaseDelta) < 1e-6);
    // Packaging BOM: 2 (Emporter) + 2 (Ksar) + 2 (Arafat) = 6 units (DINE_IN excluded!)
    assert.ok(Math.abs((startPkgStock - endPkgStock) - 6) < 1e-6);
  });

  it('T4-03: Crise Rupture Cuisine (86) & Remake double BOM deduction triggering low-stock alert', async () => {
    ctx = await startTestServer();
    const { token } = await loginTenant(ctx);
    const cat0 = (await ctx.request('GET', '/api/pos/catalog', { token })).json;

    const baseBom = cat0.recipesBom.find((b) => (b.conditionChannel ?? 'ALL') === 'ALL' && !b.modifierKey);
    const prod = cat0.products.find((p) => p.id === baseBom.productId || p.sku === baseBom.productSku);
    const prod86 = cat0.products.find((p) => String(p.id) !== String(prod.id));
    const ing = cat0.ingredients.find((i) => i.id === baseBom.ingredientId || i.sku === baseBom.ingredientSku);
    const qtyPerUnit = Number(baseBom.qtyPerUnit ?? baseBom.qty_per_unit);
    const minStock = Number(ing.minStock ?? ing.min_stock);

    // Position ingredient stock right above min_stock so 1 order + 1 remake pushes it <= min_stock
    withWritableDb(ctx.dbPath, (db) => {
      db.prepare('UPDATE ingredients SET current_stock = ? WHERE id = ?').run(minStock + qtyPerUnit * 1.5, Number(ing.id));
    });

    // 1. Chef marks prod86 ÉPUISÉ (86)
    const r86 = await ctx.request('PATCH', `/api/pos/products/${prod86.id}/availability`, {
      token,
      body: { available: false },
    });
    assert.equal(r86.status, 200, r86.text);
    const cat86 = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    assert.equal(cat86.products.find((p) => String(p.id) === String(prod86.id)).available, false);

    // 2. Customer orders 1 unit + kitchen REMAKE 1 unit (2x BOM deduction -> current_stock <= min_stock)
    const ordCode = `ORD-T4-03-${Date.now()}`;
    const res = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `s-${ordCode}`,
            entity_type: 'order',
            payload: {
              orderCode: ordCode,
              serviceMode: 'dine_in',
              totalMru: 450,
              tvaAmountMru: computeTva16(450),
              payments: [{ method: 'Cash', amountMru: 450 }],
              items: [{ productId: prod.id, sku: prod.sku, qty: 1, unitPriceMru: 450 }],
            },
          },
          {
            id: `s-rem-${ordCode}`,
            entity_type: 'remake',
            payload: {
              actionType: 'REMAKE',
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
    assert.equal(res.status, 200, res.text);

    const kpis = (await ctx.request('GET', '/api/pos/kpis', { token })).json;
    assert.equal(kpis.todayRevenueMru, 450, 'Customer must NOT be double charged on REMAKE');
    assert.ok(
      kpis.lowStockAlerts.some((a) => a.sku === ing.sku),
      `Expected ${ing.sku} in lowStockAlerts after double BOM deduction`,
    );
  });

  it('T4-05: Mode Formation mid-shift zero-mutation isolation across KPIs, BOM, Karni, KDS & Closing Z', async () => {
    ctx = await startTestServer();
    const { token } = await loginTenant(ctx);
    const cat0 = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    const prod = cat0.products[0];
    const cust = cat0.karniCustomers[0];
    const startDebt = getCustomerDebt(cust);

    // 1. Real order: 450 MRU Cash
    const realCode = `ORD-REAL-T405-${Date.now()}`;
    assert.equal(
      (
        await ctx.request('POST', '/api/pos/sync', {
          token,
          body: {
            items: [
              {
                id: `s-${realCode}`,
                entity_type: 'order',
                payload: {
                  orderCode: realCode,
                  serviceMode: 'dine_in',
                  totalMru: 450,
                  tvaAmountMru: computeTva16(450),
                  payments: [{ method: 'Cash', amountMru: 450 }],
                  isTraining: false,
                  items: [{ productId: prod.id, sku: prod.sku, qty: 1, unitPriceMru: 450 }],
                },
              },
            ],
          },
        })
      ).status,
      200,
    );

    const baselineCat = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    const baselineStocks = new Map(baselineCat.ingredients.map((i) => [i.sku, getIngredientStock(i)]));
    const baselineKpi = (await ctx.request('GET', '/api/pos/kpis', { token })).json;

    // 2. Trainee rings up 2 training orders (7000 MRU total), 1 training remake, 1 training Karni, 1 training Z
    const ts = Date.now();
    const trainRes = await ctx.request('POST', '/api/pos/sync', {
      token,
      body: {
        items: [
          {
            id: `trn-1-${ts}`,
            entity_type: 'order',
            payload: {
              orderCode: `TRN-1-${ts}`,
              serviceMode: 'dine_in',
              status: 'KDS_PREP',
              totalMru: 5000,
              tvaAmountMru: computeTva16(5000),
              payments: [{ method: 'Cash', amountMru: 5000 }],
              isTraining: true,
              items: [{ productId: prod.id, sku: prod.sku, qty: 10, unitPriceMru: 500 }],
            },
          },
          {
            id: `trn-2-${ts}`,
            entity_type: 'order',
            payload: {
              order_code: `TRN-2-${ts}`,
              service_mode: 'delivery',
              status: 'KDS_PREP',
              total_mru: 2000,
              tva_mru: computeTva16(2000),
              payments: [{ method: 'Karni', amountMru: 2000 }],
              is_training: true,
              items: [{ productId: prod.id, sku: prod.sku, qty: 4, unitPriceMru: 500 }],
            },
          },
          {
            id: `trn-rem-${ts}`,
            entity_type: 'remake',
            payload: {
              actionType: 'REMAKE',
              productId: prod.id,
              sku: prod.sku,
              qty: 3,
              reason: 'Entraînement',
              isTraining: true,
            },
          },
          {
            id: `trn-kar-${ts}`,
            entity_type: 'karni',
            payload: {
              customerId: cust.id,
              txType: 'CHARGE',
              amountMru: 2000,
              isTraining: true,
            },
          },
          {
            id: `trn-z-${ts}`,
            entity_type: 'closing_z',
            payload: {
              expectedCashMru: 5450,
              countedCashMru: 5450,
              digitalMru: 0,
              varianceMru: 0,
              isTraining: true,
              notes: 'TRAINING_SHIFT_Z',
            },
          },
        ],
      },
    });
    assert.equal(trainRes.status, 200, trainRes.text);
    assert.equal(trainRes.json.synced, 5);

    // 3. Verify 100% zero mutation vs baseline
    const afterKpi = (await ctx.request('GET', '/api/pos/kpis', { token })).json;
    assert.equal(afterKpi.todayRevenueMru, baselineKpi.todayRevenueMru);
    assert.equal(afterKpi.todayTicketsCount, baselineKpi.todayTicketsCount);
    assert.equal(afterKpi.foodCostMru, baselineKpi.foodCostMru);
    assert.equal(afterKpi.paymentBreakdown.cash, baselineKpi.paymentBreakdown.cash);
    assert.equal(afterKpi.paymentBreakdown.karni, baselineKpi.paymentBreakdown.karni);

    const afterCat = (await ctx.request('GET', '/api/pos/catalog', { token })).json;
    for (const ing of afterCat.ingredients) {
      assert.equal(getIngredientStock(ing), baselineStocks.get(ing.sku));
    }
    assert.equal(getCustomerDebt(afterCat.karniCustomers.find((c) => Number(c.id) === Number(cust.id))), startDebt);

    const afterKds = (await ctx.request('GET', '/api/pos/kds?station=ALL', { token })).json;
    assert.equal((afterKds.tickets || afterKds.orders || []).some((t) => String(t.orderCode || t.order_code).startsWith('TRN-')), false);
  });

  it('T4-07: Super-Admin new tenant FT-NKC-88 provisioning -> extended import -> full POS cycle isolated from FT-1041', async () => {
    ctx = await startTestServer();
    const { token: adminToken } = await loginAdmin(ctx);
    const auth1041 = await loginTenant(ctx, { username: DEFAULT_POS_USER, password: DEFAULT_POS_PASS });

    const newUsername = `nkc88_${Date.now()}`;
    const newPass = 'NkcResto!2026';
    const createRes = await ctx.request('POST', '/api/admin/tenants', {
      token: adminToken,
      body: {
        tenantId: 'FT-NKC-88',
        name: 'Le Palmier Nouakchott',
        module: 'resto',
        city: 'Nouakchott',
        district: 'Tevragh Zeina',
        phone: '+222 46 77 88 99',
        enabledThemes: ['01', '04', '06', '07', '11'],
        payMethods: ['Cash', 'Bankily', 'Masrivi', 'Sedad', 'Bimbank', 'Click', 'Karni'],
        username: newUsername,
        accountPassword: newPass,
        ownerPin: '8811',
      },
    });
    assert.equal(createRes.status, 201, createRes.text);
    const tid = createRes.json.id;

    // Extended XLSX import for FT-NKC-88
    const xlsxBuf = buildXlsxBuffer([
      ['sku', 'name_fr', 'name_ar', 'name_en', 'category', 'price_retail', 'icon', 'kitchen_station', 'is_top', 'is_out_of_stock', 'modifiers_json'],
      ['NKC-THIOF', 'Thiof Grillé Palmier', 'سمك تيوف مشوي', 'Grilled Thiof', 'Poissons', 950, '🐟', 'GRILL', 1, 0, '[]'],
      ['NKC-BIS', 'Bissap Glacé', 'عصير كركديه مثلج', 'Iced Hibiscus', 'Boissons', 150, '🥤', 'BAR', 0, 0, '[]'],
    ]);
    const impRes = await ctx.request('POST', `/api/admin/tenants/${tid}/catalog/import`, {
      token: adminToken,
      body: { filename: 'nkc88.xlsx', format: 'xlsx', contentBase64: xlsxBuf.toString('base64') },
    });
    assert.equal(impRes.status, 200, impRes.text);
    assert.equal(impRes.json.created, 2);

    // Tenant logs in & bootstraps catalog
    const nkcAuth = await loginTenant(ctx, { username: newUsername, password: newPass });
    assert.equal(nkcAuth.tenant.tenantId ?? nkcAuth.tenant.code, 'FT-NKC-88');

    const nkcCat = (await ctx.request('GET', '/api/pos/catalog', { token: nkcAuth.token })).json;
    assert.equal(nkcCat.products.length, 2);
    const thiof = nkcCat.products.find((p) => p.sku === 'NKC-THIOF');
    const bissap = nkcCat.products.find((p) => p.sku === 'NKC-BIS');
    assert.equal(thiof.icon, '🐟');
    assert.equal(thiof.kitchenStation, 'GRILL');
    assert.equal(thiof.isTop, true);

    // Toggle 86 on bissap, sync order with thiof, mark KDS ready, Z-close
    assert.equal(
      (await ctx.request('PATCH', `/api/pos/products/${bissap.id}/availability`, { token: nkcAuth.token, body: { available: false } })).status,
      200,
    );

    const ordCode = `ORD-NKC88-${Date.now()}`;
    const syncRes = await ctx.request('POST', '/api/pos/sync', {
      token: nkcAuth.token,
      body: {
        items: [
          {
            id: `s-${ordCode}`,
            entity_type: 'order',
            payload: {
              orderCode: ordCode,
              serviceMode: 'dine_in',
              status: 'KDS_PREP',
              totalMru: 950,
              tvaAmountMru: computeTva16(950),
              payments: [{ method: 'Bimbank', amountMru: 950, ref: 'BM-NKC-1' }],
              items: [{ productId: thiof.id, sku: thiof.sku, qty: 1, unitPriceMru: 950, kitchenStation: 'GRILL' }],
            },
          },
          {
            id: `s-z-${ordCode}`,
            entity_type: 'closing_z',
            payload: {
              expectedCashMru: 0,
              countedCashMru: 0,
              digitalMru: 950,
              varianceMru: 0,
              approvedBy: 'Gérant NKC',
            },
          },
        ],
      },
    });
    assert.equal(syncRes.status, 200, syncRes.text);

    const kds = (await ctx.request('GET', '/api/pos/kds?station=GRILL', { token: nkcAuth.token })).json;
    const tkt = (kds.tickets || kds.orders || []).find((t) => (t.orderCode || t.order_code) === ordCode);
    assert.ok(tkt);
    assert.equal((await ctx.request('PATCH', `/api/pos/kds/${tkt.orderId ?? tkt.id}`, { token: nkcAuth.token, body: { status: 'READY' } })).status, 200);

    // Settle order to PAID
    const payNkc = await ctx.request('POST', '/api/pos/sync', {
      token: nkcAuth.token,
      body: {
        items: [
          {
            id: `s-pay-${ordCode}`,
            entity_type: 'order',
            payload: {
              orderCode: ordCode,
              status: 'PAID',
              totalMru: 950,
              tvaAmountMru: computeTva16(950),
              payments: [{ method: 'Bimbank', amountMru: 950, ref: 'BM-NKC-1' }],
            },
          },
        ],
      },
    });
    assert.equal(payNkc.status, 200, payNkc.text);

    const nkcKpi = (await ctx.request('GET', '/api/pos/kpis', { token: nkcAuth.token })).json;
    assert.equal(nkcKpi.todayRevenueMru, 950);
    assert.equal(nkcKpi.todayTicketsCount, 1);
    assert.equal(nkcKpi.paymentBreakdown.bimbank, 950);

    // Strict isolation: FT-1041 remains at 0 orders & 0 revenue
    const kpi1041 = (await ctx.request('GET', '/api/pos/kpis', { token: auth1041.token })).json;
    assert.equal(kpi1041.todayRevenueMru, 0);
    assert.equal(kpi1041.todayTicketsCount, 0);
  });
});
