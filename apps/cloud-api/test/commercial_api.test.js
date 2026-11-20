const { describe, it, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const http = require('node:http');

// Isolate module-load singleton DB away from apps/cloud-api/data/fulltek.db
const singletonTmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'fulltek-comm-singleton-'));
process.env.DB_PATH = path.join(singletonTmpDir, 'singleton.db');

const { db: singletonDb } = require('../src/db');
const { signJwt } = require('../src/auth');
const { createApp, startServer } = require('../src/server');

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
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'fulltek-comm-srv-'));
  const dbPath = path.join(tmpDir, 'test.db');
  const jwtSecret = opts.jwtSecret || 'test-jwt-secret-comm';
  const srv = await startServer({
    port: 0,
    host: '127.0.0.1',
    dbPath,
    jwtSecret,
    pgBackup: opts.pgBackup || null,
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

async function loginAdmin(request) {
  const res = await request('/api/admin/login', {
    method: 'POST',
    json: { username: 'taha', password: 'FullTekAdmin@2026' },
  });
  assert.equal(res.status, 200, res.text);
  return res.json.token;
}

async function createCommercialTenant(request, adminToken, overrides = {}) {
  const suffix = Math.floor(1000 + Math.random() * 8999);
  const payload = {
    name: overrides.name || `Mauritanie Négoce ${suffix}`,
    legalName: overrides.legalName || `Mauritanie Négoce SARL ${suffix}`,
    module: 'commercial',
    nif: overrides.nif || `NIF-${suffix}`,
    rc: overrides.rc || `RC-${suffix}`,
    phone: overrides.phone || `4600${suffix}`,
    city: 'Tevragh Zeina',
    manager: overrides.manager || 'M. Ahmed',
    plan: overrides.plan || 'Pro',
    status: overrides.status || 'trial',
    daysLeft: overrides.daysLeft ?? 15,
    username: overrides.username || `comm_${suffix}`,
    accountPassword: overrides.accountPassword || 'CommPass@2026',
    ...overrides,
  };
  const created = await request('/api/admin/tenants', {
    method: 'POST',
    headers: { Authorization: `Bearer ${adminToken}` },
    json: payload,
  });
  assert.equal(created.status, 201, created.text);

  const login = await request('/api/auth/login', {
    method: 'POST',
    json: { username: payload.username, password: payload.accountPassword },
  });
  assert.equal(login.status, 200, login.text);
  return {
    tenant: created.json,
    login: login.json,
    token: login.json.token,
    authHeaders: { Authorization: `Bearer ${login.json.token}` },
  };
}

function todayStr() {
  return new Date().toISOString().slice(0, 10);
}

describe('Commercial Suite 1 — Provisioning, CORS PUT, Auth Guard, Module Isolation & pgBackup Spy', () => {
  it('supports OPTIONS CORS PUT, creates commercial tenant without branches/registers, returns user on login, and auto-provisions default treasury accounts', async () => {
    await withIsolatedServer(async ({ request, db }) => {
      const opt = await request('/api/commercial/objectives', { method: 'OPTIONS' });
      assert.equal(opt.status, 204);
      assert.ok(String(opt.headers['access-control-allow-methods'] || '').includes('PUT'));

      const adminToken = await loginAdmin(request);
      const { tenant, login, authHeaders } = await createCommercialTenant(request, adminToken, {
        payMethods: [], // empty should normalize to DEFAULT_PAY_METHODS
        nif: '30012345',
        rc: 'RC-NKC-889',
      });

      assert.equal(tenant.module, 'commercial');
      assert.equal(tenant.nif, '30012345');
      assert.equal(tenant.rc, 'RC-NKC-889');
      assert.equal(tenant.tenantCode, tenant.tenantId);
      assert.equal(tenant.payMethods.length, 7);

      // Suite 4 compatibility: MUST NOT seed branches or pos_registers
      assert.equal(db.prepare('SELECT COUNT(*) AS c FROM branches WHERE tenant_id = ?').get(tenant.id).c, 0);
      assert.equal(db.prepare('SELECT COUNT(*) AS c FROM pos_registers WHERE tenant_id = ?').get(tenant.id).c, 0);

      // Login returns { token, tenant, user }
      assert.ok(login.token);
      assert.equal(login.tenant.module, 'commercial');
      assert.equal(login.user.role, 'OWNER');
      assert.equal(login.user.username, tenant.username);

      const boot = await request('/api/commercial/bootstrap', { headers: authHeaders });
      assert.equal(boot.status, 200, boot.text);
      assert.equal(boot.json.ok, true);
      assert.equal(boot.json.treasuryAccounts.length, 2);
      assert.ok(boot.json.treasuryAccounts.some((a) => a.name === 'Caisse Principale' && a.accountType === 'CAISSE'));
      assert.ok(boot.json.treasuryAccounts.some((a) => a.name === 'Banque Principale' && a.accountType === 'BANQUE'));
    });
  });

  it('rejects unauthenticated, invalid, admin, locked, and non-commercial tokens and isolates tenants', async () => {
    await withIsolatedServer(async ({ request, jwtSecret }) => {
      const adminToken = await loginAdmin(request);
      const tA = await createCommercialTenant(request, adminToken, { username: 'comm_a1' });
      const tB = await createCommercialTenant(request, adminToken, { username: 'comm_b1' });

      // Missing / bad / expired / wrong-secret / admin / ghost tokens -> 401
      assert.equal((await request('/api/commercial/bootstrap')).status, 401);
      assert.equal(
        (await request('/api/commercial/bootstrap', { headers: { Authorization: 'Bearer invalid.jwt.token' } })).status,
        401,
      );
      assert.equal(
        (await request('/api/commercial/bootstrap', { headers: { Authorization: `Bearer ${adminToken}` } })).status,
        401,
      );
      const wrongSecret = signJwt({ tenantId: tA.tenant.id, module: 'commercial', role: 'OWNER' }, 3600, 'wrong-secret');
      assert.equal(
        (await request('/api/commercial/bootstrap', { headers: { Authorization: `Bearer ${wrongSecret}` } })).status,
        401,
      );
      const expired = signJwt({ tenantId: tA.tenant.id, module: 'commercial', role: 'OWNER' }, -10, jwtSecret);
      assert.equal(
        (await request('/api/commercial/bootstrap', { headers: { Authorization: `Bearer ${expired}` } })).status,
        401,
      );
      const ghost = signJwt({ tenantId: 999999, module: 'commercial', role: 'OWNER' }, 3600, jwtSecret);
      assert.equal(
        (await request('/api/commercial/bootstrap', { headers: { Authorization: `Bearer ${ghost}` } })).status,
        401,
      );

      // Non-commercial tenant (FT-1041 resto) -> 403
      const restoLogin = await request('/api/auth/login', {
        method: 'POST',
        json: { username: 'darelkram41', password: 'FullTek@2026' },
      });
      assert.equal(restoLogin.status, 200);
      const restoBoot = await request('/api/commercial/bootstrap', {
        headers: { Authorization: `Bearer ${restoLogin.json.token}` },
      });
      assert.equal(restoBoot.status, 403);

      // Locked tenant -> 403 on both /api/commercial/* and /api/auth/login
      await request(`/api/admin/tenants/${tB.tenant.id}/toggle-lock`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      assert.equal(
        (await request('/api/commercial/bootstrap', { headers: tB.authHeaders })).status,
        403,
      );
      const lockedLogin = await request('/api/auth/login', {
        method: 'POST',
        json: { username: 'comm_b1', password: 'CommPass@2026' },
      });
      assert.equal(lockedLogin.status, 403);

      // Cross-tenant isolation (A cannot see or mutate B's client)
      const cliB = await request('/api/commercial/clients', {
        method: 'POST',
        headers: tA.authHeaders,
        json: { name: 'Client A Only' },
      });
      assert.equal(cliB.status, 201);
      // Unlock B to test cross-tenant 404
      await request(`/api/admin/tenants/${tB.tenant.id}/toggle-lock`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      const crossPatch = await request(`/api/commercial/clients/${cliB.json.client.id}`, {
        method: 'PATCH',
        headers: tB.authHeaders,
        json: { name: 'Hacked' },
      });
      assert.equal(crossPatch.status, 404);
    });
  });

  it('triggers pgBackup.schedulePush on <400 /api/commercial/* mutations and skips on >=400 or GET', async () => {
    let pushCalls = 0;
    const spy = {
      schedulePush: () => {
        pushCalls++;
      },
      flushAndClose: async () => {},
      getStatus: () => ({ enabled: true }),
    };

    await withIsolatedServer({ pgBackup: spy }, async ({ request }) => {
      const adminToken = await loginAdmin(request);
      const { authHeaders } = await createCommercialTenant(request, adminToken);
      const callsBefore = pushCalls;

      // GET does not push
      await request('/api/commercial/bootstrap', { headers: authHeaders });
      assert.equal(pushCalls, callsBefore);

      // 400 mutation does not push
      const bad = await request('/api/commercial/clients', {
        method: 'POST',
        headers: authHeaders,
        json: { name: '' },
      });
      assert.equal(bad.status, 400);
      assert.equal(pushCalls, callsBefore);

      // 201 POST & 200 PUT push
      const okClient = await request('/api/commercial/clients', {
        method: 'POST',
        headers: authHeaders,
        json: { name: 'Client PG Spy' },
      });
      assert.equal(okClient.status, 201);
      assert.equal(pushCalls, callsBefore + 1);

      const okObj = await request('/api/commercial/objectives', {
        method: 'PUT',
        headers: authHeaders,
        json: { year: 2026, month: 5, targetCaHtMru: 500000 },
      });
      assert.equal(okObj.status, 200);
      assert.equal(pushCalls, callsBefore + 2);
    });
  });
});

describe('Commercial Suite 2 — Master Data, TVA (16% vs Exonéré) & Stock Adjustments', () => {
  it('manages clients, suppliers, articles (TVA 16%/0%, duplicate SKU 409), and stock adjustments with movements', async () => {
    await withIsolatedServer(async ({ request }) => {
      const adminToken = await loginAdmin(request);
      const { authHeaders } = await createCommercialTenant(request, adminToken);

      // Clients CRUD + soft-archive vs hard-delete
      const c1 = await request('/api/commercial/clients', {
        method: 'POST',
        headers: authHeaders,
        json: { name: 'Société Atlantique', isB2b: true, nif: 'NIF-ATL', rc: 'RC-ATL', creditLimitMru: 50000 },
      });
      assert.equal(c1.status, 201);
      assert.equal(c1.json.client.code, 'CLI-0001');

      const c2 = await request('/api/commercial/clients', {
        method: 'POST',
        headers: authHeaders,
        json: { name: 'Client Passager' },
      });
      assert.equal(c2.status, 201);
      assert.equal(c2.json.client.code, 'CLI-0002');
      const del2 = await request(`/api/commercial/clients/${c2.json.client.id}`, {
        method: 'DELETE',
        headers: authHeaders,
      });
      assert.equal(del2.status, 200);
      assert.equal(del2.json.deleted, true);

      // Suppliers CRUD
      const s1 = await request('/api/commercial/suppliers', {
        method: 'POST',
        headers: authHeaders,
        json: { name: 'Importateur Mauritanie', nif: 'NIF-IMP', paymentTermsDays: 30 },
      });
      assert.equal(s1.status, 201);
      assert.equal(s1.json.supplier.code, 'FRN-0001');

      // Articles CRUD (TVA 16% vs Exonéré)
      const a1 = await request('/api/commercial/articles', {
        method: 'POST',
        headers: authHeaders,
        json: {
          sku: 'INF-001',
          name: 'Ordinateur Portable',
          category: 'Informatique',
          priceRetailHt: 25000,
          priceWholeHt: 22000,
          priceCostMru: 18000,
          stockQty: 5,
          minStock: 2,
          tvaRate: 16,
        },
      });
      assert.equal(a1.status, 201);
      assert.equal(a1.json.article.priceRetailTtc, 29000);
      assert.equal(a1.json.article.pmpCostMru, 18000);

      const a2 = await request('/api/commercial/articles', {
        method: 'POST',
        headers: authHeaders,
        json: {
          sku: 'ALIM-001',
          name: 'Riz Basmati 25kg',
          category: 'Alimentaire',
          priceRetailHt: 1200,
          priceWholeHt: 1050,
          priceCostMru: 900,
          stockQty: 2,
          minStock: 5,
          isExempt: true,
          tvaRate: 16, // forced to 0 when isExempt=true
        },
      });
      assert.equal(a2.status, 201);
      assert.equal(a2.json.article.tvaRate, 0);
      assert.equal(a2.json.article.priceRetailTtc, 1200);
      assert.equal(a2.json.article.isLowStock, true);

      // Duplicate SKU -> 409
      const dupSku = await request('/api/commercial/articles', {
        method: 'POST',
        headers: authHeaders,
        json: { sku: 'INF-001', name: 'Autre PC', priceRetailHt: 1000 },
      });
      assert.equal(dupSku.status, 409);

      // Adjust stock (+5 at 20000 -> PMP = (5*18000 + 5*20000)/10 = 19000)
      const adj = await request(`/api/commercial/articles/${a1.json.article.id}/adjust-stock`, {
        method: 'POST',
        headers: authHeaders,
        json: { deltaQty: 5, unitCostHt: 20000, reason: 'Inventaire' },
      });
      assert.equal(adj.status, 200);
      assert.equal(adj.json.article.stockQty, 10);
      assert.equal(adj.json.article.pmpCostMru, 19000);

      const mvts = await request(`/api/commercial/stock-movements?articleId=${a1.json.article.id}`, {
        headers: authHeaders,
      });
      assert.equal(mvts.status, 200);
      assert.equal(mvts.json.movements.length, 2);
      assert.equal(mvts.json.movements[0].movementType, 'ADJUSTMENT_IN');
      assert.equal(mvts.json.movements[1].movementType, 'IN_INITIAL');
    });
  });
});

describe('Commercial Suite 3 — Sales Cycle, 1-Click Conversions, Stock Idempotency, Payments & Avoir', () => {
  it('converts Devis -> Commande -> BL -> Facture without double stock deduction, enforces Karni limits & Avoir restock', async () => {
    await withIsolatedServer(async ({ request }) => {
      const adminToken = await loginAdmin(request);
      const { authHeaders } = await createCommercialTenant(request, adminToken);

      const cli = (
        await request('/api/commercial/clients', {
          method: 'POST',
          headers: authHeaders,
          json: { name: 'Client B2B', isB2b: true, creditLimitMru: 5000 },
        })
      ).json.client;

      const artTaxed = (
        await request('/api/commercial/articles', {
          method: 'POST',
          headers: authHeaders,
          json: { sku: 'T1', name: 'Imprimante', priceRetailHt: 2000, priceCostMru: 1200, stockQty: 20, tvaRate: 16 },
        })
      ).json.article;

      const artExempt = (
        await request('/api/commercial/articles', {
          method: 'POST',
          headers: authHeaders,
          json: { sku: 'E1', name: 'Sucre 50kg', priceRetailHt: 1000, priceCostMru: 700, stockQty: 15, isExempt: true },
        })
      ).json.article;

      // Create DEVIS: 2 * 2000 (16% TVA) + 1 * 1000 (0% TVA), globalDiscountPct 10%
      // subtotalHt = 4000 + 1000 = 5000; discountHt = 500; totalHt = 4500
      // sumLineTva = 640 + 0 = 640; totalTva = 640 * 0.9 = 576; totalTtc = 5076
      const devis = await request('/api/commercial/sales-docs', {
        method: 'POST',
        headers: authHeaders,
        json: {
          docType: 'DEVIS',
          clientId: cli.id,
          issueDate: todayStr(),
          globalDiscountPct: 10,
          lines: [
            { articleId: artTaxed.id, qty: 2, unitPriceHtMru: 2000 },
            { articleId: artExempt.id, qty: 1, unitPriceHtMru: 1000 },
          ],
        },
      });
      assert.equal(devis.status, 201, devis.text);
      assert.equal(devis.json.doc.totalHtMru, 4500);
      assert.equal(devis.json.doc.totalTvaMru, 576);
      assert.equal(devis.json.doc.totalTtcMru, 5076);

      // Convert Devis -> Commande -> BL
      const cmd = await request(`/api/commercial/sales-docs/${devis.json.doc.id}/convert`, {
        method: 'POST',
        headers: authHeaders,
        json: { targetType: 'COMMANDE' },
      });
      assert.equal(cmd.status, 201);
      assert.equal(cmd.json.sourceDoc.status, 'CONVERTI');

      const bl = await request(`/api/commercial/sales-docs/${cmd.json.doc.id}/convert`, {
        method: 'POST',
        headers: authHeaders,
        json: { targetType: 'BL' },
      });
      assert.equal(bl.status, 201);
      assert.equal(bl.json.sourceDoc.status, 'LIVREE');

      // Validate BL -> deducts stock ONCE (20->18, 15->14)
      const valBl = await request(`/api/commercial/sales-docs/${bl.json.doc.id}/validate`, {
        method: 'POST',
        headers: authHeaders,
      });
      assert.equal(valBl.status, 200);
      assert.equal(valBl.json.doc.stockDeducted, true);

      // Convert BL -> Facture & validate Facture -> MUST NOT deduct stock again!
      const fac = await request(`/api/commercial/sales-docs/${bl.json.doc.id}/convert`, {
        method: 'POST',
        headers: authHeaders,
        json: { targetType: 'FACTURE' },
      });
      assert.equal(fac.status, 201);
      assert.equal(fac.json.doc.stockDeducted, true);

      const valFac = await request(`/api/commercial/sales-docs/${fac.json.doc.id}/validate`, {
        method: 'POST',
        headers: authHeaders,
      });
      assert.equal(valFac.status, 200);
      assert.equal(valFac.json.doc.status, 'VALIDEE');

      const artsAfter = (await request('/api/commercial/articles', { headers: authHeaders })).json.articles;
      assert.equal(artsAfter.find((a) => a.id === artTaxed.id).stockQty, 18);
      assert.equal(artsAfter.find((a) => a.id === artExempt.id).stockQty, 14);

      // Payments: 1000 Cash + Karni over limit (5076 - 1000 = 4076 <= 5000 works? Let's test over 5000 limit first!)
      // Wait: client creditLimitMru = 5000. Try 5001 via Karni -> exceeds remaining payable OR limit -> 400
      const pCash = await request(`/api/commercial/sales-docs/${fac.json.doc.id}/payments`, {
        method: 'POST',
        headers: authHeaders,
        json: { payMethod: 'Cash', amountMru: 76 },
      });
      assert.equal(pCash.status, 201);
      assert.equal(pCash.json.doc.status, 'PARTIELLE');

      // Try Karni 5000 -> fine (exact boundary), wait let's first test Karni > 5000 (e.g. another doc or 5001) -> 400
      const pKarniOk = await request(`/api/commercial/sales-docs/${fac.json.doc.id}/payments`, {
        method: 'POST',
        headers: authHeaders,
        json: { payMethod: 'Karni', amountMru: 4000 },
      });
      assert.equal(pKarniOk.status, 201);
      assert.equal(pKarniOk.json.doc.remainingMru, 1000);

      // Now client currentDebtMru = 4000, creditLimit = 5000 -> remaining limit 1000.
      // Create another direct Facture of 2000 TTC -> deducts stock once (14->12), try Karni 1001 -> 400!
      const directFac = await request('/api/commercial/sales-docs', {
        method: 'POST',
        headers: authHeaders,
        json: {
          docType: 'FACTURE',
          clientId: cli.id,
          validateNow: true,
          lines: [{ articleId: artExempt.id, qty: 2, unitPriceHtMru: 1000 }],
        },
      });
      assert.equal(directFac.status, 201);
      assert.equal(directFac.json.doc.status, 'VALIDEE');
      const artsAfter2 = (await request('/api/commercial/articles', { headers: authHeaders })).json.articles;
      assert.equal(artsAfter2.find((a) => a.id === artExempt.id).stockQty, 12);

      const overKarni = await request(`/api/commercial/sales-docs/${directFac.json.doc.id}/payments`, {
        method: 'POST',
        headers: authHeaders,
        json: { payMethod: 'Karni', amountMru: 1001 },
      });
      assert.equal(overKarni.status, 400);

      // Exact boundary Karni 1000 -> 201
      const exactKarni = await request(`/api/commercial/sales-docs/${directFac.json.doc.id}/payments`, {
        method: 'POST',
        headers: authHeaders,
        json: { payMethod: 'Karni', amountMru: 1000 },
      });
      assert.equal(exactKarni.status, 201);

      // Avoir exceeding remaining creditable TTC -> 400
      const badAvoir = await request('/api/commercial/sales-docs', {
        method: 'POST',
        headers: authHeaders,
        json: {
          docType: 'AVOIR',
          clientId: cli.id,
          sourceDocId: directFac.json.doc.id,
          lines: [{ articleId: artExempt.id, qty: 3, unitPriceHtMru: 1000 }],
        },
      });
      assert.equal(badAvoir.status, 400);

      // Valid Avoir with restock: true (1 unit = 1000) -> stock 12->13
      const goodAvoir = await request('/api/commercial/sales-docs', {
        method: 'POST',
        headers: authHeaders,
        json: {
          docType: 'AVOIR',
          clientId: cli.id,
          sourceDocId: directFac.json.doc.id,
          restock: true,
          validateNow: true,
          lines: [{ articleId: artExempt.id, qty: 1, unitPriceHtMru: 1000 }],
        },
      });
      assert.equal(goodAvoir.status, 201);
      const artsAfter3 = (await request('/api/commercial/articles', { headers: authHeaders })).json.articles;
      assert.equal(artsAfter3.find((a) => a.id === artExempt.id).stockQty, 13);
    });
  });
});

describe('Commercial Suite 4 — Purchases Cycle & Weighted-Average PMP', () => {
  it('recalculates weighted PMP on Réception, snapshots cost on sale, and posts supplier payments & Avoir fournisseur', async () => {
    await withIsolatedServer(async ({ request }) => {
      const adminToken = await loginAdmin(request);
      const { authHeaders } = await createCommercialTenant(request, adminToken);

      const sup = (
        await request('/api/commercial/suppliers', {
          method: 'POST',
          headers: authHeaders,
          json: { name: 'Grossiste Nouakchott' },
        })
      ).json.supplier;

      const cli = (
        await request('/api/commercial/clients', {
          method: 'POST',
          headers: authHeaders,
          json: { name: 'Client Détail' },
        })
      ).json.client;

      const art = (
        await request('/api/commercial/articles', {
          method: 'POST',
          headers: authHeaders,
          json: { sku: 'PMP-1', name: 'Câble RJ45', priceRetailHt: 800, priceCostMru: 0, stockQty: 0, tvaRate: 16 },
        })
      ).json.article;

      // 1. CF -> Réception 1: 10 @ 500 -> PMP = 500
      const cf1 = await request('/api/commercial/purchase-docs', {
        method: 'POST',
        headers: authHeaders,
        json: {
          docType: 'COMMANDE_FOURNISSEUR',
          supplierId: sup.id,
          validateNow: true,
          lines: [{ articleId: art.id, qty: 10, unitCostHtMru: 500 }],
        },
      });
      assert.equal(cf1.status, 201);

      const rec1 = await request(`/api/commercial/purchase-docs/${cf1.json.doc.id}/convert`, {
        method: 'POST',
        headers: authHeaders,
        json: { targetType: 'RECEPTION', validateNow: true },
      });
      assert.equal(rec1.status, 201);
      let artNow = (await request('/api/commercial/articles', { headers: authHeaders })).json.articles[0];
      assert.equal(artNow.stockQty, 10);
      assert.equal(artNow.pmpCostMru, 500);

      // 2. Réception 2: 30 @ 300 -> PMP = (10*500 + 30*300)/40 = 350
      const rec2 = await request('/api/commercial/purchase-docs', {
        method: 'POST',
        headers: authHeaders,
        json: {
          docType: 'RECEPTION',
          supplierId: sup.id,
          validateNow: true,
          lines: [{ articleId: art.id, qty: 30, unitCostHtMru: 300 }],
        },
      });
      assert.equal(rec2.status, 201);
      artNow = (await request('/api/commercial/articles', { headers: authHeaders })).json.articles[0];
      assert.equal(artNow.stockQty, 40);
      assert.equal(artNow.pmpCostMru, 350);

      // 3. Sale snapshots costPmpMru = 350 without modifying article PMP
      const sale = await request('/api/commercial/sales-docs', {
        method: 'POST',
        headers: authHeaders,
        json: {
          docType: 'FACTURE',
          clientId: cli.id,
          validateNow: true,
          lines: [{ articleId: art.id, qty: 4, unitPriceHtMru: 800 }],
        },
      });
      assert.equal(sale.status, 201);
      assert.equal(sale.json.doc.totalCostMru, 1400);
      assert.equal(sale.json.doc.grossMarginMru, 1800);

      // 4. Convert Réception 2 -> Facture fournisseur, pay partial, issue Avoir fournisseur with restock
      const ff = await request(`/api/commercial/purchase-docs/${rec2.json.doc.id}/convert`, {
        method: 'POST',
        headers: authHeaders,
        json: { targetType: 'FACTURE_FOURNISSEUR', validateNow: true },
      });
      assert.equal(ff.status, 201);
      // 30 * 300 * 1.16 = 10440
      assert.equal(ff.json.doc.totalTtcMru, 10440);

      const pOut = await request(`/api/commercial/purchase-docs/${ff.json.doc.id}/payments`, {
        method: 'POST',
        headers: authHeaders,
        json: { payMethod: 'Virement', amountMru: 4440 },
      });
      assert.equal(pOut.status, 201);
      assert.equal(pOut.json.doc.status, 'PARTIELLE');

      const af = await request('/api/commercial/purchase-docs', {
        method: 'POST',
        headers: authHeaders,
        json: {
          docType: 'AVOIR_FOURNISSEUR',
          supplierId: sup.id,
          sourceDocId: ff.json.doc.id,
          restock: true,
          validateNow: true,
          lines: [{ articleId: art.id, qty: 2, unitCostHtMru: 300 }],
        },
      });
      assert.equal(af.status, 201);
      artNow = (await request('/api/commercial/articles', { headers: authHeaders })).json.articles[0];
      assert.equal(artNow.stockQty, 34); // 40 - 4 (sale) - 2 (avoir fournisseur)
    });
  });
});

describe('Commercial Suite 5 — Integrated POS (Sessions, Z-Report & Tickets)', () => {
  it('enforces single OPEN session, multi-tender checkout with change & Karni, voiding, and Z-report reconciliation', async () => {
    await withIsolatedServer(async ({ request }) => {
      const adminToken = await loginAdmin(request);
      const { authHeaders } = await createCommercialTenant(request, adminToken);

      const cli = (
        await request('/api/commercial/clients', {
          method: 'POST',
          headers: authHeaders,
          json: { name: 'Client POS Karni', creditLimitMru: 2000 },
        })
      ).json.client;

      const art = (
        await request('/api/commercial/articles', {
          method: 'POST',
          headers: authHeaders,
          json: {
            sku: 'POS-1',
            name: 'Clé USB 64Go',
            priceRetailHt: 500,
            priceWholeHt: 400,
            priceCostMru: 250,
            stockQty: 20,
            isExempt: true,
          },
        })
      ).json.article;

      // Ticket without open session -> 400
      const noSes = await request('/api/commercial/pos/tickets', {
        method: 'POST',
        headers: authHeaders,
        json: { payMethod: 'Cash', lines: [{ articleId: art.id, qty: 1 }] },
      });
      assert.equal(noSes.status, 400);

      // Open session C1 with 1000 opening float
      const ses = await request('/api/commercial/pos/sessions/open', {
        method: 'POST',
        headers: authHeaders,
        json: { registerCode: 'C1', cashierName: 'Oumar', openingFloatMru: 1000 },
      });
      assert.equal(ses.status, 201);

      // Duplicate open on C1 -> 409
      const dupSes = await request('/api/commercial/pos/sessions/open', {
        method: 'POST',
        headers: authHeaders,
        json: { registerCode: 'C1', openingFloatMru: 500 },
      });
      assert.equal(dupSes.status, 409);

      // Multi-tender ticket (WHOLE tier: 5 * 400 = 2000 TTC):
      // Cash tendered 700 (200 change -> net 500 Cash), Bankily 300, Sedad 200, Bimbank 200, Click 300, Karni 500
      const tkt1 = await request('/api/commercial/pos/tickets', {
        method: 'POST',
        headers: authHeaders,
        json: {
          sessionId: ses.json.session.id,
          clientId: cli.id,
          priceTier: 'whole',
          lines: [{ articleId: art.id, qty: 5 }],
          payments: [
            { method: 'Cash', amountMru: 700 },
            { method: 'Bankily', amountMru: 300 },
            { method: 'Sedad', amountMru: 200 },
            { method: 'Bimbank', amountMru: 200 },
            { method: 'Click', amountMru: 300 },
            { method: 'Karni', amountMru: 500 },
          ],
        },
      });
      assert.equal(tkt1.status, 201, tkt1.text);
      assert.equal(tkt1.json.ticket.totalTtcMru, 2000);
      assert.equal(tkt1.json.ticket.changeMru, 200);
      assert.equal(tkt1.json.ticket.payMethod, 'Mixte');

      // Second ticket 300 Cash -> void it
      const tkt2 = await request('/api/commercial/pos/tickets', {
        method: 'POST',
        headers: authHeaders,
        json: {
          sessionId: ses.json.session.id,
          priceTier: 'retail',
          payMethod: 'Cash',
          lines: [{ articleId: art.id, qty: 1 }],
        },
      });
      assert.equal(tkt2.status, 201);

      const voidRes = await request(`/api/commercial/pos/tickets/${tkt2.json.ticket.id}/void`, {
        method: 'POST',
        headers: authHeaders,
        json: { reason: 'Erreur caisse' },
      });
      assert.equal(voidRes.status, 200);
      assert.equal(voidRes.json.ticket.status, 'VOID');

      // Double void -> 400
      const dblVoid = await request(`/api/commercial/pos/tickets/${tkt2.json.ticket.id}/void`, {
        method: 'POST',
        headers: authHeaders,
        json: { reason: 'Double' },
      });
      assert.equal(dblVoid.status, 400);

      // Stock: 20 - 5 - 1 + 1 = 15
      const artAfter = (await request('/api/commercial/articles', { headers: authHeaders })).json.articles[0];
      assert.equal(artAfter.stockQty, 15);

      // Close session with countedCashMru = 1450 (expected = 1000 + (500 + 500) - 500 = 1500 -> variance -50)
      const closeRes = await request(`/api/commercial/pos/sessions/${ses.json.session.id}/close`, {
        method: 'POST',
        headers: authHeaders,
        json: { countedCashMru: 1450 },
      });
      assert.equal(closeRes.status, 200);
      assert.equal(closeRes.json.zReport.expectedCashMru, 1500);
      assert.equal(closeRes.json.zReport.varianceMru, -50);
      assert.equal(closeRes.json.zReport.byPaymentMethod.bankily, 300);
      assert.equal(closeRes.json.zReport.byPaymentMethod.karni, 500);

      const zRes = await request(`/api/commercial/pos/sessions/${ses.json.session.id}/z-report`, {
        headers: authHeaders,
      });
      assert.equal(zRes.status, 200);
      assert.equal(zRes.json.zReport.voidedCount, 1);
    });
  });
});

describe('Commercial Suite 6 — Treasury, Cheques Lifecycle, Objectives, Dashboard & Analytics', () => {
  it('handles atomic transfers, cheque ENCAISSE->IMPAYE reversal, objectives, 6 dashboard presets, alerts, and 4 analytics routes', async () => {
    await withIsolatedServer(async ({ request }) => {
      const adminToken = await loginAdmin(request);
      const { authHeaders } = await createCommercialTenant(request, adminToken);

      const accountsRes = await request('/api/commercial/treasury/accounts', { headers: authHeaders });
      const caisse = accountsRes.json.accounts.find((a) => a.accountType === 'CAISSE');
      const banque = accountsRes.json.accounts.find((a) => a.accountType === 'BANQUE');

      // Manual IN on Caisse (+50000) + atomic transfer 20000 to Banque (net total unchanged)
      await request('/api/commercial/treasury/movements', {
        method: 'POST',
        headers: authHeaders,
        json: { accountId: caisse.id, direction: 'IN', amountMru: 50000, label: 'Apport capital' },
      });
      const sameAccErr = await request('/api/commercial/treasury/transfer', {
        method: 'POST',
        headers: authHeaders,
        json: { fromAccountId: caisse.id, toAccountId: caisse.id, amountMru: 1000 },
      });
      assert.equal(sameAccErr.status, 400);

      const trf = await request('/api/commercial/treasury/transfer', {
        method: 'POST',
        headers: authHeaders,
        json: { fromAccountId: caisse.id, toAccountId: banque.id, amountMru: 20000 },
      });
      assert.equal(trf.status, 201);
      assert.equal(trf.json.fromAccount.currentBalanceMru, 30000);
      assert.equal(trf.json.toAccount.currentBalanceMru, 20000);

      // Client + Overdue Invoice + Cheque lifecycle (EN_PORTEFEUILLE -> DEPOSE -> ENCAISSE -> IMPAYE)
      const cli = (
        await request('/api/commercial/clients', {
          method: 'POST',
          headers: authHeaders,
          json: { name: 'Client Chèque' },
        })
      ).json.client;
      const art = (
        await request('/api/commercial/articles', {
          method: 'POST',
          headers: authHeaders,
          json: { sku: 'CHQ-A', name: 'Serveur', priceRetailHt: 10000, priceCostMru: 7000, stockQty: 5, isExempt: true },
        })
      ).json.article;

      const inv = (
        await request('/api/commercial/sales-docs', {
          method: 'POST',
          headers: authHeaders,
          json: {
            docType: 'FACTURE',
            clientId: cli.id,
            issueDate: '2026-01-05',
            dueDate: '2026-01-10', // overdue
            validateNow: true,
            lines: [{ articleId: art.id, qty: 1, unitPriceHtMru: 10000 }],
          },
        })
      ).json.doc;

      const payChq = await request(`/api/commercial/sales-docs/${inv.id}/payments`, {
        method: 'POST',
        headers: authHeaders,
        json: { payMethod: 'Chèque', amountMru: 10000, ref: 'CHQ-7788', dueDate: todayStr() },
      });
      assert.equal(payChq.status, 201);
      const chqId = payChq.json.cheque.id;
      assert.equal(payChq.json.cheque.status, 'EN_PORTEFEUILLE');

      await request(`/api/commercial/cheques/${chqId}/status`, {
        method: 'PATCH',
        headers: authHeaders,
        json: { status: 'DEPOSE' },
      });
      const encRes = await request(`/api/commercial/cheques/${chqId}/status`, {
        method: 'PATCH',
        headers: authHeaders,
        json: { status: 'ENCAISSE', treasuryAccountId: banque.id },
      });
      assert.equal(encRes.status, 200);
      assert.equal(encRes.json.cheque.status, 'ENCAISSE');

      // Banque is now 20000 + 10000 = 30000, Invoice is PAYEE
      const invPaid = await request(`/api/commercial/sales-docs/${inv.id}`, { headers: authHeaders });
      assert.equal(invPaid.json.doc.status, 'PAYEE');

      // Reversal to IMPAYE restores unpaid Invoice & reverses Banque to 20000
      const impRes = await request(`/api/commercial/cheques/${chqId}/status`, {
        method: 'PATCH',
        headers: authHeaders,
        json: { status: 'IMPAYE' },
      });
      assert.equal(impRes.status, 200);
      const invReverted = await request(`/api/commercial/sales-docs/${inv.id}`, { headers: authHeaders });
      assert.equal(invReverted.json.doc.status, 'VALIDEE');
      assert.equal(invReverted.json.doc.remainingMru, 10000);

      // Supplier cheque EMIS -> DECAISSE
      const sup = (
        await request('/api/commercial/suppliers', {
          method: 'POST',
          headers: authHeaders,
          json: { name: 'Fournisseur Chèque' },
        })
      ).json.supplier;
      const supChq = await request('/api/commercial/cheques', {
        method: 'POST',
        headers: authHeaders,
        json: {
          direction: 'FOURNISSEUR',
          instrumentType: 'TRAITE',
          number: 'TRT-900',
          supplierId: sup.id,
          dueDate: todayStr(),
          amountMru: 5000,
        },
      });
      assert.equal(supChq.status, 201);
      assert.equal(supChq.json.cheque.status, 'EMIS');

      const decRes = await request(`/api/commercial/cheques/${supChq.json.cheque.id}/status`, {
        method: 'PATCH',
        headers: authHeaders,
        json: { status: 'DECAISSE', treasuryAccountId: banque.id },
      });
      assert.equal(decRes.status, 200);

      // Objectives PUT & invalid month 400
      const badObj = await request('/api/commercial/objectives', {
        method: 'PUT',
        headers: authHeaders,
        json: { year: 2026, month: 13, targetCaHtMru: 100000 },
      });
      assert.equal(badObj.status, 400);

      const curYear = new Date().getUTCFullYear();
      const putObj = await request('/api/commercial/objectives', {
        method: 'PUT',
        headers: authHeaders,
        json: {
          year: curYear,
          items: [
            { month: 1, targetCaHtMru: 100000 },
            { month: 2, targetCaHtMru: 150000 },
          ],
        },
      });
      assert.equal(putObj.status, 200);
      assert.equal(putObj.json.summary.totalTargetMru, 250000);

      // Dashboard presets + custom range + alerts
      for (const preset of ['this_month', 'last_month', 'this_quarter', 'this_year', 'last_12_months', 'last_year']) {
        const dash = await request(`/api/commercial/dashboard?preset=${preset}`, { headers: authHeaders });
        assert.equal(dash.status, 200, `${preset}: ${dash.text}`);
        assert.ok(Array.isArray(dash.json.series));
        assert.ok(dash.json.kpis);
      }

      const customDash = await request('/api/commercial/dashboard?from=2026-01-01&to=2026-12-31', {
        headers: authHeaders,
      });
      assert.equal(customDash.status, 200);
      assert.equal(customDash.json.kpis.caHtMru, 10000);
      assert.equal(customDash.json.kpis.grossMarginMru, 3000);
      assert.equal(customDash.json.kpis.clientReceivablesTtcMru, 10000);
      assert.equal(customDash.json.kpis.treasuryBalanceMru, 45000); // 30000 + 20000 - 5000
      assert.equal(customDash.json.alerts.overdueClientInvoices.count, 1);

      const badRange = await request('/api/commercial/dashboard?from=2026-12-31&to=2026-01-01', {
        headers: authHeaders,
      });
      assert.equal(badRange.status, 400);

      // 4 Analytics endpoints
      assert.equal((await request('/api/commercial/analytics/sales?preset=this_year', { headers: authHeaders })).status, 200);
      assert.equal((await request('/api/commercial/analytics/purchases-stock?preset=this_year', { headers: authHeaders })).status, 200);
      assert.equal((await request('/api/commercial/analytics/treasury?preset=this_year', { headers: authHeaders })).status, 200);
      assert.equal((await request(`/api/commercial/analytics/objectives?year=${curYear}`, { headers: authHeaders })).status, 200);
    });
  });
});

describe('Commercial Suite 7 — State Machine Guards (Cheques, Conversions, Draft Delete Revert & DEVIS)', () => {
  it('enforces cheque transition graph, reverses PENDING payment on ANNULE, and validates linked doc types on POST /cheques', async () => {
    await withIsolatedServer(async ({ request }) => {
      const adminToken = await loginAdmin(request);
      const { authHeaders } = await createCommercialTenant(request, adminToken);

      const accounts = (await request('/api/commercial/treasury/accounts', { headers: authHeaders })).json.accounts;
      const banque = accounts.find((a) => a.accountType === 'BANQUE');

      const cli = (
        await request('/api/commercial/clients', {
          method: 'POST',
          headers: authHeaders,
          json: { name: 'Client SM' },
        })
      ).json.client;
      const sup = (
        await request('/api/commercial/suppliers', {
          method: 'POST',
          headers: authHeaders,
          json: { name: 'Fournisseur SM' },
        })
      ).json.supplier;
      const art = (
        await request('/api/commercial/articles', {
          method: 'POST',
          headers: authHeaders,
          json: { sku: 'SM-1', name: 'Routeur', priceRetailHt: 1000, stockQty: 20, isExempt: true },
        })
      ).json.article;

      // Non-invoice doc rejections on POST /cheques
      const devis = (
        await request('/api/commercial/sales-docs', {
          method: 'POST',
          headers: authHeaders,
          json: { docType: 'DEVIS', clientId: cli.id, lines: [{ articleId: art.id, qty: 1 }] },
        })
      ).json.doc;
      const draftFac = (
        await request('/api/commercial/sales-docs', {
          method: 'POST',
          headers: authHeaders,
          json: { docType: 'FACTURE', clientId: cli.id, lines: [{ articleId: art.id, qty: 1 }] },
        })
      ).json.doc;
      const cf = (
        await request('/api/commercial/purchase-docs', {
          method: 'POST',
          headers: authHeaders,
          json: { docType: 'COMMANDE_FOURNISSEUR', supplierId: sup.id, validateNow: true, lines: [{ articleId: art.id, qty: 1, unitCostHtMru: 500 }] },
        })
      ).json.doc;
      const draftFf = (
        await request('/api/commercial/purchase-docs', {
          method: 'POST',
          headers: authHeaders,
          json: { docType: 'FACTURE_FOURNISSEUR', supplierId: sup.id, lines: [{ articleId: art.id, qty: 1, unitCostHtMru: 500 }] },
        })
      ).json.doc;

      assert.equal(
        (
          await request('/api/commercial/cheques', {
            method: 'POST',
            headers: authHeaders,
            json: { direction: 'CLIENT', number: 'C-BAD1', dueDate: todayStr(), amountMru: 500, salesDocId: devis.id },
          })
        ).status,
        400,
      );
      assert.equal(
        (
          await request('/api/commercial/cheques', {
            method: 'POST',
            headers: authHeaders,
            json: { direction: 'CLIENT', number: 'C-BAD2', dueDate: todayStr(), amountMru: 500, salesDocId: draftFac.id },
          })
        ).status,
        400,
      );
      assert.equal(
        (
          await request('/api/commercial/cheques', {
            method: 'POST',
            headers: authHeaders,
            json: { direction: 'FOURNISSEUR', number: 'F-BAD1', dueDate: todayStr(), amountMru: 500, purchaseDocId: cf.id },
          })
        ).status,
        400,
      );
      assert.equal(
        (
          await request('/api/commercial/cheques', {
            method: 'POST',
            headers: authHeaders,
            json: { direction: 'FOURNISSEUR', number: 'F-BAD2', dueDate: todayStr(), amountMru: 500, purchaseDocId: draftFf.id },
          })
        ).status,
        400,
      );

      // Validated client FACTURE + Chèque -> ENCAISSE -> disallow DEPOSE, ANNULE; allow IMPAYE -> disallow ENCAISSE
      const inv = (
        await request('/api/commercial/sales-docs', {
          method: 'POST',
          headers: authHeaders,
          json: { docType: 'FACTURE', clientId: cli.id, validateNow: true, lines: [{ articleId: art.id, qty: 1, unitPriceHtMru: 1000 }] },
        })
      ).json.doc;

      const chqPay1 = await request(`/api/commercial/sales-docs/${inv.id}/payments`, {
        method: 'POST',
        headers: authHeaders,
        json: { payMethod: 'Chèque', amountMru: 1000, ref: 'CHQ-SM-1', dueDate: todayStr() },
      });
      assert.equal(chqPay1.status, 201);
      const chq1Id = chqPay1.json.cheque.id;

      // EN_PORTEFEUILLE -> ANNULE reverses PENDING payment so invoice can be paid again
      assert.equal(
        (
          await request(`/api/commercial/cheques/${chq1Id}/status`, {
            method: 'PATCH',
            headers: authHeaders,
            json: { status: 'ANNULE' },
          })
        ).status,
        200,
      );
      const invAfterCancel = await request(`/api/commercial/sales-docs/${inv.id}`, { headers: authHeaders });
      assert.equal(invAfterCancel.json.payments[0].status, 'REVERSED');
      // ANNULE -> ENCAISSE is disallowed (400)
      assert.equal(
        (
          await request(`/api/commercial/cheques/${chq1Id}/status`, {
            method: 'PATCH',
            headers: authHeaders,
            json: { status: 'ENCAISSE', treasuryAccountId: banque.id },
          })
        ).status,
        400,
      );

      // Issue second cheque on same invoice -> ENCAISSE -> block DEPOSE / ANNULE -> IMPAYE -> block ENCAISSE
      const chqPay2 = await request(`/api/commercial/sales-docs/${inv.id}/payments`, {
        method: 'POST',
        headers: authHeaders,
        json: { payMethod: 'Chèque', amountMru: 1000, ref: 'CHQ-SM-2', dueDate: todayStr() },
      });
      assert.equal(chqPay2.status, 201);
      const chq2Id = chqPay2.json.cheque.id;

      assert.equal(
        (
          await request(`/api/commercial/cheques/${chq2Id}/status`, {
            method: 'PATCH',
            headers: authHeaders,
            json: { status: 'ENCAISSE', treasuryAccountId: banque.id },
          })
        ).status,
        200,
      );
      assert.equal(
        (
          await request(`/api/commercial/cheques/${chq2Id}/status`, {
            method: 'PATCH',
            headers: authHeaders,
            json: { status: 'DEPOSE' },
          })
        ).status,
        400,
      );
      assert.equal(
        (
          await request(`/api/commercial/cheques/${chq2Id}/status`, {
            method: 'PATCH',
            headers: authHeaders,
            json: { status: 'ANNULE' },
          })
        ).status,
        400,
      );
      assert.equal(
        (
          await request(`/api/commercial/cheques/${chq2Id}/status`, {
            method: 'PATCH',
            headers: authHeaders,
            json: { status: 'IMPAYE' },
          })
        ).status,
        200,
      );
      assert.equal(
        (
          await request(`/api/commercial/cheques/${chq2Id}/status`, {
            method: 'PATCH',
            headers: authHeaders,
            json: { status: 'ENCAISSE', treasuryAccountId: banque.id },
          })
        ).status,
        400,
      );

      // Supplier cheque: DECAISSE -> EMIS -> 400; ANNULE -> DECAISSE -> 400
      const ff = (
        await request('/api/commercial/purchase-docs', {
          method: 'POST',
          headers: authHeaders,
          json: { docType: 'FACTURE_FOURNISSEUR', supplierId: sup.id, validateNow: true, lines: [{ articleId: art.id, qty: 1, unitCostHtMru: 500 }] },
        })
      ).json.doc;
      const supChq1 = (
        await request(`/api/commercial/purchase-docs/${ff.id}/payments`, {
          method: 'POST',
          headers: authHeaders,
          json: { payMethod: 'Chèque', amountMru: 500, ref: 'FCHQ-1', dueDate: todayStr() },
        })
      ).json.cheque;
      assert.equal(
        (
          await request(`/api/commercial/cheques/${supChq1.id}/status`, {
            method: 'PATCH',
            headers: authHeaders,
            json: { status: 'DECAISSE', treasuryAccountId: banque.id },
          })
        ).status,
        200,
      );
      assert.equal(
        (
          await request(`/api/commercial/cheques/${supChq1.id}/status`, {
            method: 'PATCH',
            headers: authHeaders,
            json: { status: 'EMIS' },
          })
        ).status,
        400,
      );

      const supChq2 = (
        await request('/api/commercial/cheques', {
          method: 'POST',
          headers: authHeaders,
          json: { direction: 'FOURNISSEUR', number: 'FCHQ-2', dueDate: todayStr(), amountMru: 200, supplierId: sup.id },
        })
      ).json.cheque;
      assert.equal(
        (
          await request(`/api/commercial/cheques/${supChq2.id}/status`, {
            method: 'PATCH',
            headers: authHeaders,
            json: { status: 'ANNULE' },
          })
        ).status,
        200,
      );
      assert.equal(
        (
          await request(`/api/commercial/cheques/${supChq2.id}/status`, {
            method: 'PATCH',
            headers: authHeaders,
            json: { status: 'DECAISSE', treasuryAccountId: banque.id },
          })
        ).status,
        400,
      );
    });
  });

  it('guards COMMANDE double conversion, reverts source doc on draft DELETE, retains BL costPmp=0, guards DEVIS revert & partial AVOIR conversion', async () => {
    await withIsolatedServer(async ({ request }) => {
      const adminToken = await loginAdmin(request);
      const { authHeaders } = await createCommercialTenant(request, adminToken);

      const cli = (
        await request('/api/commercial/clients', {
          method: 'POST',
          headers: authHeaders,
          json: { name: 'Client Cycle' },
        })
      ).json.client;
      const sup = (
        await request('/api/commercial/suppliers', {
          method: 'POST',
          headers: authHeaders,
          json: { name: 'Fournisseur Cycle' },
        })
      ).json.supplier;
      const art = (
        await request('/api/commercial/articles', {
          method: 'POST',
          headers: authHeaders,
          json: { sku: 'ZERO-PMP', name: 'Câble', priceRetailHt: 500, priceCostMru: 0, stockQty: 20, isExempt: true },
        })
      ).json.article;

      // 1. COMMANDE -> BL (validate) -> same COMMANDE -> FACTURE must return 400 (no double stock deduction)
      const cmd = (
        await request('/api/commercial/sales-docs', {
          method: 'POST',
          headers: authHeaders,
          json: { docType: 'COMMANDE', clientId: cli.id, validateNow: true, lines: [{ articleId: art.id, qty: 4 }] },
        })
      ).json.doc;
      const blFromCmd = await request(`/api/commercial/sales-docs/${cmd.id}/convert`, {
        method: 'POST',
        headers: authHeaders,
        json: { targetType: 'BL', validateNow: true },
      });
      assert.equal(blFromCmd.status, 201);
      assert.equal(blFromCmd.json.sourceDoc.status, 'LIVREE');

      const secondConv = await request(`/api/commercial/sales-docs/${cmd.id}/convert`, {
        method: 'POST',
        headers: authHeaders,
        json: { targetType: 'FACTURE', validateNow: true },
      });
      assert.equal(secondConv.status, 400);
      let artNow = (await request('/api/commercial/articles', { headers: authHeaders })).json.articles[0];
      assert.equal(artNow.stockQty, 16); // Deducted once (20 - 4)

      // 2. BL validated at costPmp=0 -> RECEPTION updates PMP -> BL -> FACTURE retains 0 cost
      const rec = await request('/api/commercial/purchase-docs', {
        method: 'POST',
        headers: authHeaders,
        json: { docType: 'RECEPTION', supplierId: sup.id, validateNow: true, lines: [{ articleId: art.id, qty: 10, unitCostHtMru: 300 }] },
      });
      assert.equal(rec.status, 201);

      // Convert BL -> draft FACTURE, then DELETE draft FACTURE -> BL reverts to VALIDE -> re-convert & validate
      const facDraft = await request(`/api/commercial/sales-docs/${blFromCmd.json.doc.id}/convert`, {
        method: 'POST',
        headers: authHeaders,
        json: { targetType: 'FACTURE', validateNow: false },
      });
      assert.equal(facDraft.status, 201);

      const delFacDraft = await request(`/api/commercial/sales-docs/${facDraft.json.doc.id}`, {
        method: 'DELETE',
        headers: authHeaders,
      });
      assert.equal(delFacDraft.status, 200);

      const blReverted = await request(`/api/commercial/sales-docs/${blFromCmd.json.doc.id}`, { headers: authHeaders });
      assert.equal(blReverted.json.doc.status, 'VALIDE');
      assert.equal(blReverted.json.doc.convertedToDocId, null);

      const facFinal = await request(`/api/commercial/sales-docs/${blFromCmd.json.doc.id}/convert`, {
        method: 'POST',
        headers: authHeaders,
        json: { targetType: 'FACTURE', validateNow: true },
      });
      assert.equal(facFinal.status, 201);
      assert.equal(facFinal.json.doc.totalCostMru, 0); // Historical 0 cost retained!

      // 3. Purchase double-conversion guard + draft delete revert
      const cf = (
        await request('/api/commercial/purchase-docs', {
          method: 'POST',
          headers: authHeaders,
          json: { docType: 'COMMANDE_FOURNISSEUR', supplierId: sup.id, validateNow: true, lines: [{ articleId: art.id, qty: 2, unitCostHtMru: 300 }] },
        })
      ).json.doc;
      const recDraft = await request(`/api/commercial/purchase-docs/${cf.id}/convert`, {
        method: 'POST',
        headers: authHeaders,
        json: { targetType: 'RECEPTION', validateNow: false },
      });
      assert.equal(recDraft.status, 201);
      // Same CF cannot convert again while RECEPTIONNEE
      assert.equal(
        (
          await request(`/api/commercial/purchase-docs/${cf.id}/convert`, {
            method: 'POST',
            headers: authHeaders,
            json: { targetType: 'FACTURE_FOURNISSEUR' },
          })
        ).status,
        400,
      );
      // Delete draft RECEPTION -> reverts CF to ENVOYEE
      assert.equal(
        (await request(`/api/commercial/purchase-docs/${recDraft.json.doc.id}`, { method: 'DELETE', headers: authHeaders })).status,
        200,
      );
      const cfAfterDel = await request(`/api/commercial/purchase-docs/${cf.id}`, { headers: authHeaders });
      assert.equal(cfAfterDel.json.doc.status, 'ENVOYEE');
      assert.equal(cfAfterDel.json.doc.convertedToDocId, null);

      // 4. DEVIS closed status revert guard
      const devis = (
        await request('/api/commercial/sales-docs', {
          method: 'POST',
          headers: authHeaders,
          json: { docType: 'DEVIS', clientId: cli.id, lines: [{ articleId: art.id, qty: 1 }] },
        })
      ).json.doc;
      assert.equal(
        (
          await request(`/api/commercial/sales-docs/${devis.id}`, {
            method: 'PATCH',
            headers: authHeaders,
            json: { status: 'ANNULE' },
          })
        ).status,
        200,
      );
      assert.equal(
        (
          await request(`/api/commercial/sales-docs/${devis.id}`, {
            method: 'PATCH',
            headers: authHeaders,
            json: { status: 'BROUILLON' },
          })
        ).status,
        400,
      );

      // 5. Partial AVOIR conversion scaling & over-credit guard
      const inv2 = (
        await request('/api/commercial/sales-docs', {
          method: 'POST',
          headers: authHeaders,
          json: { docType: 'FACTURE', clientId: cli.id, validateNow: true, lines: [{ articleId: art.id, qty: 2, unitPriceHtMru: 500 }] },
        })
      ).json.doc; // 1000 TTC
      await request('/api/commercial/sales-docs', {
        method: 'POST',
        headers: authHeaders,
        json: { docType: 'AVOIR', clientId: cli.id, sourceDocId: inv2.id, validateNow: true, lines: [{ articleId: art.id, qty: 1, unitPriceHtMru: 400 }] },
      });
      // Custom lines > remaining 600 -> 400
      assert.equal(
        (
          await request(`/api/commercial/sales-docs/${inv2.id}/convert`, {
            method: 'POST',
            headers: authHeaders,
            json: { targetType: 'AVOIR', validateNow: false, lines: [{ articleId: art.id, qty: 1, unitPriceHtMru: 700 }] },
          })
        ).status,
        400,
      );
      // Default convert (validateNow: false) scales draft to remaining 600
      const avDraft = await request(`/api/commercial/sales-docs/${inv2.id}/convert`, {
        method: 'POST',
        headers: authHeaders,
        json: { targetType: 'AVOIR', validateNow: false },
      });
      assert.equal(avDraft.status, 201);
      assert.equal(avDraft.json.doc.totalTtcMru, 600);
      // Validate it -> remaining is 0 -> further convert returns 400
      assert.equal(
        (await request(`/api/commercial/sales-docs/${avDraft.json.doc.id}/validate`, { method: 'POST', headers: authHeaders })).status,
        200,
      );
      assert.equal(
        (
          await request(`/api/commercial/sales-docs/${inv2.id}/convert`, {
            method: 'POST',
            headers: authHeaders,
            json: { targetType: 'AVOIR', validateNow: false },
          })
        ).status,
        400,
      );
    });
  });
});

describe('Commercial Suite 8 — POS Hardening, Karni Reconciliation, Drafts, List Filters, Analytics & NaN Guards', () => {
  it('validates POS tenders, Karni total encours, closed-session voiding, AVOIR on Karni invoice, karni-pay, analytics & NaN inputs', async () => {
    await withIsolatedServer(async ({ request }) => {
      const adminToken = await loginAdmin(request);
      const { authHeaders } = await createCommercialTenant(request, adminToken);

      // Empty DB analytics/dashboard zero-division returns null
      const emptyDash = await request('/api/commercial/dashboard?preset=this_year', { headers: authHeaders });
      assert.equal(emptyDash.status, 200);
      assert.equal(emptyDash.json.kpis.marginRatePct, null);
      const emptySalesAn = await request('/api/commercial/analytics/sales?preset=this_year', { headers: authHeaders });
      assert.equal(emptySalesAn.status, 200);
      assert.equal(emptySalesAn.json.summary.marginRatePct, null);

      // NaN numeric validation -> 400
      const accounts = (await request('/api/commercial/treasury/accounts', { headers: authHeaders })).json.accounts;
      assert.equal(
        (
          await request('/api/commercial/treasury/accounts', {
            method: 'POST',
            headers: authHeaders,
            json: { name: 'Bad Acc', accountType: 'CAISSE', initialBalanceMru: 'abc' },
          })
        ).status,
        400,
      );
      assert.equal(
        (
          await request('/api/commercial/objectives', {
            method: 'PUT',
            headers: authHeaders,
            json: { year: 2026, month: 3, targetCaHtMru: 'abc' },
          })
        ).status,
        400,
      );
      assert.equal(
        (
          await request('/api/commercial/objectives', {
            method: 'PUT',
            headers: authHeaders,
            json: { year: 2026, month: 3, targetCaHtMru: 1000, targetMarginPct: 'abc' },
          })
        ).status,
        400,
      );
      assert.equal(
        (
          await request('/api/commercial/articles', {
            method: 'POST',
            headers: authHeaders,
            json: { name: 'Bad Art', priceRetailTtc: 'abc' },
          })
        ).status,
        400,
      );

      const cli = (
        await request('/api/commercial/clients', {
          method: 'POST',
          headers: authHeaders,
          json: { name: 'Client Karni Total', creditLimitMru: 1000 },
        })
      ).json.client;
      const sup = (
        await request('/api/commercial/suppliers', {
          method: 'POST',
          headers: authHeaders,
          json: { name: 'Fournisseur Draft' },
        })
      ).json.supplier;
      const art = (
        await request('/api/commercial/articles', {
          method: 'POST',
          headers: authHeaders,
          json: { sku: 'KAR-1', name: 'Écran 24"', priceRetailHt: 500, priceCostMru: 300, stockQty: 30, isExempt: true },
        })
      ).json.article;

      // Draft PATCH on sales & purchase docs
      const draftSales = (
        await request('/api/commercial/sales-docs', {
          method: 'POST',
          headers: authHeaders,
          json: { docType: 'DEVIS', clientId: cli.id, lines: [{ articleId: art.id, qty: 1 }] },
        })
      ).json.doc;
      const patchedSales = await request(`/api/commercial/sales-docs/${draftSales.id}`, {
        method: 'PATCH',
        headers: authHeaders,
        json: { notes: 'Updated draft', lines: [{ articleId: art.id, qty: 2, unitPriceHtMru: 450 }] },
      });
      assert.equal(patchedSales.status, 200);
      assert.equal(patchedSales.json.doc.totalTtcMru, 900);

      const draftPurch = (
        await request('/api/commercial/purchase-docs', {
          method: 'POST',
          headers: authHeaders,
          json: { docType: 'COMMANDE_FOURNISSEUR', supplierId: sup.id, lines: [{ articleId: art.id, qty: 1, unitCostHtMru: 300 }] },
        })
      ).json.doc;
      const patchedPurch = await request(`/api/commercial/purchase-docs/${draftPurch.id}`, {
        method: 'PATCH',
        headers: authHeaders,
        json: { notes: 'Updated PO', lines: [{ articleId: art.id, qty: 3, unitCostHtMru: 300 }] },
      });
      assert.equal(patchedPurch.status, 200);
      assert.equal(patchedPurch.json.doc.totalHtMru, 900);

      // Unpaid FACTURE of 900 -> invoiceEncoursMru = 900
      const inv900 = (
        await request('/api/commercial/sales-docs', {
          method: 'POST',
          headers: authHeaders,
          json: { docType: 'FACTURE', clientId: cli.id, validateNow: true, lines: [{ articleId: art.id, qty: 2, unitPriceHtMru: 450 }] },
        })
      ).json.doc;

      // Open POS session & test tender validation + Karni encours limit + closed void guard
      const ses = (
        await request('/api/commercial/pos/sessions/open', {
          method: 'POST',
          headers: authHeaders,
          json: { registerCode: 'C1', openingFloatMru: 1000 },
        })
      ).json.session;

      for (const badPayload of [
        { payMethod: 'Mixte', lines: [{ articleId: art.id, qty: 1 }] },
        { payMethod: 'Chèque', lines: [{ articleId: art.id, qty: 1 }] },
        { payMethod: 'Traite', lines: [{ articleId: art.id, qty: 1 }] },
        { payMethod: 'Virement', lines: [{ articleId: art.id, qty: 1 }] },
        { payments: [{ method: 'Mixte', amountMru: 500 }], lines: [{ articleId: art.id, qty: 1 }] },
        { payments: [{ method: 'Virement', amountMru: 500 }], lines: [{ articleId: art.id, qty: 1 }] },
      ]) {
        assert.equal(
          (
            await request('/api/commercial/pos/tickets', {
              method: 'POST',
              headers: authHeaders,
              json: { sessionId: ses.id, ...badPayload },
            })
          ).status,
          400,
        );
      }

      // POS Karni 500 when invoiceEncoursMru=900 and creditLimit=1000 -> 900 + 500 > 1000 -> 400!
      const posKarniOver = await request('/api/commercial/pos/tickets', {
        method: 'POST',
        headers: authHeaders,
        json: { sessionId: ses.id, clientId: cli.id, payMethod: 'Karni', lines: [{ articleId: art.id, qty: 1 }] },
      });
      assert.equal(posKarniOver.status, 400);

      // Valid POS ticket with discountMru: 50 (500 - 50 = 450 HT/TTC)
      const posCash = await request('/api/commercial/pos/tickets', {
        method: 'POST',
        headers: authHeaders,
        json: { sessionId: ses.id, payMethod: 'Cash', discountMru: 50, lines: [{ articleId: art.id, qty: 1 }] },
      });
      assert.equal(posCash.status, 201);
      assert.equal(posCash.json.ticket.totalHtMru, 450);

      // Close session -> voiding ticket in CLOSED session returns 400 & Z-report stays consistent
      const closeRes = await request(`/api/commercial/pos/sessions/${ses.id}/close`, {
        method: 'POST',
        headers: authHeaders,
        json: { countedCashMru: 1450 },
      });
      assert.equal(closeRes.status, 200);
      assert.equal(closeRes.json.zReport.varianceMru, 0);

      const voidClosed = await request(`/api/commercial/pos/tickets/${posCash.json.ticket.id}/void`, {
        method: 'POST',
        headers: authHeaders,
        json: { reason: 'Post close' },
      });
      assert.equal(voidClosed.status, 400);
      const zAfter = await request(`/api/commercial/pos/sessions/${ses.id}/z-report`, { headers: authHeaders });
      assert.equal(zAfter.json.zReport.expectedCashMru, 1450);
      assert.equal(zAfter.json.zReport.varianceMru, 0);

      // Pay another 600 Karni invoice (raise limit first) & test karni-pay + AVOIR on Karni invoice
      await request(`/api/commercial/clients/${cli.id}`, {
        method: 'PATCH',
        headers: authHeaders,
        json: { creditLimitMru: 5000 },
      });
      const inv600 = (
        await request('/api/commercial/sales-docs', {
          method: 'POST',
          headers: authHeaders,
          json: { docType: 'FACTURE', clientId: cli.id, validateNow: true, lines: [{ articleId: art.id, qty: 1, unitPriceHtMru: 600 }] },
        })
      ).json.doc;
      await request(`/api/commercial/sales-docs/${inv600.id}/payments`, {
        method: 'POST',
        headers: authHeaders,
        json: { payMethod: 'Karni', amountMru: 600 },
      });

      // karni-pay NaN -> 400; valid karni-pay 200 -> karniDebtMru=400, encoursTtcMru = 900 + 400 = 1300
      assert.equal(
        (
          await request(`/api/commercial/clients/${cli.id}/karni-pay`, {
            method: 'POST',
            headers: authHeaders,
            json: { amountMru: 'abc' },
          })
        ).status,
        400,
      );
      const kpay = await request(`/api/commercial/clients/${cli.id}/karni-pay`, {
        method: 'POST',
        headers: authHeaders,
        json: { amountMru: 200, payMethod: 'Cash' },
      });
      assert.equal(kpay.status, 200);
      assert.equal(kpay.json.client.karniDebtMru, 400);
      assert.equal(kpay.json.client.invoiceEncoursMru, 900);
      assert.equal(kpay.json.client.encoursTtcMru, 1300);

      // Full AVOIR (600) on Karni-paid inv600 reduces remaining karniDebtMru (400 -> 0)
      const avKarni = await request('/api/commercial/sales-docs', {
        method: 'POST',
        headers: authHeaders,
        json: { docType: 'AVOIR', clientId: cli.id, sourceDocId: inv600.id, validateNow: true, lines: [{ articleId: art.id, qty: 1, unitPriceHtMru: 600 }] },
      });
      assert.equal(avKarni.status, 201);
      const cliList = (await request('/api/commercial/clients', { headers: authHeaders })).json.clients;
      const cliAfterAvoir = cliList.find((c) => c.id === cli.id);
      assert.equal(cliAfterAvoir.karniDebtMru, 0);
      assert.equal(cliAfterAvoir.encoursTtcMru, 900);

      // Delete standalone drafts (sales & purchase)
      assert.equal(
        (await request(`/api/commercial/sales-docs/${draftSales.id}`, { method: 'DELETE', headers: authHeaders })).status,
        200,
      );
      assert.equal(
        (await request(`/api/commercial/purchase-docs/${draftPurch.id}`, { method: 'DELETE', headers: authHeaders })).status,
        200,
      );

      // List GET endpoints
      assert.equal((await request(`/api/commercial/pos/tickets?sessionId=${ses.id}`, { headers: authHeaders })).json.tickets.length, 1);
      assert.equal((await request('/api/commercial/pos/sessions?status=CLOSED', { headers: authHeaders })).json.sessions.length, 1);
      assert.ok((await request('/api/commercial/treasury/movements', { headers: authHeaders })).json.movements.length >= 2);
      assert.equal((await request('/api/commercial/cheques', { headers: authHeaders })).status, 200);
      assert.equal((await request('/api/commercial/objectives', { headers: authHeaders })).status, 200);

      // Analytics payloads: summary.caHtMru = 900 + 600 + 450 - 600 = 1350; topArticles sums 900 + 600 + 450 = 1950 (with POS discountMru 50 applied!)
      const salesAn = await request('/api/commercial/analytics/sales?preset=this_year', { headers: authHeaders });
      assert.equal(salesAn.status, 200);
      assert.equal(salesAn.json.summary.caHtMru, 1350);
      assert.equal(salesAn.json.topArticles[0].caHtMru, 1950);
      assert.ok(salesAn.json.topClients.length >= 1);
      assert.ok(salesAn.json.byPaymentMethod.length >= 1);

      const psAn = await request('/api/commercial/analytics/purchases-stock?preset=this_year', { headers: authHeaders });
      assert.equal(psAn.status, 200);
      assert.ok(Array.isArray(psAn.json.stockByCategory));
      assert.ok(psAn.json.summary.totalSkus >= 1);

      const trAn = await request('/api/commercial/analytics/treasury?preset=this_year', { headers: authHeaders });
      assert.equal(trAn.status, 200);
      assert.equal(trAn.json.summary.netCashflowMru, 650); // 450 POS Cash + 200 Karni-pay
    });
  });
});
