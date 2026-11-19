'use strict';

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');

const {
  PRISMA_SQLITE_PATH,
  PRISMA_PG_PATH,
  DEFAULT_JWT_SECRET,
  DEFAULT_ADMIN_PASS,
  startTestServer,
  loginAdmin,
  buildXlsxBuffer,
  corruptXlsxMagic,
  truncateBuffer,
  buildZipMissingSheet,
  makeExpiredJwt,
  makeWrongSecretJwt,
  makeAlgNoneJwt,
  tamperJwtPayload,
  verifyEd25519Lease,
  tamperLeasePayload,
  tamperLeaseSignature,
  generateWrongEd25519PublicKeyPem,
  withReadOnlyDb,
  withCopiedWritableDb,
  getForeignKeys,
  buildSchemaAwareRow,
  parsePrismaSchema,
} = require('./helpers');

// ---------------------------------------------------------------------------
// Area 2.1: Auth Boundaries (7 tests)
// ---------------------------------------------------------------------------
describe('Tier 2 · Area 2.1: Super-Admin Auth Boundaries', () => {
  let ctx;

  before(async () => {
    ctx = await startTestServer({ jwtSecret: DEFAULT_JWT_SECRET });
  });

  after(async () => {
    await ctx?.stop();
  });

  it('T2-AUTH-01: missing Authorization header returns 401 on every /api/admin/* route', async () => {
    const protectedEndpoints = [
      ['GET', '/api/admin/me'],
      ['GET', '/api/admin/dashboard'],
      ['POST', '/api/admin/tenants', { name: 'X' }],
      ['PATCH', '/api/admin/tenants/1', { tills: 2 }],
      ['POST', '/api/admin/tenants/1/extend', { days: 10 }],
      ['POST', '/api/admin/tenants/1/toggle-lock', {}],
      ['POST', '/api/admin/tenants/1/offline-code', { days: 30 }],
      ['POST', '/api/admin/tenants/1/support', {}],
      ['POST', '/api/admin/payments/P-901/approve', {}],
      ['POST', '/api/admin/tenants/1/catalog/import', { csvText: 'name_fr,price_retail\nA,10\n' }],
      ['GET', '/api/admin/tenants/1/catalog'],
    ];

    for (const [method, urlPath, body] of protectedEndpoints) {
      const res = await ctx.request(method, urlPath, body ? { body } : {});
      assert.equal(res.status, 401, `${method} ${urlPath} expected 401, got ${res.status}: ${res.text}`);
      assert.ok(res.json && typeof res.json.error === 'string');
    }
  });

  it('T2-AUTH-02: malformed Authorization Bearer tokens all return 401', async () => {
    const malformedHeaders = [
      '',
      'Bearer',
      'Bearer ',
      'Basic dGFoYTpwYXNz',
      'Bearer abc',
      'Bearer a.b',
      'Bearer a.b.c.d',
    ];

    for (const auth of malformedHeaders) {
      const res = await ctx.request('GET', '/api/admin/dashboard', {
        headers: { Authorization: auth },
      });
      assert.equal(res.status, 401, `Header "${auth}" expected 401, got ${res.status}`);
    }
  });

  it('T2-AUTH-03: expired HS256 JWT returns 401 on /api/admin/me and /api/admin/dashboard', async () => {
    const expiredToken = makeExpiredJwt(DEFAULT_JWT_SECRET);
    const r1 = await ctx.request('GET', '/api/admin/me', { token: expiredToken });
    assert.equal(r1.status, 401, r1.text);
    const r2 = await ctx.request('GET', '/api/admin/dashboard', { token: expiredToken });
    assert.equal(r2.status, 401, r2.text);
  });

  it('T2-AUTH-04: wrong-secret JWT, alg=none JWT, and tampered payload JWT all return 401', async () => {
    const { token: validToken } = await loginAdmin(ctx);
    const tampered = tamperJwtPayload(validToken, (p) => ({ ...p, username: 'other' }));
    const wrongSecret = makeWrongSecretJwt();
    const algNone = makeAlgNoneJwt();

    for (const badToken of [wrongSecret, algNone, tampered]) {
      const res = await ctx.request('GET', '/api/admin/dashboard', { token: badToken });
      assert.equal(res.status, 401, `Expected 401 for bad token, got ${res.status}: ${res.text}`);
    }
  });

  it('T2-AUTH-05: tenant OWNER JWT from /api/auth/login cannot access /api/admin/* (401)', async () => {
    const ownerRes = await ctx.request('POST', '/api/auth/login', {
      body: { username: 'darelkram41', password: 'FullTek@2026' },
    });
    assert.equal(ownerRes.status, 200, ownerRes.text);
    const ownerToken = ownerRes.json.token;

    const adminRoutes = [
      ['GET', '/api/admin/me'],
      ['GET', '/api/admin/dashboard'],
      ['POST', '/api/admin/tenants/1/offline-code', { days: 30 }],
      ['POST', '/api/admin/tenants/1/catalog/import', { csvText: 'name_fr,price_retail\nA,10\n' }],
    ];
    for (const [method, urlPath, body] of adminRoutes) {
      const res = await ctx.request(method, urlPath, { token: ownerToken, ...(body ? { body } : {}) });
      assert.equal(res.status, 401, `OWNER token on ${method} ${urlPath} returned ${res.status}`);
    }
  });

  it('T2-AUTH-06: missing login credentials and malformed JSON return 400 cleanly', async () => {
    const badPayloads = [
      {},
      { username: 'taha' },
      { password: DEFAULT_ADMIN_PASS },
      { username: '', password: '' },
    ];
    for (const body of badPayloads) {
      const res = await ctx.request('POST', '/api/admin/login', { body });
      assert.equal(res.status, 400, `Expected 400 for ${JSON.stringify(body)}, got ${res.status}`);
    }

    const badJson = await ctx.request('POST', '/api/admin/login', {
      headers: { 'Content-Type': 'application/json' },
      rawBody: '{bad',
    });
    assert.equal(badJson.status, 400, `Expected 400 for invalid JSON, got ${badJson.status}`);
  });

  it('T2-AUTH-07: wrong password or unknown username returns 401', async () => {
    const r1 = await ctx.request('POST', '/api/admin/login', {
      body: { username: 'taha', password: 'WrongPassword!' },
    });
    assert.equal(r1.status, 401);

    const r2 = await ctx.request('POST', '/api/admin/login', {
      body: { username: 'unknown_user', password: DEFAULT_ADMIN_PASS },
    });
    assert.equal(r2.status, 401);
  });
});

// ---------------------------------------------------------------------------
// Area 2.2: Ed25519 Offline License Boundaries (6 tests)
// ---------------------------------------------------------------------------
describe('Tier 2 · Area 2.2: Ed25519 License Boundaries', () => {
  let ctx;
  let adminToken;
  let validLease;

  before(async () => {
    ctx = await startTestServer();
    adminToken = (await loginAdmin(ctx)).token;
    const res = await ctx.request('POST', '/api/admin/tenants/1/offline-code', {
      token: adminToken,
      body: { days: 30, graceDays: 7, registerCode: 'C1' },
    });
    assert.equal(res.status, 200);
    validLease = res.json;
  });

  after(async () => {
    await ctx?.stop();
  });

  it('T2-LIC-01: tampered leaseToken payload fails both API verify and crypto.verify', async () => {
    const tampered = tamperLeasePayload(validLease.leaseToken, (p) => ({ ...p, days: 3650 }));
    assert.equal(verifyEd25519Lease(tampered, validLease.publicKey).valid, false);

    const res = await ctx.request('POST', '/api/licenses/verify', {
      body: { leaseToken: tampered },
    });
    assert.equal(res.status, 200);
    assert.equal(res.json.valid, false);
  });

  it('T2-LIC-02: tampered signature bytes fail both API verify and crypto.verify', async () => {
    const tamperedSig = tamperLeaseSignature(validLease.leaseToken);
    assert.equal(verifyEd25519Lease(tamperedSig, validLease.publicKey).valid, false);

    const res = await ctx.request('POST', '/api/licenses/verify', {
      body: { leaseToken: tamperedSig },
    });
    assert.equal(res.status, 200);
    assert.equal(res.json.valid, false);
  });

  it('T2-LIC-03: verification with foreign Ed25519 public key fails', async () => {
    const foreignPubPem = generateWrongEd25519PublicKeyPem();
    assert.equal(verifyEd25519Lease(validLease.leaseToken, foreignPubPem).valid, false);

    const res = await ctx.request('POST', '/api/licenses/verify', {
      body: { leaseToken: validLease.leaseToken, publicKey: foreignPubPem },
    });
    assert.equal(res.status, 200);
    assert.equal(res.json.valid, false);
  });

  it('T2-LIC-04: malformed leaseToken strings never return 500 or valid=true', async () => {
    const notJsonToken = `${Buffer.from('not-json', 'utf8').toString('base64url')}.${validLease.signature}`;
    const malformed = ['', 'abc', 'a.b.c', '!!!.???', notJsonToken];

    for (const token of malformed) {
      const res = await ctx.request('POST', '/api/licenses/verify', {
        body: { leaseToken: token },
      });
      assert.ok(res.status === 200 || res.status === 400, `Unexpected status ${res.status} for "${token}"`);
      if (res.status === 200) {
        assert.equal(res.json.valid, false);
      }
    }
  });

  it('T2-LIC-05: unknown tenant ID on offline-code returns 404 with zero DB writes', async () => {
    const beforeCounts = withReadOnlyDb(ctx.dbPath, (db) => ({
      leases: db.prepare('SELECT COUNT(*) AS cnt FROM offline_lease_tokens').get().cnt,
      codes: db.prepare('SELECT COUNT(*) AS cnt FROM offline_codes').get().cnt,
    }));

    const res = await ctx.request('POST', '/api/admin/tenants/999999/offline-code', {
      token: adminToken,
      body: { days: 30 },
    });
    assert.equal(res.status, 404);

    const afterCounts = withReadOnlyDb(ctx.dbPath, (db) => ({
      leases: db.prepare('SELECT COUNT(*) AS cnt FROM offline_lease_tokens').get().cnt,
      codes: db.prepare('SELECT COUNT(*) AS cnt FROM offline_codes').get().cnt,
    }));
    assert.deepEqual(afterCounts, beforeCounts);
  });

  it('T2-LIC-06: invalid days / graceDays boundaries return 400 with zero DB writes', async () => {
    const beforeCount = withReadOnlyDb(ctx.dbPath, (db) =>
      db.prepare('SELECT COUNT(*) AS cnt FROM offline_lease_tokens').get().cnt,
    );

    for (const body of [{ days: 0 }, { days: -10 }, { days: 'abc' }, { days: 30, graceDays: -1 }]) {
      const res = await ctx.request('POST', '/api/admin/tenants/1/offline-code', {
        token: adminToken,
        body,
      });
      assert.equal(res.status, 400, `Expected 400 for ${JSON.stringify(body)}, got ${res.status}`);
    }

    const afterCount = withReadOnlyDb(ctx.dbPath, (db) =>
      db.prepare('SELECT COUNT(*) AS cnt FROM offline_lease_tokens').get().cnt,
    );
    assert.equal(afterCount, beforeCount);
  });
});

// ---------------------------------------------------------------------------
// Area 2.3: Catalog Import Boundaries & Atomic Rollback (6 tests)
// ---------------------------------------------------------------------------
describe('Tier 2 · Area 2.3: Catalog Import Boundaries & Atomic Rollback', () => {
  let ctx;
  let adminToken;

  before(async () => {
    ctx = await startTestServer();
    adminToken = (await loginAdmin(ctx)).token;
  });

  after(async () => {
    await ctx?.stop();
  });

  function snapshotTenantCatalogCounts(tenantId) {
    return withReadOnlyDb(ctx.dbPath, (db) => ({
      products: db.prepare('SELECT COUNT(*) AS cnt FROM products WHERE tenant_id = ?').get(tenantId).cnt,
      categories: db.prepare('SELECT COUNT(*) AS cnt FROM categories WHERE tenant_id = ?').get(tenantId).cnt,
    }));
  }

  it('T2-CAT-01: empty CSV and header-only CSV return 400 without DB writes', async () => {
    const snap = snapshotTenantCatalogCounts(1);
    for (const csvText of ['', '   \r\n  ', 'name_fr,price_retail\n']) {
      const res = await ctx.request('POST', '/api/admin/tenants/1/catalog/import', {
        token: adminToken,
        body: { filename: 'empty.csv', format: 'csv', csvText },
      });
      assert.equal(res.status, 400, `Expected 400 for ${JSON.stringify(csvText)}, got ${res.status}`);
    }
    assert.deepEqual(snapshotTenantCatalogCounts(1), snap);
  });

  it('T2-CAT-02: missing required headers returns 400 with zero DB writes', async () => {
    const snap = snapshotTenantCatalogCounts(1);
    const res = await ctx.request('POST', '/api/admin/tenants/1/catalog/import', {
      token: adminToken,
      body: {
        filename: 'missing_headers.csv',
        format: 'csv',
        csvText: 'sku,category,name_ar\nA1,Boissons,شاي\n',
      },
    });
    assert.equal(res.status, 400);
    assert.ok(res.json && res.json.error);
    assert.deepEqual(snapshotTenantCatalogCounts(1), snap);
  });

  it('T2-CAT-03: negative or non-numeric price triggers atomic rollback (row 1 not persisted)', async () => {
    const snap = snapshotTenantCatalogCounts(1);

    const badPayloads = [
      'sku,name_fr,category,price_retail\nRB-1,ValidBeforeFail,CatRollback1,100\nRB-2,BadNeg,CatRollback1,-50\n',
      'sku,name_fr,category,price_retail\nRB-3,ValidBeforeNaN,CatRollback2,100\nRB-4,BadStr,CatRollback2,not-a-number\n',
    ];

    for (const csvText of badPayloads) {
      const res = await ctx.request('POST', '/api/admin/tenants/1/catalog/import', {
        token: adminToken,
        body: { filename: 'rollback.csv', format: 'csv', csvText },
      });
      assert.equal(res.status, 400, res.text);
      assert.ok(Array.isArray(res.json.errors) && res.json.errors.length >= 1);
      assert.deepEqual(snapshotTenantCatalogCounts(1), snap, 'Valid row 1 / category must be rolled back');
    }
  });

  it('T2-CAT-04: corrupt .xlsx payloads return 400 cleanly (never 500) with zero partial writes', async () => {
    const snap = snapshotTenantCatalogCounts(1);
    const validXlsx = buildXlsxBuffer([
      ['sku', 'name_fr', 'price_retail'],
      ['X-1', 'Test', 100],
    ]);

    const corruptBuffers = [
      Buffer.from('NOT_A_ZIP_XLSX', 'utf8'),
      corruptXlsxMagic(validXlsx),
      truncateBuffer(validXlsx, 0.35),
      buildZipMissingSheet('Catalogue'),
    ];

    for (const buf of corruptBuffers) {
      const res = await ctx.request('POST', '/api/admin/tenants/1/catalog/import', {
        token: adminToken,
        headers: {
          'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        },
        rawBody: buf,
      });
      assert.equal(res.status, 400, `Expected 400 for corrupt xlsx, got ${res.status}: ${res.text}`);
    }
    assert.deepEqual(snapshotTenantCatalogCounts(1), snap);
  });

  it('T2-CAT-05: unknown tenant ID returns 404 on catalog import and catalog read', async () => {
    const rImport = await ctx.request('POST', '/api/admin/tenants/999999/catalog/import', {
      token: adminToken,
      body: { filename: 'cat.csv', format: 'csv', csvText: 'name_fr,price_retail\nItem,100\n' },
    });
    assert.equal(rImport.status, 404);

    const rRead = await ctx.request('GET', '/api/admin/tenants/999999/catalog', { token: adminToken });
    assert.equal(rRead.status, 404);
  });

  it('T2-CAT-06: blank name_fr in middle row triggers atomic rollback of rows 1 and 3', async () => {
    const snap = snapshotTenantCatalogCounts(2);
    const csvText = [
      'sku,name_fr,category,price_retail',
      'MID-1,RowOneValid,CatMid,150',
      'MID-2,,CatMid,200',
      'MID-3,RowThreeValid,CatMid,300',
    ].join('\n');

    const res = await ctx.request('POST', '/api/admin/tenants/2/catalog/import', {
      token: adminToken,
      body: { filename: 'blank_mid.csv', format: 'csv', csvText },
    });
    assert.equal(res.status, 400, res.text);
    assert.ok(Array.isArray(res.json.errors) && res.json.errors.length >= 1);
    assert.deepEqual(snapshotTenantCatalogCounts(2), snap);
  });
});

// ---------------------------------------------------------------------------
// Area 2.4: CSV / XLSX Parsing Corner Cases (6 tests)
// ---------------------------------------------------------------------------
describe('Tier 2 · Area 2.4: CSV / XLSX Corner Cases', () => {
  let ctx;
  let adminToken;

  before(async () => {
    ctx = await startTestServer();
    adminToken = (await loginAdmin(ctx)).token;
  });

  after(async () => {
    await ctx?.stop();
  });

  it('T2-PARSE-01: duplicate SKU within same CSV leaves single row and repeat import is idempotent', async () => {
    const csv = [
      'sku,name_fr,price_retail',
      'DUP-01,Produit Initial,100',
      'DUP-01,Produit Final,200',
    ].join('\n');

    const r1 = await ctx.request('POST', '/api/admin/tenants/6/catalog/import', {
      token: adminToken,
      body: { filename: 'dup.csv', format: 'csv', csvText: csv },
    });
    assert.equal(r1.status, 200, r1.text);

    const rowsAfter1 = withReadOnlyDb(ctx.dbPath, (db) =>
      db.prepare("SELECT * FROM products WHERE tenant_id = 6 AND sku = 'DUP-01'").all(),
    );
    assert.equal(rowsAfter1.length, 1);
    assert.equal(rowsAfter1[0].price_retail, 200);

    const r2 = await ctx.request('POST', '/api/admin/tenants/6/catalog/import', {
      token: adminToken,
      body: { filename: 'dup.csv', format: 'csv', csvText: csv },
    });
    assert.equal(r2.status, 200, r2.text);
    assert.equal(r2.json.created, 0);

    const rowsAfter2 = withReadOnlyDb(ctx.dbPath, (db) =>
      db.prepare("SELECT * FROM products WHERE tenant_id = 6 AND sku = 'DUP-01'").all(),
    );
    assert.equal(rowsAfter2.length, 1);
  });

  it('T2-PARSE-02: UTF-8 BOM + CRLF + quoted commas & escaped quotes parse accurately', async () => {
    const csv =
      '\uFEFFname_fr,price_retail,category\r\n' +
      '"Couscous, Royal ""Spécial""",450,"Plats, Chauds"\r\n';

    const res = await ctx.request('POST', '/api/admin/tenants/7/catalog/import', {
      token: adminToken,
      body: { filename: 'bom_quoted.csv', format: 'csv', csvText: csv },
    });
    assert.equal(res.status, 200, res.text);
    assert.equal(res.json.created, 1);

    withReadOnlyDb(ctx.dbPath, (db) => {
      const prod = db.prepare('SELECT p.*, c.name_fr AS cat_name FROM products p LEFT JOIN categories c ON c.id = p.category_id WHERE p.tenant_id = 7').get();
      assert.equal(prod.name_fr, 'Couscous, Royal "Spécial"');
      assert.equal(prod.price_retail, 450);
      assert.equal(prod.cat_name, 'Plats, Chauds');
    });
  });

  it('T2-PARSE-03: whitespace around headers and values is trimmed cleanly', async () => {
    const csv = '  sku  ,  name_fr  ,  price_retail  \n  S-TRIM  ,  Thé Vert  ,  120  \n';
    const res = await ctx.request('POST', '/api/admin/tenants/4/catalog/import', {
      token: adminToken,
      body: { filename: 'trim.csv', format: 'csv', csvText: csv },
    });
    assert.equal(res.status, 200, res.text);

    withReadOnlyDb(ctx.dbPath, (db) => {
      const prod = db.prepare("SELECT sku, name_fr, price_retail FROM products WHERE tenant_id = 4 AND sku = 'S-TRIM'").get();
      assert.ok(prod);
      assert.equal(prod.sku, 'S-TRIM');
      assert.equal(prod.name_fr, 'Thé Vert');
      assert.equal(prod.price_retail, 120);
    });
  });

  it('T2-PARSE-04: FR and EN header aliases map fields accurately into products & categories', async () => {
    const frCsv = [
      'nom,prix_vente,code_barre,categorie,nom_ar,prix_gros,fefo,cnam',
      'Sirop Menthe,250,6139990001112,Sirops,شراب النعناع,210,1,1',
    ].join('\n');

    const enCsv = [
      'name,price,barcode,category',
      'Mineral Water,60,6139990002228,Beverages',
    ].join('\n');

    const rFr = await ctx.request('POST', '/api/admin/tenants/5/catalog/import', {
      token: adminToken,
      body: { filename: 'fr_alias.csv', format: 'csv', csvText: frCsv },
    });
    assert.equal(rFr.status, 200, rFr.text);

    const rEn = await ctx.request('POST', '/api/admin/tenants/5/catalog/import', {
      token: adminToken,
      body: { filename: 'en_alias.csv', format: 'csv', csvText: enCsv },
    });
    assert.equal(rEn.status, 200, rEn.text);

    withReadOnlyDb(ctx.dbPath, (db) => {
      const p1 = db.prepare("SELECT * FROM products WHERE tenant_id = 5 AND barcode = '6139990001112'").get();
      assert.equal(p1.name_fr, 'Sirop Menthe');
      assert.equal(p1.price_retail, 250);
      assert.equal(p1.price_whole, 210);
      assert.equal(p1.name_ar, 'شراب النعناع');
      assert.equal(p1.track_fefo, 1);
      assert.equal(p1.requires_cnam, 1);

      const p2 = db.prepare("SELECT * FROM products WHERE tenant_id = 5 AND barcode = '6139990002228'").get();
      assert.equal(p2.name_fr, 'Mineral Water');
      assert.equal(p2.price_retail, 60);
    });
  });

  it('T2-PARSE-05: native .xlsx inlineStr cells and sparse columns (omitted B2) do not shift columns', async () => {
    const xlsxBuf = buildXlsxBuffer(
      [
        ['name_fr', 'category', 'price_retail'],
        ['Produit Sparse', null, 420],
      ],
      { inlineStrings: true },
    );

    const res = await ctx.request('POST', '/api/admin/tenants/4/catalog/import', {
      token: adminToken,
      body: {
        filename: 'inline_sparse.xlsx',
        format: 'xlsx',
        contentBase64: xlsxBuf.toString('base64'),
      },
    });
    assert.equal(res.status, 200, res.text);
    assert.equal(res.json.created, 1);

    withReadOnlyDb(ctx.dbPath, (db) => {
      const prod = db.prepare("SELECT * FROM products WHERE tenant_id = 4 AND name_fr = 'Produit Sparse'").get();
      assert.ok(prod);
      assert.equal(prod.price_retail, 420);
      assert.equal(prod.category_id, null);
    });
  });

  it('T2-PARSE-06: identical SKU imported to two tenants remains strictly isolated per tenant', async () => {
    await ctx.request('POST', '/api/admin/tenants/1/catalog/import', {
      token: adminToken,
      body: { filename: 't1.csv', format: 'csv', csvText: 'sku,name_fr,price_retail\nSHARED-001,Tenant1 Item,100\n' },
    });
    await ctx.request('POST', '/api/admin/tenants/2/catalog/import', {
      token: adminToken,
      body: { filename: 't2.csv', format: 'csv', csvText: 'sku,name_fr,price_retail\nSHARED-001,Tenant2 Item,999\n' },
    });

    const c1 = await ctx.request('GET', '/api/admin/tenants/1/catalog', { token: adminToken });
    const c2 = await ctx.request('GET', '/api/admin/tenants/2/catalog', { token: adminToken });
    const p1 = c1.json.products.find((p) => p.sku === 'SHARED-001');
    const p2 = c2.json.products.find((p) => p.sku === 'SHARED-001');
    assert.equal(p1.price_retail ?? p1.priceRetail, 100);
    assert.equal(p2.price_retail ?? p2.priceRetail, 999);
  });
});

// ---------------------------------------------------------------------------
// Area 2.5: MCD / RBAC / Prisma Parity Checks (6 tests)
// ---------------------------------------------------------------------------
describe('Tier 2 · Area 2.5: MCD Constraints, RBAC & Prisma Parity', () => {
  let ctx;

  before(async () => {
    ctx = await startTestServer();
  });

  after(async () => {
    await ctx?.stop();
  });

  it('T2-PRISMA-01: SQLite UNIQUE constraints reject duplicates across core & admin tables', () => {
    withCopiedWritableDb(ctx.dbPath, (db) => {
      assert.throws(() => {
        db.prepare(`
          INSERT INTO tenants (tenant_code, name, module, city, phone, username, password_hash)
          VALUES ('FT-1041', 'Dup', 'resto', 'NKC', '+222', 'unique_u_1', 'x:y')
        `).run();
      }, /UNIQUE|constraint/i);

      assert.throws(() => {
        db.prepare(`
          INSERT INTO tenants (tenant_code, name, module, city, phone, username, password_hash)
          VALUES ('FT-UNIQ-9', 'Dup', 'resto', 'NKC', '+222', 'darelkram41', 'x:y')
        `).run();
      }, /UNIQUE|constraint/i);

      assert.throws(() => {
        db.prepare(`
          INSERT INTO users (tenant_id, full_name, username, pass_hash, pin_code, role)
          VALUES (1, 'Dup User', 'darelkram41', 'x:y', '1111', 'CASHIER')
        `).run();
      }, /UNIQUE|constraint/i);

      assert.throws(() => {
        db.prepare(`
          INSERT INTO saas_payments (pay_code, tenant_id, method, amount)
          VALUES ('P-901', 1, 'Bankily', 3000)
        `).run();
      }, /UNIQUE|constraint/i);

      assert.throws(() => {
        buildSchemaAwareRow(db, 'super_admins', {
          username: 'taha',
          email: 'other@fulltek.mr',
          password_hash: 'aa:bb',
          role: 'SUPER_ADMIN',
        }).run();
      }, /UNIQUE|constraint/i);
    });
  });

  it('T2-PRISMA-02: SQLite FOREIGN KEY constraints reject invalid tenant_id=999999 across M1 MCD tables', () => {
    withCopiedWritableDb(ctx.dbPath, (db) => {
      // Create valid tenant-1 parent rows for tables that have additional non-tenant FKs
      const branchId = Number(buildSchemaAwareRow(db, 'branches', { tenant_id: 1, name: 'B1' }).run().lastInsertRowid);
      const zoneId = Number(buildSchemaAwareRow(db, 'dining_zones', { tenant_id: 1, branch_id: branchId, name: 'Z1' }).run().lastInsertRowid);
      const ingId = Number(buildSchemaAwareRow(db, 'ingredients', { tenant_id: 1, name: 'Ing1' }).run().lastInsertRowid);
      const prodId = Number(
        db.prepare("INSERT INTO products (tenant_id, sku, name_fr, price_retail) VALUES (1, 'FK-P1', 'Prod FK', 100)").run().lastInsertRowid,
      );
      const orderId = Number(
        db.prepare("INSERT INTO orders (tenant_id, order_code, pay_method, total_mru) VALUES (1, 'FK-O1', 'Cash', 100)").run().lastInsertRowid,
      );
      let signingKeyRow = db.prepare('SELECT key_id FROM signing_keys WHERE is_active = 1 LIMIT 1').get();
      if (!signingKeyRow) {
        const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
        const keyId = 'ed25519-fk-probe-1';
        db.prepare(`
          INSERT INTO signing_keys (key_id, algorithm, public_key_pem, private_key_pem, is_active)
          VALUES (?, 'Ed25519', ?, ?, 1)
        `).run(
          keyId,
          publicKey.export({ type: 'spki', format: 'pem' }),
          privateKey.export({ type: 'pkcs8', format: 'pem' }),
        );
        signingKeyRow = { key_id: keyId };
      }

      const m1Tables = [
        'branches',
        'pos_registers',
        'customer_credits_karni',
        'recipes_bom',
        'returns_remakes_comps',
        'reservations_vip',
        'offline_lease_tokens',
      ];

      for (const table of m1Tables) {
        const fks = getForeignKeys(db, table);
        assert.ok(fks.some((f) => f.table === 'tenants'), `${table} should declare FK to tenants`);

        assert.throws(() => {
          buildSchemaAwareRow(db, table, {
            tenant_id: 999999,
            branch_id: branchId,
            zone_id: zoneId,
            ingredient_id: ingId,
            product_id: prodId,
            order_id: orderId,
            key_id: signingKeyRow.key_id,
          }).run();
        }, /FOREIGN KEY|constraint/i, `Expected FK constraint failure inserting tenant_id=999999 into ${table}`);
      }
    });
  });

  it('T2-PRISMA-03: ON DELETE RESTRICT on order_items->products and cascading tenant cleanup work cleanly', () => {
    withCopiedWritableDb(ctx.dbPath, (db) => {
      const tid = Number(
        db.prepare(`
          INSERT INTO tenants (tenant_code, name, module, city, phone, username, password_hash)
          VALUES ('FT-DEL-1', 'Throwaway', 'resto', 'NKC', '+222', 'throwaway_del', 'a:b')
        `).run().lastInsertRowid,
      );

      const branchId = Number(buildSchemaAwareRow(db, 'branches', { tenant_id: tid, name: 'Main' }).run().lastInsertRowid);
      buildSchemaAwareRow(db, 'pos_registers', { tenant_id: tid, branch_id: branchId, code: 'C1' }).run();
      const catId = Number(db.prepare("INSERT INTO categories (tenant_id, name_fr) VALUES (?, 'Cat')").run(tid).lastInsertRowid);
      const prodId = Number(
        db.prepare("INSERT INTO products (tenant_id, category_id, sku, name_fr, price_retail) VALUES (?, ?, 'DEL-P', 'Plat', 500)").run(tid, catId).lastInsertRowid,
      );
      const orderId = Number(
        db.prepare("INSERT INTO orders (tenant_id, order_code, pay_method, total_mru) VALUES (?, 'ORD-DEL', 'Cash', 500)").run(tid).lastInsertRowid,
      );
      db.prepare('INSERT INTO order_items (order_id, product_id, qty, unit_price) VALUES (?, ?, 1, 500)').run(orderId, prodId);

      // Deleting referenced product must fail due to ON DELETE RESTRICT
      assert.throws(() => {
        db.prepare('DELETE FROM products WHERE id = ?').run(prodId);
      }, /FOREIGN KEY|constraint/i);

      // Delete order first (cascades order_items), then delete tenant (cascades remaining children)
      db.prepare('DELETE FROM orders WHERE id = ?').run(orderId);
      assert.equal(db.prepare('SELECT COUNT(*) AS cnt FROM order_items WHERE order_id = ?').get(orderId).cnt, 0);

      // Dynamically check M1 tables with FK -> tenants and verify declared ON DELETE rule
      const regFkToTenant = getForeignKeys(db, 'pos_registers').find((f) => f.table === 'tenants');
      const brFkToTenant = getForeignKeys(db, 'branches').find((f) => f.table === 'tenants');
      if (regFkToTenant?.on_delete === 'CASCADE' && brFkToTenant?.on_delete === 'CASCADE') {
        db.prepare('DELETE FROM tenants WHERE id = ?').run(tid);
        assert.equal(db.prepare('SELECT COUNT(*) AS cnt FROM branches WHERE tenant_id = ?').get(tid).cnt, 0);
        assert.equal(db.prepare('SELECT COUNT(*) AS cnt FROM pos_registers WHERE tenant_id = ?').get(tid).cnt, 0);
        assert.equal(db.prepare('SELECT COUNT(*) AS cnt FROM products WHERE tenant_id = ?').get(tid).cnt, 0);
      }
    });
  });

  it('T2-PRISMA-04: 1:1 model and field parity between schema.prisma and schema.postgresql.prisma', () => {
    const sqliteSchema = parsePrismaSchema(PRISMA_SQLITE_PATH);
    const pgSchema = parsePrismaSchema(PRISMA_PG_PATH);

    const sqliteModels = [...sqliteSchema.models.keys()].sort();
    const pgModels = [...pgSchema.models.keys()].sort();
    assert.deepEqual(pgModels, sqliteModels);

    for (const modelName of sqliteModels) {
      const sFields = [...sqliteSchema.models.get(modelName).fields].sort();
      const pFields = [...pgSchema.models.get(modelName).fields].sort();
      assert.deepEqual(pFields, sFields, `Field mismatch in Prisma model ${modelName}`);
    }
  });

  it('T2-PRISMA-05: both Prisma schemas have valid providers and balanced braces', () => {
    const sqliteSchema = parsePrismaSchema(PRISMA_SQLITE_PATH);
    const pgSchema = parsePrismaSchema(PRISMA_PG_PATH);
    assert.equal(sqliteSchema.provider, 'sqlite');
    assert.equal(sqliteSchema.balancedBraces, true);
    assert.equal(pgSchema.provider, 'postgresql');
    assert.equal(pgSchema.balancedBraces, true);
    assert.ok(sqliteSchema.models.size >= 25);
  });

  it('T2-PRISMA-06: RBAC role_permissions prevents duplicates and roles/permissions have non-empty keys', () => {
    withCopiedWritableDb(ctx.dbPath, (db) => {
      const roles = db.prepare('SELECT * FROM roles').all();
      const perms = db.prepare('SELECT * FROM permissions').all();
      assert.ok(roles.length >= 9);
      assert.ok(perms.length >= 9);

      for (const r of roles) {
        const vals = Object.values(r).filter((v) => typeof v === 'string' && v.trim().length > 0);
        assert.ok(vals.length >= 1, `Role row ${r.id} missing identifier string`);
      }
      for (const p of perms) {
        const vals = Object.values(p).filter((v) => typeof v === 'string' && v.trim().length > 0);
        assert.ok(vals.length >= 1, `Permission row ${p.id} missing identifier string`);
      }

      const existingPair = db.prepare('SELECT * FROM role_permissions LIMIT 1').get();
      assert.ok(existingPair);
      assert.throws(() => {
        db.prepare('INSERT INTO role_permissions (role_id, permission_id) VALUES (?, ?)').run(
          existingPair.role_id,
          existingPair.permission_id,
        );
      }, /UNIQUE|PRIMARY KEY|constraint/i);
    });
  });
});
