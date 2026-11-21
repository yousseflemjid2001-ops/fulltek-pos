'use strict';

const assert = require('node:assert/strict');
const { spawn, spawnSync } = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const http = require('node:http');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const { DatabaseSync } = require('node:sqlite');

const ROOT_DIR = path.resolve(__dirname, '..', '..');
const CLOUD_API_DIR = path.join(ROOT_DIR, 'apps', 'cloud-api');
const SUPERADMIN_DIR = path.join(ROOT_DIR, 'apps', 'fulltek_superadmin');
const COMMERCIAL_DIR = path.join(ROOT_DIR, 'apps', 'fulltek_commercial');
const COMMERCIAL_WEB_DIR = path.join(COMMERCIAL_DIR, 'build', 'web');
const PROD_DB_PATH = path.join(CLOUD_API_DIR, 'data', 'fulltek.db');
const PRISMA_SQLITE_PATH = path.join(CLOUD_API_DIR, 'prisma', 'schema.prisma');
const PRISMA_PG_PATH = path.join(CLOUD_API_DIR, 'prisma', 'schema.postgresql.prisma');

const DEFAULT_JWT_SECRET = 'e2e-test-jwt-secret-2026';
const DEFAULT_ADMIN_USER = 'taha';
const DEFAULT_ADMIN_PASS = 'FullTekAdmin@2026';
const COMMERCIAL_PAY_METHODS = Object.freeze([
  'Cash',
  'Bankily',
  'Masrivi',
  'Sedad',
  'Bimbank',
  'Click',
  'Karni',
]);
const TVA_STANDARD_RATE = 16;

const MIME_TYPES = Object.freeze({
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.css': 'text/css; charset=utf-8',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.symbols': 'text/plain; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
});

const STATIC_ASSET_EXTS = new Set([
  '.html',
  '.htm',
  '.js',
  '.mjs',
  '.wasm',
  '.json',
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.svg',
  '.css',
  '.ico',
  '.ttf',
  '.otf',
  '.woff',
  '.woff2',
  '.symbols',
  '.txt',
  '.map',
]);

// ---------------------------------------------------------------------------
// Port, Filesystem & HTTP Helpers
// ---------------------------------------------------------------------------

function getFreePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.unref();
    srv.on('error', reject);
    srv.listen(0, '127.0.0.1', () => {
      const addr = srv.address();
      const port = addr && typeof addr === 'object' ? addr.port : 0;
      srv.close((err) => {
        if (err) return reject(err);
        resolve(port);
      });
    });
  });
}

function removeDirWithRetries(dirPath) {
  if (!dirPath || !fs.existsSync(dirPath)) return;
  fs.rmSync(dirPath, {
    recursive: true,
    force: true,
    maxRetries: 10,
    retryDelay: 60,
  });
}

function sleepSync(ms) {
  const sab = new SharedArrayBuffer(4);
  const view = new Int32Array(sab);
  Atomics.wait(view, 0, 0, ms);
}

function copyFileWithRetries(srcPath, destPath) {
  const transientCodes = new Set(['EBUSY', 'EPERM', 'EACCES']);
  let lastErr = null;
  for (let attempt = 0; attempt < 10; attempt += 1) {
    try {
      fs.copyFileSync(srcPath, destPath);
      return;
    } catch (err) {
      lastErr = err;
      if (!transientCodes.has(err?.code) || attempt === 9) {
        throw err;
      }
      sleepSync(20 * (attempt + 1));
    }
  }
  throw lastErr;
}

function resolveBaseUrl(baseUrlOrCtx) {
  if (typeof baseUrlOrCtx === 'string') return baseUrlOrCtx;
  if (baseUrlOrCtx && typeof baseUrlOrCtx.baseUrl === 'string') return baseUrlOrCtx.baseUrl;
  throw new Error('Expected baseUrl string or stack context with baseUrl');
}

function request(baseUrlOrCtx, method, urlPath, opts = {}) {
  const baseUrl = resolveBaseUrl(baseUrlOrCtx);
  return new Promise((resolve, reject) => {
    const base = new URL(baseUrl);
    const reqPath = opts.rawPath
      ? (String(urlPath).startsWith('/') ? String(urlPath) : `/${String(urlPath)}`)
      : (() => {
          const target = new URL(urlPath, base);
          return `${target.pathname}${target.search}`;
        })();
    const headers = { ...(opts.headers || {}) };
    const hasHeader = (name) =>
      Object.keys(headers).some((k) => k.toLowerCase() === name.toLowerCase());

    if (opts.token && !hasHeader('authorization')) {
      headers.Authorization = `Bearer ${opts.token}`;
    }

    let payloadBuf = null;
    if (opts.rawBody !== undefined && opts.rawBody !== null) {
      payloadBuf = Buffer.isBuffer(opts.rawBody)
        ? opts.rawBody
        : Buffer.from(String(opts.rawBody), 'utf8');
      if (!hasHeader('content-length')) {
        headers['Content-Length'] = String(payloadBuf.length);
      }
    } else if (opts.body !== undefined) {
      payloadBuf = Buffer.from(JSON.stringify(opts.body), 'utf8');
      if (!hasHeader('content-type')) {
        headers['Content-Type'] = 'application/json; charset=utf-8';
      }
      if (!hasHeader('content-length')) {
        headers['Content-Length'] = String(payloadBuf.length);
      }
    }

    const req = http.request(
      {
        hostname: base.hostname,
        port: Number(base.port),
        path: reqPath,
        method: method.toUpperCase(),
        headers,
        timeout: opts.timeoutMs || 15000,
      },
      (res) => {
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => {
          const buffer = Buffer.concat(chunks);
          const text = buffer.toString('utf8');
          let json = null;
          try {
            json = text ? JSON.parse(text) : null;
          } catch {
            json = null;
          }
          resolve({
            status: res.statusCode,
            headers: res.headers,
            buffer,
            text,
            json,
          });
        });
      },
    );

    req.on('timeout', () => {
      req.destroy(new Error(`HTTP timeout on ${method} ${urlPath}`));
    });
    req.on('error', reject);
    if (payloadBuf) req.write(payloadBuf);
    req.end();
  });
}

async function apiJson(baseUrlOrCtx, method, urlPath, body = undefined, token = undefined, opts = {}) {
  const reqOpts = { ...opts };
  if (body !== undefined) reqOpts.body = body;
  if (token !== undefined && token !== null) reqOpts.token = token;
  const res = await request(baseUrlOrCtx, method, urlPath, reqOpts);
  return {
    status: res.status,
    headers: res.headers,
    data: res.json,
    json: res.json,
    text: res.text,
    buffer: res.buffer,
  };
}

async function waitForHealth(baseUrl, timeoutMs = 8000) {
  const deadline = Date.now() + timeoutMs;
  let lastErr = null;
  while (Date.now() < deadline) {
    try {
      const res = await request(baseUrl, 'GET', '/health', { timeoutMs: 1500 });
      if (res.status === 200 && res.json && res.json.ok) {
        return res.json;
      }
      lastErr = new Error(`Unexpected /health status=${res.status} body=${res.text}`);
    } catch (err) {
      lastErr = err;
    }
    await new Promise((r) => setTimeout(r, 30));
  }
  throw new Error(`Server did not become healthy within ${timeoutMs}ms: ${lastErr?.message || 'unknown'}`);
}

// ---------------------------------------------------------------------------
// Static Web Server (Flutter Web build/web + SPA Fallback + Strict MIME)
// ---------------------------------------------------------------------------

async function startStaticWebServer({
  rootDir = COMMERCIAL_WEB_DIR,
  host = '127.0.0.1',
  port = 0,
  spaFallback = true,
  cors = true,
} = {}) {
  const resolvedRoot = path.resolve(rootDir);
  if (!fs.existsSync(resolvedRoot) || !fs.statSync(resolvedRoot).isDirectory()) {
    throw new Error(`Static web rootDir does not exist or is not a directory: ${resolvedRoot}`);
  }
  const rootPrefix = resolvedRoot.endsWith(path.sep) ? resolvedRoot : resolvedRoot + path.sep;
  const indexHtmlPath = path.join(resolvedRoot, 'index.html');

  function applyCommonHeaders(extra = {}) {
    const hdrs = {
      'Cache-Control': 'no-store',
      ...extra,
    };
    if (cors) {
      hdrs['Access-Control-Allow-Origin'] = '*';
      hdrs['Access-Control-Allow-Methods'] = 'GET,HEAD,OPTIONS';
      hdrs['Access-Control-Allow-Headers'] = '*';
    }
    return hdrs;
  }

  function sendText(res, statusCode, message) {
    const buf = Buffer.from(message, 'utf8');
    res.writeHead(
      statusCode,
      applyCommonHeaders({
        'Content-Type': 'text/plain; charset=utf-8',
        'Content-Length': String(buf.length),
      }),
    );
    res.end(buf);
  }

  function sendFile(res, method, filePath) {
    const ext = path.extname(filePath).toLowerCase();
    const mime = MIME_TYPES[ext] || 'application/octet-stream';
    const stat = fs.statSync(filePath);
    res.writeHead(
      200,
      applyCommonHeaders({
        'Content-Type': mime,
        'Content-Length': String(stat.size),
      }),
    );
    if (method === 'HEAD') {
      res.end();
      return;
    }
    const stream = fs.createReadStream(filePath);
    stream.on('error', () => {
      if (!res.headersSent) {
        sendText(res, 500, 'Internal Server Error');
      } else {
        res.destroy();
      }
    });
    stream.pipe(res);
  }

  const server = http.createServer((req, res) => {
    const method = (req.method || 'GET').toUpperCase();
    if (method === 'OPTIONS') {
      res.writeHead(204, applyCommonHeaders());
      res.end();
      return;
    }
    if (method !== 'GET' && method !== 'HEAD') {
      sendText(res, 405, 'Method Not Allowed');
      return;
    }

    const rawUrl = req.url || '/';
    const rawPathPart = rawUrl.split('?')[0].split('#')[0];
    let decodedRawPath;
    try {
      decodedRawPath = decodeURIComponent(rawPathPart);
    } catch {
      sendText(res, 400, 'Bad Request');
      return;
    }

    if (decodedRawPath.includes('\0')) {
      sendText(res, 403, 'Forbidden');
      return;
    }

    // Reject path traversal BEFORE URL dot-segment normalization
    const rawSegments = decodedRawPath.replace(/\\/g, '/').split('/');
    if (rawSegments.includes('..')) {
      sendText(res, 403, 'Forbidden: Path traversal rejected');
      return;
    }

    let pathname = decodedRawPath;
    if (!pathname.startsWith('/')) pathname = `/${pathname}`;

    const relPath = pathname === '/' ? 'index.html' : pathname.slice(1);
    let candidatePath = path.resolve(resolvedRoot, relPath);

    if (candidatePath !== resolvedRoot && !candidatePath.startsWith(rootPrefix)) {
      sendText(res, 403, 'Forbidden: Path traversal rejected');
      return;
    }

    if (fs.existsSync(candidatePath) && fs.statSync(candidatePath).isDirectory()) {
      candidatePath = path.join(candidatePath, 'index.html');
    }

    if (fs.existsSync(candidatePath) && fs.statSync(candidatePath).isFile()) {
      sendFile(res, method, candidatePath);
      return;
    }

    const ext = path.extname(pathname).toLowerCase();
    const isApiPath = pathname === '/api' || pathname.startsWith('/api/');
    if (spaFallback && !isApiPath && !STATIC_ASSET_EXTS.has(ext) && fs.existsSync(indexHtmlPath)) {
      sendFile(res, method, indexHtmlPath);
      return;
    }

    sendText(res, 404, 'Not Found');
  });

  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, host, () => {
      server.removeListener('error', reject);
      resolve();
    });
  });

  const addr = server.address();
  const actualPort = addr && typeof addr === 'object' ? addr.port : port;
  const url = `http://${host}:${actualPort}`;

  let stopped = false;
  async function stop() {
    if (stopped) return;
    stopped = true;
    try { server.closeAllConnections?.(); } catch {}
    await new Promise((resolve) => server.close(() => resolve()));
  }

  return {
    url,
    port: actualPort,
    rootDir: resolvedRoot,
    server,
    stop,
  };
}

// ---------------------------------------------------------------------------
// Isolated Commercial Stack Runner (cloud-api + optional static web server)
// ---------------------------------------------------------------------------

async function startCommercialStack({
  serveWeb = false,
  webDir = COMMERCIAL_WEB_DIR,
  subprocess = true,
  dbPath,
  tmpDir,
  ownsTmpDir,
  jwtSecret = DEFAULT_JWT_SECRET,
  superadminUser,
  superadminPassword,
} = {}) {
  const ownsDir = ownsTmpDir ?? !dbPath;
  const effectiveTmpDir = tmpDir || (dbPath ? path.dirname(dbPath) : fs.mkdtempSync(path.join(os.tmpdir(), 'fulltek-comm-e2e-')));
  const effectiveDbPath = dbPath || path.join(effectiveTmpDir, 'fulltek-commercial-e2e.db');

  // Strict production safety guard
  const resolvedDb = path.resolve(effectiveDbPath);
  const resolvedTmp = path.resolve(os.tmpdir());
  const tmpPrefix = resolvedTmp.endsWith(path.sep) ? resolvedTmp : resolvedTmp + path.sep;
  assert.ok(
    resolvedDb.toLowerCase().startsWith(tmpPrefix.toLowerCase()),
    `Refusing non-tmpdir dbPath: ${resolvedDb}`,
  );
  assert.notEqual(
    resolvedDb.toLowerCase(),
    path.resolve(PROD_DB_PATH).toLowerCase(),
    'Refusing to target production data/fulltek.db',
  );

  let port = 0;
  let baseUrl = '';
  let child = null;
  let srvHandle = null;
  let webSrv = null;
  let stdoutLogs = '';
  let stderrLogs = '';

  const envVars = {
    ...process.env,
    HOST: '127.0.0.1',
    DB_PATH: resolvedDb,
    FULLTEK_DB_PATH: resolvedDb,
    DATABASE_URL: `file:${resolvedDb}`,
    JWT_SECRET: jwtSecret,
    ...(superadminUser ? { SUPERADMIN_USER: superadminUser } : {}),
    ...(superadminPassword ? { SUPERADMIN_PASSWORD: superadminPassword } : {}),
  };

  async function emergencyCleanup() {
    if (webSrv) {
      try { await webSrv.stop(); } catch {}
    }
    if (child && child.exitCode === null && child.signalCode === null) {
      try { child.kill('SIGKILL'); } catch {}
    }
    if (srvHandle) {
      try { await srvHandle.close?.(); } catch {}
      try { srvHandle.db?.close?.(); } catch {}
    }
    if (ownsDir) {
      try { removeDirWithRetries(effectiveTmpDir); } catch {}
    }
  }

  let health;
  try {
    if (subprocess) {
      port = await getFreePort();
      envVars.PORT = String(port);
      baseUrl = `http://127.0.0.1:${port}`;

      const bootstrapCode = `
        const path = require('node:path');
        const serverPath = path.resolve(${JSON.stringify(path.join(CLOUD_API_DIR, 'src', 'server.js'))});
        const mod = require(serverPath);
        const port = Number(process.env.PORT);
        const dbPath = process.env.DB_PATH;
        const jwtSecret = process.env.JWT_SECRET;

        (async () => {
          const handle = await mod.startServer({
            port,
            host: '127.0.0.1',
            dbPath,
            jwtSecret,
            quiet: true,
          });
          let closing = false;
          const shutdown = async () => {
            if (closing) return;
            closing = true;
            const forceExit = setTimeout(() => process.exit(0), 600);
            forceExit.unref();
            try {
              await handle.close();
            } catch {}
            process.exit(0);
          };
          process.on('SIGTERM', shutdown);
          process.on('SIGINT', shutdown);
        })().catch((err) => {
          console.error(err);
          process.exit(1);
        });
      `;

      child = spawn(process.execPath, ['--no-warnings', '-e', bootstrapCode], {
        cwd: CLOUD_API_DIR,
        env: envVars,
        stdio: ['ignore', 'pipe', 'pipe'],
      });
      child.stdout.on('data', (d) => {
        stdoutLogs += d.toString('utf8');
      });
      child.stderr.on('data', (d) => {
        stderrLogs += d.toString('utf8');
      });
    } else {
      Object.assign(process.env, envVars);
      const serverPath = path.join(CLOUD_API_DIR, 'src', 'server.js');
      const mod = require(serverPath);
      srvHandle = await mod.startServer({
        port: 0,
        host: '127.0.0.1',
        dbPath: resolvedDb,
        jwtSecret,
        quiet: true,
      });
      port = srvHandle.port;
      baseUrl = `http://127.0.0.1:${port}`;
    }

    health = await waitForHealth(baseUrl, 8000);
    assert.ok(health.dbPath, `/health must expose dbPath (got ${JSON.stringify(health)})`);
    assert.equal(
      path.resolve(health.dbPath).toLowerCase(),
      resolvedDb.toLowerCase(),
      `Server bound to unexpected DB path: ${health.dbPath} !== ${resolvedDb}`,
    );
    assert.equal(
      health.pgBackup?.enabled,
      false,
      `Expected pgBackup.enabled === false for isolated dbPath, got ${JSON.stringify(health.pgBackup)}`,
    );

    if (serveWeb) {
      const indexFile = path.join(path.resolve(webDir), 'index.html');
      assert.ok(fs.existsSync(indexFile), `Static webDir missing index.html: ${indexFile}`);
      webSrv = await startStaticWebServer({ rootDir: webDir });
    }
  } catch (err) {
    await emergencyCleanup();
    throw new Error(`${err.message}\nstdout: ${stdoutLogs}\nstderr: ${stderrLogs}`);
  }

  let stopped = false;

  async function stop({ cleanup = ownsDir } = {}) {
    if (stopped) {
      if (cleanup) removeDirWithRetries(effectiveTmpDir);
      return;
    }
    stopped = true;

    if (webSrv) {
      try { await webSrv.stop(); } catch {}
    }

    if (child && child.exitCode === null && child.signalCode === null) {
      const exitPromise = new Promise((resolve) => {
        child.once('exit', resolve);
        setTimeout(() => {
          try { child.kill('SIGKILL'); } catch {}
        }, 1500).unref();
      });
      try {
        child.kill('SIGTERM');
      } catch {}
      await exitPromise;
    }

    if (srvHandle) {
      try { await srvHandle.close(); } catch {}
      try { srvHandle.db?.close?.(); } catch {}
    }

    if (cleanup) {
      removeDirWithRetries(effectiveTmpDir);
    }
  }

  const boundRequest = (method, urlPath, reqOpts) => request(baseUrl, method, urlPath, reqOpts);
  const boundApiJson = (method, urlPath, body, token, reqOpts) =>
    apiJson(baseUrl, method, urlPath, body, token, reqOpts);

  return {
    baseUrl,
    webUrl: webSrv ? webSrv.url : null,
    port,
    webPort: webSrv ? webSrv.port : null,
    dbPath: resolvedDb,
    tmpDir: effectiveTmpDir,
    jwtSecret,
    health,
    api: {
      baseUrl,
      request: boundRequest,
      apiJson: boundApiJson,
    },
    request: boundRequest,
    apiJson: boundApiJson,
    stop,
    cleanup: () => removeDirWithRetries(effectiveTmpDir),
  };
}

// ---------------------------------------------------------------------------
// Auth, Commercial Tenant Provisioning & Readiness Probes
// ---------------------------------------------------------------------------

async function loginAdmin(baseUrlOrCtx, creds = {}) {
  const baseUrl = resolveBaseUrl(baseUrlOrCtx);
  const username = creds.username ?? DEFAULT_ADMIN_USER;
  const password = creds.password ?? DEFAULT_ADMIN_PASS;
  const res = await request(baseUrl, 'POST', '/api/admin/login', {
    body: { username, password },
  });
  assert.equal(res.status, 200, `Admin login failed (${res.status}): ${res.text}`);
  assert.ok(res.json && res.json.token, 'Admin login response missing token');
  return res.json;
}

async function loginTenant(baseUrlOrCtx, creds = {}) {
  const baseUrl = resolveBaseUrl(baseUrlOrCtx);
  const username = creds.username;
  const password = creds.password;
  assert.ok(username && password, 'loginTenant requires username and password');
  const res = await request(baseUrl, 'POST', '/api/auth/login', {
    body: { username, password },
  });
  assert.equal(res.status, 200, `Tenant login failed (${res.status}): ${res.text}`);
  assert.ok(res.json && res.json.token, 'Tenant login response missing token');
  assert.ok(res.json.tenant, 'Tenant login response missing tenant');
  const decoded = decodeJwt(res.json.token);
  assert.ok(decoded.payload && decoded.payload.tenantId, 'Tenant JWT missing tenantId');
  assert.ok(decoded.payload && decoded.payload.role, 'Tenant JWT missing role');
  return {
    ...res.json,
    user: res.json.user ?? null,
  };
}

async function provisionCommercialTenant(baseUrlOrCtx, overrides = {}) {
  const baseUrl = resolveBaseUrl(baseUrlOrCtx);
  const {
    adminToken: providedAdminToken,
    adminCreds,
    ...tenantOverrides
  } = overrides;

  let adminToken = providedAdminToken;
  if (!adminToken) {
    const adminLogin = await loginAdmin(baseUrl, adminCreds || {});
    adminToken = adminLogin.token;
  }

  const unique = `${Date.now().toString(36)}-${crypto.randomBytes(3).toString('hex')}`;
  const username = tenantOverrides.username || `comm_${unique.replace(/-/g, '_')}`;
  const password = tenantOverrides.accountPassword || tenantOverrides.password || `CommPass@${unique}`;
  const tenantCode = tenantOverrides.tenantId || `FT-COM-${crypto.randomInt(1000, 9999)}-${crypto.randomBytes(2).toString('hex').toUpperCase()}`;

  const payload = {
    tenantId: tenantCode,
    name: `Éts Mauritanie Commerce ${unique}`,
    module: 'commercial',
    subType: 'Grossiste / Distribution',
    city: 'Nouakchott',
    district: 'Tevragh Zeina',
    address: 'Avenue Gamal Abdel Nasser, Ilot C',
    legalName: `SARL Mauritanie Commerce ${unique}`,
    nif: '00123456',
    rc: `RC-NKC-2026-${crypto.randomInt(100, 999)}`,
    phone: `+22245${crypto.randomInt(100000, 999999)}`,
    email: `${username}@fulltek.mr`,
    manager: 'Mohamed Ould Ahmed',
    defaultLang: 'fr',
    plan: 'Pro',
    billing: 'monthly',
    mrr: 5000,
    tills: 2,
    daysLeft: 30,
    payMethods: [...COMMERCIAL_PAY_METHODS],
    ...tenantOverrides,
    username,
    accountPassword: password,
    module: 'commercial',
  };
  delete payload.password;

  const createRes = await apiJson(baseUrl, 'POST', '/api/admin/tenants', payload, adminToken);
  assert.equal(
    createRes.status,
    201,
    `POST /api/admin/tenants failed (${createRes.status}): ${createRes.text}`,
  );
  assert.ok(createRes.data && createRes.data.id, 'Created tenant missing id');
  assert.equal(createRes.data.module, 'commercial', 'Created tenant module must be commercial');

  const loginRes = await loginTenant(baseUrl, { username, password });
  const tenant = loginRes.tenant || createRes.data;

  return {
    tenant,
    createdTenant: createRes.data,
    user: loginRes.user ?? null,
    token: loginRes.token,
    headers: { Authorization: `Bearer ${loginRes.token}` },
    credentials: { username, password },
    adminToken,
  };
}

async function isCommercialStackReady(baseUrlOrCtx, { token } = {}) {
  try {
    const baseUrl = resolveBaseUrl(baseUrlOrCtx);
    const res = await request(baseUrl, 'GET', '/api/commercial/bootstrap', {
      token,
      timeoutMs: 3000,
    });
    if (res.status === 404) return false;
    if (token) return res.status === 200;
    return res.status < 500;
  } catch {
    return false;
  }
}

function isWebBuildReady(webDir = COMMERCIAL_WEB_DIR) {
  try {
    const resolved = path.resolve(webDir);
    if (!fs.existsSync(resolved) || !fs.statSync(resolved).isDirectory()) return false;
    const hasIndex = fs.existsSync(path.join(resolved, 'index.html'));
    const hasBundle =
      fs.existsSync(path.join(resolved, 'main.dart.js')) ||
      fs.existsSync(path.join(resolved, 'flutter_bootstrap.js'));
    return hasIndex && hasBundle;
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Mauritanian Domain Math, PMP & CSV Export Helpers
// ---------------------------------------------------------------------------

function round2(n) {
  const num = Number(n);
  if (!Number.isFinite(num)) return NaN;
  const sign = num < 0 ? -1 : 1;
  const r = sign * (Math.round((Math.abs(num) + 1e-9) * 100) / 100);
  return r === 0 ? 0 : r;
}

function calcLineTotals({
  qty,
  unitPriceHt,
  discountPct = 0,
  tvaRate = TVA_STANDARD_RATE,
  isExempt = false,
}) {
  const q = Number(qty);
  const price = Number(unitPriceHt);
  const disc = Number(discountPct || 0);
  const grossHt = round2(q * price);
  const lineHt = round2(q * price * (1 - disc / 100));
  const effectiveRate = isExempt ? 0 : Number(tvaRate);
  const lineTva = isExempt ? 0 : round2(lineHt * (effectiveRate / 100));
  const lineTtc = round2(lineHt + lineTva);
  return {
    grossHt,
    lineHt,
    lineTva,
    lineTtc,
    tvaRate: effectiveRate,
  };
}

function calcPmp({ currentStock, currentPmp, receivedQty, receivedUnitCostHt }) {
  const curStock = Number(currentStock);
  const curPmp = Number(currentPmp);
  const q = Number(receivedQty);
  const cost = Number(receivedUnitCostHt);
  const s0 = Math.max(0, curStock);
  const newStock = round2(curStock + q);
  const newPmp =
    s0 + q > 0
      ? round2((s0 * curPmp + q * cost) / (s0 + q))
      : round2(curPmp);
  return { newStock, newPmp };
}

function parseCsvWithBom(input, { delimiter = ';' } = {}) {
  let hasBom = false;
  let text = '';
  if (Buffer.isBuffer(input)) {
    hasBom =
      input.length >= 3 &&
      input[0] === 0xef &&
      input[1] === 0xbb &&
      input[2] === 0xbf;
    text = (hasBom ? input.subarray(3) : input).toString('utf8');
  } else {
    text = String(input ?? '');
    if (text.startsWith('\uFEFF')) {
      hasBom = true;
      text = text.slice(1);
    }
  }

  const parsedRows = [];
  let currentRow = [];
  let currentField = '';
  let inQuotes = false;

  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (inQuotes) {
      if (ch === '"') {
        if (text[i + 1] === '"') {
          currentField += '"';
          i += 1;
        } else {
          inQuotes = false;
        }
      } else {
        currentField += ch;
      }
      continue;
    }

    if (ch === '"' && currentField.length === 0) {
      inQuotes = true;
    } else if (ch === delimiter) {
      currentRow.push(currentField);
      currentField = '';
    } else if (ch === '\r') {
      if (text[i + 1] === '\n') i += 1;
      currentRow.push(currentField);
      parsedRows.push(currentRow);
      currentRow = [];
      currentField = '';
    } else if (ch === '\n') {
      currentRow.push(currentField);
      parsedRows.push(currentRow);
      currentRow = [];
      currentField = '';
    } else {
      currentField += ch;
    }
  }

  if (currentField.length > 0 || currentRow.length > 0) {
    currentRow.push(currentField);
    parsedRows.push(currentRow);
  }

  // Drop trailing single empty row if caused by trailing newline
  while (
    parsedRows.length > 0 &&
    parsedRows[parsedRows.length - 1].length === 1 &&
    parsedRows[parsedRows.length - 1][0] === ''
  ) {
    parsedRows.pop();
  }

  const headers = parsedRows.length > 0 ? parsedRows[0] : [];
  const rows = parsedRows.length > 1 ? parsedRows.slice(1) : [];
  const records = rows.map((row) => {
    const obj = {};
    for (let i = 0; i < headers.length; i += 1) {
      obj[headers[i]] = row[i] ?? '';
    }
    return obj;
  });

  return {
    hasBom,
    delimiter,
    headers,
    rows,
    records,
  };
}

function isDangerousCsvCell(rawCell, { allowNegativeNumbers = true } = {}) {
  const cell = String(rawCell ?? '');
  if (cell.length === 0) return false;
  // Leading single quote neutralizes spreadsheet formula execution
  if (cell[0] === "'") return false;

  const first = cell[0];
  const dangerousStart = new Set(['=', '+', '-', '@', '\t', '\r']);
  if (dangerousStart.has(first)) {
    if (allowNegativeNumbers && first === '-' && /^-\d+(?:[.,]\d+)?$/.test(cell.trim())) {
      return false;
    }
    return true;
  }

  const trimmedStart = cell.trimStart();
  if (
    trimmedStart.length > 0 &&
    trimmedStart[0] !== "'" &&
    ['=', '+', '-', '@'].includes(trimmedStart[0])
  ) {
    if (
      allowNegativeNumbers &&
      trimmedStart[0] === '-' &&
      /^-\d+(?:[.,]\d+)?$/.test(trimmedStart.trim())
    ) {
      return false;
    }
    return true;
  }
  return false;
}

function hasCsvFormulaRisk(input, { delimiter = ';', allowNegativeNumbers = true } = {}) {
  let cells = [];
  if (Array.isArray(input)) {
    for (const item of input) {
      if (Array.isArray(item)) {
        cells.push(...item);
      } else {
        cells.push(item);
      }
    }
  } else {
    const parsed = parseCsvWithBom(input, { delimiter });
    cells = [...parsed.headers, ...parsed.rows.flat()];
  }

  return cells.some((cell) => isDangerousCsvCell(cell, { allowNegativeNumbers }));
}

// ---------------------------------------------------------------------------
// JWT & SQLite Inspection Helpers
// ---------------------------------------------------------------------------

function decodeJwt(token) {
  const parts = String(token || '').split('.');
  if (parts.length !== 3) {
    throw new Error(`Invalid JWT structure (${parts.length} parts)`);
  }
  const header = JSON.parse(Buffer.from(parts[0], 'base64url').toString('utf8'));
  const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  return { header, payload, signature: parts[2] };
}

function forgeJwt(payload, secret, { header = { alg: 'HS256', typ: 'JWT' } } = {}) {
  const h = Buffer.from(JSON.stringify(header), 'utf8').toString('base64url');
  const p = Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
  if (String(header.alg || '').toLowerCase() === 'none') {
    return `${h}.${p}.`;
  }
  const sig = crypto.createHmac('sha256', String(secret)).update(`${h}.${p}`).digest('base64url');
  return `${h}.${p}.${sig}`;
}

function makeExpiredJwt(secret, claims = {}) {
  const now = Math.floor(Date.now() / 1000);
  return forgeJwt(
    {
      id: 1,
      username: 'taha',
      role: 'SUPER_ADMIN',
      iat: now - 3600,
      exp: now - 120,
      ...claims,
    },
    secret,
  );
}

function makeWrongSecretJwt(claims = {}, wrongSecret = 'wrong-secret-key-2026') {
  const now = Math.floor(Date.now() / 1000);
  return forgeJwt(
    {
      id: 1,
      username: 'taha',
      role: 'SUPER_ADMIN',
      iat: now,
      exp: now + 3600,
      ...claims,
    },
    wrongSecret,
  );
}

function makeAlgNoneJwt(claims = {}) {
  const now = Math.floor(Date.now() / 1000);
  return forgeJwt(
    {
      id: 1,
      username: 'taha',
      role: 'SUPER_ADMIN',
      iat: now,
      exp: now + 3600,
      ...claims,
    },
    '',
    { header: { alg: 'none', typ: 'JWT' } },
  );
}

function quoteIdent(ident) {
  return `"${String(ident).replace(/"/g, '""')}"`;
}

function withReadOnlyDb(dbPath, fn) {
  const db = new DatabaseSync(dbPath, { readOnly: true });
  try {
    return fn(db);
  } finally {
    db.close();
  }
}

function withCopiedWritableDb(sourceDbPath, fn) {
  const copyDir = fs.mkdtempSync(path.join(os.tmpdir(), 'fulltek-comm-dbcopy-'));
  const copyPath = path.join(copyDir, 'copy.db');
  try {
    copyFileWithRetries(sourceDbPath, copyPath);
    const walPath = `${sourceDbPath}-wal`;
    if (fs.existsSync(walPath)) {
      copyFileWithRetries(walPath, `${copyPath}-wal`);
    }
    const db = new DatabaseSync(copyPath);
    try {
      db.exec('PRAGMA foreign_keys = ON;');
      return fn(db, copyPath);
    } finally {
      db.close();
    }
  } finally {
    removeDirWithRetries(copyDir);
  }
}

function listTables(db) {
  return db
    .prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
    .all()
    .map((r) => r.name);
}

function getTableColumns(db, tableName) {
  return db.prepare(`PRAGMA table_info(${quoteIdent(tableName)})`).all();
}

function getForeignKeys(db, tableName) {
  return db.prepare(`PRAGMA foreign_key_list(${quoteIdent(tableName)})`).all();
}

function runFlutterCli(args, opts = {}) {
  return spawnSync('flutter', args, {
    cwd: opts.cwd || COMMERCIAL_DIR,
    shell: process.platform === 'win32',
    encoding: 'utf8',
    timeout: opts.timeout || 240000,
    env: { ...process.env, ...(opts.env || {}) },
  });
}

module.exports = {
  ROOT_DIR,
  CLOUD_API_DIR,
  SUPERADMIN_DIR,
  COMMERCIAL_DIR,
  COMMERCIAL_WEB_DIR,
  PROD_DB_PATH,
  PRISMA_SQLITE_PATH,
  PRISMA_PG_PATH,
  DEFAULT_JWT_SECRET,
  DEFAULT_ADMIN_USER,
  DEFAULT_ADMIN_PASS,
  COMMERCIAL_PAY_METHODS,
  TVA_STANDARD_RATE,
  getFreePort,
  removeDirWithRetries,
  request,
  apiJson,
  waitForHealth,
  startStaticWebServer,
  startCommercialStack,
  loginAdmin,
  loginTenant,
  provisionCommercialTenant,
  isCommercialStackReady,
  isWebBuildReady,
  round2,
  calcLineTotals,
  calcPmp,
  parseCsvWithBom,
  hasCsvFormulaRisk,
  decodeJwt,
  forgeJwt,
  makeExpiredJwt,
  makeWrongSecretJwt,
  makeAlgNoneJwt,
  withReadOnlyDb,
  withCopiedWritableDb,
  listTables,
  getTableColumns,
  getForeignKeys,
  runFlutterCli,
};
