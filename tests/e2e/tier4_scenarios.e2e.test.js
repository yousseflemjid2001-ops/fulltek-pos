'use strict';

const { describe, it, afterEach } = require('node:test');
const assert = require('node:assert/strict');

const {
  startTestServer,
  loginAdmin,
  buildXlsxBuffer,
  verifyEd25519Lease,
  tamperLeasePayload,
  tamperLeaseSignature,
  withReadOnlyDb,
  withCopiedWritableDb,
  buildSchemaAwareRow,
} = require('./helpers');

describe('Tier 4 · Real-World Mauritanian POS Domain Scenarios', () => {
  let ctx = null;

  afterEach(async () => {
    if (ctx) {
      await ctx.stop();
      ctx = null;
    }
  });

  it('T4.1: Restaurant Oasis Tevragh-Zeina (Khaima VIP, Arboun, BOM, Remakes, FR/AR catalog, Ed25519)', async () => {
    ctx = await startTestServer();
    const { token: adminToken } = await loginAdmin(ctx);

    // 1. Provision Restaurant Oasis Tevragh-Zeina
    const createRes = await ctx.request('POST', '/api/admin/tenants', {
      token: adminToken,
      body: {
        tenantId: 'FT-OASIS-TZ',
        name: 'Restaurant Oasis Tevragh-Zeina',
        module: 'resto',
        subType: 'Salon Khaima VIP',
        city: 'Nouakchott',
        district: 'Tevragh Zeina',
        phone: '+222 46 88 77 66',
        plan: 'Pro',
        mrr: 6500,
        tills: 3,
        enabledThemes: ['01', '07'],
        payMethods: ['Bankily', 'Masrivi', 'Sedad', 'Cash'],
        username: 'oasis_tz_admin',
        accountPassword: 'OasisVip!2026',
      },
    });
    assert.equal(createRes.status, 201, createRes.text);
    const tid = createRes.json.id;

    // 2. 1-click FR/AR catalog import (UTF-8 BOM + semicolon CSV)
    const csv = [
      '\uFEFFsku;name_fr;name_ar;category;category_ar;price_retail',
      "OAS-MECH;Méchoui d'Agneau;مشوي غنم;Grillades Khaima;مشويات الخيمة;1800",
      'OAS-ATAY;Thé à la menthe;أتاي بالنعناع;Boissons;مشروبات;150',
      'OAS-THIEB;Thiéboudienne Royal;أرز بالسمك;Plats Traditionnels;أطباق تقليدية;850',
      'OAS-BURG;Burger Chameau;برغر لحم الإبل;Fast-Food;وجبات سريعة;350',
    ].join('\r\n');

    const impRes = await ctx.request('POST', `/api/admin/tenants/${tid}/catalog/import`, {
      token: adminToken,
      body: { filename: 'oasis_fr_ar.csv', format: 'csv', csvText: csv },
    });
    assert.equal(impRes.status, 200, impRes.text);
    assert.equal(impRes.json.created, 4);

    const catRes = await ctx.request('GET', `/api/admin/tenants/${tid}/catalog`, { token: adminToken });
    assert.equal(catRes.status, 200);
    assert.equal(catRes.json.products.length, 4);
    const mech = catRes.json.products.find((p) => p.sku === 'OAS-MECH');
    const atay = catRes.json.products.find((p) => p.sku === 'OAS-ATAY');
    assert.equal(mech.name_ar ?? mech.nameAr, 'مشوي غنم');
    assert.equal(atay.name_ar ?? atay.nameAr, 'أتاي بالنعناع');

    // 3. Issue 30d Ed25519 offline lease bound to C1 & hardwareFingerprint
    const leaseRes = await ctx.request('POST', `/api/admin/tenants/${tid}/offline-code`, {
      token: adminToken,
      body: {
        days: 30,
        graceDays: 7,
        registerCode: 'C1',
        hardwareFingerprint: 'FP-OASIS-TZ-C1-01',
      },
    });
    assert.equal(leaseRes.status, 200, leaseRes.text);
    assert.equal(leaseRes.json.payload.registerCode, 'C1');
    assert.equal(leaseRes.json.payload.hardwareFingerprint, 'FP-OASIS-TZ-C1-01');
    assert.equal(leaseRes.json.payload.days, 30);
    assert.equal(leaseRes.json.payload.graceDays, 7);

    const apiVer = await ctx.request('POST', '/api/licenses/verify', {
      body: { leaseToken: leaseRes.json.leaseToken },
    });
    assert.equal(apiVer.status, 200);
    assert.equal(apiVer.json.valid, true);
    assert.equal(verifyEd25519Lease(leaseRes.json.leaseToken, leaseRes.json.publicKey).valid, true);

    // Tampering hardwareFingerprint or registerCode invalidates Ed25519 lease
    const tamperedHw = tamperLeasePayload(leaseRes.json.leaseToken, (p) => ({
      ...p,
      hardwareFingerprint: 'FP-HIJACKED',
    }));
    const tamperedReg = tamperLeasePayload(leaseRes.json.leaseToken, (p) => ({
      ...p,
      registerCode: 'C9',
    }));
    assert.equal(verifyEd25519Lease(tamperedHw, leaseRes.json.publicKey).valid, false);
    assert.equal(verifyEd25519Lease(tamperedReg, leaseRes.json.publicKey).valid, false);

    // 4. Verify multi-site & Resto MCD records in SQLite
    withCopiedWritableDb(ctx.dbPath, (db) => {
      const bMain = Number(
        buildSchemaAwareRow(db, 'branches', {
          tenant_id: tid,
          name: 'Oasis Tevragh-Zeina',
          code: 'BR-TZ',
          city: 'Nouakchott',
        }).run().lastInsertRowid,
      );
      const bKsar = Number(
        buildSchemaAwareRow(db, 'branches', {
          tenant_id: tid,
          name: 'Oasis Annexe Ksar',
          code: 'BR-KSAR',
          city: 'Nouakchott',
        }).run().lastInsertRowid,
      );
      assert.ok(bMain > 0 && bKsar > 0);

      buildSchemaAwareRow(db, 'pos_registers', {
        tenant_id: tid,
        branch_id: bMain,
        code: 'C1',
        name: 'Caisse Principale Khaima',
        hardware_fingerprint: 'FP-OASIS-TZ-C1-01',
        is_master: 1,
      }).run();

      const zoneId = Number(
        buildSchemaAwareRow(db, 'dining_zones', {
          tenant_id: tid,
          branch_id: bMain,
          name: 'Salon VIP / Khaima privée',
          min_spend_mru: 3000,
        }).run().lastInsertRowid,
      );

      buildSchemaAwareRow(db, 'reservations_vip', {
        tenant_id: tid,
        branch_id: bMain,
        zone_id: zoneId,
        name: 'Groupe Ambassade VIP',
        phone: '+222 46 11 00 99',
        party_size: 12,
        deposit_mru: 1000,
        deposit_method: 'Bankily',
        reserved_at: '2026-11-22T20:30:00Z',
        status: 'CONFIRMED',
      }).run();

      const ingCamel = Number(
        buildSchemaAwareRow(db, 'ingredients', {
          tenant_id: tid,
          name: 'Viande chameau',
          unit: 'kg',
          pmp_cost: 420,
          stock_qty: 40,
        }).run().lastInsertRowid,
      );
      const ingBox = Number(
        buildSchemaAwareRow(db, 'ingredients', {
          tenant_id: tid,
          name: 'Boîte emballage',
          unit: 'pcs',
          pmp_cost: 15,
          stock_qty: 200,
        }).run().lastInsertRowid,
      );

      const burger = db.prepare("SELECT id FROM products WHERE tenant_id = ? AND sku = 'OAS-BURG'").get(tid);
      buildSchemaAwareRow(db, 'recipes_bom', {
        tenant_id: tid,
        product_id: burger.id,
        ingredient_id: ingCamel,
        stock_qty: 0.25,
        unit: 'kg',
        condition_type: 'ALWAYS',
      }).run();
      buildSchemaAwareRow(db, 'recipes_bom', {
        tenant_id: tid,
        product_id: burger.id,
        ingredient_id: ingBox,
        stock_qty: 1,
        unit: 'pcs',
        condition_type: 'TAKEAWAY',
      }).run();

      const orderId = Number(
        db.prepare(`
          INSERT INTO orders (tenant_id, order_code, table_name, status, pay_method, total_mru)
          VALUES (?, 'ORD-OAS-1', 'Khaima VIP 1', 'PAID', 'Bankily', 2150)
        `).run(tid).lastInsertRowid,
      );

      buildSchemaAwareRow(db, 'returns_remakes_comps', {
        tenant_id: tid,
        branch_id: bMain,
        order_id: orderId,
        product_id: burger.id,
        action_type: 'REMAKE',
        reason: 'Client demande cuisson bien cuite',
        amount_mru: 350,
      }).run();
      buildSchemaAwareRow(db, 'returns_remakes_comps', {
        tenant_id: tid,
        branch_id: bMain,
        order_id: orderId,
        product_id: burger.id,
        action_type: 'STAFF_MEAL',
        reason: 'Repas équipe cuisine',
        amount_mru: 350,
      }).run();

      assert.equal(db.prepare('SELECT COUNT(*) AS cnt FROM branches WHERE tenant_id = ?').get(tid).cnt, 2);
      assert.equal(db.prepare('SELECT COUNT(*) AS cnt FROM recipes_bom WHERE tenant_id = ?').get(tid).cnt, 2);
      assert.equal(db.prepare('SELECT COUNT(*) AS cnt FROM returns_remakes_comps WHERE tenant_id = ?').get(tid).cnt, 2);
    });
  });

  it('T4.2: Pharmacie Chinguetti / Supérette El Mina (FEFO, CNAM, Karni, Air-Gap Offline Verify)', async () => {
    ctx = await startTestServer();
    const { token: adminToken } = await loginAdmin(ctx);

    // 1. Provision Supérette & Pharmacie El Mina
    const createRes = await ctx.request('POST', '/api/admin/tenants', {
      token: adminToken,
      body: {
        tenantId: 'FT-ELMINA-01',
        name: 'Supérette & Pharmacie El Mina',
        module: 'pharma',
        city: 'Nouakchott',
        district: 'El Mina',
        nif: '00481920',
        rc: 'RC-NKC-4410',
        phone: '+222 42 77 88 99',
        plan: 'Entreprise',
        tills: 2,
        username: 'elmina_pharma_owner',
        accountPassword: 'ElMinaPass!2026',
      },
    });
    assert.equal(createRes.status, 201, createRes.text);
    const tid = createRes.json.id;

    // 2. 1-click .xlsx import with FEFO + CNAM + wholesale + lot batch
    const xlsxBuf = buildXlsxBuffer([
      ['sku', 'barcode', 'name_fr', 'name_ar', 'category', 'price_retail', 'price_whole', 'track_fefo', 'requires_cnam', 'lot_number', 'qty', 'expires_at'],
      ['PH-AMX', '3400930001122', 'Amoxicilline 500mg', 'أموكسيسيلين 500 ملغ', 'Antibiotiques', 185, 160, 1, 1, 'LOT-IMMINENT', 30, '2026-12-01'],
      ['PH-DOL', '3400930003344', 'Doliprane 1000mg', 'دوليبران 1000 ملغ', 'Antalgiques', 120, 100, 1, 1, 'LOT-DOL-01', 50, '2027-06-30'],
      ['MK-LAIT', '6130009991111', 'Lait en poudre 900g', 'حليب مجفف', 'Épicerie', 650, 590, 1, 0, 'LOT-LAIT-01', 20, '2027-04-01'],
      ['MK-SUC', '6130009992222', 'Sucre cristallisé 5kg', 'سكر', 'Épicerie', 220, 195, 0, 0, null, null, null],
    ]);

    const impRes = await ctx.request('POST', `/api/admin/tenants/${tid}/catalog/import`, {
      token: adminToken,
      body: {
        filename: 'elmina_catalog.xlsx',
        format: 'xlsx',
        contentBase64: xlsxBuf.toString('base64'),
      },
    });
    assert.equal(impRes.status, 200, impRes.text);
    assert.equal(impRes.json.format, 'xlsx');
    assert.equal(impRes.json.created, 4);

    const catRes = await ctx.request('GET', `/api/admin/tenants/${tid}/catalog`, { token: adminToken });
    assert.equal(catRes.status, 200);
    assert.equal(catRes.json.products.length, 4);
    const amx = catRes.json.products.find((p) => p.sku === 'PH-AMX');
    const sucre = catRes.json.products.find((p) => p.sku === 'MK-SUC');
    assert.equal(Boolean(amx.track_fefo ?? amx.trackFefo), true);
    assert.equal(Boolean(amx.requires_cnam ?? amx.requiresCnam), true);
    assert.equal(Boolean(sucre.track_fefo ?? sucre.trackFefo), false);

    // 3. Verify FEFO stock_batches ordering & Karni + Master/Replica registers in SQLite
    withCopiedWritableDb(ctx.dbPath, (db) => {
      const amxRow = db.prepare("SELECT id FROM products WHERE tenant_id = ? AND sku = 'PH-AMX'").get(tid);
      db.prepare('INSERT INTO stock_batches (tenant_id, product_id, lot_number, qty, expires_at) VALUES (?, ?, ?, ?, ?)')
        .run(tid, amxRow.id, 'LOT-EXPIRED', 10, '2025-01-01');
      db.prepare('INSERT INTO stock_batches (tenant_id, product_id, lot_number, qty, expires_at) VALUES (?, ?, ?, ?, ?)')
        .run(tid, amxRow.id, 'LOT-LATER', 60, '2027-09-15');

      const validFefo = db.prepare(`
        SELECT lot_number, expires_at
        FROM stock_batches
        WHERE tenant_id = ? AND product_id = ? AND expires_at >= '2026-11-18'
        ORDER BY expires_at ASC
      `).all(tid, amxRow.id);
      assert.equal(validFefo[0].lot_number, 'LOT-IMMINENT');
      assert.equal(validFefo[1].lot_number, 'LOT-LATER');

      const expiredLots = db.prepare(`
        SELECT lot_number FROM stock_batches
        WHERE tenant_id = ? AND product_id = ? AND expires_at < '2026-11-18'
      `).all(tid, amxRow.id);
      assert.equal(expiredLots.length, 1);
      assert.equal(expiredLots[0].lot_number, 'LOT-EXPIRED');

      // Karni B2B credit ledger + repayment
      const karniId = Number(
        buildSchemaAwareRow(db, 'customer_credits_karni', {
          tenant_id: tid,
          name: 'Clinique El Mina B2B',
          nif: '00778899',
          phone: '+222 45 00 22 11',
          credit_limit_mru: 15000,
          current_debt_mru: 4500,
        }).run().lastInsertRowid,
      );
      const ktRes = buildSchemaAwareRow(db, 'karni_transactions', {
        tenant_id: tid,
        credit_id: karniId,
        amount_mru: 1500,
        action_type: 'REPAYMENT',
        reason: 'Règlement partiel Masrivi',
      }).run();
      const ktRow = db.prepare('SELECT customer_id, tx_type, amount_mru FROM karni_transactions WHERE id = ?').get(Number(ktRes.lastInsertRowid));
      assert.equal(ktRow.customer_id, karniId);
      assert.equal(ktRow.tx_type, 'REPAYMENT');
      assert.equal(ktRow.amount_mru, 1500);

      // Master C1 + Replica C2 registers
      const brId = Number(buildSchemaAwareRow(db, 'branches', { tenant_id: tid, name: 'Pharmacie El Mina' }).run().lastInsertRowid);
      buildSchemaAwareRow(db, 'pos_registers', {
        tenant_id: tid,
        branch_id: brId,
        code: 'C1',
        hardware_fingerprint: 'FP-ELMINA-C1',
        is_master: 1,
      }).run();
      buildSchemaAwareRow(db, 'pos_registers', {
        tenant_id: tid,
        branch_id: brId,
        code: 'C2',
        hardware_fingerprint: 'FP-ELMINA-C2',
        is_master: 0,
      }).run();
      assert.equal(db.prepare('SELECT COUNT(*) AS cnt FROM pos_registers WHERE tenant_id = ?').get(tid).cnt, 2);
    });

    // 4. Issue Ed25519 lease, cache locally, SHUT DOWN server, and verify true air-gap offline!
    const leaseRes = await ctx.request('POST', `/api/admin/tenants/${tid}/offline-code`, {
      token: adminToken,
      body: {
        days: 30,
        graceDays: 7,
        registerCode: 'C1',
        hardwareFingerprint: 'FP-ELMINA-C1',
      },
    });
    assert.equal(leaseRes.status, 200);
    const { leaseToken, publicKey, code } = leaseRes.json;
    assert.ok(code && leaseToken && publicKey);

    // Shut down cloud-api completely (preserve tmpDir cleanup in afterEach via ctx.stop)
    await ctx.stop();
    ctx = null;

    // Pure air-gap verification with zero HTTP server running
    const offlineCheck = verifyEd25519Lease(leaseToken, publicKey);
    assert.equal(offlineCheck.valid, true);
    assert.equal(offlineCheck.payload.tenantId, tid);
    assert.equal(offlineCheck.payload.registerCode, 'C1');
    assert.equal(offlineCheck.payload.hardwareFingerprint, 'FP-ELMINA-C1');

    const tamperedOffline = tamperLeasePayload(leaseToken, (p) => ({
      ...p,
      hardwareFingerprint: 'FP-OTHER-MACHINE',
    }));
    assert.equal(verifyEd25519Lease(tamperedOffline, publicKey).valid, false);
    assert.equal(verifyEd25519Lease(tamperLeaseSignature(leaseToken), publicKey).valid, false);
  });

  it('T4.3: Mauritanian SaaS billing lockout recovery (FT-4012 + P-902 Masrivi -> unlock -> extend -> Ed25519 re-issue)', async () => {
    ctx = await startTestServer();
    const { token: adminToken } = await loginAdmin(ctx);

    // 1. Find seeded expired tenant FT-4012 & pending Masrivi P-902
    const dash0 = await ctx.request('GET', '/api/admin/dashboard', { token: adminToken });
    const ft4012 = dash0.json.stores.find((s) => s.tenantId === 'FT-4012');
    assert.ok(ft4012, 'Seeded tenant FT-4012 must exist');
    assert.equal(ft4012.status, 'expired');
    assert.equal(ft4012.daysLeft, 0);
    assert.ok(dash0.json.payments.some((p) => p.id === 'P-902'));

    // 2. Lock tenant for non-payment
    const lockRes = await ctx.request('POST', `/api/admin/tenants/${ft4012.id}/toggle-lock`, {
      token: adminToken,
      body: {},
    });
    assert.equal(lockRes.status, 200);
    assert.equal(lockRes.json.status, 'locked');

    // 3. Approve pending Masrivi payment P-902
    const approveRes = await ctx.request('POST', '/api/admin/payments/P-902/approve', {
      token: adminToken,
      body: {},
    });
    assert.equal(approveRes.status, 200);
    assert.equal(approveRes.json.ok, true);

    // 4. Verify FT-4012 is active with 30 daysLeft and P-902 removed from pending
    const dash1 = await ctx.request('GET', '/api/admin/dashboard', { token: adminToken });
    const updated1 = dash1.json.stores.find((s) => s.id === ft4012.id);
    assert.equal(updated1.status, 'active');
    assert.equal(updated1.daysLeft, 30);
    assert.equal(dash1.json.payments.some((p) => p.id === 'P-902'), false);

    // 5. Extend by an additional 30 days
    const extendRes = await ctx.request('POST', `/api/admin/tenants/${ft4012.id}/extend`, {
      token: adminToken,
      body: { days: 30 },
    });
    assert.equal(extendRes.status, 200);
    assert.equal(extendRes.json.daysLeft, 60);
    assert.equal(extendRes.json.status, 'active');

    // 6. Re-issue Ed25519 offline lease for 60 days
    const leaseRes = await ctx.request('POST', `/api/admin/tenants/${ft4012.id}/offline-code`, {
      token: adminToken,
      body: {
        days: 60,
        graceDays: 7,
        registerCode: 'C1',
        hardwareFingerprint: 'FP-ELWIAM-C1',
      },
    });
    assert.equal(leaseRes.status, 200);
    assert.equal(leaseRes.json.payload.days, 60);
    assert.equal(verifyEd25519Lease(leaseRes.json.leaseToken, leaseRes.json.publicKey).valid, true);

    const verRes = await ctx.request('POST', '/api/licenses/verify', {
      body: { leaseToken: leaseRes.json.leaseToken },
    });
    assert.equal(verRes.status, 200);
    assert.equal(verRes.json.valid, true);

    // 7. Verify SQLite consistency across offline_lease_tokens, saas_payments, and audit_logs
    withReadOnlyDb(ctx.dbPath, (db) => {
      const payRow = db.prepare("SELECT status FROM saas_payments WHERE pay_code = 'P-902'").get();
      assert.equal(payRow.status, 'approved');

      const leases = db.prepare('SELECT * FROM offline_lease_tokens WHERE tenant_id = ?').all(ft4012.id);
      assert.ok(leases.length >= 1);

      const audits = db.prepare('SELECT title FROM audit_logs WHERE tenant_id = ? ORDER BY id ASC').all(ft4012.id);
      const joined = audits.map((a) => a.title).join(' | ');
      assert.match(joined, /Suspension/i);
      assert.match(joined, /Masrivi/i);
      assert.match(joined, /\+30j/i);
      assert.ok(audits.length >= 4);
    });
  });
});
