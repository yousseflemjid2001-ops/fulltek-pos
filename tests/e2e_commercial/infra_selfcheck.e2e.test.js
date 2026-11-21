'use strict';

const { describe, it, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const {
  PROD_DB_PATH,
  COMMERCIAL_PAY_METHODS,
  TVA_STANDARD_RATE,
  removeDirWithRetries,
  request,
  apiJson,
  startStaticWebServer,
  startCommercialStack,
  provisionCommercialTenant,
  isCommercialStackReady,
  isWebBuildReady,
  round2,
  calcLineTotals,
  calcPmp,
  parseCsvWithBom,
  hasCsvFormulaRisk,
  decodeJwt,
} = require('./helpers');
const { DEFAULT_CHROME_PATH, launchHeadlessChrome } = require('./cdp_browser');

function makeTempFixtureDir(prefix = 'fulltek-comm-fixture-') {
  return fs.mkdtempSync(path.join(os.tmpdir(), prefix));
}

function readPngDimensions(pngBuf) {
  assert.ok(Buffer.isBuffer(pngBuf) && pngBuf.length >= 24, 'PNG buffer too small');
  const magic = pngBuf.subarray(0, 8);
  assert.deepEqual(
    magic,
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    'Invalid PNG magic signature',
  );
  // IHDR chunk starts at byte 8: 4-byte length, 4-byte 'IHDR', 4-byte width, 4-byte height
  assert.equal(pngBuf.subarray(12, 16).toString('ascii'), 'IHDR', 'Missing IHDR chunk');
  return {
    width: pngBuf.readUInt32BE(16),
    height: pngBuf.readUInt32BE(20),
  };
}

describe('E2E-M1 Self-Check · Isolated Cloud-API Stack, Provisioning & Readiness', () => {
  const cleanups = [];

  afterEach(async () => {
    while (cleanups.length > 0) {
      const fn = cleanups.pop();
      await fn();
    }
  });

  it('starts isolated cloud-api in os.tmpdir() with pgBackup disabled, provisions commercial tenant, and cleans up completely', async () => {
    const stack = await startCommercialStack({ serveWeb: false });
    let stopped = false;
    cleanups.push(async () => {
      if (!stopped) await stack.stop();
    });

    const resolvedTmp = path.resolve(os.tmpdir()).toLowerCase();
    assert.ok(
      path.resolve(stack.dbPath).toLowerCase().startsWith(resolvedTmp),
      `dbPath must reside inside os.tmpdir(): ${stack.dbPath}`,
    );
    assert.notEqual(
      path.resolve(stack.dbPath).toLowerCase(),
      path.resolve(PROD_DB_PATH).toLowerCase(),
      'dbPath must never equal PROD_DB_PATH',
    );
    assert.equal(stack.webUrl, null);
    assert.equal(stack.webPort, null);
    assert.equal(stack.health.ok, true);
    assert.equal(stack.health.pgBackup?.enabled, false);

    // Readiness guard executes cleanly without throwing
    const readyBefore = await isCommercialStackReady(stack);
    assert.equal(typeof readyBefore, 'boolean');

    // Provision commercial tenant via super-admin API & login
    const prov = await provisionCommercialTenant(stack, {
      nif: '00987654',
      rc: 'RC-NKC-2026-888',
      legalName: 'Société Mauritanienne Test SARL',
    });

    assert.equal(prov.tenant.module, 'commercial');
    assert.equal(prov.tenant.nif, '00987654');
    assert.equal(prov.tenant.rc, 'RC-NKC-2026-888');
    assert.deepEqual(prov.tenant.payMethods, COMMERCIAL_PAY_METHODS);
    assert.ok(prov.token);
    assert.ok(prov.headers.Authorization.startsWith('Bearer '));

    const jwt = decodeJwt(prov.token);
    assert.equal(jwt.payload.module, 'commercial');
    assert.ok(jwt.payload.tenantId);

    const readyAuthed = await isCommercialStackReady(stack.baseUrl, { token: prov.token });
    assert.equal(typeof readyAuthed, 'boolean');

    // Verify apiJson wrapper works cleanly
    const healthRes = await stack.apiJson('GET', '/health');
    assert.equal(healthRes.status, 200);
    assert.equal(healthRes.data.ok, true);

    const tmpDirPath = stack.tmpDir;
    assert.equal(fs.existsSync(tmpDirPath), true);
    await stack.stop();
    stopped = true;
    assert.equal(fs.existsSync(tmpDirPath), false, 'stack.stop() must remove temp directory');
  });

  it('isWebBuildReady detects missing dirs vs valid Flutter Web build fixtures', () => {
    const missingDir = path.join(os.tmpdir(), `fulltek-missing-web-${Date.now()}`);
    assert.equal(isWebBuildReady(missingDir), false);

    const dirWithOnlyHtml = makeTempFixtureDir('fulltek-web-htmlonly-');
    cleanups.push(async () => removeDirWithRetries(dirWithOnlyHtml));
    fs.writeFileSync(path.join(dirWithOnlyHtml, 'index.html'), '<html></html>');
    assert.equal(isWebBuildReady(dirWithOnlyHtml), false);

    const dirReady = makeTempFixtureDir('fulltek-web-ready-');
    cleanups.push(async () => removeDirWithRetries(dirReady));
    fs.writeFileSync(path.join(dirReady, 'index.html'), '<html></html>');
    fs.writeFileSync(path.join(dirReady, 'flutter_bootstrap.js'), '// bootstrap');
    assert.equal(isWebBuildReady(dirReady), true);

    const dirReadyMainDart = makeTempFixtureDir('fulltek-web-maindart-');
    cleanups.push(async () => removeDirWithRetries(dirReadyMainDart));
    fs.writeFileSync(path.join(dirReadyMainDart, 'index.html'), '<html></html>');
    fs.writeFileSync(path.join(dirReadyMainDart, 'main.dart.js'), '// main');
    assert.equal(isWebBuildReady(dirReadyMainDart), true);
  });
});

describe('E2E-M1 Self-Check · Static Web Server (MIME, CORS, SPA Fallback & Security)', () => {
  const cleanups = [];

  afterEach(async () => {
    while (cleanups.length > 0) {
      const fn = cleanups.pop();
      await fn();
    }
  });

  it('serves assets with strict MIME types, CORS, SPA fallback, 404 on missing assets, and 403 on path traversal', async () => {
    const webDir = makeTempFixtureDir('fulltek-static-web-');
    cleanups.push(async () => removeDirWithRetries(webDir));

    fs.mkdirSync(path.join(webDir, 'canvaskit'), { recursive: true });
    fs.writeFileSync(path.join(webDir, 'index.html'), '<!doctype html><html><body>SPA_INDEX</body></html>');
    fs.writeFileSync(path.join(webDir, 'main.dart.js'), 'console.log("ok");');
    fs.writeFileSync(path.join(webDir, 'canvaskit', 'canvaskit.wasm'), Buffer.from([0x00, 0x61, 0x73, 0x6d]));
    fs.writeFileSync(path.join(webDir, 'manifest.json'), '{"name":"FullTek Commercial"}');
    fs.writeFileSync(path.join(webDir, 'styles.css'), 'body { margin: 0; }');
    fs.writeFileSync(path.join(webDir, 'logo.svg'), '<svg xmlns="http://www.w3.org/2000/svg"></svg>');

    const stack = await startCommercialStack({ serveWeb: true, webDir });
    cleanups.push(async () => stack.stop());

    assert.ok(stack.webUrl && stack.webUrl.startsWith('http://127.0.0.1:'));
    assert.ok(stack.webPort > 0);

    const rootRes = await request(stack.webUrl, 'GET', '/');
    assert.equal(rootRes.status, 200);
    assert.match(rootRes.headers['content-type'], /text\/html/i);
    assert.equal(rootRes.headers['cache-control'], 'no-store');
    assert.equal(rootRes.headers['access-control-allow-origin'], '*');
    assert.ok(rootRes.text.includes('SPA_INDEX'));

    const jsRes = await request(stack.webUrl, 'GET', '/main.dart.js');
    assert.equal(jsRes.status, 200);
    assert.match(jsRes.headers['content-type'], /application\/javascript/i);

    const wasmRes = await request(stack.webUrl, 'GET', '/canvaskit/canvaskit.wasm');
    assert.equal(wasmRes.status, 200);
    assert.equal(wasmRes.headers['content-type'], 'application/wasm');

    const jsonRes = await request(stack.webUrl, 'GET', '/manifest.json');
    assert.equal(jsonRes.status, 200);
    assert.match(jsonRes.headers['content-type'], /application\/json/i);

    const cssRes = await request(stack.webUrl, 'GET', '/styles.css');
    assert.equal(cssRes.status, 200);
    assert.match(cssRes.headers['content-type'], /text\/css/i);

    const svgRes = await request(stack.webUrl, 'GET', '/logo.svg');
    assert.equal(svgRes.status, 200);
    assert.match(svgRes.headers['content-type'], /image\/svg\+xml/i);

    // CORS preflight
    const optRes = await request(stack.webUrl, 'OPTIONS', '/manifest.json');
    assert.equal(optRes.status, 204);
    assert.equal(optRes.headers['access-control-allow-origin'], '*');

    // SPA fallback for client-side route
    const spaRes = await request(stack.webUrl, 'GET', '/ventes/factures');
    assert.equal(spaRes.status, 200);
    assert.ok(spaRes.text.includes('SPA_INDEX'));

    // Missing static asset & /api/* must return 404 (not index.html)
    const missingWasm = await request(stack.webUrl, 'GET', '/canvaskit/missing.wasm');
    assert.equal(missingWasm.status, 404);
    const missingApi = await request(stack.webUrl, 'GET', '/api/commercial/bootstrap');
    assert.equal(missingApi.status, 404);

    // Path traversal rejection (rawPath sends literal /../ without client URL normalization)
    const traversal1 = await request(stack.webUrl, 'GET', '/../package.json', { rawPath: true });
    assert.equal(traversal1.status, 403);
    const traversal2 = await request(stack.webUrl, 'GET', '/%2e%2e/package.json', { rawPath: true });
    assert.equal(traversal2.status, 403);
  });

  it('startStaticWebServer can run standalone without cloud-api', async () => {
    const dir = makeTempFixtureDir('fulltek-static-solo-');
    cleanups.push(async () => removeDirWithRetries(dir));
    fs.writeFileSync(path.join(dir, 'index.html'), '<h1>SOLO</h1>');

    const srv = await startStaticWebServer({ rootDir: dir, spaFallback: false });
    cleanups.push(async () => srv.stop());

    const ok = await request(srv.url, 'GET', '/');
    assert.equal(ok.status, 200);
    const notFound = await request(srv.url, 'GET', '/unknown-route');
    assert.equal(notFound.status, 404);
  });
});

describe('E2E-M1 Self-Check · Headless Chrome CDP Driver', () => {
  const cleanups = [];

  afterEach(async () => {
    while (cleanups.length > 0) {
      const fn = cleanups.pop();
      await fn();
    }
  });

  it('exercises real Chrome CDP: DOM interaction, AXTree, clean & intentional errors, A4 Blob print, BOM CSV download, 1440x900 PNG screenshot, apiRewrite & clean teardown', async () => {
    assert.equal(
      fs.existsSync(DEFAULT_CHROME_PATH),
      true,
      `Chrome executable missing at ${DEFAULT_CHROME_PATH}`,
    );

    const webDir = makeTempFixtureDir('fulltek-cdp-fixture-');
    const shotDir = makeTempFixtureDir('fulltek-cdp-shots-');
    cleanups.push(async () => removeDirWithRetries(webDir));
    cleanups.push(async () => removeDirWithRetries(shotDir));

    const fixtureHtml = `<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8" />
  <title>FullTek Commercial CDP Fixture</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 24px; background: #F8FAFC; color: #0F172A; }
    .card { padding: 16px; background: #fff; border: 1px solid #E2E8F0; border-radius: 8px; }
    button { padding: 8px 14px; margin-right: 8px; cursor: pointer; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Tableau de bord Commercial</h1>
    <label for="client-search">Rechercher client</label>
    <input id="client-search" type="text" placeholder="Nom du client" />
    <button id="apply-btn" type="button">Appliquer filtre</button>
    <button id="csv-btn" type="button">Exporter CSV</button>
    <button id="print-btn" type="button">PDF / Imprimer</button>
    <button id="err-console-btn" type="button">Trigger Console Error</button>
    <button id="err-throw-btn" type="button">Trigger Uncaught Error</button>
    <button id="api-ping-btn" type="button">Ping Rewritten API</button>
    <button id="vh-btn" type="button" style="visibility:hidden;width:80px;height:30px;">Hidden Button</button>
    <div class="regression-box">
      <code id="tag-code">TAG_CODE</code>
      <label for="code-input">code</label>
      <input id="code-input" type="text" />
      <div role="button" aria-label="Bouton Séparé" style="width:0px;height:0px;overflow:hidden;"></div>
      <div style="height:24px;"></div>
      <flt-semantics id="real-ax-btn" role="button" aria-label="Bouton Séparé" style="display:inline-block;width:120px;height:36px;background:#E2E8F0;cursor:pointer;"></flt-semantics>
    </div>
    <div id="status">Initial</div>
    <div id="api-out"></div>
  </div>
  <script>
    const inputEl = document.getElementById('client-search');
    const statusEl = document.getElementById('status');
    const apiOutEl = document.getElementById('api-out');

    document.getElementById('real-ax-btn').addEventListener('click', () => {
      statusEl.textContent = 'AX_VISIBLE_CLICKED';
    });

    document.getElementById('apply-btn').addEventListener('click', () => {
      statusEl.textContent = 'Filtre: ' + inputEl.value;
    });

    document.getElementById('csv-btn').addEventListener('click', () => {
      const csvContent = '\\uFEFFClient;NIF;Solde_MRU\\r\\n"Mauritanie Négoce; SARL";00123456;15000.50\\r\\n';
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'export_clients_mru.csv';
      document.body.appendChild(a);
      a.click();
      a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 50);
    });

    document.getElementById('print-btn').addEventListener('click', () => {
      const html = '<!doctype html><html><head><style>@page { size: A4; margin: 12mm; }</style></head><body><h1>Facture A4</h1><p>Total: 11 600 MRU</p></body></html>';
      const blob = new Blob([html], { type: 'text/html;charset=utf-8' });
      const url = URL.createObjectURL(blob);
      const w = window.open(url, '_blank');
      if (w) {
        w.focus();
        w.print();
      }
      setTimeout(() => URL.revokeObjectURL(url), 10);
      statusEl.textContent = 'PrintPreviewTriggered';
    });

    document.getElementById('err-console-btn').addEventListener('click', () => {
      console.error('intentional-cdp-console-error', { code: 500 });
    });

    document.getElementById('err-throw-btn').addEventListener('click', () => {
      setTimeout(() => {
        throw new Error('intentional-cdp-uncaught-exception');
      }, 0);
    });

    document.getElementById('api-ping-btn').addEventListener('click', async () => {
      const resp = await fetch('https://api.full-tek.com/health', {
        headers: { 'X-Custom-Header': 'e2e-check' },
      });
      const data = await resp.json();
      apiOutEl.textContent = 'API_OK:' + String(data.ok) + ':PG=' + String(data.pgBackup && data.pgBackup.enabled);
    });
  </script>
</body>
</html>`;

    fs.writeFileSync(path.join(webDir, 'index.html'), fixtureHtml, 'utf8');

    const stack = await startCommercialStack({ serveWeb: true, webDir });
    cleanups.push(async () => stack.stop());

    const browser = await launchHeadlessChrome({
      viewport: { width: 1440, height: 900 },
      apiRewrite: {
        fromOrigin: 'https://api.full-tek.com',
        toOrigin: stack.baseUrl,
      },
    });
    let browserClosed = false;
    cleanups.push(async () => {
      if (!browserClosed) await browser.close();
    });

    assert.ok(browser.pid > 0);
    assert.ok(browser.wsUrl.startsWith('ws://'));
    assert.ok(browser.sessionId);

    await browser.goto(stack.webUrl, { waitUntil: 'load' });
    await browser.waitForSelector('#client-search');
    await browser.waitForText('Tableau de bord Commercial');

    // Clean initial error state
    assert.deepEqual(browser.getConsoleErrors(), []);
    assert.deepEqual(browser.getPageErrors(), []);
    assert.deepEqual(browser.getNetworkErrors(), []);

    // Accessibility tree verification
    const axTree = await browser.getAccessibilityTree();
    assert.ok(Array.isArray(axTree) && axTree.length > 0);
    assert.ok(
      axTree.some(
        (n) => n?.role?.value === 'heading' && String(n?.name?.value).includes('Tableau de bord Commercial'),
      ),
      'AXTree should expose heading "Tableau de bord Commercial"',
    );
    assert.ok(
      axTree.some(
        (n) => n?.role?.value === 'button' && String(n?.name?.value).includes('Exporter CSV'),
      ),
      'AXTree should expose button "Exporter CSV"',
    );

    // Fill input + click selector + verify visible text + waitForCondition
    await browser.fillSelector('#client-search', 'Boutique Chinguetti');
    await browser.clickSelector('#apply-btn');
    await browser.waitForText('Filtre: Boutique Chinguetti');
    await browser.waitForCondition(
      () => document.getElementById('status')?.textContent === 'Filtre: Boutique Chinguetti',
    );

    // Test fillInput by label + pressKey
    await browser.fillInput('Rechercher client', 'Sidi');
    await browser.clickText('Appliquer filtre');
    const bodyText = await browser.getBodyText();
    assert.ok(bodyText.includes('Filtre: Sidi'));

    // Regression: fillInput('code', 'CODE-001') when <code> exists on the page must fill <input>, not <code>
    await browser.fillInput('code', 'CODE-001');
    const codeInputValue = await browser.evaluate("document.getElementById('code-input').value");
    const codeTagText = await browser.evaluate("document.getElementById('tag-code').textContent");
    assert.equal(codeInputValue, 'CODE-001');
    assert.equal(codeTagText, 'TAG_CODE');
    await assert.rejects(
      () => browser.fillSelector('code', 'BAD'),
      /not fillable/i,
    );

    // Regression: clickSelector rejects visibility:hidden elements
    await assert.rejects(
      () => browser.clickSelector('#vh-btn'),
      /not found or invisible/i,
    );

    // Regression: clickText AXTree fallback skips 0x0 node ahead of visible button
    await browser.clickText('Bouton Séparé', { role: 'button' });
    await browser.waitForText('AX_VISIBLE_CLICKED');

    // Still zero errors on clean interactions
    assert.equal(browser.getConsoleErrors().length, 0);
    assert.equal(browser.getPageErrors().length, 0);

    // Test apiRewrite proxy from https://api.full-tek.com/health -> local isolated cloud-api
    await browser.clickSelector('#api-ping-btn');
    await browser.waitForText('API_OK:true:PG=false');

    // Test A4 Blob print preview interception
    await browser.interceptPopupsAndBlobs();
    await browser.clickSelector('#print-btn');
    await browser.waitForText('PrintPreviewTriggered');
    const popups = await browser.getPrintPopups();
    assert.equal(popups.length, 1);
    assert.equal(popups[0].printed, true);
    assert.ok(popups[0].blob && popups[0].blob.text);
    assert.ok(popups[0].blob.text.includes('@page { size: A4; margin: 12mm; }'));
    assert.ok(popups[0].blob.text.includes('11 600 MRU'));

    // Test UTF-8 BOM semicolon CSV download capture & verification
    const dl = await browser.waitForDownload(() => browser.clickSelector('#csv-btn'));
    assert.equal(dl.filename, 'export_clients_mru.csv');
    assert.ok(dl.size > 0);
    assert.ok(fs.existsSync(dl.filePath));
    const parsedCsv = parseCsvWithBom(dl.buffer, { delimiter: ';' });
    assert.equal(parsedCsv.hasBom, true);
    assert.deepEqual(parsedCsv.headers, ['Client', 'NIF', 'Solde_MRU']);
    assert.equal(parsedCsv.rows.length, 1);
    assert.equal(parsedCsv.records[0].Client, 'Mauritanie Négoce; SARL');
    assert.equal(parsedCsv.records[0].Solde_MRU, '15000.50');
    assert.equal(hasCsvFormulaRisk(dl.buffer), false);
    assert.equal(browser.getDownloads().length, 1);

    // Test 1440x900 PNG screenshot capture
    const shotPath = path.join(shotDir, 'selfcheck_1440x900.png');
    const pngBuf = await browser.screenshot(shotPath);
    assert.ok(fs.existsSync(shotPath));
    assert.ok(pngBuf.length > 1000);
    const dims = readPngDimensions(pngBuf);
    assert.deepEqual(dims, { width: 1440, height: 900 });

    // Intentional console.error and uncaught runtime exception MUST be captured
    await browser.clickSelector('#err-console-btn');
    await browser.waitForCondition(() => true);
    await browser.clickSelector('#err-throw-btn');
    // Give setTimeout(..., 0) a moment to fire in page
    await new Promise((r) => setTimeout(r, 150));

    const consoleErrs = browser.getConsoleErrors();
    const pageErrs = browser.getPageErrors();
    assert.ok(
      consoleErrs.some((e) => e.text.includes('intentional-cdp-console-error')),
      `Expected console error capture, got ${JSON.stringify(consoleErrs)}`,
    );
    assert.ok(
      pageErrs.some((e) => e.description.includes('intentional-cdp-uncaught-exception')),
      `Expected page exception capture, got ${JSON.stringify(pageErrs)}`,
    );

    browser.clearErrors();
    assert.equal(browser.getConsoleErrors().length, 0);
    assert.equal(browser.getPageErrors().length, 0);

    await browser.clearPrintPopups();
    assert.equal((await browser.getPrintPopups()).length, 0);

    // Verify concurrent close() awaits full cleanup and cleans up temp Chrome profile & download dirs
    const { userDataDir, downloadDir } = browser;
    const closeInFlight = browser.close();
    await browser.close();
    browserClosed = true;
    await closeInFlight;

    assert.equal(fs.existsSync(userDataDir), false, 'Chrome userDataDir must be removed on close()');
    assert.equal(fs.existsSync(downloadDir), false, 'Chrome downloadDir must be removed on close()');
  });

  it('cleans up fulltek-cdp-* temp dirs when spawn() throws synchronously (e.g. .cmd chromePath)', async () => {
    const cmdDir = makeTempFixtureDir('fulltek-cmd-probe-');
    cleanups.push(async () => removeDirWithRetries(cmdDir));
    const fakeCmd = path.join(cmdDir, 'fake-chrome.cmd');
    fs.writeFileSync(fakeCmd, '@echo off\r\nexit /b 1\r\n', 'utf8');

    const beforeCdpDirs = new Set(
      fs.readdirSync(os.tmpdir()).filter((name) => name.startsWith('fulltek-cdp-')),
    );

    await assert.rejects(() => launchHeadlessChrome({ chromePath: fakeCmd }));

    const afterCdpDirs = fs
      .readdirSync(os.tmpdir())
      .filter((name) => name.startsWith('fulltek-cdp-') && !beforeCdpDirs.has(name));
    assert.deepEqual(afterCdpDirs, [], 'No new fulltek-cdp-* temp dirs may leak on spawn() failure');
  });
});

describe('E2E-M1 Self-Check · Mauritanian Domain Math & CSV Helpers', () => {
  it('round2 handles half-up rounding, negative numbers, and -0 normalization', () => {
    assert.equal(round2(10.005), 10.01);
    assert.equal(round2(10.004), 10);
    assert.equal(round2(-10.005), -10.01);
    assert.equal(round2(35.855), 35.86);
    assert.equal(round2(-35.855), -35.86);
    assert.equal(round2(2.135), 2.14);
    assert.equal(Object.is(round2(-0), 0), true);
  });

  it('calcLineTotals computes standard 16% TVA, discounts, and exempt lines', () => {
    assert.equal(TVA_STANDARD_RATE, 16);

    const std = calcLineTotals({ qty: 3, unitPriceHt: 1000, discountPct: 10 });
    assert.deepEqual(std, {
      grossHt: 3000,
      lineHt: 2700,
      lineTva: 432,
      lineTtc: 3132,
      tvaRate: 16,
    });

    const exempt = calcLineTotals({ qty: 2, unitPriceHt: 1250.5, isExempt: true });
    assert.deepEqual(exempt, {
      grossHt: 2501,
      lineHt: 2501,
      lineTva: 0,
      lineTtc: 2501,
      tvaRate: 0,
    });
  });

  it('calcPmp computes weighted average cost accurately from zero and positive stock', () => {
    const initial = calcPmp({
      currentStock: 0,
      currentPmp: 0,
      receivedQty: 10,
      receivedUnitCostHt: 500,
    });
    assert.deepEqual(initial, { newStock: 10, newPmp: 500 });

    const updated = calcPmp({
      currentStock: 10,
      currentPmp: 500,
      receivedQty: 30,
      receivedUnitCostHt: 700,
    });
    assert.deepEqual(updated, { newStock: 40, newPmp: 650 });

    // Negative stock clamps S0 to 0 per PROJECT.md §3
    const fromNegative = calcPmp({
      currentStock: -2,
      currentPmp: 400,
      receivedQty: 5,
      receivedUnitCostHt: 600,
    });
    assert.deepEqual(fromNegative, { newStock: 3, newPmp: 600 });
  });

  it('parseCsvWithBom and hasCsvFormulaRisk validate UTF-8 BOM, RFC-4180 quotes, and formula injection', () => {
    const safeCsv = Buffer.from(
      '\uFEFFCode;Libellé;Montant\r\n"A-01";"Riz ""Basmati""; 25kg";-250.50\r\n',
      'utf8',
    );
    const parsed = parseCsvWithBom(safeCsv, { delimiter: ';' });
    assert.equal(parsed.hasBom, true);
    assert.deepEqual(parsed.headers, ['Code', 'Libellé', 'Montant']);
    assert.deepEqual(parsed.rows, [['A-01', 'Riz "Basmati"; 25kg', '-250.50']]);
    assert.equal(hasCsvFormulaRisk(safeCsv), false);
    assert.equal(hasCsvFormulaRisk(safeCsv, { allowNegativeNumbers: false }), true);

    const dangerousCsv = '\uFEFFNom;Note\r\nClient;=CMD|\'/C calc\'!A0\r\n';
    assert.equal(hasCsvFormulaRisk(dangerousCsv), true);

    const escapedCsv = '\uFEFFNom;Note\r\nClient;\'=CMD|\'/C calc\'!A0\r\n';
    assert.equal(hasCsvFormulaRisk(escapedCsv), false);

    assert.equal(hasCsvFormulaRisk(['+1+1']), true);
    assert.equal(hasCsvFormulaRisk(['@SUM(1,2)']), true);
    assert.equal(hasCsvFormulaRisk(['\t=1']), true);
    assert.equal(hasCsvFormulaRisk([['H'], [' -cmd|calc']]), true);
    assert.equal(hasCsvFormulaRisk([['H'], [' -1+1']]), true);
    assert.equal(hasCsvFormulaRisk([['H'], ['\n-cmd']]), true);
    assert.equal(hasCsvFormulaRisk([['H'], [' -123.45']]), false);
    assert.equal(hasCsvFormulaRisk([['H'], [' -123.45']], { allowNegativeNumbers: false }), true);
  });
});
