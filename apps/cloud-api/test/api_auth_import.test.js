const { describe, it, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const http = require('node:http');
const crypto = require('node:crypto');
const zlib = require('node:zlib');

// Isolate module-load singleton DB away from apps/cloud-api/data/fulltek.db
const singletonTmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'fulltek-m2-singleton-'));
process.env.DB_PATH = path.join(singletonTmpDir, 'singleton.db');

const { db: singletonDb, createDb, hashPassword } = require('../src/db');
const { signJwt, verifyJwt } = require('../src/auth');
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
          resolve({
            status: res.statusCode,
            headers: res.headers,
            raw,
            text,
            json,
          });
        });
      },
    );

    req.on('error', reject);
    if (bodyBuf !== null) {
      req.write(bodyBuf);
    }
    req.end();
  });
}

async function withIsolatedServer(opts, fn) {
  if (typeof opts === 'function') {
    fn = opts;
    opts = {};
  }
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'fulltek-m2-srv-'));
  const dbPath = path.join(tmpDir, 'test.db');
  const jwtSecret = opts.jwtSecret || 'test-jwt-secret-m2';
  const srv = await startServer({
    port: 0,
    host: '127.0.0.1',
    dbPath,
    jwtSecret,
    maxBodyBytes: opts.maxBodyBytes,
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

async function loginAsSuperAdmin(request, creds = {}) {
  const res = await request('/api/admin/login', {
    method: 'POST',
    json: {
      username: creds.username ?? 'taha',
      password: creds.password ?? 'FullTekAdmin@2026',
    },
  });
  assert.equal(res.status, 200);
  return res.json.token;
}

function escapeXml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function colIndexToLetters(idx) {
  let n = idx + 1;
  let out = '';
  while (n > 0) {
    const rem = (n - 1) % 26;
    out = String.fromCharCode(65 + rem) + out;
    n = Math.floor((n - 1) / 26);
  }
  return out;
}

function buildZip(entries, { store = false } = {}) {
  const localParts = [];
  const centralParts = [];
  let offset = 0;

  for (const entry of entries) {
    const nameBuf = Buffer.from(entry.name, 'utf8');
    const uncompBuf = Buffer.isBuffer(entry.data) ? entry.data : Buffer.from(entry.data, 'utf8');
    const compBuf = store ? uncompBuf : zlib.deflateRawSync(uncompBuf);
    const method = store ? 0 : 8;
    const crc = zlib.crc32(uncompBuf) >>> 0;

    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(0x0800, 6);
    local.writeUInt16LE(method, 8);
    local.writeUInt16LE(0, 10);
    local.writeUInt16LE(0, 12);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(compBuf.length, 18);
    local.writeUInt32LE(uncompBuf.length, 22);
    local.writeUInt16LE(nameBuf.length, 26);
    local.writeUInt16LE(0, 28);

    localParts.push(local, nameBuf, compBuf);

    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4);
    central.writeUInt16LE(20, 6);
    central.writeUInt16LE(0x0800, 8);
    central.writeUInt16LE(method, 10);
    central.writeUInt16LE(0, 12);
    central.writeUInt16LE(0, 14);
    central.writeUInt32LE(crc, 16);
    central.writeUInt32LE(compBuf.length, 20);
    central.writeUInt32LE(uncompBuf.length, 24);
    central.writeUInt16LE(nameBuf.length, 28);
    central.writeUInt16LE(0, 30);
    central.writeUInt16LE(0, 32);
    central.writeUInt16LE(0, 34);
    central.writeUInt16LE(0, 36);
    central.writeUInt32LE(0, 38);
    central.writeUInt32LE(offset, 42);

    centralParts.push(central, nameBuf);
    offset += local.length + nameBuf.length + compBuf.length;
  }

  const centralBuf = Buffer.concat(centralParts);
  const eocd = Buffer.alloc(22);
  eocd.writeUInt32LE(0x06054b50, 0);
  eocd.writeUInt16LE(0, 4);
  eocd.writeUInt16LE(0, 6);
  eocd.writeUInt16LE(entries.length, 8);
  eocd.writeUInt16LE(entries.length, 10);
  eocd.writeUInt32LE(centralBuf.length, 12);
  eocd.writeUInt32LE(offset, 16);
  eocd.writeUInt16LE(0, 20);

  return Buffer.concat([...localParts, centralBuf, eocd]);
}

function buildXlsxBuffer(rows, { inlineStrings = false, store = false } = {}) {
  const sharedStrings = [];
  const sharedMap = new Map();
  const intern = (s) => {
    const key = String(s);
    if (!sharedMap.has(key)) {
      sharedMap.set(key, sharedStrings.length);
      sharedStrings.push(key);
    }
    return sharedMap.get(key);
  };

  const rowXmls = rows.map((row, rIdx) => {
    const cellsXml = [];
    for (let cIdx = 0; cIdx < row.length; cIdx++) {
      const val = row[cIdx];
      if (val === null || val === undefined) continue;
      const ref = `${colIndexToLetters(cIdx)}${rIdx + 1}`;
      if (typeof val === 'number') {
        cellsXml.push(`<c r="${ref}"><v>${val}</v></c>`);
      } else if (typeof val === 'boolean') {
        cellsXml.push(`<c r="${ref}" t="b"><v>${val ? 1 : 0}</v></c>`);
      } else if (inlineStrings) {
        cellsXml.push(`<c r="${ref}" t="inlineStr"><is><t xml:space="preserve">${escapeXml(val)}</t></is></c>`);
      } else {
        const sIdx = intern(val);
        cellsXml.push(`<c r="${ref}" t="s"><v>${sIdx}</v></c>`);
      }
    }
    return `<row r="${rIdx + 1}">${cellsXml.join('')}</row>`;
  });

  const sheetXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
    `<sheetData>${rowXmls.join('')}</sheetData>` +
    '</worksheet>';

  const entries = [
    {
      name: '[Content_Types].xml',
      data:
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
        '<Default Extension="xml" ContentType="application/xml"/>' +
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +
        (inlineStrings
          ? ''
          : '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>') +
        '</Types>',
    },
    {
      name: '_rels/.rels',
      data:
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
        '</Relationships>',
    },
    {
      name: 'xl/workbook.xml',
      data:
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' +
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
        '<sheets><sheet name="Catalog" sheetId="1" r:id="rId1"/></sheets>' +
        '</workbook>',
    },
    {
      name: 'xl/_rels/workbook.xml.rels',
      data:
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>' +
        '</Relationships>',
    },
    {
      name: 'xl/worksheets/sheet1.xml',
      data: sheetXml,
    },
  ];

  if (!inlineStrings) {
    const siXml = sharedStrings.map((s) => `<si><t xml:space="preserve">${escapeXml(s)}</t></si>`).join('');
    entries.push({
      name: 'xl/sharedStrings.xml',
      data:
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        `<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="${sharedStrings.length}" uniqueCount="${sharedStrings.length}">` +
        siXml +
        '</sst>',
    });
  }

  return buildZip(entries, { store });
}

describe('Suite 1 — Super-Admin JWT Auth & /api/admin/* Guard', () => {
  it('signJwt / verifyJwt handles roundtrip, wrong secret, tampered payload, alg=none, and expired exp', () => {
    const secret = 'unit-secret-123';
    const token = signJwt({ sub: 1, role: 'SUPER_ADMIN' }, 3600, secret);
    const ok = verifyJwt(token, secret);
    assert.equal(ok.valid, true);
    assert.equal(ok.payload.sub, 1);
    assert.equal(ok.payload.role, 'SUPER_ADMIN');
    assert.ok(ok.payload.exp > ok.payload.iat);

    assert.equal(verifyJwt(token, 'wrong-secret').reason, 'invalid_signature');

    const [hdr, pay, sig] = token.split('.');
    const tamperedPay = Buffer.from(JSON.stringify({ sub: 99, role: 'SUPER_ADMIN', exp: 9999999999 })).toString('base64url');
    assert.equal(verifyJwt(`${hdr}.${tamperedPay}.${sig}`, secret).reason, 'invalid_signature');

    const algNoneHdr = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
    assert.equal(verifyJwt(`${algNoneHdr}.${pay}.`, secret).reason, 'malformed_token');
    assert.equal(verifyJwt(`${algNoneHdr}.${pay}.fakesig`, secret).reason, 'unsupported_alg');

    const expired = signJwt({ sub: 1, role: 'SUPER_ADMIN' }, -10, secret);
    assert.equal(verifyJwt(expired, secret).reason, 'expired');
  });

  it('POST /api/admin/login & /api/admin/auth/login authenticate by username and email, and GET /api/admin/me returns profile', async () => {
    await withIsolatedServer(async ({ request, db, jwtSecret }) => {
      const loginUser = await request('/api/admin/login', {
        method: 'POST',
        json: { username: 'taha', password: 'FullTekAdmin@2026' },
      });
      assert.equal(loginUser.status, 200);
      assert.equal(loginUser.json.ok, true);
      assert.equal(loginUser.json.expiresIn, 86400);
      assert.equal(loginUser.json.admin.username, 'taha');
      assert.equal(loginUser.json.admin.role, 'SUPER_ADMIN');
      assert.equal(loginUser.json.admin.password_hash, undefined);

      const verified = verifyJwt(loginUser.json.token, jwtSecret);
      assert.equal(verified.valid, true);
      assert.equal(verified.payload.sub, loginUser.json.admin.id);
      assert.equal(verified.payload.id, loginUser.json.admin.id);

      const saRow = db.prepare('SELECT last_login_at FROM super_admins WHERE username = ?').get('taha');
      assert.ok(saRow.last_login_at);

      const loginEmail = await request('/api/admin/auth/login', {
        method: 'POST',
        json: { email: 'taha@fulltek.mr', password: 'FullTekAdmin@2026' },
      });
      assert.equal(loginEmail.status, 200);
      assert.ok(loginEmail.json.token);

      const meRes = await request('/api/admin/me', {
        headers: { Authorization: `Bearer ${loginEmail.json.token}` },
      });
      assert.equal(meRes.status, 200);
      assert.equal(meRes.json.ok, true);
      assert.equal(meRes.json.admin.username, 'taha');
      assert.equal(meRes.json.admin.email, 'taha@fulltek.mr');
    });
  });

  it('returns 400 on missing login fields and 401 on wrong password or unknown user', async () => {
    await withIsolatedServer(async ({ request }) => {
      const missing = await request('/api/admin/login', { method: 'POST', json: { username: 'taha' } });
      assert.equal(missing.status, 400);

      const badPw = await request('/api/admin/login', {
        method: 'POST',
        json: { username: 'taha', password: 'WrongPassword' },
      });
      assert.equal(badPw.status, 401);

      const unknown = await request('/api/admin/login', {
        method: 'POST',
        json: { username: 'ghost', password: 'FullTekAdmin@2026' },
      });
      assert.equal(unknown.status, 401);
    });
  });

  it('blocks all protected /api/admin/* routes with 401 on missing, malformed, expired, wrong-secret, inactive admin, or OWNER tokens', async () => {
    await withIsolatedServer(async ({ request, db, jwtSecret }) => {
      const token = await loginAsSuperAdmin(request);

      // Create a tenant and log in as tenant OWNER
      const tenantRes = await request('/api/admin/tenants', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: {
          name: 'Boutique Test Guard',
          phone: '22001122',
          username: 'owner_guard',
          accountPassword: 'OwnerPass@123',
        },
      });
      assert.equal(tenantRes.status, 201);

      const ownerLogin = await request('/api/auth/login', {
        method: 'POST',
        json: { username: 'owner_guard', password: 'OwnerPass@123' },
      });
      assert.equal(ownerLogin.status, 200);
      const ownerVerified = verifyJwt(ownerLogin.json.token, jwtSecret);
      assert.equal(ownerVerified.valid, true);
      assert.equal(ownerVerified.payload.role, 'OWNER');
      assert.ok(ownerVerified.payload.exp > ownerVerified.payload.iat);

      const expiredJwt = signJwt({ sub: 1, id: 1, role: 'SUPER_ADMIN' }, -60, jwtSecret);
      const wrongSecretJwt = signJwt({ sub: 1, id: 1, role: 'SUPER_ADMIN' }, 3600, 'different-secret');

      const protectedRoutes = [
        ['GET', '/api/admin/me'],
        ['GET', '/api/admin/dashboard'],
        ['POST', '/api/admin/tenants'],
        ['PATCH', `/api/admin/tenants/${tenantRes.json.id}`],
        ['POST', `/api/admin/tenants/${tenantRes.json.id}/extend`],
        ['POST', `/api/admin/tenants/${tenantRes.json.id}/toggle-lock`],
        ['POST', `/api/admin/tenants/${tenantRes.json.id}/offline-code`],
        ['POST', `/api/admin/tenants/${tenantRes.json.id}/support`],
        ['POST', '/api/admin/payments/P-100/approve'],
        ['POST', `/api/admin/tenants/${tenantRes.json.id}/catalog/import`],
        ['GET', `/api/admin/tenants/${tenantRes.json.id}/catalog`],
        ['GET', '/api/admin/unknown-route'],
      ];

      const badAuthHeaders = [
        {},
        { Authorization: 'Basic dGFoYTpwYXNz' },
        { Authorization: 'Bearer not-a-jwt' },
        { Authorization: `Bearer ${expiredJwt}` },
        { Authorization: `Bearer ${wrongSecretJwt}` },
        { Authorization: `Bearer ${ownerLogin.json.token}` },
      ];

      for (const [method, routePath] of protectedRoutes) {
        for (const hdrs of badAuthHeaders) {
          const r = await request(routePath, { method, headers: hdrs });
          assert.equal(r.status, 401, `Expected 401 for ${method} ${routePath} with headers ${JSON.stringify(hdrs)}`);
          assert.equal(r.headers['access-control-allow-origin'], '*');
        }
      }

      // Deactivated super_admin row must be rejected immediately
      db.prepare('UPDATE super_admins SET active = 0 WHERE username = ?').run('taha');
      const deactivatedRes = await request('/api/admin/me', {
        headers: { Authorization: `Bearer ${token}` },
      });
      assert.equal(deactivatedRes.status, 401);
    });
  });
});

describe('Suite 2 — Ed25519 Offline License Endpoints', () => {
  it('GET /api/licenses/public-key and POST /api/admin/tenants/:id/offline-code issue cryptographically verifiable Ed25519 tokens', async () => {
    await withIsolatedServer(async ({ request, db }) => {
      const token = await loginAsSuperAdmin(request);

      const pubRes = await request('/api/licenses/public-key');
      assert.equal(pubRes.status, 200);
      assert.equal(pubRes.json.ok, true);
      assert.equal(pubRes.json.algorithm, 'Ed25519');
      assert.ok(pubRes.json.publicKey.includes('BEGIN PUBLIC KEY'));

      const missingKeyRes = await request('/api/licenses/public-key?keyId=ed25519-nonexistent');
      assert.equal(missingKeyRes.status, 404);

      const tenant = db.prepare('SELECT id FROM tenants LIMIT 1').get();
      assert.ok(tenant);

      const issueRes = await request(`/api/admin/tenants/${tenant.id}/offline-code`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: { days: 45, graceDays: 5, registerCode: 'C1', hardwareFingerprint: 'HW-RIM-01' },
      });
      assert.equal(issueRes.status, 200);
      assert.equal(issueRes.json.ok, true);
      assert.equal(issueRes.json.days, 45);
      assert.equal(issueRes.json.graceDays, 5);
      assert.match(issueRes.json.code, /^\d{4}-\d{4}-\d{4}$/);

      // Independent Ed25519 signature check via node:crypto
      const [payloadB64, sigB64] = issueRes.json.leaseToken.split('.');
      assert.equal(sigB64, issueRes.json.signature);
      const sigValid = crypto.verify(
        null,
        Buffer.from(payloadB64, 'utf8'),
        issueRes.json.publicKey,
        Buffer.from(sigB64, 'base64url'),
      );
      assert.equal(sigValid, true);

      // Verify persistence in offline_lease_tokens, offline_codes, and audit_logs
      const leaseRow = db.prepare('SELECT * FROM offline_lease_tokens WHERE unlock_code = ?').get(issueRes.json.code);
      assert.ok(leaseRow);
      const codeRow = db.prepare('SELECT * FROM offline_codes WHERE code = ?').get(issueRes.json.code);
      assert.ok(codeRow);
      const auditRow = db
        .prepare("SELECT * FROM audit_logs WHERE action = 'OFFLINE_LICENSE_ISSUE' AND entity_id = ?")
        .get(issueRes.json.code);
      assert.ok(auditRow);

      // POST /api/licenses/verify valid & tampered & foreign key
      const verifyOk = await request('/api/licenses/verify', {
        method: 'POST',
        json: { leaseToken: issueRes.json.leaseToken, hardwareFingerprint: 'HW-RIM-01', registerCode: 'C1' },
      });
      assert.equal(verifyOk.status, 200);
      assert.equal(verifyOk.json.valid, true);

      const tamperedPayload = Buffer.from(
        JSON.stringify({ ...issueRes.json.payload, days: 9999 }),
      ).toString('base64url');
      const verifyTampered = await request('/api/licenses/verify', {
        method: 'POST',
        json: { leaseToken: `${tamperedPayload}.${sigB64}` },
      });
      assert.equal(verifyTampered.status, 200);
      assert.equal(verifyTampered.json.valid, false);
      assert.equal(verifyTampered.json.reason, 'invalid_signature');

      const foreignKey = crypto.generateKeyPairSync('ed25519', {
        publicKeyEncoding: { type: 'spki', format: 'pem' },
        privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
      });
      const verifyForeign = await request('/api/licenses/verify', {
        method: 'POST',
        json: { leaseToken: issueRes.json.leaseToken, publicKey: foreignKey.publicKey },
      });
      assert.equal(verifyForeign.status, 200);
      assert.equal(verifyForeign.json.valid, false);
      assert.equal(verifyForeign.json.reason, 'invalid_signature');
    });
  });

  it('handles unknown tenant (404), invalid days (400), and persists signing keypair across server restart', async () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'fulltek-m2-persist-'));
    const dbPath = path.join(tmpDir, 'persist.db');
    let keyId1;
    let pubKey1;
    let leaseToken;

    try {
      const srv1 = await startServer({ port: 0, host: '127.0.0.1', dbPath, jwtSecret: 's1', quiet: true });
      try {
        const req1 = (p, o) => httpRequest(srv1.url, p, o);
        const token1 = await loginAsSuperAdmin(req1);

        const notFound = await req1('/api/admin/tenants/999999/offline-code', {
          method: 'POST',
          headers: { Authorization: `Bearer ${token1}` },
          json: { days: 30 },
        });
        assert.equal(notFound.status, 404);

        const badDays = await req1('/api/admin/tenants/1/offline-code', {
          method: 'POST',
          headers: { Authorization: `Bearer ${token1}` },
          json: { days: -5 },
        });
        assert.equal(badDays.status, 400);

        const issued = await req1('/api/admin/tenants/1/offline-code', {
          method: 'POST',
          headers: { Authorization: `Bearer ${token1}` },
          json: {},
        });
        assert.equal(issued.status, 200);
        keyId1 = issued.json.keyId;
        pubKey1 = issued.json.publicKey;
        leaseToken = issued.json.leaseToken;
      } finally {
        await srv1.close();
      }

      const srv2 = await startServer({ port: 0, host: '127.0.0.1', dbPath, jwtSecret: 's1', quiet: true });
      try {
        const req2 = (p, o) => httpRequest(srv2.url, p, o);
        const pub2 = await req2('/api/licenses/public-key');
        assert.equal(pub2.status, 200);
        assert.equal(pub2.json.keyId, keyId1);
        assert.equal(pub2.json.publicKey, pubKey1);

        const ver2 = await req2('/api/licenses/verify', {
          method: 'POST',
          json: { leaseToken },
        });
        assert.equal(ver2.status, 200);
        assert.equal(ver2.json.valid, true);
      } finally {
        await srv2.close();
      }
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true, maxRetries: 10, retryDelay: 50 });
    }
  });
});

describe('Suite 3 — 1-Click Catalog CSV / Native .xlsx Import & Readback', () => {
  it('imports CSV (JSON csvText + raw text/csv + UTF-8 BOM/semicolon/Arabic/quoted commas) and reads back catalog', async () => {
    await withIsolatedServer(async ({ request, db }) => {
      const token = await loginAsSuperAdmin(request);
      const tRes = await request('/api/admin/tenants', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: { name: 'Supermarché Nouakchott', phone: '22334455', username: 'nktt_cat', accountPassword: 'pw' },
      });
      const tenantId = tRes.json.id;

      // 1. JSON csvText with quoted commas, BOM, CRLF, and Arabic
      const csvBom =
        '\uFEFFsku;barcode;name_fr;name_ar;category;category_ar;price_retail;price_whole;price_cost;track_fefo;requires_cnam\r\n' +
        'SKU-01;6130001110001;"Couscous, Royal ""Spécial""";كسكس ملكي;"Plats, Chauds";أطباق ساخنة;450;400;250;true;false\r\n' +
        'SKU-02;6130001110002;Thé Ataya;شاي أتاي;Boissons;مشروبات;150;120;80;0;0\r\n';

      const imp1 = await request(`/api/admin/tenants/${tenantId}/catalog/import`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: { filename: 'catalog.csv', format: 'csv', csvText: csvBom },
      });
      assert.equal(imp1.status, 200);
      assert.equal(imp1.json.ok, true);
      assert.equal(imp1.json.format, 'csv');
      assert.equal(imp1.json.totalRows, 2);
      assert.equal(imp1.json.created, 2);
      assert.equal(imp1.json.updated, 0);
      assert.equal(imp1.json.categoriesCreated, 2);

      // 2. Barcode-only update via raw text/csv must preserve existing sku SKU-02!
      const rawCsvUpdate = 'sku,barcode,name_fr,price_retail\n,6130001110002,Thé Ataya Premium,180\n';
      const imp2 = await request(`/api/admin/tenants/${tenantId}/catalog/import`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'text/csv; charset=utf-8',
        },
        body: rawCsvUpdate,
      });
      assert.equal(imp2.status, 200);
      assert.equal(imp2.json.created, 0);
      assert.equal(imp2.json.updated, 1);

      const catRes = await request(`/api/admin/tenants/${tenantId}/catalog`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      assert.equal(catRes.status, 200);
      assert.equal(catRes.json.categories.length, 2);
      assert.equal(catRes.json.products.length, 2);

      const prod1 = catRes.json.products.find((p) => p.sku === 'SKU-01');
      assert.equal(prod1.name_fr, 'Couscous, Royal "Spécial"');
      assert.equal(prod1.name_ar, 'كسكس ملكي');
      assert.equal(prod1.track_fefo, 1);
      assert.equal(prod1.requires_cnam, 0);

      const prod2 = catRes.json.products.find((p) => p.barcode === '6130001110002');
      assert.equal(prod2.sku, 'SKU-02');
      assert.equal(prod2.name_fr, 'Thé Ataya Premium');
      assert.equal(prod2.price_retail, 180);

      const auditRows = db
        .prepare("SELECT * FROM audit_logs WHERE tenant_id = ? AND action = 'CATALOG_IMPORT'")
        .all(tenantId);
      assert.equal(auditRows.length, 2);
    });
  });

  it('imports native .xlsx (sharedStrings & inlineStr + sparse cells + pharmacy stock_batches) via base64 and raw binary', async () => {
    await withIsolatedServer(async ({ request, db }) => {
      const token = await loginAsSuperAdmin(request);
      const tRes = await request('/api/admin/tenants', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: { name: 'Pharmacie Chinguetti', module: 'pharma', phone: '22778899', username: 'pharma_cat', accountPassword: 'pw' },
      });
      const tenantId = tRes.json.id;

      // 1. Native .xlsx with sharedStrings & pharmacy lot_number / qty / expires_at
      const xlsxBuf = buildXlsxBuffer([
        ['sku', 'nom', 'nom_ar', 'categorie', 'prix_vente', 'fefo', 'cnam', 'lot_number', 'qty', 'expires_at'],
        ['PH-100', 'Doliprane 1000mg', 'دوليبران', 'Antalgiques', 250, true, true, 'LOT-2027A', 50, '2027-06-30'],
      ]);
      const impXlsx = await request(`/api/admin/tenants/${tenantId}/catalog/import`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: { filename: 'pharma.xlsx', format: 'xlsx', contentBase64: xlsxBuf.toString('base64') },
      });
      assert.equal(impXlsx.status, 200);
      assert.equal(impXlsx.json.format, 'xlsx');
      assert.equal(impXlsx.json.created, 1);

      const batch = db
        .prepare('SELECT * FROM stock_batches WHERE tenant_id = ? AND lot_number = ?')
        .get(tenantId, 'LOT-2027A');
      assert.ok(batch);
      assert.equal(batch.qty, 50);
      assert.equal(batch.expires_at, '2027-06-30');

      // 2. Raw binary .xlsx with inlineStr + sparse cell (null category must leave category_id null)
      const sparseXlsx = buildXlsxBuffer(
        [
          ['sku', 'category', 'name_fr', 'price_retail'],
          ['PH-200', null, 'Sérum Physiologique', 90],
        ],
        { inlineStrings: true, store: true },
      );
      const impRaw = await request(`/api/admin/tenants/${tenantId}/catalog/import`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        },
        body: sparseXlsx,
      });
      assert.equal(impRaw.status, 200);
      assert.equal(impRaw.json.format, 'xlsx');
      assert.equal(impRaw.json.created, 1);

      const sparseProd = db
        .prepare('SELECT * FROM products WHERE tenant_id = ? AND sku = ?')
        .get(tenantId, 'PH-200');
      assert.ok(sparseProd);
      assert.equal(sparseProd.name_fr, 'Sérum Physiologique');
      assert.equal(sparseProd.price_retail, 90);
      assert.equal(sparseProd.category_id, null);
    });
  });

  it('enforces atomic rollback and clean 400/404 responses on invalid CSV, corrupt .xlsx, and unknown tenant', async () => {
    await withIsolatedServer(async ({ request, db }) => {
      const token = await loginAsSuperAdmin(request);
      const tRes = await request('/api/admin/tenants', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: { name: 'Rollback Test', phone: '22009988', username: 'rb_user', accountPassword: 'pw' },
      });
      const tenantId = tRes.json.id;

      // Mid-file validation failure must roll back row 1 & category & audit log
      const badCsv = 'sku,name_fr,category,price_retail\nRB-1,Valid Product,CatRollback,100\nRB-2,Bad Price,CatRollback,-25\n';
      const failRes = await request(`/api/admin/tenants/${tenantId}/catalog/import`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: { filename: 'bad.csv', format: 'csv', csvText: badCsv },
      });
      assert.equal(failRes.status, 400);
      assert.ok(Array.isArray(failRes.json.errors) && failRes.json.errors.length >= 1);
      assert.equal(db.prepare('SELECT COUNT(*) AS c FROM products WHERE tenant_id = ?').get(tenantId).c, 0);
      assert.equal(db.prepare('SELECT COUNT(*) AS c FROM categories WHERE tenant_id = ?').get(tenantId).c, 0);
      assert.equal(
        db.prepare("SELECT COUNT(*) AS c FROM audit_logs WHERE tenant_id = ? AND action = 'CATALOG_IMPORT'").get(tenantId).c,
        0,
      );

      // Missing required headers -> 400
      const missingHdr = await request(`/api/admin/tenants/${tenantId}/catalog/import`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'text/csv' },
        body: 'sku,category\nA1,Cat\n',
      });
      assert.equal(missingHdr.status, 400);

      // Corrupt .xlsx variants -> 400 (never 500!)
      const validXlsx = buildXlsxBuffer([['name_fr', 'price_retail'], ['Item', 100]]);
      const badMagic = Buffer.from(validXlsx);
      badMagic.write('BAD!', 0, 'ascii');
      const truncated = validXlsx.subarray(0, Math.floor(validXlsx.length * 0.35));
      const missingSheetZip = buildZip([
        { name: 'xl/workbook.xml', data: '<workbook><sheets><sheet name="S1" sheetId="1" r:id="rId1"/></sheets></workbook>' },
        { name: 'xl/_rels/workbook.xml.rels', data: '<Relationships/>' },
      ]);

      for (const badBuf of [Buffer.from('NOT_A_ZIP_XLSX'), badMagic, truncated, missingSheetZip]) {
        const res = await request(`/api/admin/tenants/${tenantId}/catalog/import`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          },
          body: badBuf,
        });
        assert.equal(res.status, 400);
      }

      // Unknown tenant -> 404
      const unknownPost = await request('/api/admin/tenants/999999/catalog/import', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'text/csv' },
        body: 'name_fr,price_retail\nTest,100\n',
      });
      assert.equal(unknownPost.status, 404);

      const unknownGet = await request('/api/admin/tenants/999999/catalog', {
        headers: { Authorization: `Bearer ${token}` },
      });
      assert.equal(unknownGet.status, 404);
    });
  });
});

describe('Suite 4 — Baseline Endpoints, CORS, Body Limits & Isolation', () => {
  it('supports OPTIONS CORS preflight, GET /health dbPath, malformed JSON 400, payload limit 413, and preserves baseline tenant routes without auto-seeding BR-01', async () => {
    await withIsolatedServer({ maxBodyBytes: 4096 }, async ({ request, dbPath, db }) => {
      const opt = await request('/api/admin/dashboard', { method: 'OPTIONS' });
      assert.equal(opt.status, 204);
      assert.equal(opt.headers['access-control-allow-origin'], '*');

      const health = await request('/health');
      assert.equal(health.status, 200);
      assert.equal(health.json.ok, true);
      assert.equal(health.json.dbPath, dbPath);

      const badJson = await request('/api/admin/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: '{invalid json',
      });
      assert.equal(badJson.status, 400);

      const tooBig = await request('/api/admin/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: 'taha', password: 'x'.repeat(5000) }),
      });
      assert.equal(tooBig.status, 413);

      const token = await loginAsSuperAdmin(request);
      const createRes = await request('/api/admin/tenants', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: {
          name: 'Resto Baseline',
          phone: '22112233',
          username: 'resto_base',
          accountPassword: 'pw',
          initialPayMethod: 'Bankily',
          initialPayRef: 'BK-99',
        },
      });
      assert.equal(createRes.status, 201);
      const tid = createRes.json.id;

      // Must NOT auto-seed branches BR-01 or pos_registers C1
      assert.equal(db.prepare('SELECT COUNT(*) AS c FROM branches WHERE tenant_id = ?').get(tid).c, 0);
      assert.equal(db.prepare('SELECT COUNT(*) AS c FROM pos_registers WHERE tenant_id = ?').get(tid).c, 0);

      const patchRes = await request(`/api/admin/tenants/${tid}`, {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${token}` },
        json: { city: 'Ksar' },
      });
      assert.equal(patchRes.status, 200);
      assert.equal(patchRes.json.city, 'Ksar');

      const extRes = await request(`/api/admin/tenants/${tid}/extend`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        json: { days: 15 },
      });
      assert.equal(extRes.status, 200);
      assert.equal(extRes.json.daysLeft, 45);

      const lockRes = await request(`/api/admin/tenants/${tid}/toggle-lock`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
      });
      assert.equal(lockRes.status, 200);
      assert.equal(lockRes.json.status, 'locked');

      const supRes = await request(`/api/admin/tenants/${tid}/support`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
      });
      assert.equal(supRes.status, 200);
      assert.equal(supRes.json.ok, true);

      // Insert pending payment and approve it
      db.prepare(`
        INSERT INTO saas_payments (pay_code, tenant_id, method, ref, amount, status, time_label)
        VALUES ('PAY-M2-1', ?, 'Masrivi', 'MS-123', 3000, 'pending', '10:00')
      `).run(tid);
      const appRes = await request('/api/admin/payments/PAY-M2-1/approve', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
      });
      assert.equal(appRes.status, 200);
      assert.equal(appRes.json.ok, true);
    });
  });
});
