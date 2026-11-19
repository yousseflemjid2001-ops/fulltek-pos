const http = require('node:http');
const {
  createDb,
  db: singletonDb,
  DEFAULT_DB_PATH,
  hashPassword,
  verifyPassword,
} = require('./db');
const {
  getPublicKey,
  issueOfflineLicense,
  verifyOfflineLicense,
} = require('./license');
const {
  DEFAULT_JWT_SECRET,
  DEFAULT_EXPIRES_IN_SEC,
  signJwt,
  verifyJwt,
  extractBearerToken,
  authenticateSuperAdmin,
  requireSuperAdmin,
} = require('./auth');
const { importCatalog } = require('./catalogImport');

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,POST,PATCH,DELETE,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
};

function nowHM() {
  const d = new Date();
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

function createHttpError(statusCode, message, extra = {}) {
  const err = new Error(message);
  err.statusCode = statusCode;
  Object.assign(err, extra);
  return err;
}

function parseJson(raw, fallback = []) {
  try {
    const v = JSON.parse(raw);
    return Array.isArray(v) ? v : fallback;
  } catch {
    return fallback;
  }
}

function serializeTenant(r) {
  return {
    id: r.id,
    tenantId: r.tenant_code,
    name: r.name,
    module: r.module,
    subType: r.sub_type,
    city: r.city,
    district: r.district,
    address: r.address,
    legalName: r.legal_name,
    nif: r.nif,
    rc: r.rc,
    phone: r.phone,
    email: r.email,
    manager: r.manager,
    defaultLang: r.default_lang,
    plan: r.plan,
    billing: r.billing,
    mrr: r.mrr,
    tills: r.tills,
    daysLeft: r.days_left,
    status: r.status,
    online: Boolean(r.online),
    pendingSync: r.pending_sync,
    enabledThemes: parseJson(r.enabled_themes, ['01', '06', '07', '11']),
    features: parseJson(r.features),
    payMethods: parseJson(r.pay_methods),
    hardware: parseJson(r.hardware),
    notes: r.notes,
    username: r.username,
    accountPassword: r.account_password,
    ownerPin: r.owner_pin,
    initialPayMethod: r.initial_pay_method,
    initialPayRef: r.initial_pay_ref,
    initialOfflineCode: r.initial_offline_code,
  };
}

function sendJson(res, status, data) {
  const body = JSON.stringify(data);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    ...CORS_HEADERS,
  });
  res.end(body);
}

function readRawBody(req, limitBytes) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let totalBytes = 0;
    let settled = false;

    const fail = (err) => {
      if (settled) return;
      settled = true;
      chunks.length = 0;
      reject(err);
    };

    req.on('data', (chunk) => {
      if (settled) return;
      const buf = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
      totalBytes += buf.length;
      if (totalBytes > limitBytes) {
        fail(createHttpError(413, 'Payload too large'));
        req.resume();
        return;
      }
      chunks.push(buf);
    });

    req.on('end', () => {
      if (settled) return;
      settled = true;
      resolve(Buffer.concat(chunks));
    });

    req.on('error', (err) => {
      fail(err);
    });

    req.on('aborted', () => {
      fail(createHttpError(400, 'Request aborted'));
    });
  });
}

function parseJsonBuffer(buf) {
  if (!buf || buf.length === 0) return {};
  const text = buf.toString('utf8').trim();
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch {
    throw createHttpError(400, 'Invalid JSON');
  }
}

async function readJsonBody(req, limitBytes) {
  const raw = await readRawBody(req, limitBytes);
  return parseJsonBuffer(raw);
}

function peekLeaseKeyId(leaseToken) {
  if (typeof leaseToken !== 'string') return null;
  const parts = leaseToken.trim().split('.');
  if (parts.length !== 2 || !parts[0]) return null;
  try {
    const payload = JSON.parse(Buffer.from(parts[0], 'base64url').toString('utf8'));
    if (payload && typeof payload.keyId === 'string' && payload.keyId.trim() !== '') {
      return payload.keyId.trim();
    }
  } catch {
    return null;
  }
  return null;
}

function resolveDatabase(options = {}) {
  if (options.db) {
    return {
      database: options.db,
      dbPath: options.dbPath || options.db.dbPath || DEFAULT_DB_PATH,
      ownsDb: false,
    };
  }

  const resolvedDbPath =
    options.dbPath ||
    process.env.DB_PATH ||
    process.env.FULLTEK_DB_PATH ||
    DEFAULT_DB_PATH;

  if (
    !options.dbPath &&
    singletonDb &&
    singletonDb.isOpen !== false &&
    resolvedDbPath === singletonDb.dbPath
  ) {
    return {
      database: singletonDb,
      dbPath: resolvedDbPath,
      ownsDb: false,
    };
  }

  return {
    database: createDb(resolvedDbPath),
    dbPath: resolvedDbPath,
    ownsDb: true,
  };
}

function createApp(options = {}) {
  const { database, dbPath, ownsDb } = resolveDatabase(options);
  const effectiveJwtSecret =
    options.jwtSecret !== undefined
      ? options.jwtSecret
      : (process.env.JWT_SECRET || DEFAULT_JWT_SECRET);
  const standardLimit =
    options.maxBodyBytes !== undefined ? Number(options.maxBodyBytes) : 1 * 1024 * 1024;
  const catalogLimit =
    options.maxBodyBytes !== undefined ? Number(options.maxBodyBytes) : 10 * 1024 * 1024;

  let dbClosed = false;
  const closeDb = () => {
    if (!ownsDb || dbClosed) return;
    dbClosed = true;
    try {
      database.close();
    } catch {
      // ignore close errors
    }
  };

  const handler = async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.writeHead(204, CORS_HEADERS);
      return res.end();
    }

    const url = new URL(req.url || '/', 'http://localhost');
    const p = url.pathname;

    try {
      // 1. Health check (Public)
      if (req.method === 'GET' && p === '/health') {
        const { cnt } = database.prepare('SELECT COUNT(*) AS cnt FROM tenants').get();
        return sendJson(res, 200, {
          ok: true,
          service: 'fulltek-cloud-api',
          dbPath,
          tenants: cnt,
        });
      }

      // 2. Tenant Owner Login (Public)
      if (req.method === 'POST' && p === '/api/auth/login') {
        const parsed = await readJsonBody(req, standardLimit);
        const b = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        const row = database
          .prepare('SELECT * FROM tenants WHERE username = ?')
          .get(String(b.username || ''));
        if (!row || !verifyPassword(b.password, row.password_hash)) {
          return sendJson(res, 401, { error: 'Identifiant ou mot de passe incorrect' });
        }
        const token = signJwt(
          {
            tenantId: row.id,
            tenantCode: row.tenant_code,
            module: row.module,
            role: 'OWNER',
          },
          DEFAULT_EXPIRES_IN_SEC,
          effectiveJwtSecret,
        );
        return sendJson(res, 200, { token, tenant: serializeTenant(row) });
      }

      // 2b. POS Offline-First SyncQueue Endpoint (Tenant JWT protected)
      if (req.method === 'POST' && p === '/api/pos/sync') {
        const token = extractBearerToken(req);
        if (!token) {
          return sendJson(res, 401, { error: 'Missing Bearer token' });
        }
        const verified = verifyJwt(token, effectiveJwtSecret);
        if (!verified.valid || !verified.payload.tenantId) {
          return sendJson(res, 401, { error: 'Invalid or expired POS token' });
        }
        const parsed = await readJsonBody(req, standardLimit);
        const items = parsed && Array.isArray(parsed.items) ? parsed.items : null;
        if (!items) {
          return sendJson(res, 400, { error: 'items array is required' });
        }
        const tenantId = verified.payload.tenantId;
        const insertAudit = database.prepare(
          'INSERT INTO audit_logs (tenant_id, action, details, created_at) VALUES (?, ?, ?, ?)',
        );
        const nowIso = new Date().toISOString();
        database.exec('BEGIN');
        try {
          for (const item of items) {
            const entityType = String(item?.entity_type || 'event').slice(0, 40);
            insertAudit.run(
              tenantId,
              `POS_SYNC_${entityType.toUpperCase()}`,
              JSON.stringify(item?.payload || {}),
              nowIso,
            );
          }
          database.exec('COMMIT');
        } catch (err) {
          database.exec('ROLLBACK');
          throw err;
        }
        return sendJson(res, 200, {
          ok: true,
          tenantId,
          synced: items.length,
          syncedAt: nowIso,
        });
      }

      // 3. Public Ed25519 License Key & Verification Endpoints
      if (req.method === 'GET' && p === '/api/licenses/public-key') {
        const keyId = url.searchParams.get('keyId');
        const pub = getPublicKey(database, keyId);
        if (!pub) {
          return sendJson(res, 404, { error: 'Signing key not found' });
        }
        return sendJson(res, 200, {
          ok: true,
          keyId: pub.keyId,
          algorithm: pub.algorithm,
          publicKey: pub.publicKey,
        });
      }

      if (req.method === 'POST' && p === '/api/licenses/verify') {
        const parsed = await readJsonBody(req, standardLimit);
        const b = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        const leaseToken = b.leaseToken;
        let publicKeyPem;
        if (b.publicKey !== undefined && b.publicKey !== null) {
          publicKeyPem = b.publicKey;
        } else {
          const peekedKeyId = peekLeaseKeyId(leaseToken);
          const pub = (peekedKeyId ? getPublicKey(database, peekedKeyId) : null) || getPublicKey(database);
          publicKeyPem = pub ? pub.publicKey : '';
        }
        const result = verifyOfflineLicense(leaseToken, publicKeyPem, {
          now: b.now,
          lastVerifiedAt: b.lastVerifiedAt,
          allowGrace: b.allowGrace,
          requireHardwareMatch: b.requireHardwareMatch,
          hardwareFingerprint: b.hardwareFingerprint,
          registerCode: b.registerCode,
        });
        return sendJson(res, 200, result);
      }

      // 4. Super-Admin JWT Login Endpoints (Unprotected)
      if (req.method === 'POST' && (p === '/api/admin/login' || p === '/api/admin/auth/login')) {
        const parsed = await readJsonBody(req, standardLimit);
        const b = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        const identifier =
          typeof b.username === 'string' && b.username.trim() !== ''
            ? b.username
            : b.email;
        const result = authenticateSuperAdmin(database, identifier, b.password, {
          jwtSecret: effectiveJwtSecret,
          ipAddress: req.socket?.remoteAddress || '',
        });
        if (!result.ok) {
          return sendJson(res, result.status, { error: result.error });
        }
        return sendJson(res, 200, {
          ok: true,
          token: result.token,
          expiresIn: result.expiresIn,
          admin: result.admin,
        });
      }

      // 5. Centralized Super-Admin Auth Guard for ALL /api/admin/* routes
      let currentAdmin = null;
      if (p === '/api/admin' || p.startsWith('/api/admin/')) {
        currentAdmin = requireSuperAdmin(req, res, database, {
          jwtSecret: effectiveJwtSecret,
          sendJson,
        });
        if (!currentAdmin) return;
      }

      // 6. Super-Admin Session Profile
      if (req.method === 'GET' && p === '/api/admin/me') {
        return sendJson(res, 200, {
          ok: true,
          admin: {
            id: currentAdmin.id,
            username: currentAdmin.username,
            email: currentAdmin.email,
            fullName: currentAdmin.fullName,
            role: currentAdmin.role,
          },
        });
      }

      // 7. Super-Admin Dashboard
      if (req.method === 'GET' && p === '/api/admin/dashboard') {
        const tenants = database.prepare('SELECT * FROM tenants ORDER BY id DESC').all().map(serializeTenant);
        const payments = database.prepare(`
          SELECT p.pay_code AS id, p.tenant_id AS storeId, t.name AS storeName,
                 p.method, p.ref, p.amount, p.time_label AS time
          FROM saas_payments p
          JOIN tenants t ON t.id = p.tenant_id
          WHERE p.status = 'pending'
          ORDER BY p.id DESC
        `).all();
        const audits = database.prepare(`
          SELECT id, title, subtitle, time_label AS time
          FROM audit_logs ORDER BY id DESC LIMIT 50
        `).all();
        return sendJson(res, 200, { stores: tenants, payments, audits });
      }

      // 8. Create Tenant
      if (req.method === 'POST' && p === '/api/admin/tenants') {
        const parsed = await readJsonBody(req, standardLimit);
        const b = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        if (!b.name || !b.phone || !b.username || !b.accountPassword) {
          return sendJson(res, 400, { error: 'name, phone, username and accountPassword are required' });
        }
        const pwHash = hashPassword(b.accountPassword);
        const tenantCode = b.tenantId || `FT-${1000 + Math.floor(Math.random() * 9000)}`;
        const info = database.prepare(`
          INSERT INTO tenants (
            tenant_code, name, module, sub_type, city, district, address, legal_name,
            nif, rc, phone, email, manager, default_lang, plan, billing, mrr, tills,
            days_left, status, enabled_themes, features, pay_methods, hardware, notes,
            username, password_hash, account_password, owner_pin,
            initial_pay_method, initial_pay_ref, initial_offline_code
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(
          tenantCode, b.name, b.module || 'resto', b.subType || '', b.city || 'Tevragh Zeina',
          b.district || '', b.address || '', b.legalName || '', b.nif || '', b.rc || '',
          b.phone, b.email || '', b.manager || '', b.defaultLang || 'fr',
          b.plan || 'Pro', b.billing || 'monthly', Number(b.mrr ?? 3000), Number(b.tills ?? 1),
          Number(b.daysLeft ?? 30), b.status || 'active',
          JSON.stringify(b.enabledThemes || ['01', '06', '07', '11']),
          JSON.stringify(b.features || []),
          JSON.stringify(b.payMethods || ['Bankily', 'Masrivi', 'Sedad', 'Cash']),
          JSON.stringify(b.hardware || []),
          b.notes || '', b.username, pwHash, String(b.accountPassword), String(b.ownerPin || '4242'),
          b.initialPayMethod || '', b.initialPayRef || '', b.initialOfflineCode || '',
        );
        const id = Number(info.lastInsertRowid);
        database.prepare(`
          INSERT INTO users (tenant_id, full_name, username, pass_hash, pin_code, role)
          VALUES (?, ?, ?, ?, ?, 'OWNER')
        `).run(id, b.manager || b.name, b.username, pwHash, String(b.ownerPin || '4242'));

        if (b.initialPayMethod) {
          database.prepare(`
            INSERT INTO saas_payments (pay_code, tenant_id, method, ref, amount, status, time_label)
            VALUES (?, ?, ?, ?, ?, 'approved', ?)
          `).run(`P-${Date.now().toString().slice(-5)}`, id, b.initialPayMethod, b.initialPayRef || 'INITIAL', Number(b.mrr ?? 0), nowHM());
        }

        database.prepare(`
          INSERT INTO audit_logs (tenant_id, actor, title, subtitle, time_label) VALUES (?, ?, ?, ?, ?)
        `).run(
          id,
          currentAdmin.fullName || currentAdmin.username,
          `Nouveau client · ${b.name}`,
          `Full·Tek ${b.module || 'resto'} · ${tenantCode} · ${Number(b.tills ?? 1)} caisses`,
          nowHM(),
        );

        const created = database.prepare('SELECT * FROM tenants WHERE id = ?').get(id);
        return sendJson(res, 201, serializeTenant(created));
      }

      let m;

      // 9. Update Tenant
      if (req.method === 'PATCH' && (m = p.match(/^\/api\/admin\/tenants\/(\d+)$/))) {
        const id = Number(m[1]);
        const cur = database.prepare('SELECT * FROM tenants WHERE id = ?').get(id);
        if (!cur) return sendJson(res, 404, { error: 'Not found' });
        const parsed = await readJsonBody(req, standardLimit);
        const b = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};

        const newPw = b.accountPassword && String(b.accountPassword).trim() !== ''
          ? String(b.accountPassword).trim()
          : cur.account_password;
        const newHash = b.accountPassword && String(b.accountPassword).trim() !== ''
          ? hashPassword(newPw)
          : cur.password_hash;

        database.prepare(`
          UPDATE tenants SET
            name = ?, manager = ?, phone = ?, city = ?, district = ?, nif = ?, rc = ?,
            notes = ?, username = ?, account_password = ?, password_hash = ?, owner_pin = ?,
            tills = ?, enabled_themes = ?, updated_at = CURRENT_TIMESTAMP
          WHERE id = ?
        `).run(
          b.name ?? cur.name,
          b.manager ?? cur.manager,
          b.phone ?? cur.phone,
          b.city ?? cur.city,
          b.district ?? cur.district,
          b.nif ?? cur.nif,
          b.rc ?? cur.rc,
          b.notes ?? cur.notes,
          b.username ?? cur.username,
          newPw,
          newHash,
          b.ownerPin ?? cur.owner_pin,
          b.tills !== undefined ? Number(b.tills) : cur.tills,
          b.enabledThemes !== undefined ? JSON.stringify(b.enabledThemes) : cur.enabled_themes,
          id,
        );
        database.prepare('INSERT INTO audit_logs (tenant_id, actor, title, subtitle, time_label) VALUES (?, ?, ?, ?, ?)')
          .run(id, currentAdmin.fullName || currentAdmin.username, `Modification · ${b.name ?? cur.name}`, 'M. Taha · Fiche client mise à jour', nowHM());
        const updated = database.prepare('SELECT * FROM tenants WHERE id = ?').get(id);
        return sendJson(res, 200, serializeTenant(updated));
      }

      // 10. Extend Tenant License
      if (req.method === 'POST' && (m = p.match(/^\/api\/admin\/tenants\/(\d+)\/extend$/))) {
        const id = Number(m[1]);
        const cur = database.prepare('SELECT * FROM tenants WHERE id = ?').get(id);
        if (!cur) return sendJson(res, 404, { error: 'Not found' });
        const parsed = await readJsonBody(req, standardLimit);
        const b = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        const days = Number(b.days || 30);
        database.prepare("UPDATE tenants SET days_left = ?, status = 'active', updated_at = CURRENT_TIMESTAMP WHERE id = ?")
          .run(cur.days_left + days, id);
        database.prepare('INSERT INTO audit_logs (tenant_id, actor, title, subtitle, time_label) VALUES (?, ?, ?, ?, ?)')
          .run(id, currentAdmin.fullName || currentAdmin.username, `Licence +${days}j · ${cur.name}`, 'M. Taha · Prolongation Cloud', nowHM());
        return sendJson(res, 200, serializeTenant(database.prepare('SELECT * FROM tenants WHERE id = ?').get(id)));
      }

      // 11. Toggle Tenant Lock
      if (req.method === 'POST' && (m = p.match(/^\/api\/admin\/tenants\/(\d+)\/toggle-lock$/))) {
        const id = Number(m[1]);
        const cur = database.prepare('SELECT * FROM tenants WHERE id = ?').get(id);
        if (!cur) return sendJson(res, 404, { error: 'Not found' });
        await readRawBody(req, standardLimit);
        const nextStatus = cur.status === 'locked' ? (cur.days_left > 5 ? 'active' : 'warn') : 'locked';
        database.prepare('UPDATE tenants SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(nextStatus, id);
        database.prepare('INSERT INTO audit_logs (tenant_id, actor, title, subtitle, time_label) VALUES (?, ?, ?, ?, ?)')
          .run(id, currentAdmin.fullName || currentAdmin.username, `${nextStatus === 'locked' ? 'Suspension' : 'Réactivation'} · ${cur.name}`, 'M. Taha · Verrouillage distant', nowHM());
        return sendJson(res, 200, serializeTenant(database.prepare('SELECT * FROM tenants WHERE id = ?').get(id)));
      }

      // 12. Issue Ed25519 Signed Offline License Code
      if (req.method === 'POST' && (m = p.match(/^\/api\/admin\/tenants\/(\d+)\/offline-code$/))) {
        const id = Number(m[1]);
        const parsed = await readJsonBody(req, standardLimit);
        const opts = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        const result = issueOfflineLicense(database, id, opts);
        database.prepare(`
          INSERT INTO audit_logs (
            tenant_id, actor, action, title, subtitle, entity_type, entity_id, time_label
          ) VALUES (?, ?, 'OFFLINE_LICENSE_ISSUE', ?, ?, 'offline_lease_token', ?, ?)
        `).run(
          id,
          currentAdmin.fullName || currentAdmin.username,
          `Code Offline ${result.code} · ${result.storeName}`,
          `+${result.days}j (grâce ${result.graceDays}j) · ${result.keyId}`,
          result.code,
          nowHM(),
        );
        return sendJson(res, 200, result);
      }

      // 13. Support Diagnostic Audit
      if (req.method === 'POST' && (m = p.match(/^\/api\/admin\/tenants\/(\d+)\/support$/))) {
        const id = Number(m[1]);
        const cur = database.prepare('SELECT * FROM tenants WHERE id = ?').get(id);
        if (!cur) return sendJson(res, 404, { error: 'Not found' });
        await readRawBody(req, standardLimit);
        database.prepare('INSERT INTO audit_logs (tenant_id, actor, title, subtitle, time_label) VALUES (?, ?, ?, ?, ?)')
          .run(id, currentAdmin.fullName || currentAdmin.username, `Support Sécurisé · ${cur.name}`, `Diagnostic distant ouvert (${cur.city})`, nowHM());
        return sendJson(res, 200, { ok: true });
      }

      // 14. Approve SaaS Payment
      if (req.method === 'POST' && (m = p.match(/^\/api\/admin\/payments\/([^/]+)\/approve$/))) {
        const payCode = decodeURIComponent(m[1]);
        await readRawBody(req, standardLimit);
        const pay = database.prepare(`
          SELECT p.*, t.name AS tenant_name, t.days_left
          FROM saas_payments p JOIN tenants t ON t.id = p.tenant_id
          WHERE p.pay_code = ?
        `).get(payCode);
        if (!pay) return sendJson(res, 404, { error: 'Payment not found' });
        database.exec('BEGIN');
        try {
          database.prepare("UPDATE saas_payments SET status = 'approved' WHERE pay_code = ?").run(payCode);
          database.prepare("UPDATE tenants SET days_left = ?, status = 'active', updated_at = CURRENT_TIMESTAMP WHERE id = ?")
            .run(pay.days_left + 30, pay.tenant_id);
          database.prepare('INSERT INTO audit_logs (tenant_id, actor, title, subtitle, time_label) VALUES (?, ?, ?, ?, ?)')
            .run(pay.tenant_id, currentAdmin.fullName || currentAdmin.username, `Paiement ${pay.method} · ${pay.tenant_name}`, `Réf. ${pay.ref} · +${pay.amount} MRU`, nowHM());
          database.exec('COMMIT');
        } catch (e) {
          database.exec('ROLLBACK');
          throw e;
        }
        return sendJson(res, 200, { ok: true });
      }

      // 15. 1-Click Catalog CSV / XLSX / JSON Import
      if (req.method === 'POST' && (m = p.match(/^\/api\/admin\/tenants\/(\d+)\/catalog\/import$/))) {
        const id = Number(m[1]);
        const rawBuffer = await readRawBody(req, catalogLimit);
        const result = importCatalog(database, id, {
          buffer: rawBuffer,
          contentType: req.headers['content-type'] || '',
          filename: url.searchParams.get('filename') || '',
          actor: currentAdmin.fullName || currentAdmin.username,
        });
        return sendJson(res, 200, result);
      }

      // 16. Read Tenant Catalog
      if (req.method === 'GET' && (m = p.match(/^\/api\/admin\/tenants\/(\d+)\/catalog$/))) {
        const id = Number(m[1]);
        const tenant = database.prepare('SELECT id FROM tenants WHERE id = ?').get(id);
        if (!tenant) return sendJson(res, 404, { error: 'Tenant not found' });

        const categories = database
          .prepare('SELECT * FROM categories WHERE tenant_id = ? ORDER BY sort_order ASC, id ASC')
          .all(id);
        const products = database
          .prepare(`
            SELECT p.*, COALESCE(c.name_fr, '') AS category_name
            FROM products p
            LEFT JOIN categories c ON c.id = p.category_id
            WHERE p.tenant_id = ?
            ORDER BY p.id ASC
          `)
          .all(id);
        return sendJson(res, 200, { ok: true, tenantId: id, categories, products });
      }

      return sendJson(res, 404, { error: 'Route not found' });
    } catch (err) {
      if (err && Number.isInteger(err.statusCode)) {
        const errBody = { error: err.message };
        if (Array.isArray(err.errors)) {
          errBody.errors = err.errors;
        }
        return sendJson(res, err.statusCode, errBody);
      }
      if (err && /UNIQUE constraint failed/i.test(err.message)) {
        return sendJson(res, 409, { error: err.message });
      }
      return sendJson(res, 500, { error: err?.message || 'Internal Server Error' });
    }
  };

  const server = http.createServer(handler);
  server.on('close', closeDb);

  const close = () =>
    new Promise((resolve) => {
      if (!server.listening) {
        closeDb();
        return resolve();
      }
      server.closeAllConnections?.();
      server.close(() => {
        closeDb();
        resolve();
      });
    });

  return { server, handler, db: database, dbPath, close };
}

function startServer(options = {}) {
  const port = options.port !== undefined ? Number(options.port) : Number(process.env.PORT || 4000);
  const host = options.host || process.env.HOST || '0.0.0.0';
  const app = createApp(options);

  return new Promise((resolve, reject) => {
    const onError = (err) => {
      app.close().finally(() => reject(err));
    };
    app.server.once('error', onError);
    app.server.listen(port, host, () => {
      app.server.removeListener('error', onError);
      const addr = app.server.address();
      const actualPort = addr && typeof addr === 'object' ? addr.port : port;
      const displayHost = host === '0.0.0.0' ? '127.0.0.1' : host;
      if (options.quiet !== true && (require.main === module || options.logStartup === true)) {
        console.log(`Full·Tek Cloud API (SQLite WAL) running on http://${displayHost}:${actualPort} (DB: ${app.dbPath})`);
      }
      resolve({
        ...app,
        port: actualPort,
        url: `http://${displayHost}:${actualPort}`,
      });
    });
  });
}

if (require.main === module) {
  startServer().catch((err) => {
    console.error('Failed to start cloud-api server:', err);
    process.exit(1);
  });
}

module.exports = {
  createApp,
  startServer,
};
