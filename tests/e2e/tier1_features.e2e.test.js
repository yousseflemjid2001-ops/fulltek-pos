'use strict';

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const {
  FLUTTER_APP_DIR,
  PRISMA_SQLITE_PATH,
  PRISMA_PG_PATH,
  DEFAULT_ADMIN_USER,
  DEFAULT_ADMIN_PASS,
  startTestServer,
  loginAdmin,
  buildXlsxBuffer,
  decodeJwt,
  verifyEd25519Lease,
  withReadOnlyDb,
  withCopiedWritableDb,
  listTables,
  getTableColumns,
  getForeignKeys,
  buildSchemaAwareRow,
  parsePrismaSchema,
  runFlutterCli,
} = require('./helpers');

// ---------------------------------------------------------------------------
// Area 1.1: Super-Admin JWT Login & /api/admin/* Protection (6 tests)
// ---------------------------------------------------------------------------
describe('Tier 1 · Area 1.1: Super-Admin JWT Auth & /api/admin/* Guard', () => {
  let ctx;

  before(async () => {
    ctx = await startTestServer();
  });

  after(async () => {
    await ctx?.stop();
  });

  it('T1-AUTH-01: valid Super-Admin login via username issues HS256 JWT with exp', async () => {
    const res = await ctx.request('POST', '/api/admin/login', {
      body: { username: DEFAULT_ADMIN_USER, password: DEFAULT_ADMIN_PASS },
    });
    assert.equal(res.status, 200, res.text);
    assert.equal(res.json.ok, true);
    assert.equal(res.json.expiresIn, 86400);
    assert.equal(res.json.admin.username, 'taha');
    assert.equal(res.json.admin.email, 'taha@fulltek.mr');
    assert.equal(res.json.admin.role, 'SUPER_ADMIN');
    assert.equal(res.json.admin.passwordHash, undefined);
    assert.equal(res.json.admin.password_hash, undefined);

    const decoded = decodeJwt(res.json.token);
    assert.equal(decoded.header.alg, 'HS256');
    assert.equal(decoded.payload.role, 'SUPER_ADMIN');
    assert.ok(typeof decoded.payload.iat === 'number');
    assert.ok(typeof decoded.payload.exp === 'number');
    assert.ok(decoded.payload.exp > decoded.payload.iat);
  });

  it('T1-AUTH-02: login route alias (/api/admin/auth/login) and email alias work identically', async () => {
    const cases = [
      ['/api/admin/auth/login', { email: 'taha@fulltek.mr', password: DEFAULT_ADMIN_PASS }],
      ['/api/admin/login', { email: 'taha@fulltek.mr', password: DEFAULT_ADMIN_PASS }],
      ['/api/admin/auth/login', { username: DEFAULT_ADMIN_USER, password: DEFAULT_ADMIN_PASS }],
    ];
    for (const [route, payload] of cases) {
      const res = await ctx.request('POST', route, { body: payload });
      assert.equal(res.status, 200, `${route} failed: ${res.text}`);
      assert.equal(res.json.ok, true);
      assert.equal(res.json.admin.role, 'SUPER_ADMIN');
      const decoded = decodeJwt(res.json.token);
      assert.equal(decoded.payload.role, 'SUPER_ADMIN');
    }
  });

  it('T1-AUTH-03: GET /api/admin/me returns session profile without password hash', async () => {
    const { token } = await loginAdmin(ctx);
    const res = await ctx.request('GET', '/api/admin/me', { token });
    assert.equal(res.status, 200, res.text);
    assert.equal(res.json.ok, true);
    assert.equal(res.json.admin.username, 'taha');
    assert.equal(res.json.admin.role, 'SUPER_ADMIN');
    assert.equal(res.json.admin.password, undefined);
    assert.equal(res.json.admin.passwordHash, undefined);
    assert.equal(res.json.admin.password_hash, undefined);
  });

  it('T1-AUTH-04: protected /api/admin/* CRUD lifecycle works with Bearer JWT', async () => {
    const { token } = await loginAdmin(ctx);

    const dash0 = await ctx.request('GET', '/api/admin/dashboard', { token });
    assert.equal(dash0.status, 200);
    assert.ok(Array.isArray(dash0.json.stores));
    assert.ok(dash0.json.stores.length >= 7);

    const uniqueUser = `t1_crud_${Date.now()}`;
    const createRes = await ctx.request('POST', '/api/admin/tenants', {
      token,
      body: {
        tenantId: `FT-T1-${String(Date.now()).slice(-4)}`,
        name: 'Boutique T1 CRUD',
        module: 'market',
        city: 'Tevragh Zeina',
        phone: '+222 44 00 11 22',
        username: uniqueUser,
        accountPassword: 'StorePass!2026',
        tills: 2,
        daysLeft: 10,
      },
    });
    assert.equal(createRes.status, 201, createRes.text);
    const tid = createRes.json.id;
    assert.ok(tid);

    const patchRes = await ctx.request('PATCH', `/api/admin/tenants/${tid}`, {
      token,
      body: { tills: 4, nif: '00112233', rc: 'RC-NKC-100' },
    });
    assert.equal(patchRes.status, 200, patchRes.text);
    assert.equal(patchRes.json.tills, 4);
    assert.equal(patchRes.json.nif, '00112233');

    const extendRes = await ctx.request('POST', `/api/admin/tenants/${tid}/extend`, {
      token,
      body: { days: 15 },
    });
    assert.equal(extendRes.status, 200, extendRes.text);
    assert.equal(extendRes.json.daysLeft, 25);
    assert.equal(extendRes.json.status, 'active');

    const lockRes = await ctx.request('POST', `/api/admin/tenants/${tid}/toggle-lock`, { token, body: {} });
    assert.equal(lockRes.status, 200);
    assert.equal(lockRes.json.status, 'locked');

    const unlockRes = await ctx.request('POST', `/api/admin/tenants/${tid}/toggle-lock`, { token, body: {} });
    assert.equal(unlockRes.status, 200);
    assert.equal(unlockRes.json.status, 'active');

    const supRes = await ctx.request('POST', `/api/admin/tenants/${tid}/support`, { token, body: {} });
    assert.equal(supRes.status, 200);
    assert.equal(supRes.json.ok, true);

    const payRes = await ctx.request('POST', '/api/admin/payments/P-901/approve', { token, body: {} });
    assert.equal(payRes.status, 200, payRes.text);
    assert.equal(payRes.json.ok, true);

    const dash1 = await ctx.request('GET', '/api/admin/dashboard', { token });
    assert.equal(dash1.status, 200);
    assert.ok(dash1.json.stores.some((s) => s.id === tid));
    assert.equal(dash1.json.payments.some((p) => p.id === 'P-901'), false);
  });

  it('T1-AUTH-05: SUPERADMIN_USER and SUPERADMIN_PASSWORD env overrides work on fresh DB', async () => {
    const customCtx = await startTestServer({
      subprocess: true,
      superadminUser: 'customadmin',
      superadminPassword: 'CustomPass!2026',
    });
    try {
      const loginRes = await customCtx.request('POST', '/api/admin/login', {
        body: { username: 'customadmin', password: 'CustomPass!2026' },
      });
      assert.equal(loginRes.status, 200, loginRes.text);
      assert.equal(loginRes.json.admin.username, 'customadmin');

      const meRes = await customCtx.request('GET', '/api/admin/me', {
        token: loginRes.json.token,
      });
      assert.equal(meRes.status, 200);
      assert.equal(meRes.json.admin.username, 'customadmin');
    } finally {
      await customCtx.stop();
    }
  });

  it('T1-AUTH-06: public routes remain accessible without Super-Admin JWT', async () => {
    const healthRes = await ctx.request('GET', '/health');
    assert.equal(healthRes.status, 200);
    assert.equal(healthRes.json.ok, true);
    assert.ok(healthRes.json.tenants >= 7);

    const ownerLogin = await ctx.request('POST', '/api/auth/login', {
      body: { username: 'darelkram41', password: 'FullTek@2026' },
    });
    assert.equal(ownerLogin.status, 200, ownerLogin.text);
    assert.ok(ownerLogin.json.token);
    const decoded = decodeJwt(ownerLogin.json.token);
    assert.equal(decoded.payload.role, 'OWNER');
    assert.ok(decoded.payload.exp > decoded.payload.iat);

    const pubRes = await ctx.request('GET', '/api/licenses/public-key');
    assert.equal(pubRes.status, 200, pubRes.text);
    assert.equal(pubRes.json.ok, true);
    assert.equal(pubRes.json.algorithm, 'Ed25519');

    const verifyRes = await ctx.request('POST', '/api/licenses/verify', {
      body: { leaseToken: 'invalid.token' },
    });
    assert.equal(verifyRes.status, 200);
    assert.equal(verifyRes.json.valid, false);
  });
});

// ---------------------------------------------------------------------------
// Area 1.2: MCD Schema, RBAC & Prisma Parity (6 tests)
// ---------------------------------------------------------------------------
describe('Tier 1 · Area 1.2: MCD Schema, RBAC & Prisma Parity', () => {
  let ctx;

  before(async () => {
    ctx = await startTestServer();
  });

  after(async () => {
    await ctx?.stop();
  });

  it('T1-MCD-01: SQLite WAL mode and all baseline + Étape 1 R3 MCD tables exist', () => {
    const requiredTables = [
      'tenants', 'users', 'saas_payments', 'offline_codes', 'audit_logs',
      'categories', 'products', 'stock_batches', 'orders', 'order_items', 'cash_closings_z',
      'super_admins', 'signing_keys', 'branches', 'pos_registers',
      'roles', 'permissions', 'role_permissions', 'user_permissions',
      'offline_lease_tokens', 'customer_credits_karni', 'karni_transactions',
      'ingredients', 'recipes_bom', 'returns_remakes_comps',
      'dining_zones', 'reservations_vip',
    ];

    withReadOnlyDb(ctx.dbPath, (db) => {
      const jm = db.prepare('PRAGMA journal_mode').get();
      assert.equal(String(jm.journal_mode).toLowerCase(), 'wal');
      const tables = new Set(listTables(db));
      for (const t of requiredTables) {
        assert.ok(tables.has(t), `Missing MCD table in SQLite: ${t}`);
      }
    });
  });

  it('T1-MCD-02: 9 CDC RBAC roles and >= 9 sensitive permissions are seeded with role_permissions', () => {
    withReadOnlyDb(ctx.dbPath, (db) => {
      const roles = db.prepare('SELECT * FROM roles').all();
      const permissions = db.prepare('SELECT * FROM permissions').all();
      const rolePerms = db.prepare('SELECT * FROM role_permissions').all();

      assert.ok(roles.length >= 9, `Expected >= 9 RBAC roles, got ${roles.length}`);
      assert.ok(permissions.length >= 9, `Expected >= 9 permissions, got ${permissions.length}`);
      assert.ok(rolePerms.length >= 9, `Expected populated role_permissions, got ${rolePerms.length}`);

      const roleText = roles.map((r) => Object.values(r).join(' ').toUpperCase()).join('\n');
      const expectedRoleTokens = [
        /SUPER.?ADMIN/,
        /OWNER|PROPRI/,
        /MANAGER|GERANT|GÉRANT/,
        /CASHIER|CAISSIER/,
        /WAITER|SERVEUR/,
        /CHEF|CUISINIER|BARMAN/,
        /STOCK|MAGASINIER/,
        /PHARM/,
        /ACCOUNTANT|COMPTABLE/,
      ];
      for (const rx of expectedRoleTokens) {
        assert.match(roleText, rx, `Missing CDC RBAC role matching ${rx}`);
      }

      // Check OWNER has full permission count and restricted roles have fewer (exclude explicit 'DENY' matrix rows)
      const ownerRow = roles.find((r) => /OWNER|PROPRI/i.test(Object.values(r).join(' ')));
      const waiterRow = roles.find((r) => /WAITER|SERVEUR/i.test(Object.values(r).join(' ')));
      assert.ok(ownerRow, 'OWNER role row must exist');
      assert.ok(waiterRow, 'WAITER role row must exist');
      const isGranted = (rp) => String(rp.access_mode || 'ALLOW').toUpperCase() !== 'DENY';
      const ownerPermsCount = rolePerms.filter((rp) => rp.role_id === ownerRow.id && isGranted(rp)).length;
      const waiterPermsCount = rolePerms.filter((rp) => rp.role_id === waiterRow.id && isGranted(rp)).length;
      assert.ok(ownerPermsCount >= 9, `OWNER should have >= 9 permissions, got ${ownerPermsCount}`);
      assert.ok(waiterPermsCount < ownerPermsCount, 'WAITER should have fewer permissions than OWNER');
    });
  });

  it('T1-MCD-03: seeded super_admins + 7 tenants exist and restart on same DB is idempotent', async () => {
    const firstCounts = withReadOnlyDb(ctx.dbPath, (db) => {
      const admins = db.prepare('SELECT * FROM super_admins').all();
      const tenants = db.prepare('SELECT tenant_code FROM tenants ORDER BY id').all();
      const roles = db.prepare('SELECT COUNT(*) AS cnt FROM roles').get().cnt;
      const perms = db.prepare('SELECT COUNT(*) AS cnt FROM permissions').get().cnt;
      return { admins, tenants, roles, perms };
    });

    assert.ok(firstCounts.admins.length >= 1);
    const taha = firstCounts.admins.find((a) => a.username === 'taha');
    assert.ok(taha, 'Seeded super_admin "taha" must exist');
    assert.equal(taha.email, 'taha@fulltek.mr');
    assert.match(String(taha.password_hash || ''), /^[a-f0-9]+:[a-f0-9]+$/i);
    assert.equal(firstCounts.tenants.length, 7);

    // Stop server and restart on same dbPath
    const sameDbPath = ctx.dbPath;
    const sameTmpDir = ctx.tmpDir;
    await ctx.stop({ cleanup: false });

    ctx = await startTestServer({ dbPath: sameDbPath, tmpDir: sameTmpDir, ownsTmpDir: true });
    const secondCounts = withReadOnlyDb(ctx.dbPath, (db) => ({
      admins: db.prepare('SELECT COUNT(*) AS cnt FROM super_admins').get().cnt,
      tenants: db.prepare('SELECT COUNT(*) AS cnt FROM tenants').get().cnt,
      roles: db.prepare('SELECT COUNT(*) AS cnt FROM roles').get().cnt,
      perms: db.prepare('SELECT COUNT(*) AS cnt FROM permissions').get().cnt,
    }));

    assert.equal(secondCounts.admins, firstCounts.admins.length);
    assert.equal(secondCounts.tenants, firstCounts.tenants.length);
    assert.equal(secondCounts.roles, firstCounts.roles);
    assert.equal(secondCounts.perms, firstCounts.perms);
  });

  it('T1-MCD-04: relational inserts across all new R3 MCD tables succeed with FK integrity', () => {
    withCopiedWritableDb(ctx.dbPath, (db) => {
      const tenant = db.prepare('SELECT id FROM tenants ORDER BY id LIMIT 1').get();
      assert.ok(tenant);
      const tid = tenant.id;

      const branchRes = buildSchemaAwareRow(db, 'branches', {
        tenant_id: tid,
        name: 'Siège Tevragh-Zeina',
        code: 'BR-TZ-01',
        city: 'Nouakchott',
      }).run();
      const branchId = Number(branchRes.lastInsertRowid);
      assert.ok(branchId > 0);

      const regRes = buildSchemaAwareRow(db, 'pos_registers', {
        tenant_id: tid,
        branch_id: branchId,
        code: 'C99',
        name: 'Caisse Secondaire MCD C99',
        hardware_fingerprint: 'HW-MCD-99',
        is_master: 0,
      }).run();
      assert.ok(Number(regRes.lastInsertRowid) > 0);

      const karniRes = buildSchemaAwareRow(db, 'customer_credits_karni', {
        tenant_id: tid,
        name: 'Société Mauritanie BTP',
        phone: '+222 46 00 11 00',
        nif: '00998877',
        credit_limit_mru: 50000,
        current_debt_mru: 12000,
      }).run();
      const creditId = Number(karniRes.lastInsertRowid);
      assert.ok(creditId > 0);

      const ktRes = buildSchemaAwareRow(db, 'karni_transactions', {
        tenant_id: tid,
        credit_id: creditId,
        amount_mru: 5000,
        action_type: 'REPAYMENT',
        reason: 'Paiement Bankily',
      }).run();
      const ktId = Number(ktRes.lastInsertRowid);
      assert.ok(ktId > 0);
      const ktRow = db.prepare('SELECT customer_id, tx_type, amount_mru FROM karni_transactions WHERE id = ?').get(ktId);
      assert.equal(ktRow.customer_id, creditId);
      assert.equal(ktRow.tx_type, 'REPAYMENT');
      assert.equal(ktRow.amount_mru, 5000);

      // Ensure a parent product & order exist for recipes_bom & returns_remakes_comps
      const prodRes = db.prepare(`
        INSERT INTO products (tenant_id, sku, name_fr, price_retail)
        VALUES (?, 'MCD-PROD-1', 'Plat Test BOM', 900)
      `).run(tid);
      const productId = Number(prodRes.lastInsertRowid);

      const ingRes = buildSchemaAwareRow(db, 'ingredients', {
        tenant_id: tid,
        name: 'Viande Chameau',
        unit: 'kg',
        pmp_cost: 420,
        stock_qty: 25,
      }).run();
      const ingredientId = Number(ingRes.lastInsertRowid);
      assert.ok(ingredientId > 0);
      const ingRow = db.prepare('SELECT pmp_cost_mru, current_stock FROM ingredients WHERE id = ?').get(ingredientId);
      assert.equal(ingRow.pmp_cost_mru, 420);
      assert.equal(ingRow.current_stock, 25);

      const bomRes = buildSchemaAwareRow(db, 'recipes_bom', {
        tenant_id: tid,
        product_id: productId,
        ingredient_id: ingredientId,
        stock_qty: 0.35,
        unit: 'kg',
        condition_type: 'ALWAYS',
      }).run();
      const bomId = Number(bomRes.lastInsertRowid);
      assert.ok(bomId > 0);
      const bomRow = db.prepare('SELECT qty_per_unit FROM recipes_bom WHERE id = ?').get(bomId);
      assert.equal(bomRow.qty_per_unit, 0.35);

      const zoneRes = buildSchemaAwareRow(db, 'dining_zones', {
        tenant_id: tid,
        branch_id: branchId,
        name: 'Khaima VIP',
        min_spend_mru: 3000,
      }).run();
      const zoneId = Number(zoneRes.lastInsertRowid);
      assert.ok(zoneId > 0);

      const vipRes = buildSchemaAwareRow(db, 'reservations_vip', {
        tenant_id: tid,
        branch_id: branchId,
        zone_id: zoneId,
        name: 'Client VIP Nouakchott',
        phone: '+222 44 12 34 56',
        party_size: 8,
        deposit_mru: 1000,
        deposit_method: 'Bankily',
        reserved_at: '2026-11-20T20:00:00Z',
        status: 'CONFIRMED',
      }).run();
      assert.ok(Number(vipRes.lastInsertRowid) > 0);

      const orderRes = db.prepare(`
        INSERT INTO orders (tenant_id, order_code, table_name, status, pay_method, total_mru)
        VALUES (?, 'ORD-MCD-1', 'Khaima 1', 'PAID', 'Cash', 900)
      `).run(tid);
      const orderId = Number(orderRes.lastInsertRowid);

      const remRes = buildSchemaAwareRow(db, 'returns_remakes_comps', {
        tenant_id: tid,
        branch_id: branchId,
        order_id: orderId,
        product_id: productId,
        action_type: 'REMAKE',
        reason: 'Cuisson insuffisante',
        amount_mru: 900,
      }).run();
      assert.ok(Number(remRes.lastInsertRowid) > 0);
    });
  });

  it('T1-MCD-05: prisma/schema.prisma uses sqlite provider and declares all baseline + R3 models', () => {
    const parsed = parsePrismaSchema(PRISMA_SQLITE_PATH);
    assert.equal(parsed.provider, 'sqlite');
    assert.equal(parsed.balancedBraces, true);

    const expectedTablesOrModels = [
      'tenants', 'users', 'saas_payments', 'offline_codes', 'audit_logs',
      'categories', 'products', 'stock_batches', 'orders', 'order_items', 'cash_closings_z',
      'super_admins', 'signing_keys', 'branches', 'pos_registers',
      'roles', 'permissions', 'role_permissions', 'user_permissions',
      'offline_lease_tokens', 'customer_credits_karni', 'karni_transactions',
      'ingredients', 'recipes_bom', 'returns_remakes_comps',
      'dining_zones', 'reservations_vip',
    ];

    const available = new Set();
    for (const [modelName, info] of parsed.models.entries()) {
      available.add(modelName.toLowerCase());
      if (info.mapName) available.add(info.mapName.toLowerCase());
    }

    for (const expected of expectedTablesOrModels) {
      const singularish = expected.replace(/_/g, '').toLowerCase();
      const found =
        available.has(expected) ||
        [...available].some((a) => a.replace(/_/g, '').startsWith(singularish.slice(0, -1)));
      assert.ok(found, `schema.prisma missing model/@@map for "${expected}"`);
    }
  });

  it('T1-MCD-06: prisma/schema.postgresql.prisma uses postgresql provider and has full model parity', () => {
    const sqliteSchema = parsePrismaSchema(PRISMA_SQLITE_PATH);
    const pgSchema = parsePrismaSchema(PRISMA_PG_PATH);
    assert.equal(pgSchema.provider, 'postgresql');
    assert.equal(pgSchema.balancedBraces, true);

    for (const modelName of sqliteSchema.models.keys()) {
      assert.ok(pgSchema.models.has(modelName), `schema.postgresql.prisma missing model ${modelName}`);
    }
  });
});

// ---------------------------------------------------------------------------
// Area 1.3: Ed25519 Offline Licenses (6 tests)
// ---------------------------------------------------------------------------
describe('Tier 1 · Area 1.3: Ed25519 Offline Licenses', () => {
  let ctx;

  before(async () => {
    ctx = await startTestServer();
  });

  after(async () => {
    await ctx?.stop();
  });

  it('T1-LIC-01: GET /api/licenses/public-key returns valid Ed25519 SPKI PEM', async () => {
    const res = await ctx.request('GET', '/api/licenses/public-key');
    assert.equal(res.status, 200, res.text);
    assert.equal(res.json.ok, true);
    assert.equal(res.json.algorithm, 'Ed25519');
    assert.ok(typeof res.json.keyId === 'string' && res.json.keyId.length > 0);
    assert.ok(res.json.publicKey.includes('BEGIN PUBLIC KEY'));

    const keyObj = crypto.createPublicKey(res.json.publicKey);
    assert.equal(keyObj.asymmetricKeyType, 'ed25519');
  });

  it('T1-LIC-02: Ed25519 keypair persists across server restarts on the same SQLite DB', async () => {
    const { token } = await loginAdmin(ctx);
    const pub1 = await ctx.request('GET', '/api/licenses/public-key');
    assert.equal(pub1.status, 200);

    const licRes = await ctx.request('POST', '/api/admin/tenants/1/offline-code', {
      token,
      body: { days: 30, graceDays: 7, registerCode: 'C1' },
    });
    assert.equal(licRes.status, 200, licRes.text);
    const savedLeaseToken = licRes.json.leaseToken;

    const sameDb = ctx.dbPath;
    const sameDir = ctx.tmpDir;
    await ctx.stop({ cleanup: false });
    ctx = await startTestServer({ dbPath: sameDb, tmpDir: sameDir, ownsTmpDir: true });

    const pub2 = await ctx.request('GET', '/api/licenses/public-key');
    assert.equal(pub2.status, 200);
    assert.equal(pub2.json.keyId, pub1.json.keyId);
    assert.equal(pub2.json.publicKey, pub1.json.publicKey);

    const verifyAfterRestart = await ctx.request('POST', '/api/licenses/verify', {
      body: { leaseToken: savedLeaseToken },
    });
    assert.equal(verifyAfterRestart.status, 200);
    assert.equal(verifyAfterRestart.json.valid, true);
  });

  it('T1-LIC-03: POST /api/admin/tenants/:id/offline-code issues complete signed lease response', async () => {
    const { token } = await loginAdmin(ctx);
    const res = await ctx.request('POST', '/api/admin/tenants/1/offline-code', {
      token,
      body: {
        days: 30,
        graceDays: 7,
        registerCode: 'C1',
        hardwareFingerprint: 'HW-TEST-01',
      },
    });
    assert.equal(res.status, 200, res.text);
    assert.equal(res.json.ok, true);
    assert.ok(typeof res.json.code === 'string' && res.json.code.length >= 8);
    assert.equal(res.json.days, 30);
    assert.equal(res.json.graceDays, 7);
    assert.ok(res.json.keyId);
    assert.ok(res.json.issuedAt);
    assert.ok(res.json.expiresAt);
    assert.equal(res.json.leaseToken, `${Buffer.from(res.json.leaseToken.split('.')[0], 'base64url').toString('base64url')}.${res.json.signature}`);

    const p = res.json.payload;
    assert.equal(p.version, 1);
    assert.equal(p.tenantId, 1);
    assert.equal(p.registerCode, 'C1');
    assert.equal(p.hardwareFingerprint, 'HW-TEST-01');
    assert.equal(p.days, 30);
    assert.equal(p.graceDays, 7);
    assert.ok(p.nonce);
    assert.ok(p.tillsQuota >= 1);
    assert.ok(p.tenantCode);
  });

  it('T1-LIC-04: independent node:crypto.verify validates Ed25519 signature and 30d duration', async () => {
    const { token } = await loginAdmin(ctx);
    const res = await ctx.request('POST', '/api/admin/tenants/1/offline-code', {
      token,
      body: { days: 30, graceDays: 7, registerCode: 'C2' },
    });
    assert.equal(res.status, 200);

    const check = verifyEd25519Lease(res.json.leaseToken, res.json.publicKey);
    assert.equal(check.valid, true);
    assert.deepEqual(check.payload, res.json.payload);

    const diffMs = Date.parse(res.json.expiresAt) - Date.parse(res.json.issuedAt);
    assert.equal(diffMs, 30 * 86400 * 1000);
  });

  it('T1-LIC-05: POST /api/licenses/verify succeeds with server default key and explicit publicKey', async () => {
    const { token } = await loginAdmin(ctx);
    const res = await ctx.request('POST', '/api/admin/tenants/1/offline-code', {
      token,
      body: { days: 15, graceDays: 3 },
    });
    assert.equal(res.status, 200);

    const v1 = await ctx.request('POST', '/api/licenses/verify', {
      body: { leaseToken: res.json.leaseToken },
    });
    assert.equal(v1.status, 200);
    assert.equal(v1.json.valid, true);
    assert.equal(v1.json.payload.days, 15);
    assert.equal(v1.json.payload.graceDays, 3);

    const v2 = await ctx.request('POST', '/api/licenses/verify', {
      body: { leaseToken: res.json.leaseToken, publicKey: res.json.publicKey },
    });
    assert.equal(v2.status, 200);
    assert.equal(v2.json.valid, true);
    assert.equal(v2.json.payload.code, res.json.code);
  });

  it('T1-LIC-06: offline lease is persisted in offline_lease_tokens, offline_codes, and audit_logs', async () => {
    const { token } = await loginAdmin(ctx);
    const res = await ctx.request('POST', '/api/admin/tenants/2/offline-code', {
      token,
      body: { days: 45, graceDays: 5, registerCode: 'C3' },
    });
    assert.equal(res.status, 200);

    withReadOnlyDb(ctx.dbPath, (db) => {
      const leaseRows = db.prepare('SELECT * FROM offline_lease_tokens WHERE tenant_id = 2').all();
      assert.ok(leaseRows.length >= 1, 'Expected row in offline_lease_tokens');
      const matched = leaseRows.find((r) => JSON.stringify(r).includes(res.json.code));
      assert.ok(matched, 'offline_lease_tokens row must record issued code');

      const codeRows = db.prepare('SELECT * FROM offline_codes WHERE tenant_id = 2 AND code = ?').all(res.json.code);
      assert.equal(codeRows.length, 1);

      const audits = db.prepare('SELECT * FROM audit_logs WHERE tenant_id = 2').all();
      assert.ok(audits.length >= 1);
    });
  });
});

// ---------------------------------------------------------------------------
// Area 1.4: 1-Click Catalog Import (6 tests)
// ---------------------------------------------------------------------------
describe('Tier 1 · Area 1.4: 1-Click Catalog CSV / XLSX Import', () => {
  let ctx;
  let adminToken;
  let pharmaTenantId;

  before(async () => {
    ctx = await startTestServer();
    const login = await loginAdmin(ctx);
    adminToken = login.token;
    const dash = await ctx.request('GET', '/api/admin/dashboard', { token: adminToken });
    const pharma = dash.json.stores.find((s) => s.tenantId === 'FT-3019');
    assert.ok(pharma, 'Seeded tenant FT-3019 must exist');
    pharmaTenantId = pharma.id;
  });

  after(async () => {
    await ctx?.stop();
  });

  it('T1-CAT-01: imports comma CSV via JSON payload and raw text/csv body', async () => {
    const csv1 = [
      'sku,name_fr,category,price_retail',
      'RST-001,Méchoui Royal,Grillades,1800',
      'RST-002,Jus Bissap,Boissons,150',
    ].join('\n');

    const res1 = await ctx.request('POST', '/api/admin/tenants/1/catalog/import', {
      token: adminToken,
      body: { filename: 'menu.csv', format: 'csv', csvText: csv1 },
    });
    assert.equal(res1.status, 200, res1.text);
    assert.equal(res1.json.ok, true);
    assert.equal(res1.json.tenantId, 1);
    assert.equal(res1.json.format, 'csv');
    assert.equal(res1.json.totalRows, 2);
    assert.equal(res1.json.created, 2);
    assert.equal(res1.json.updated, 0);
    assert.equal(res1.json.categoriesCreated, 2);
    assert.deepEqual(res1.json.errors, []);

    const csv2 = [
      'sku,name_fr,category,price_retail',
      'RST-003,Tacos Poulet,Fast-Food,350',
    ].join('\n');

    const res2 = await ctx.request('POST', '/api/admin/tenants/1/catalog/import', {
      token: adminToken,
      headers: { 'Content-Type': 'text/csv; charset=utf-8' },
      rawBody: csv2,
    });
    assert.equal(res2.status, 200, res2.text);
    assert.equal(res2.json.created, 1);
  });

  it('T1-CAT-02: imports semicolon CSV with UTF-8 Arabic (name_ar, category_ar) without corruption', async () => {
    const csv = [
      'sku;name_fr;name_ar;category;category_ar;price_retail',
      'AR-001;Thé à la menthe;شاي بالنعناع;Boissons;مشروبات;150',
      'AR-002;Couscous Royal;كسكس ملكي;Plats;أطباق;850',
      'AR-003;Lait Frais;ألبان;Produits Laitiers;منتجات الألبان;220',
    ].join('\n');

    const res = await ctx.request('POST', '/api/admin/tenants/2/catalog/import', {
      token: adminToken,
      body: { filename: 'arabic.csv', format: 'csv', csvText: csv },
    });
    assert.equal(res.status, 200, res.text);
    assert.equal(res.json.created, 3);

    const catRes = await ctx.request('GET', '/api/admin/tenants/2/catalog', { token: adminToken });
    assert.equal(catRes.status, 200);
    const tea = catRes.json.products.find((p) => p.sku === 'AR-001');
    assert.ok(tea);
    assert.equal(tea.name_ar ?? tea.nameAr, 'شاي بالنعناع');

    withReadOnlyDb(ctx.dbPath, (db) => {
      const dbProd = db.prepare("SELECT name_ar FROM products WHERE tenant_id = 2 AND sku = 'AR-002'").get();
      assert.equal(dbProd.name_ar, 'كسكس ملكي');
      const dbCat = db.prepare("SELECT name_ar FROM categories WHERE tenant_id = 2 AND name_fr = 'Produits Laitiers'").get();
      assert.equal(dbCat.name_ar, 'منتجات الألبان');
    });
  });

  it('T1-CAT-03: imports native .xlsx (via JSON contentBase64 and raw binary OOXML)', async () => {
    const xlsx1 = buildXlsxBuffer([
      ['sku', 'name_fr', 'name_ar', 'category', 'price_retail'],
      ['XL-101', 'Café Touba', 'قهوة طوبا', 'Boissons Chaudes', 100],
      ['XL-102', 'Croissant Beurre', 'كرواسون', 'Boulangerie', 120],
    ]);

    const res1 = await ctx.request('POST', '/api/admin/tenants/4/catalog/import', {
      token: adminToken,
      body: {
        filename: 'catalogue.xlsx',
        format: 'xlsx',
        contentBase64: xlsx1.toString('base64'),
      },
    });
    assert.equal(res1.status, 200, res1.text);
    assert.equal(res1.json.format, 'xlsx');
    assert.equal(res1.json.created, 2);

    const xlsx2 = buildXlsxBuffer([
      ['sku', 'name_fr', 'price_retail'],
      ['XL-103', 'Eau Minérale 1.5L', 80],
    ]);

    const res2 = await ctx.request('POST', '/api/admin/tenants/4/catalog/import', {
      token: adminToken,
      headers: {
        'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      },
      rawBody: xlsx2,
    });
    assert.equal(res2.status, 200, res2.text);
    assert.equal(res2.json.format, 'xlsx');
    assert.equal(res2.json.created, 1);

    withReadOnlyDb(ctx.dbPath, (db) => {
      const cnt = db.prepare('SELECT COUNT(*) AS cnt FROM products WHERE tenant_id = 4').get().cnt;
      assert.equal(cnt, 3);
    });
  });

  it('T1-CAT-04: upserts existing products matched by SKU and by barcode without duplicating rows', async () => {
    const initialCsv = [
      'sku,barcode,name_fr,price_retail',
      'SKU-UPS-1,6130001112223,Original Product,500',
      'SKU-UPS-2,6130001119999,Barcode Target,300',
    ].join('\n');

    const r1 = await ctx.request('POST', '/api/admin/tenants/5/catalog/import', {
      token: adminToken,
      body: { filename: 'init.csv', format: 'csv', csvText: initialCsv },
    });
    assert.equal(r1.status, 200, r1.text);
    assert.equal(r1.json.created, 2);

    const updateCsv = [
      'sku,barcode,name_fr,price_retail',
      'SKU-UPS-1,6130001112223,Updated By SKU,650',
      ',6130001119999,Updated By Barcode,390',
    ].join('\n');

    const r2 = await ctx.request('POST', '/api/admin/tenants/5/catalog/import', {
      token: adminToken,
      body: { filename: 'upd.csv', format: 'csv', csvText: updateCsv },
    });
    assert.equal(r2.status, 200, r2.text);
    assert.equal(r2.json.created, 0);
    assert.equal(r2.json.updated, 2);

    withReadOnlyDb(ctx.dbPath, (db) => {
      const rows = db.prepare('SELECT sku, barcode, name_fr, price_retail FROM products WHERE tenant_id = 5').all();
      assert.equal(rows.length, 2);
      const bySku = rows.find((r) => r.sku === 'SKU-UPS-1');
      assert.equal(bySku.price_retail, 650);
      assert.equal(bySku.name_fr, 'Updated By SKU');
      const byBc = rows.find((r) => r.barcode === '6130001119999');
      assert.equal(byBc.price_retail, 390);
      assert.equal(byBc.name_fr, 'Updated By Barcode');
    });
  });

  it('T1-CAT-05: GET /api/admin/tenants/:id/catalog returns imported categories and products', async () => {
    const res = await ctx.request('GET', '/api/admin/tenants/2/catalog', { token: adminToken });
    assert.equal(res.status, 200, res.text);
    assert.equal(res.json.ok, true);
    assert.equal(res.json.tenantId, 2);
    assert.ok(Array.isArray(res.json.categories) && res.json.categories.length >= 3);
    assert.ok(Array.isArray(res.json.products) && res.json.products.length >= 3);
  });

  it('T1-CAT-06: Pharmacy import persists track_fefo, requires_cnam, and stock_batches lot', async () => {
    const csv = [
      'sku,barcode,name_fr,name_ar,category,price_retail,track_fefo,requires_cnam,lot_number,qty,expires_at',
      'MED-PAR-1000,3400930008888,Paracétamol 1000mg,باراسيتامول,Antalgiques,120,1,1,LOT-NEW-99,25,2028-01-15',
    ].join('\n');

    const res = await ctx.request('POST', `/api/admin/tenants/${pharmaTenantId}/catalog/import`, {
      token: adminToken,
      body: { filename: 'pharma.csv', format: 'csv', csvText: csv },
    });
    assert.equal(res.status, 200, res.text);
    assert.equal(res.json.created, 1);

    withReadOnlyDb(ctx.dbPath, (db) => {
      const prod = db
        .prepare("SELECT * FROM products WHERE tenant_id = ? AND sku = 'MED-PAR-1000'")
        .get(pharmaTenantId);
      assert.ok(prod);
      assert.equal(prod.track_fefo, 1);
      assert.equal(prod.requires_cnam, 1);

      const batch = db
        .prepare("SELECT * FROM stock_batches WHERE tenant_id = ? AND product_id = ? AND lot_number = 'LOT-NEW-99'")
        .get(pharmaTenantId, prod.id);
      assert.ok(batch, 'Expected stock_batches row for LOT-NEW-99');
      assert.equal(batch.qty, 25);
      assert.equal(batch.expires_at, '2028-01-15');
    });
  });
});

// ---------------------------------------------------------------------------
// Area 1.5: Flutter Super-Admin CLI Verification (5 tests, zero browser)
// ---------------------------------------------------------------------------
describe('Tier 1 · Area 1.5: Flutter Super-Admin CLI Verification (R5)', () => {
  it('T1-FLT-01: flutter analyze --no-pub exits 0 with zero issues', () => {
    const res = runFlutterCli(['analyze', '--no-pub']);
    assert.equal(res.status, 0, `flutter analyze failed:\n${res.stdout}\n${res.stderr}`);
    assert.match(res.stdout, /No issues found!/i);
  });

  it('T1-FLT-02: flutter test --no-pub exits 0 and passes all tests', () => {
    const res = runFlutterCli(['test', '--no-pub']);
    assert.equal(res.status, 0, `flutter test failed:\n${res.stdout}\n${res.stderr}`);
    assert.match(res.stdout, /All tests passed!/i);
  });

  it('T1-FLT-03: flutter test --no-pub --machine confirms passing auth/login and catalog import tests', () => {
    const res = runFlutterCli(['test', '--no-pub', '--machine']);
    assert.equal(res.status, 0, `flutter test --machine failed:\n${res.stdout}\n${res.stderr}`);

    const events = res.stdout
      .split(/\r?\n/)
      .filter((line) => line.trim().startsWith('{'))
      .map((line) => {
        try {
          return JSON.parse(line);
        } catch {
          return null;
        }
      })
      .filter(Boolean);

    const testNamesById = new Map();
    for (const ev of events) {
      if (ev.type === 'testStart' && ev.test && !ev.test.name.startsWith('loading ')) {
        testNamesById.set(ev.test.id, ev.test.name);
      }
    }

    const doneEvents = events.filter((ev) => ev.type === 'testDone' && !ev.hidden && testNamesById.has(ev.testID));
    assert.ok(doneEvents.length >= 4, `Expected >= 4 Flutter tests after M3, got ${doneEvents.length}`);

    for (const ev of doneEvents) {
      assert.equal(ev.result, 'success', `Flutter test failed: ${testNamesById.get(ev.testID)}`);
    }

    const passedNames = doneEvents.map((ev) => testNamesById.get(ev.testID));
    assert.ok(
      passedNames.some((n) => /login|auth|jwt|401/i.test(n)),
      `Expected passing Flutter test covering JWT auth/login; got: ${passedNames.join(' | ')}`,
    );
    assert.ok(
      passedNames.some((n) => /catalog|import|csv|xlsx/i.test(n)),
      `Expected passing Flutter test covering 1-click catalog import; got: ${passedNames.join(' | ')}`,
    );
  });

  it('T1-FLT-04: pubspec.yaml adds zero third-party pub dependencies and zero browser drivers', () => {
    const pubspec = fs.readFileSync(path.join(FLUTTER_APP_DIR, 'pubspec.yaml'), 'utf8');
    assert.doesNotMatch(pubspec, /chromedriver|selenium|puppeteer|flutter_driver|playwright|http:|dio:/i);
    const depsBlockMatch = pubspec.match(/(?:^|\r?\n)dependencies:\r?\n([\s\S]*?)dev_dependencies:/);
    assert.ok(depsBlockMatch, 'dependencies block must exist in pubspec.yaml');
    const depKeys = depsBlockMatch[1]
      .split(/\r?\n/)
      .map((l) => l.replace(/#.*$/, ''))
      .filter((l) => /^\s{2}[a-zA-Z0-9_]+:/.test(l))
      .map((l) => l.trim().split(':')[0]);
    assert.deepEqual(depKeys.sort(), ['cupertino_icons', 'flutter']);
  });

  it('T1-FLT-05: conditional IO/Web bridges (http_bridge & file_reader) exist and compile cleanly', () => {
    const expectedFiles = [
      'lib/services/http_bridge.dart',
      'lib/services/http_bridge_io.dart',
      'lib/services/http_bridge_web.dart',
      'lib/utils/file_reader.dart',
      'lib/utils/file_reader_io.dart',
      'lib/utils/file_reader_web.dart',
      'lib/screens/admin_login_screen.dart',
    ];
    for (const rel of expectedFiles) {
      assert.ok(fs.existsSync(path.join(FLUTTER_APP_DIR, rel)), `Missing Flutter file: ${rel}`);
    }
  });
});
