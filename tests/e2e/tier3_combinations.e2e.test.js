'use strict';

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');

const {
  DEFAULT_ADMIN_USER,
  DEFAULT_ADMIN_PASS,
  startTestServer,
  loginAdmin,
  buildXlsxBuffer,
  verifyEd25519Lease,
  tamperLeaseSignature,
  withReadOnlyDb,
  withCopiedWritableDb,
  listTables,
  getForeignKeys,
  buildSchemaAwareRow,
} = require('./helpers');

describe('Tier 3 · Cross-Feature Combinations & Multi-Tenant Isolation', () => {
  let ctx;
  let adminToken;

  before(async () => {
    ctx = await startTestServer();
    adminToken = (await loginAdmin(ctx)).token;
  });

  after(async () => {
    await ctx?.stop();
  });

  it('T3.1: Super-Admin onboarding -> dual-format CSV+XLSX catalog import -> Ed25519 lease -> audit trail', async () => {
    // 1. Verify /api/admin/me
    const meRes = await ctx.request('GET', '/api/admin/me', { token: adminToken });
    assert.equal(meRes.status, 200);
    assert.equal(meRes.json.admin.username, DEFAULT_ADMIN_USER);
    assert.equal(meRes.json.admin.role, 'SUPER_ADMIN');

    // 2. Create tenant
    const tenantRes = await ctx.request('POST', '/api/admin/tenants', {
      token: adminToken,
      body: {
        tenantId: 'FT-T3-01',
        name: 'Restaurant Oasis T3',
        module: 'resto',
        plan: 'Pro',
        tills: 3,
        city: 'Tevragh Zeina',
        phone: '+222 46 22 33 44',
        username: 'oasis_t3_owner',
        accountPassword: 'OasisPass!2026',
      },
    });
    assert.equal(tenantRes.status, 201, tenantRes.text);
    const tenantId = tenantRes.json.id;

    // 3. Import Format 1: UTF-8 BOM + semicolon CSV with FR/AR columns
    const csvText = [
      '\uFEFFsku;name_fr;name_ar;category;price_retail',
      'T3-MECH;Méchoui Agneau;مشوي غنم;Grillades;1800',
      'T3-THE;Thé à la menthe;أتاي بالنعناع;Boissons;150',
      'T3-BISS;Jus Bissap;عصير كركديه;Boissons;120',
    ].join('\r\n');

    const impCsv = await ctx.request('POST', `/api/admin/tenants/${tenantId}/catalog/import`, {
      token: adminToken,
      body: { filename: 'oasis_menu.csv', format: 'csv', csvText },
    });
    assert.equal(impCsv.status, 200, impCsv.text);
    assert.equal(impCsv.json.created, 3);
    assert.equal(impCsv.json.updated, 0);
    assert.deepEqual(impCsv.json.errors, []);

    // 4. Import Format 2: native .xlsx upserting 1 SKU + creating 1 new SKU
    const xlsxBuf = buildXlsxBuffer([
      ['sku', 'name_fr', 'name_ar', 'category', 'price_retail'],
      ['T3-MECH', 'Méchoui Agneau', 'مشوي غنم', 'Grillades', 1950],
      ['T3-TACOS', 'Tacos Poulet', 'تاكوس دجاج', 'Fast-Food', 350],
    ]);
    const impXlsx = await ctx.request('POST', `/api/admin/tenants/${tenantId}/catalog/import`, {
      token: adminToken,
      body: {
        filename: 'oasis_update.xlsx',
        format: 'xlsx',
        contentBase64: xlsxBuf.toString('base64'),
      },
    });
    assert.equal(impXlsx.status, 200, impXlsx.text);
    assert.equal(impXlsx.json.format, 'xlsx');
    assert.equal(impXlsx.json.updated, 1);
    assert.equal(impXlsx.json.created, 1);

    // 5. Verify catalog readback
    const catRes = await ctx.request('GET', `/api/admin/tenants/${tenantId}/catalog`, { token: adminToken });
    assert.equal(catRes.status, 200);
    assert.equal(catRes.json.tenantId, tenantId);
    assert.equal(catRes.json.products.length, 4);
    const mech = catRes.json.products.find((p) => p.sku === 'T3-MECH');
    assert.equal(mech.price_retail ?? mech.priceRetail, 1950);

    // 6. Issue Ed25519 offline lease bound to C1 + hardwareFingerprint
    const leaseRes = await ctx.request('POST', `/api/admin/tenants/${tenantId}/offline-code`, {
      token: adminToken,
      body: {
        days: 30,
        graceDays: 7,
        registerCode: 'C1',
        hardwareFingerprint: 'HW-NKC-C1-9988',
      },
    });
    assert.equal(leaseRes.status, 200, leaseRes.text);
    assert.equal(leaseRes.json.payload.tenantId, tenantId);
    assert.equal(leaseRes.json.payload.registerCode, 'C1');
    assert.equal(leaseRes.json.payload.hardwareFingerprint, 'HW-NKC-C1-9988');
    assert.equal(leaseRes.json.payload.tillsQuota, 3);

    // 7. Verify Ed25519 signature 3 ways (public-key endpoint, verify endpoint, node:crypto)
    const pubRes = await ctx.request('GET', '/api/licenses/public-key');
    assert.equal(pubRes.status, 200);
    assert.equal(pubRes.json.publicKey, leaseRes.json.publicKey);
    assert.equal(pubRes.json.keyId, leaseRes.json.keyId);

    const apiVerify = await ctx.request('POST', '/api/licenses/verify', {
      body: { leaseToken: leaseRes.json.leaseToken },
    });
    assert.equal(apiVerify.status, 200);
    assert.equal(apiVerify.json.valid, true);

    const apiVerifyTampered = await ctx.request('POST', '/api/licenses/verify', {
      body: { leaseToken: tamperLeaseSignature(leaseRes.json.leaseToken) },
    });
    assert.equal(apiVerifyTampered.status, 200);
    assert.equal(apiVerifyTampered.json.valid, false);

    const cryptoVerify = verifyEd25519Lease(leaseRes.json.leaseToken, pubRes.json.publicKey);
    assert.equal(cryptoVerify.valid, true);

    // 8. Verify dashboard stores and audit_logs
    const dash = await ctx.request('GET', '/api/admin/dashboard', { token: adminToken });
    assert.equal(dash.status, 200);
    assert.ok(dash.json.stores.some((s) => s.id === tenantId));

    withReadOnlyDb(ctx.dbPath, (db) => {
      const audits = db.prepare('SELECT * FROM audit_logs WHERE tenant_id = ?').all(tenantId);
      assert.ok(audits.length >= 2, `Expected >= 2 audit_logs for tenant ${tenantId}, got ${audits.length}`);
    });
  });

  it('T3.2: Tenant lifecycle (PATCH, warn lock/unlock, extend, support, payment approve) + MCD FK integrity', async () => {
    const createRes = await ctx.request('POST', '/api/admin/tenants', {
      token: adminToken,
      body: {
        tenantId: 'FT-T3-02',
        name: 'Boutique Lifecycle T3',
        module: 'market',
        city: 'Ksar',
        phone: '+222 44 55 66 77',
        username: 'lifecycle_t3_owner',
        accountPassword: 'LifePass!2026',
        tills: 2,
        daysLeft: 3,
        status: 'warn',
      },
    });
    assert.equal(createRes.status, 201);
    const tid = createRes.json.id;

    const patchRes = await ctx.request('PATCH', `/api/admin/tenants/${tid}`, {
      token: adminToken,
      body: { tills: 4, nif: '00991122', rc: 'RC-NKC-2026', enabledThemes: ['01', '07'] },
    });
    assert.equal(patchRes.status, 200);
    assert.equal(patchRes.json.tills, 4);
    assert.equal(patchRes.json.nif, '00991122');
    assert.deepEqual(patchRes.json.enabledThemes, ['01', '07']);

    const lockRes = await ctx.request('POST', `/api/admin/tenants/${tid}/toggle-lock`, { token: adminToken, body: {} });
    assert.equal(lockRes.status, 200);
    assert.equal(lockRes.json.status, 'locked');

    // Unlocking with daysLeft <= 5 restores status to 'warn'
    const unlockWarn = await ctx.request('POST', `/api/admin/tenants/${tid}/toggle-lock`, { token: adminToken, body: {} });
    assert.equal(unlockWarn.status, 200);
    assert.equal(unlockWarn.json.status, 'warn');

    const extendRes = await ctx.request('POST', `/api/admin/tenants/${tid}/extend`, {
      token: adminToken,
      body: { days: 30 },
    });
    assert.equal(extendRes.status, 200);
    assert.equal(extendRes.json.daysLeft, 33);
    assert.equal(extendRes.json.status, 'active');

    const supRes = await ctx.request('POST', `/api/admin/tenants/${tid}/support`, { token: adminToken, body: {} });
    assert.equal(supRes.status, 200);
    assert.equal(supRes.json.ok, true);

    // Approve seeded pending payment P-901 (FT-1041 had 2 daysLeft -> 32 active)
    const payRes = await ctx.request('POST', '/api/admin/payments/P-901/approve', { token: adminToken, body: {} });
    assert.equal(payRes.status, 200);
    assert.equal(payRes.json.ok, true);

    const dash = await ctx.request('GET', '/api/admin/dashboard', { token: adminToken });
    assert.equal(dash.json.payments.some((p) => p.id === 'P-901'), false);
    const ft1041 = dash.json.stores.find((s) => s.tenantId === 'FT-1041');
    assert.equal(ft1041.status, 'active');
    assert.equal(ft1041.daysLeft, 32);

    // MCD relational & RBAC integrity across M1 tables for API-created tenant
    withCopiedWritableDb(ctx.dbPath, (db) => {
      const tables = new Set(listTables(db));
      for (const reqTable of [
        'branches', 'pos_registers', 'offline_lease_tokens', 'roles', 'permissions',
        'role_permissions', 'user_permissions', 'customer_credits_karni', 'ingredients',
        'recipes_bom', 'returns_remakes_comps', 'dining_zones', 'reservations_vip',
      ]) {
        assert.ok(tables.has(reqTable), `Missing MCD table ${reqTable}`);
      }

      const branchId = Number(buildSchemaAwareRow(db, 'branches', { tenant_id: tid, name: 'Ksar Main' }).run().lastInsertRowid);
      buildSchemaAwareRow(db, 'pos_registers', { tenant_id: tid, branch_id: branchId, code: 'C1' }).run();
      buildSchemaAwareRow(db, 'customer_credits_karni', { tenant_id: tid, name: 'Client B2B', credit_limit_mru: 10000 }).run();
      const ingId = Number(buildSchemaAwareRow(db, 'ingredients', { tenant_id: tid, name: 'Sucre' }).run().lastInsertRowid);
      const prodId = Number(db.prepare("INSERT INTO products (tenant_id, sku, name_fr, price_retail) VALUES (?, 'T3-P', 'Produit', 200)").run(tid).lastInsertRowid);
      buildSchemaAwareRow(db, 'recipes_bom', { tenant_id: tid, product_id: prodId, ingredient_id: ingId, stock_qty: 1 }).run();
      const zoneId = Number(buildSchemaAwareRow(db, 'dining_zones', { tenant_id: tid, branch_id: branchId, name: 'Zone 1' }).run().lastInsertRowid);
      buildSchemaAwareRow(db, 'reservations_vip', { tenant_id: tid, branch_id: branchId, zone_id: zoneId, name: 'VIP' }).run();
      const orderId = Number(db.prepare("INSERT INTO orders (tenant_id, order_code, pay_method, total_mru) VALUES (?, 'T3-O', 'Cash', 200)").run(tid).lastInsertRowid);
      buildSchemaAwareRow(db, 'returns_remakes_comps', { tenant_id: tid, branch_id: branchId, order_id: orderId, product_id: prodId, action_type: 'COMP', reason: 'Test' }).run();

      assert.ok(getForeignKeys(db, 'branches').some((f) => f.table === 'tenants'));
      assert.throws(() => {
        buildSchemaAwareRow(db, 'branches', { tenant_id: 999999, name: 'Invalid FK' }).run();
      }, /FOREIGN KEY|constraint/i);
    });
  });

  it('T3.3: strict cross-tenant catalog isolation + OWNER JWT rejected (401) on every /api/admin/* route', async () => {
    const tARes = await ctx.request('POST', '/api/admin/tenants', {
      token: adminToken,
      body: {
        tenantId: 'FT-ISO-A',
        name: 'Restaurant Khaima Iso',
        module: 'resto',
        city: 'Tevragh Zeina',
        phone: '+222 44 10 10 10',
        username: 'khaima_owner_t3',
        accountPassword: 'KhaimaPass!2026',
      },
    });
    assert.equal(tARes.status, 201);
    const idA = tARes.json.id;

    const tBRes = await ctx.request('POST', '/api/admin/tenants', {
      token: adminToken,
      body: {
        tenantId: 'FT-ISO-B',
        name: 'Pharmacie Chinguetti Iso',
        module: 'pharma',
        city: 'Ksar',
        phone: '+222 44 20 20 20',
        username: 'chinguetti_owner_t3',
        accountPassword: 'PharmaPass!2026',
      },
    });
    assert.equal(tBRes.status, 201);
    const idB = tBRes.json.id;

    const impA = await ctx.request('POST', `/api/admin/tenants/${idA}/catalog/import`, {
      token: adminToken,
      body: {
        filename: 'resto.csv',
        format: 'csv',
        csvText: 'sku,name_fr,price_retail\nISO-A1,Méchoui A,1500\nISO-A2,Thé A,100\nISO-A3,Jus A,120\n',
      },
    });
    assert.equal(impA.status, 200);

    const impB = await ctx.request('POST', `/api/admin/tenants/${idB}/catalog/import`, {
      token: adminToken,
      body: {
        filename: 'pharma.csv',
        format: 'csv',
        csvText: 'sku,name_fr,price_retail\nISO-B1,Amoxicilline B,185\nISO-B2,Doliprane B,120\n',
      },
    });
    assert.equal(impB.status, 200);

    // Failed import on Tenant A must rollback cleanly without affecting A or B
    const badImpA = await ctx.request('POST', `/api/admin/tenants/${idA}/catalog/import`, {
      token: adminToken,
      body: {
        filename: 'bad.csv',
        format: 'csv',
        csvText: 'sku,name_fr,price_retail\nISO-NEW,ShouldRollback,300\nISO-BAD,InvalidPrice,-10\n',
      },
    });
    assert.equal(badImpA.status, 400);

    const catA = await ctx.request('GET', `/api/admin/tenants/${idA}/catalog`, { token: adminToken });
    const catB = await ctx.request('GET', `/api/admin/tenants/${idB}/catalog`, { token: adminToken });
    assert.equal(catA.json.products.length, 3);
    assert.equal(catB.json.products.length, 2);
    assert.equal(catA.json.products.some((p) => String(p.sku).startsWith('ISO-B')), false);
    assert.equal(catB.json.products.some((p) => String(p.sku).startsWith('ISO-A')), false);

    // Login as Tenant A OWNER and attempt every /api/admin/* route -> all MUST return 401
    const ownerLogin = await ctx.request('POST', '/api/auth/login', {
      body: { username: 'khaima_owner_t3', password: 'KhaimaPass!2026' },
    });
    assert.equal(ownerLogin.status, 200);
    const ownerToken = ownerLogin.json.token;

    const adminCalls = [
      ['GET', '/api/admin/me'],
      ['GET', '/api/admin/dashboard'],
      ['POST', '/api/admin/tenants', { name: 'Escalate' }],
      ['GET', `/api/admin/tenants/${idA}/catalog`],
      ['POST', `/api/admin/tenants/${idA}/catalog/import`, { csvText: 'name_fr,price_retail\nX,10\n' }],
      ['POST', `/api/admin/tenants/${idA}/offline-code`, { days: 30 }],
      ['POST', `/api/admin/tenants/${idA}/extend`, { days: 10 }],
      ['POST', `/api/admin/tenants/${idA}/toggle-lock`, {}],
      ['POST', `/api/admin/tenants/${idA}/support`, {}],
      ['POST', '/api/admin/payments/P-902/approve', {}],
    ];
    for (const [method, urlPath, body] of adminCalls) {
      const res = await ctx.request(method, urlPath, { token: ownerToken, ...(body ? { body } : {}) });
      assert.equal(res.status, 401, `OWNER JWT succeeded or returned ${res.status} on ${method} ${urlPath}`);
    }
  });

  it('T3.4: payload resilience — malformed JSON & oversized bodies return 4xx and server stays healthy', async () => {
    const badJson = await ctx.request('POST', '/api/admin/tenants', {
      token: adminToken,
      headers: { 'Content-Type': 'application/json' },
      rawBody: '{"broken": ',
    });
    assert.equal(badJson.status, 400);

    const bigBody = JSON.stringify({ padding: 'A'.repeat(1_100_000) });
    const tooLarge = await ctx.request('POST', '/api/admin/tenants', {
      token: adminToken,
      headers: { 'Content-Type': 'application/json' },
      rawBody: bigBody,
    }).catch((err) => ({ error: err }));
    if (!tooLarge.error) {
      assert.ok(tooLarge.status === 400 || tooLarge.status === 413, `Unexpected oversized status ${tooLarge.status}`);
    }

    const health = await ctx.request('GET', '/health');
    assert.equal(health.status, 200);
    assert.equal(health.json.ok, true);
  });
});
