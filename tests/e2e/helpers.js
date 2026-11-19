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
const zlib = require('node:zlib');

const ROOT_DIR = path.resolve(__dirname, '..', '..');
const CLOUD_API_DIR = path.join(ROOT_DIR, 'apps', 'cloud-api');
const FLUTTER_APP_DIR = path.join(ROOT_DIR, 'apps', 'fulltek_superadmin');
const FLUTTER_POS_DIR = path.join(ROOT_DIR, 'apps', 'fulltek_pos');
const PROD_DB_PATH = path.join(CLOUD_API_DIR, 'data', 'fulltek.db');
const PRISMA_SQLITE_PATH = path.join(CLOUD_API_DIR, 'prisma', 'schema.prisma');
const PRISMA_PG_PATH = path.join(CLOUD_API_DIR, 'prisma', 'schema.postgresql.prisma');

const DEFAULT_JWT_SECRET = 'e2e-test-jwt-secret-2026';
const DEFAULT_ADMIN_USER = 'taha';
const DEFAULT_ADMIN_PASS = 'FullTekAdmin@2026';
const DEFAULT_POS_USER = 'darelkram41';
const DEFAULT_POS_PASS = 'FullTek@2026';

// ---------------------------------------------------------------------------
// Port & HTTP helpers
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

function request(baseUrl, method, urlPath, opts = {}) {
  return new Promise((resolve, reject) => {
    const target = new URL(urlPath, baseUrl);
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
        hostname: target.hostname,
        port: Number(target.port),
        path: `${target.pathname}${target.search}`,
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

// ---------------------------------------------------------------------------
// Isolated cloud-api server lifecycle (dual-mode: subprocess & in-process)
// ---------------------------------------------------------------------------

async function startTestServer(opts = {}) {
  const ownsTmpDir = opts.ownsTmpDir ?? !opts.dbPath;
  const tmpDir = opts.tmpDir || (opts.dbPath ? path.dirname(opts.dbPath) : fs.mkdtempSync(path.join(os.tmpdir(), 'fulltek-e2e-')));
  const dbPath = opts.dbPath || path.join(tmpDir, 'fulltek-e2e.db');
  const jwtSecret = opts.jwtSecret || DEFAULT_JWT_SECRET;
  const subprocess = opts.subprocess !== false;

  // Safety guard: dbPath must live in os.tmpdir(), never touch data/fulltek.db
  const resolvedDb = path.resolve(dbPath);
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
  let server = null;
  let dbHandle = null;
  let stdoutLogs = '';
  let stderrLogs = '';

  const envVars = {
    ...process.env,
    HOST: '127.0.0.1',
    DB_PATH: resolvedDb,
    FULLTEK_DB_PATH: resolvedDb,
    DATABASE_URL: `file:${resolvedDb}`,
    JWT_SECRET: jwtSecret,
    ...(opts.superadminUser ? { SUPERADMIN_USER: opts.superadminUser } : {}),
    ...(opts.superadminPassword ? { SUPERADMIN_PASSWORD: opts.superadminPassword } : {}),
  };

  if (subprocess) {
    port = await getFreePort();
    envVars.PORT = String(port);
    baseUrl = `http://127.0.0.1:${port}`;

    // Bootstrap script handles both refactored M2 exports (startServer / createApp)
    // and direct top-level server execution cleanly in an isolated Node process.
    const bootstrapCode = `
      const http = require('node:http');
      const path = require('node:path');
      const serverPath = path.resolve(${JSON.stringify(path.join(CLOUD_API_DIR, 'src', 'server.js'))});
      const mod = require(serverPath);
      const port = Number(process.env.PORT);
      const dbPath = process.env.DB_PATH;
      const jwtSecret = process.env.JWT_SECRET;

      (async () => {
        let srv = null;
        let db = null;
        if (typeof mod.startServer === 'function') {
          const res = await mod.startServer({ port, host: '127.0.0.1', dbPath, jwtSecret });
          srv = res && res.server ? res.server : res;
          db = res && res.db ? res.db : null;
        } else if (typeof mod.createApp === 'function') {
          const res = await mod.createApp({ dbPath, jwtSecret });
          db = res && res.db ? res.db : null;
          if (typeof res === 'function') {
            srv = http.createServer(res);
          } else if (res && typeof res.handler === 'function') {
            srv = http.createServer(res.handler);
          } else if (res && res.server) {
            srv = res.server;
          } else {
            srv = res;
          }
          if (srv && typeof srv.listen === 'function' && !srv.listening) {
            await new Promise((resolve) => srv.listen(port, '127.0.0.1', resolve));
          }
        }
        const shutdown = () => {
          const finish = () => {
            try { db?.close?.(); } catch {}
            process.exit(0);
          };
          if (srv && typeof srv.close === 'function') {
            try { srv.closeAllConnections?.(); } catch {}
            srv.close(finish);
            setTimeout(finish, 500).unref();
          } else {
            finish();
          }
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
    // In-process mode (exercising createApp / startServer directly when exported)
    Object.assign(process.env, envVars);
    const serverPath = path.join(CLOUD_API_DIR, 'src', 'server.js');
    const mod = require(serverPath);
    if (typeof mod.startServer === 'function') {
      const res = await mod.startServer({ port: 0, host: '127.0.0.1', dbPath: resolvedDb, jwtSecret });
      server = res && res.server ? res.server : res;
      dbHandle = res && res.db ? res.db : null;
    } else if (typeof mod.createApp === 'function') {
      const res = await mod.createApp({ dbPath: resolvedDb, jwtSecret });
      dbHandle = res && res.db ? res.db : null;
      if (typeof res === 'function') {
        server = http.createServer(res);
      } else if (res && typeof res.handler === 'function') {
        server = http.createServer(res.handler);
      } else if (res && res.server) {
        server = res.server;
      } else {
        server = res;
      }
      if (!server.listening) {
        await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
      }
    } else {
      throw new Error('In-process mode requires server.js to export startServer or createApp');
    }
    const addr = server.address();
    port = addr && typeof addr === 'object' ? addr.port : 0;
    baseUrl = `http://127.0.0.1:${port}`;
  }

  let health;
  try {
    health = await waitForHealth(baseUrl, 8000);
    assert.ok(health.dbPath, `/health must expose dbPath (got ${JSON.stringify(health)})`);
    assert.equal(
      path.resolve(health.dbPath).toLowerCase(),
      resolvedDb.toLowerCase(),
      `Server bound to unexpected DB path: ${health.dbPath} !== ${resolvedDb}`,
    );
  } catch (err) {
    if (child) {
      try { child.kill('SIGKILL'); } catch {}
    }
    if (server) {
      try { server.closeAllConnections?.(); server.close(); } catch {}
    }
    try { dbHandle?.close?.(); } catch {}
    if (ownsTmpDir) {
      try { removeDirWithRetries(tmpDir); } catch {}
    }
    throw new Error(`${err.message}\nstdout: ${stdoutLogs}\nstderr: ${stderrLogs}`);
  }

  let stopped = false;

  async function stop({ cleanup = ownsTmpDir } = {}) {
    if (stopped) {
      if (cleanup) removeDirWithRetries(tmpDir);
      return;
    }
    stopped = true;

    if (child) {
      if (child.exitCode === null && child.signalCode === null) {
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
    }

    if (server) {
      await new Promise((resolve) => {
        try { server.closeAllConnections?.(); } catch {}
        server.close(() => resolve());
      });
    }
    try { dbHandle?.close?.(); } catch {}

    if (cleanup) {
      removeDirWithRetries(tmpDir);
    }
  }

  return {
    baseUrl,
    port,
    dbPath: resolvedDb,
    tmpDir,
    jwtSecret,
    health,
    request: (method, urlPath, reqOpts) => request(baseUrl, method, urlPath, reqOpts),
    stop,
    cleanup: () => removeDirWithRetries(tmpDir),
  };
}

async function loginAdmin(ctx, creds = {}) {
  const username = creds.username ?? DEFAULT_ADMIN_USER;
  const password = creds.password ?? DEFAULT_ADMIN_PASS;
  const res = await ctx.request('POST', '/api/admin/login', {
    body: { username, password },
  });
  assert.equal(res.status, 200, `Admin login failed (${res.status}): ${res.text}`);
  assert.ok(res.json && res.json.token, 'Admin login response missing token');
  return res.json;
}

async function loginTenant(ctx, creds = {}) {
  const username = creds.username ?? DEFAULT_POS_USER;
  const password = creds.password ?? DEFAULT_POS_PASS;
  const res = await ctx.request('POST', '/api/auth/login', {
    body: { username, password },
  });
  assert.equal(res.status, 200, `Tenant login failed (${res.status}): ${res.text}`);
  assert.ok(res.json && res.json.token, 'Tenant login response missing token');
  assert.ok(res.json.tenant, 'Tenant login response missing tenant');
  const decoded = decodeJwt(res.json.token);
  assert.ok(decoded.payload && decoded.payload.tenantId, 'Tenant JWT missing tenantId');
  assert.ok(decoded.payload && decoded.payload.role, 'Tenant JWT missing role');
  return res.json;
}

function computeTva16(netTotalMru) {
  return Math.round((Number(netTotalMru) * 16) / 116);
}

// ---------------------------------------------------------------------------
// Pure node:zlib ZIP & OOXML (.xlsx) generator + corrupt fixtures
// ---------------------------------------------------------------------------

function buildZip(entries, { store = false } = {}) {
  const localChunks = [];
  const centralChunks = [];
  let offset = 0;

  for (const entry of entries) {
    const nameBuf = Buffer.from(entry.name, 'utf8');
    const raw = Buffer.isBuffer(entry.data) ? entry.data : Buffer.from(String(entry.data), 'utf8');
    const crc = zlib.crc32(raw) >>> 0;
    const method = store ? 0 : 8;
    const compressed = store ? raw : zlib.deflateRawSync(raw);

    const localHeader = Buffer.alloc(30);
    localHeader.writeUInt32LE(0x04034b50, 0);
    localHeader.writeUInt16LE(20, 4);
    localHeader.writeUInt16LE(0x0800, 6); // UTF-8 filename flag
    localHeader.writeUInt16LE(method, 8);
    localHeader.writeUInt16LE(0, 10);
    localHeader.writeUInt16LE(0, 12);
    localHeader.writeUInt32LE(crc, 14);
    localHeader.writeUInt32LE(compressed.length, 18);
    localHeader.writeUInt32LE(raw.length, 22);
    localHeader.writeUInt16LE(nameBuf.length, 26);
    localHeader.writeUInt16LE(0, 28);

    localChunks.push(localHeader, nameBuf, compressed);

    const centralHeader = Buffer.alloc(46);
    centralHeader.writeUInt32LE(0x02014b50, 0);
    centralHeader.writeUInt16LE(20, 4);
    centralHeader.writeUInt16LE(20, 6);
    centralHeader.writeUInt16LE(0x0800, 8);
    centralHeader.writeUInt16LE(method, 10);
    centralHeader.writeUInt16LE(0, 12);
    centralHeader.writeUInt16LE(0, 14);
    centralHeader.writeUInt32LE(crc, 16);
    centralHeader.writeUInt32LE(compressed.length, 20);
    centralHeader.writeUInt32LE(raw.length, 24);
    centralHeader.writeUInt16LE(nameBuf.length, 28);
    centralHeader.writeUInt16LE(0, 30);
    centralHeader.writeUInt16LE(0, 32);
    centralHeader.writeUInt16LE(0, 34);
    centralHeader.writeUInt16LE(0, 36);
    centralHeader.writeUInt32LE(0, 38);
    centralHeader.writeUInt32LE(offset, 42);

    centralChunks.push(centralHeader, nameBuf);
    offset += localHeader.length + nameBuf.length + compressed.length;
  }

  const centralDir = Buffer.concat(centralChunks);
  const eocd = Buffer.alloc(22);
  eocd.writeUInt32LE(0x06054b50, 0);
  eocd.writeUInt16LE(0, 4);
  eocd.writeUInt16LE(0, 6);
  eocd.writeUInt16LE(entries.length, 8);
  eocd.writeUInt16LE(entries.length, 10);
  eocd.writeUInt32LE(centralDir.length, 12);
  eocd.writeUInt32LE(offset, 16);
  eocd.writeUInt16LE(0, 20);

  return Buffer.concat([...localChunks, centralDir, eocd]);
}

function xmlEscape(value) {
  return String(value)
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

function buildXlsxBuffer(rows, { sheetName = 'Catalogue', inlineStrings = false, store = false } = {}) {
  const sharedStrings = [];
  const sharedIndex = new Map();

  function getSharedIdx(str) {
    const key = String(str);
    if (!sharedIndex.has(key)) {
      sharedIndex.set(key, sharedStrings.length);
      sharedStrings.push(key);
    }
    return sharedIndex.get(key);
  }

  const sheetRowsXml = rows
    .map((row, rIdx) => {
      const rowNum = rIdx + 1;
      const cells = [];
      for (let cIdx = 0; cIdx < row.length; cIdx += 1) {
        const val = row[cIdx];
        if (val === undefined || val === null) continue;
        const ref = `${colIndexToLetters(cIdx)}${rowNum}`;
        if (typeof val === 'number' && Number.isFinite(val)) {
          cells.push(`<c r="${ref}"><v>${val}</v></c>`);
        } else if (typeof val === 'boolean') {
          cells.push(`<c r="${ref}" t="b"><v>${val ? 1 : 0}</v></c>`);
        } else if (inlineStrings) {
          cells.push(`<c r="${ref}" t="inlineStr"><is><t xml:space="preserve">${xmlEscape(val)}</t></is></c>`);
        } else {
          const sIdx = getSharedIdx(String(val));
          cells.push(`<c r="${ref}" t="s"><v>${sIdx}</v></c>`);
        }
      }
      return `<row r="${rowNum}">${cells.join('')}</row>`;
    })
    .join('');

  const contentTypesXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  ${inlineStrings ? '' : '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>'}
</Types>`;

  const rootRelsXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>`;

  const workbookXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="${xmlEscape(sheetName)}" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>`;

  const workbookRelsXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  ${inlineStrings ? '' : '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>'}
</Relationships>`;

  const sheetXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>${sheetRowsXml}</sheetData>
</worksheet>`;

  const entries = [
    { name: '[Content_Types].xml', data: contentTypesXml },
    { name: '_rels/.rels', data: rootRelsXml },
    { name: 'xl/workbook.xml', data: workbookXml },
    { name: 'xl/_rels/workbook.xml.rels', data: workbookRelsXml },
    { name: 'xl/worksheets/sheet1.xml', data: sheetXml },
  ];

  if (!inlineStrings) {
    const siItems = sharedStrings
      .map((s) => `<si><t xml:space="preserve">${xmlEscape(s)}</t></si>`)
      .join('');
    const sharedStringsXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="${sharedStrings.length}" uniqueCount="${sharedStrings.length}">${siItems}</sst>`;
    entries.push({ name: 'xl/sharedStrings.xml', data: sharedStringsXml });
  }

  return buildZip(entries, { store });
}

function corruptXlsxMagic(buf) {
  const copy = Buffer.from(buf);
  copy.write('BAD!', 0, 'ascii');
  return copy;
}

function truncateBuffer(buf, ratio = 0.4) {
  const len = Math.max(1, Math.floor(buf.length * ratio));
  return Buffer.from(buf.subarray(0, len));
}

function buildZipMissingSheet(sheetName = 'Catalogue') {
  return buildZip([
    {
      name: '[Content_Types].xml',
      data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/></Types>`,
    },
    {
      name: '_rels/.rels',
      data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`,
    },
    {
      name: 'xl/workbook.xml',
      data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="${xmlEscape(sheetName)}" sheetId="1" r:id="rId1"/></sheets></workbook>`,
    },
    {
      name: 'xl/_rels/workbook.xml.rels',
      data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>`,
    },
  ]);
}

// ---------------------------------------------------------------------------
// JWT & Ed25519 cryptographic helpers (node:crypto)
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

function tamperJwtPayload(jwt, mutatorFn) {
  const parts = String(jwt || '').split('.');
  assert.equal(parts.length, 3, 'Expected 3-part JWT');
  const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  const mutated = mutatorFn({ ...payload }) || payload;
  const newPayloadB64 = Buffer.from(JSON.stringify(mutated), 'utf8').toString('base64url');
  return `${parts[0]}.${newPayloadB64}.${parts[2]}`;
}

function makeNonAdminJwt(secret, claims = {}) {
  const now = Math.floor(Date.now() / 1000);
  return forgeJwt(
    {
      tenantId: 1,
      tenantCode: 'FT-1041',
      module: 'resto',
      role: 'OWNER',
      iat: now,
      exp: now + 3600,
      ...claims,
    },
    secret,
  );
}

function verifyEd25519Lease(leaseToken, publicKeyPem) {
  const parts = String(leaseToken || '').split('.');
  if (parts.length !== 2 || !parts[0] || !parts[1]) {
    return { valid: false, payload: null, payloadB64: null, signature: null };
  }
  const [payloadB64, signature] = parts;
  let valid = false;
  try {
    valid = crypto.verify(
      null,
      Buffer.from(payloadB64, 'utf8'),
      publicKeyPem,
      Buffer.from(signature, 'base64url'),
    );
  } catch {
    valid = false;
  }
  let payload = null;
  try {
    payload = JSON.parse(Buffer.from(payloadB64, 'base64url').toString('utf8'));
  } catch {
    payload = null;
  }
  return { valid, payload, payloadB64, signature };
}

function tamperLeasePayload(leaseToken, mutatorFn) {
  const parts = String(leaseToken || '').split('.');
  assert.equal(parts.length, 2, 'Expected 2-part leaseToken');
  const payload = JSON.parse(Buffer.from(parts[0], 'base64url').toString('utf8'));
  const mutated = mutatorFn({ ...payload }) || payload;
  const newPayloadB64 = Buffer.from(JSON.stringify(mutated), 'utf8').toString('base64url');
  return `${newPayloadB64}.${parts[1]}`;
}

function tamperLeaseSignature(leaseToken) {
  const parts = String(leaseToken || '').split('.');
  assert.equal(parts.length, 2, 'Expected 2-part leaseToken');
  const sigBuf = Buffer.from(parts[1], 'base64url');
  assert.ok(sigBuf.length > 0, 'Empty signature buffer');
  sigBuf[0] ^= 0xff;
  return `${parts[0]}.${sigBuf.toString('base64url')}`;
}

function generateWrongEd25519PublicKeyPem() {
  const { publicKey } = crypto.generateKeyPairSync('ed25519');
  return publicKey.export({ type: 'spki', format: 'pem' });
}

// ---------------------------------------------------------------------------
// SQLite inspection & schema-aware MCD helpers (node:sqlite)
// ---------------------------------------------------------------------------

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

function withWritableDb(dbPath, fn) {
  const db = new DatabaseSync(dbPath);
  try {
    db.exec('PRAGMA foreign_keys = ON;');
    db.exec('PRAGMA busy_timeout = 5000;');
    return fn(db);
  } finally {
    db.close();
  }
}

function withCopiedWritableDb(sourceDbPath, fn) {
  const copyDir = fs.mkdtempSync(path.join(os.tmpdir(), 'fulltek-dbcopy-'));
  const copyPath = path.join(copyDir, 'copy.db');
  try {
    // Copy main DB + -wal only (never -shm, which is locked by active WAL writers on Windows)
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

function findExistingTable(db, candidates) {
  const existing = new Set(listTables(db));
  return candidates.find((c) => existing.has(c)) || null;
}

function getTableColumns(db, tableName) {
  return db.prepare(`PRAGMA table_info(${quoteIdent(tableName)})`).all();
}

function getForeignKeys(db, tableName) {
  return db.prepare(`PRAGMA foreign_key_list(${quoteIdent(tableName)})`).all();
}

function buildSchemaAwareRow(db, tableName, semanticValues = {}) {
  const cols = getTableColumns(db, tableName);
  const fks = getForeignKeys(db, tableName);
  const fkCols = new Set(fks.map((f) => f.from));

  const aliasGroups = [
    ['tenant_id', 'tenantId'],
    ['branch_id', 'branchId'],
    ['product_id', 'productId'],
    ['order_id', 'orderId'],
    ['user_id', 'userId'],
    ['role_id', 'roleId'],
    ['permission_id', 'permissionId'],
    ['category_id', 'categoryId'],
    ['ingredient_id', 'ingredientId'],
    ['zone_id', 'zoneId', 'dining_zone_id'],
    ['register_id', 'registerId', 'pos_register_id'],
    ['customer_id', 'credit_id', 'customer_credit_id', 'karni_id'],
    ['key_id', 'signing_key_id'],
    ['name', 'name_fr', 'label', 'title', 'zone_name', 'customer_name', 'client_name', 'guest_name'],
    ['name_ar', 'label_ar'],
    ['code', 'branch_code', 'register_code', 'role_code', 'perm_code', 'permission_code', 'key_code', 'sku'],
    ['hardware_fingerprint', 'fingerprint', 'hw_fingerprint', 'device_id'],
    ['is_master', 'master'],
    ['active', 'is_active'],
    ['credit_limit_mru', 'credit_limit', 'limit_mru', 'max_credit_mru'],
    ['current_debt_mru', 'current_debt', 'debt_mru', 'balance_mru', 'balance', 'amount_mru', 'amount'],
    ['min_spend_mru', 'min_spend', 'minimum_spend'],
    ['deposit_mru', 'arboun_mru', 'arboun_amount', 'deposit', 'arboun'],
    ['deposit_method', 'pay_method', 'payment_method'],
    ['party_size', 'guests', 'guests_count', 'pax'],
    ['reserved_at', 'reservation_date', 'reservation_time', 'scheduled_at'],
    ['unit', 'uom'],
    ['pmp_cost_mru', 'pmp_cost', 'cost_mru', 'unit_cost', 'cost', 'price_cost'],
    ['current_stock', 'qty_per_unit', 'stock_qty', 'qty', 'quantity', 'qty_required', 'grammage'],
    ['condition_channel', 'condition_type', 'condition_tag', 'condition', 'mode'],
    ['action_type', 'tx_type', 'type', 'kind', 'entry_type'],
    ['reason', 'motif', 'notes', 'note'],
    ['nif', 'tax_id'],
    ['phone', 'phone_whatsapp', 'customer_phone', 'telephone'],
    ['status', 'state'],
    ['nonce'],
    ['kitchen_station', 'station'],
    ['is_top', 'isTop'],
    ['is_out_of_stock', 'isOutOfStock'],
    ['service_mode', 'serviceMode', 'channel'],
    ['delivery_zone', 'deliveryZone'],
    ['delivery_fee_mru', 'deliveryFeeMru'],
    ['tva_mru', 'tvaMru'],
    ['is_training', 'isTraining'],
  ];

  function resolveSemantic(colName) {
    if (Object.prototype.hasOwnProperty.call(semanticValues, colName)) {
      return semanticValues[colName];
    }
    for (const group of aliasGroups) {
      if (group.includes(colName)) {
        for (const alias of group) {
          if (Object.prototype.hasOwnProperty.call(semanticValues, alias)) {
            return semanticValues[alias];
          }
        }
      }
    }
    return undefined;
  }

  const chosenCols = [];
  const chosenVals = [];

  for (const col of cols) {
    // Skip autoincrement integer primary keys unless explicitly supplied
    const isIntPk = col.pk === 1 && /INT/i.test(col.type || '');
    if (isIntPk && !Object.prototype.hasOwnProperty.call(semanticValues, col.name)) {
      continue;
    }

    const val = resolveSemantic(col.name);
    if (val !== undefined) {
      chosenCols.push(col.name);
      chosenVals.push(val);
      continue;
    }

    // Populate NOT NULL columns lacking defaults (and non-FK columns)
    const needsValue = col.notnull === 1 && col.dflt_value === null;
    if (needsValue) {
      if (fkCols.has(col.name)) {
        throw new Error(`Missing required FK value for ${tableName}.${col.name}`);
      }
      const upperType = String(col.type || '').toUpperCase();
      if (upperType.includes('INT') || upperType.includes('REAL') || upperType.includes('NUM') || upperType.includes('FLOAT')) {
        chosenCols.push(col.name);
        chosenVals.push(1);
      } else {
        chosenCols.push(col.name);
        chosenVals.push(`e2e-${col.name}-${Date.now()}`);
      }
    }
  }

  const colSql = chosenCols.map(quoteIdent).join(', ');
  const placeholders = chosenCols.map(() => '?').join(', ');
  const sql = `INSERT INTO ${quoteIdent(tableName)} (${colSql}) VALUES (${placeholders})`;

  return {
    columns: chosenCols,
    values: chosenVals,
    sql,
    run: () => db.prepare(sql).run(...chosenVals),
  };
}

// ---------------------------------------------------------------------------
// Prisma schema parser
// ---------------------------------------------------------------------------

function parsePrismaSchema(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  let depth = 0;
  let balancedBraces = true;
  for (let i = 0; i < raw.length; i += 1) {
    if (raw[i] === '{') depth += 1;
    else if (raw[i] === '}') {
      depth -= 1;
      if (depth < 0) {
        balancedBraces = false;
        break;
      }
    }
  }
  if (depth !== 0) balancedBraces = false;

  const dsMatch = raw.match(/datasource\s+\w+\s*\{([\s\S]*?)\}/);
  const providerMatch = dsMatch ? dsMatch[1].match(/provider\s*=\s*"([^"]+)"/) : null;
  const provider = providerMatch ? providerMatch[1] : null;

  const models = new Map();
  const modelRe = /model\s+(\w+)\s*\{([\s\S]*?)\}/g;
  let m;
  while ((m = modelRe.exec(raw)) !== null) {
    const modelName = m[1];
    const body = m[2];
    const fields = [];
    let mapName = null;

    for (const rawLine of body.split(/\r?\n/)) {
      const line = rawLine.replace(/\/\/.*$/, '').trim();
      if (!line) continue;
      if (line.startsWith('@@map')) {
        const mm = line.match(/@@map\(\s*"([^"]+)"\s*\)/);
        if (mm) mapName = mm[1];
        continue;
      }
      if (line.startsWith('@@')) continue;
      const fieldMatch = line.match(/^(\w+)\s+/);
      if (fieldMatch) {
        fields.push(fieldMatch[1]);
      }
    }
    models.set(modelName, { fields, mapName });
  }

  return { provider, balancedBraces, models, raw };
}

// ---------------------------------------------------------------------------
// Flutter CLI runner (no browser - R5)
// ---------------------------------------------------------------------------

function runFlutterCli(args, opts = {}) {
  return spawnSync('flutter', args, {
    cwd: opts.cwd || FLUTTER_APP_DIR,
    shell: process.platform === 'win32',
    encoding: 'utf8',
    timeout: opts.timeout || 120000,
    env: { ...process.env, ...(opts.env || {}) },
  });
}

function runPosFlutterCli(args, opts = {}) {
  return runFlutterCli(args, {
    cwd: FLUTTER_POS_DIR,
    timeout: opts.timeout || 240000,
    ...opts,
  });
}

module.exports = {
  ROOT_DIR,
  CLOUD_API_DIR,
  FLUTTER_APP_DIR,
  FLUTTER_POS_DIR,
  PROD_DB_PATH,
  PRISMA_SQLITE_PATH,
  PRISMA_PG_PATH,
  DEFAULT_JWT_SECRET,
  DEFAULT_ADMIN_USER,
  DEFAULT_ADMIN_PASS,
  DEFAULT_POS_USER,
  DEFAULT_POS_PASS,
  getFreePort,
  request,
  waitForHealth,
  startTestServer,
  loginAdmin,
  loginTenant,
  computeTva16,
  buildZip,
  buildXlsxBuffer,
  corruptXlsxMagic,
  truncateBuffer,
  buildZipMissingSheet,
  decodeJwt,
  forgeJwt,
  makeExpiredJwt,
  makeWrongSecretJwt,
  makeAlgNoneJwt,
  tamperJwtPayload,
  makeNonAdminJwt,
  verifyEd25519Lease,
  tamperLeasePayload,
  tamperLeaseSignature,
  generateWrongEd25519PublicKeyPem,
  withReadOnlyDb,
  withWritableDb,
  withCopiedWritableDb,
  listTables,
  findExistingTable,
  getTableColumns,
  getForeignKeys,
  buildSchemaAwareRow,
  parsePrismaSchema,
  runFlutterCli,
  runPosFlutterCli,
};
