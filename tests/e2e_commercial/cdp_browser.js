'use strict';

const { spawn, execFileSync } = require('node:child_process');
const fs = require('node:fs');
const http = require('node:http');
const https = require('node:https');
const os = require('node:os');
const path = require('node:path');
const { removeDirWithRetries } = require('./helpers');

const DEFAULT_CHROME_PATH = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

const KEY_MAP = Object.freeze({
  Enter: { key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13, text: '\r' },
  Tab: { key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9 },
  Escape: { key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27 },
  Backspace: { key: 'Backspace', code: 'Backspace', windowsVirtualKeyCode: 8 },
  Delete: { key: 'Delete', code: 'Delete', windowsVirtualKeyCode: 46 },
  ArrowDown: { key: 'ArrowDown', code: 'ArrowDown', windowsVirtualKeyCode: 40 },
  ArrowUp: { key: 'ArrowUp', code: 'ArrowUp', windowsVirtualKeyCode: 38 },
  ArrowLeft: { key: 'ArrowLeft', code: 'ArrowLeft', windowsVirtualKeyCode: 37 },
  ArrowRight: { key: 'ArrowRight', code: 'ArrowRight', windowsVirtualKeyCode: 39 },
  Space: { key: ' ', code: 'Space', windowsVirtualKeyCode: 32, text: ' ' },
  ' ': { key: ' ', code: 'Space', windowsVirtualKeyCode: 32, text: ' ' },
});

const DOCUMENT_HOOK_SCRIPT = `
(() => {
  if (window.__e2eHooksInstalled) return;
  window.__e2eHooksInstalled = true;

  const hooks = {
    blobs: new Map(),
    popups: [],
    printCalls: [],
    flutterFirstFrame: false,
  };
  window.__e2eHooks = hooks;

  window.addEventListener('flutter-first-frame', () => {
    hooks.flutterFirstFrame = true;
  }, { passive: true });

  const origCreateObjectURL = URL.createObjectURL.bind(URL);
  URL.createObjectURL = function e2eCreateObjectURL(obj) {
    const url = origCreateObjectURL(obj);
    try {
      if (obj && typeof Blob !== 'undefined' && obj instanceof Blob) {
        const entry = {
          url,
          type: obj.type || '',
          size: obj.size || 0,
          text: null,
          textPromise: null,
        };
        entry.textPromise = obj.text().then((t) => {
          entry.text = t;
          return t;
        }).catch(() => null);
        hooks.blobs.set(url, entry);
      }
    } catch {}
    return url;
  };

  window.open = function e2eWindowOpen(url, target, features) {
    const rec = {
      url: url !== undefined && url !== null ? String(url) : '',
      target: target !== undefined && target !== null ? String(target) : '',
      features: features !== undefined && features !== null ? String(features) : '',
      writtenHtml: '',
      printed: false,
      closed: false,
      ts: Date.now(),
    };
    hooks.popups.push(rec);

    const mockWin = {
      closed: false,
      location: { href: rec.url },
      document: {
        open() { return this; },
        write(str) { rec.writtenHtml += String(str ?? ''); },
        writeln(str) { rec.writtenHtml += String(str ?? '') + '\\n'; },
        close() {},
      },
      focus() {},
      print() {
        rec.printed = true;
        hooks.printCalls.push({ ts: Date.now(), source: 'popup', url: rec.url });
      },
      close() {
        rec.closed = true;
        mockWin.closed = true;
      },
    };
    return mockWin;
  };

  window.print = function e2eWindowPrint() {
    hooks.printCalls.push({ ts: Date.now(), source: 'window', url: window.location.href });
  };
})();
`;

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isFaviconUrl(url) {
  if (!url) return false;
  try {
    return new URL(url).pathname.endsWith('/favicon.ico');
  } catch {
    return String(url).endsWith('/favicon.ico');
  }
}

function formatRemoteObject(arg) {
  if (!arg || typeof arg !== 'object') return String(arg);
  if (Object.prototype.hasOwnProperty.call(arg, 'value')) {
    return typeof arg.value === 'string' ? arg.value : JSON.stringify(arg.value);
  }
  if (arg.description) return String(arg.description);
  if (arg.type) return `[${arg.type}]`;
  return String(arg);
}

function nodeForwardRequest(targetUrl, method, headers, bodyBase64) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(targetUrl);
    const mod = parsed.protocol === 'https:' ? https : http;
    const reqHeaders = {};
    for (const [k, v] of Object.entries(headers || {})) {
      const lower = k.toLowerCase();
      if (lower === 'host' || lower === 'content-length' || lower === 'origin' || lower === 'referer') {
        continue;
      }
      reqHeaders[k] = v;
    }
    const bodyBuf = bodyBase64 ? Buffer.from(bodyBase64, 'base64') : null;
    if (bodyBuf) {
      reqHeaders['Content-Length'] = String(bodyBuf.length);
    }

    const req = mod.request(
      {
        hostname: parsed.hostname,
        port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
        path: `${parsed.pathname}${parsed.search}`,
        method,
        headers: reqHeaders,
        timeout: 15000,
      },
      (res) => {
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => {
          const buf = Buffer.concat(chunks);
          const responseHeaders = [];
          for (const [name, val] of Object.entries(res.headers)) {
            if (val === undefined) continue;
            if (Array.isArray(val)) {
              for (const item of val) responseHeaders.push({ name, value: String(item) });
            } else {
              responseHeaders.push({ name, value: String(val) });
            }
          }
          resolve({
            responseCode: res.statusCode || 200,
            responseHeaders,
            body: buf.toString('base64'),
          });
        });
      },
    );
    req.on('timeout', () => req.destroy(new Error(`apiRewrite timeout for ${targetUrl}`)));
    req.on('error', reject);
    if (bodyBuf) req.write(bodyBuf);
    req.end();
  });
}

async function launchHeadlessChrome(options = {}) {
  const chromePath = options.chromePath || DEFAULT_CHROME_PATH;
  if (!fs.existsSync(chromePath)) {
    throw new Error(`Chrome executable not found at: ${chromePath}`);
  }

  const viewport = {
    width: Number(options.viewport?.width || 1440),
    height: Number(options.viewport?.height || 900),
  };
  const headless = options.headless !== false;
  const timeoutMs = Number(options.timeoutMs || 15000);
  const ignoreFavicon404 = options.ignoreFavicon404 !== false;
  const apiRewrite = options.apiRewrite || null;

  const ownedDirs = [];
  let tmpRoot = null;
  if (!options.userDataDir || !options.downloadDir) {
    tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'fulltek-cdp-'));
    ownedDirs.push(tmpRoot);
  }

  function cleanupOwnedDirs() {
    for (const dir of ownedDirs) {
      try {
        removeDirWithRetries(dir);
      } catch {}
    }
  }

  const resolvedUserDataDir = path.resolve(
    options.userDataDir || path.join(tmpRoot, 'profile'),
  );
  const resolvedDownloadDir = path.resolve(
    options.downloadDir || path.join(tmpRoot, 'downloads'),
  );

  const args = [
    ...(headless ? ['--headless=new'] : []),
    '--remote-debugging-port=0',
    '--disable-gpu',
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-extensions',
    '--disable-background-networking',
    '--disable-popup-blocking',
    `--window-size=${viewport.width},${viewport.height}`,
    `--user-data-dir=${resolvedUserDataDir}`,
    'about:blank',
  ];

  let chrome;
  try {
    fs.mkdirSync(resolvedUserDataDir, { recursive: true });
    fs.mkdirSync(resolvedDownloadDir, { recursive: true });
    chrome = spawn(chromePath, args, {
      stdio: ['ignore', 'pipe', 'pipe'],
      windowsHide: true,
    });
  } catch (err) {
    cleanupOwnedDirs();
    throw err;
  }

  let ws = null;
  let closed = false;
  let closePromise = null;
  let chromeExited = false;
  let exitInfo = null;
  const exitWaiters = [];

  chrome.on('exit', (code, signal) => {
    chromeExited = true;
    exitInfo = { code, signal };
    while (exitWaiters.length > 0) {
      exitWaiters.shift()(exitInfo);
    }
  });

  function waitForChromeExit(ms) {
    if (chromeExited) return Promise.resolve(exitInfo);
    return new Promise((resolve) => {
      const timer = setTimeout(() => resolve(null), ms);
      timer.unref();
      exitWaiters.push((info) => {
        clearTimeout(timer);
        resolve(info);
      });
    });
  }

  function forceKillChrome() {
    if (chromeExited || !chrome.pid) return;
    if (process.platform === 'win32') {
      try {
        execFileSync('taskkill', ['/PID', String(chrome.pid), '/T', '/F'], {
          stdio: 'ignore',
        });
      } catch {}
    } else {
      try {
        chrome.kill('SIGKILL');
      } catch {}
    }
  }

  const stderrChunks = [];
  const wsUrl = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      cleanup();
      reject(
        new Error(
          `Timed out after ${timeoutMs}ms waiting for Chrome DevTools WS URL. stderr: ${stderrChunks.join('')}`,
        ),
      );
    }, timeoutMs);
    timer.unref();

    function onStderr(chunk) {
      const str = chunk.toString('utf8');
      stderrChunks.push(str);
      const joined = stderrChunks.join('');
      const match = joined.match(/DevTools listening on (ws:\/\/[^\s\r\n]+)/);
      if (match) {
        cleanup();
        resolve(match[1]);
      }
    }

    function onError(err) {
      cleanup();
      reject(new Error(`Failed to spawn Chrome: ${err.message}`));
    }

    function onExit(code, signal) {
      cleanup();
      reject(
        new Error(
          `Chrome exited prematurely (code=${code}, signal=${signal}). stderr: ${stderrChunks.join('')}`,
        ),
      );
    }

    function cleanup() {
      clearTimeout(timer);
      chrome.stderr.off('data', onStderr);
      chrome.off('error', onError);
      chrome.off('exit', onExit);
    }

    chrome.stderr.on('data', onStderr);
    chrome.on('error', onError);
    chrome.on('exit', onExit);
  }).catch((err) => {
    forceKillChrome();
    cleanupOwnedDirs();
    throw err;
  });

  let nextId = 1;
  const pending = new Map();
  const eventListeners = new Map();
  let sessionId = null;
  let targetId = null;

  function rejectAllPending(reason) {
    for (const [id, item] of pending.entries()) {
      clearTimeout(item.timer);
      pending.delete(id);
      item.reject(new Error(`${item.method}: ${reason}`));
    }
  }

  function emitEvent(method, params, msg) {
    const set = eventListeners.get(method);
    if (!set) return;
    for (const fn of [...set]) {
      try {
        fn(params, msg);
      } catch {}
    }
  }

  function on(event, handler) {
    let set = eventListeners.get(event);
    if (!set) {
      set = new Set();
      eventListeners.set(event, set);
    }
    set.add(handler);
    return () => {
      set.delete(handler);
    };
  }

  function send(method, params = {}, targetSessionId, callTimeoutMs = timeoutMs) {
    if (!ws || ws.readyState !== WebSocket.OPEN) {
      return Promise.reject(new Error(`CDP WebSocket is not open (calling ${method})`));
    }
    const id = nextId++;
    let effectiveSessionId = targetSessionId;
    if (effectiveSessionId === undefined) {
      const isBrowserDomain = method.startsWith('Target.') || method.startsWith('Browser.');
      effectiveSessionId = isBrowserDomain ? null : sessionId;
    }

    const payload = { id, method, params };
    if (effectiveSessionId) {
      payload.sessionId = effectiveSessionId;
    }

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        pending.delete(id);
        reject(new Error(`CDP timeout after ${callTimeoutMs}ms calling ${method}`));
      }, callTimeoutMs);
      timer.unref();
      pending.set(id, { resolve, reject, timer, method });
      try {
        ws.send(JSON.stringify(payload));
      } catch (err) {
        clearTimeout(timer);
        pending.delete(id);
        reject(err);
      }
    });
  }

  try {
    ws = await new Promise((resolve, reject) => {
      const socket = new WebSocket(wsUrl);
      const timer = setTimeout(() => {
        try { socket.close(); } catch {}
        reject(new Error(`Timed out connecting WebSocket to ${wsUrl}`));
      }, timeoutMs);
      timer.unref();

      socket.addEventListener('open', () => {
        clearTimeout(timer);
        resolve(socket);
      }, { once: true });

      socket.addEventListener('error', (ev) => {
        clearTimeout(timer);
        reject(new Error(`WebSocket connection error: ${ev?.message || 'unknown'}`));
      }, { once: true });
    });

    ws.addEventListener('close', () => {
      rejectAllPending('CDP WebSocket closed');
    });
    ws.addEventListener('error', () => {
      rejectAllPending('CDP WebSocket error');
    });
    ws.addEventListener('message', (event) => {
      let msg;
      try {
        msg = JSON.parse(String(event.data));
      } catch {
        return;
      }
      if (msg.id !== undefined) {
        const entry = pending.get(msg.id);
        if (!entry) return;
        pending.delete(msg.id);
        clearTimeout(entry.timer);
        if (msg.error) {
          entry.reject(
            new Error(
              `CDP ${entry.method} error (${msg.error.code}): ${msg.error.message}`,
            ),
          );
        } else {
          entry.resolve(msg.result || {});
        }
        return;
      }
      if (msg.method) {
        emitEvent(msg.method, msg.params || {}, msg);
      }
    });

    // Attach to existing page target or create one (never use Target.setAutoAttach)
    const { targetInfos } = await send('Target.getTargets', {}, null);
    let pageTarget =
      (targetInfos || []).find((t) => t.type === 'page' && t.url === 'about:blank') ||
      (targetInfos || []).find((t) => t.type === 'page');

    if (!pageTarget) {
      const created = await send('Target.createTarget', { url: 'about:blank' }, null);
      targetId = created.targetId;
    } else {
      targetId = pageTarget.targetId;
    }

    const attached = await send(
      'Target.attachToTarget',
      { targetId, flatten: true },
      null,
    );
    sessionId = attached.sessionId;

    // Exact viewport dimensions for screenshots & rendering
    await send('Emulation.setDeviceMetricsOverride', {
      width: viewport.width,
      height: viewport.height,
      deviceScaleFactor: 1,
      mobile: false,
    });

    // Enable required domains (explicitly omit deprecated Console domain)
    await send('Page.enable');
    await send('Runtime.enable');
    await send('Log.enable');
    await send('DOM.enable');
    await send('Network.enable');
    await send('Accessibility.enable');

    // Allow and uniquely name downloads via GUID in downloadDir
    await send(
      'Browser.setDownloadBehavior',
      {
        behavior: 'allowAndName',
        downloadPath: resolvedDownloadDir,
        eventsEnabled: true,
      },
      null,
    );

    // Install popup/Blob/print/flutter hooks on every future document and current document
    await send('Page.addScriptToEvaluateOnNewDocument', {
      source: DOCUMENT_HOOK_SCRIPT,
    });
    await send('Runtime.evaluate', {
      expression: DOCUMENT_HOOK_SCRIPT,
      returnByValue: true,
    });

    // Optional API origin rewrite (e.g., https://api.full-tek.com -> http://127.0.0.1:port)
    if (apiRewrite && apiRewrite.fromOrigin && apiRewrite.toOrigin) {
      const fromOrigin = String(apiRewrite.fromOrigin).replace(/\/+$/, '');
      const toOrigin = String(apiRewrite.toOrigin).replace(/\/+$/, '');

      await send('Fetch.enable', {
        patterns: [{ urlPattern: `${fromOrigin}/*`, requestStage: 'Request' }],
      });

      on('Fetch.requestPaused', async (params) => {
        const reqUrl = params.request?.url || '';
        const suffix = reqUrl.startsWith(fromOrigin) ? reqUrl.slice(fromOrigin.length) : reqUrl;
        const rewrittenUrl = `${toOrigin}${suffix}`;
        try {
          if (params.request?.method === 'OPTIONS') {
            const reqHeaders = params.request?.headers || {};
            let requestedAllowHeaders = '';
            for (const [k, v] of Object.entries(reqHeaders)) {
              if (k.toLowerCase() === 'access-control-request-headers' && v) {
                requestedAllowHeaders = String(v);
                break;
              }
            }
            await send('Fetch.fulfillRequest', {
              requestId: params.requestId,
              responseCode: 204,
              responseHeaders: [
                { name: 'Access-Control-Allow-Origin', value: '*' },
                { name: 'Access-Control-Allow-Methods', value: 'GET,POST,PATCH,PUT,DELETE,OPTIONS' },
                {
                  name: 'Access-Control-Allow-Headers',
                  value: requestedAllowHeaders || 'Content-Type,Authorization',
                },
              ],
            });
            return;
          }
          const resp = await nodeForwardRequest(
            rewrittenUrl,
            params.request?.method || 'GET',
            params.request?.headers || {},
            params.request?.postData
              ? Buffer.from(params.request.postData, 'utf8').toString('base64')
              : null,
          );
          const hasCors = resp.responseHeaders.some(
            (h) => h.name.toLowerCase() === 'access-control-allow-origin',
          );
          if (!hasCors) {
            resp.responseHeaders.push({ name: 'Access-Control-Allow-Origin', value: '*' });
          }
          await send('Fetch.fulfillRequest', {
            requestId: params.requestId,
            responseCode: resp.responseCode,
            responseHeaders: resp.responseHeaders,
            body: resp.body,
          });
        } catch {
          await send('Fetch.failRequest', {
            requestId: params.requestId,
            errorReason: 'Failed',
          }).catch(() => {});
        }
      });
    }
  } catch (err) {
    try { ws?.close(); } catch {}
    forceKillChrome();
    await waitForChromeExit(1000);
    cleanupOwnedDirs();
    throw err;
  }

  // Telemetry & Error Listeners
  const consoleErrors = [];
  const pageErrors = [];
  const networkErrors = [];
  const inflightRequests = new Set();

  on('Network.requestWillBeSent', (params) => {
    if (params.requestId) inflightRequests.add(params.requestId);
  });
  on('Network.loadingFinished', (params) => {
    if (params.requestId) inflightRequests.delete(params.requestId);
  });
  on('Network.loadingFailed', (params) => {
    if (params.requestId) inflightRequests.delete(params.requestId);
    if (params.canceled) return;
    networkErrors.push({
      type: 'loadingFailed',
      errorText: params.errorText || 'Network loading failed',
      resourceType: params.type || '',
      timestamp: Date.now(),
    });
  });
  on('Network.responseReceived', (params) => {
    if (params.requestId) inflightRequests.delete(params.requestId);
    const resp = params.response || {};
    if (resp.status >= 400) {
      if (ignoreFavicon404 && resp.status === 404 && isFaviconUrl(resp.url)) {
        return;
      }
      networkErrors.push({
        type: 'httpError',
        status: resp.status,
        statusText: resp.statusText || '',
        url: resp.url || '',
        timestamp: Date.now(),
      });
    }
  });

  on('Runtime.consoleAPICalled', (params) => {
    if (params.type !== 'error') return;
    const args = (params.args || []).map(formatRemoteObject);
    consoleErrors.push({
      type: 'console.error',
      text: args.join(' '),
      args,
      timestamp: Date.now(),
    });
  });

  on('Runtime.exceptionThrown', (params) => {
    const details = params.exceptionDetails || {};
    const desc =
      details.exception?.description ||
      details.exception?.value ||
      details.text ||
      'Uncaught exception';
    pageErrors.push({
      type: 'exception',
      text: details.text || 'Uncaught',
      description: String(desc),
      url: details.url || '',
      lineNumber: details.lineNumber ?? null,
      columnNumber: details.columnNumber ?? null,
      timestamp: Date.now(),
    });
  });

  on('Log.entryAdded', (params) => {
    const entry = params.entry || {};
    if (entry.level !== 'error') return;
    if (
      ignoreFavicon404 &&
      entry.source === 'network' &&
      isFaviconUrl(entry.url) &&
      String(entry.text || '').includes('404')
    ) {
      return;
    }
    if (entry.source === 'network') {
      networkErrors.push({
        type: 'log.network',
        text: entry.text || '',
        url: entry.url || '',
        timestamp: Date.now(),
      });
    } else if (entry.source !== 'javascript') {
      consoleErrors.push({
        type: `log.${entry.source || 'browser'}`,
        text: entry.text || '',
        url: entry.url || '',
        timestamp: Date.now(),
      });
    }
  });

  // Download tracking
  const inFlightDownloads = new Map();
  const downloads = [];
  const downloadWaiters = [];

  on('Browser.downloadWillBegin', (params) => {
    inFlightDownloads.set(params.guid, {
      guid: params.guid,
      url: params.url || '',
      suggestedFilename: params.suggestedFilename || '',
      startedAt: Date.now(),
    });
  });

  on('Browser.downloadProgress', (params) => {
    const meta = inFlightDownloads.get(params.guid) || {
      guid: params.guid,
      url: '',
      suggestedFilename: '',
    };
    if (params.state === 'completed') {
      inFlightDownloads.delete(params.guid);
      const filePath = params.filePath || path.join(resolvedDownloadDir, params.guid);
      let buffer = Buffer.alloc(0);
      for (let attempt = 0; attempt < 10; attempt += 1) {
        try {
          if (fs.existsSync(filePath)) {
            buffer = fs.readFileSync(filePath);
            break;
          }
        } catch {}
        Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 20);
      }
      const record = {
        guid: params.guid,
        filename: meta.suggestedFilename || path.basename(filePath),
        filePath,
        url: meta.url,
        size: buffer.length,
        totalBytes: params.totalBytes ?? buffer.length,
        receivedBytes: params.receivedBytes ?? buffer.length,
        buffer,
        text: buffer.toString('utf8'),
      };
      downloads.push(record);
      for (const waiter of [...downloadWaiters]) {
        waiter.resolve(record);
      }
    } else if (params.state === 'canceled') {
      inFlightDownloads.delete(params.guid);
      for (const waiter of [...downloadWaiters]) {
        waiter.reject(new Error(`Download canceled: ${meta.suggestedFilename || params.guid}`));
      }
    }
  });

  // -------------------------------------------------------------------------
  // High-level Browser API
  // -------------------------------------------------------------------------

  async function evaluate(expr, opts = {}) {
    const res = await send('Runtime.evaluate', {
      expression: String(expr),
      awaitPromise: opts.awaitPromise !== false,
      userGesture: Boolean(opts.userGesture),
      returnByValue: opts.returnByValue !== false,
    });
    if (res.exceptionDetails) {
      const msg =
        res.exceptionDetails.exception?.description ||
        res.exceptionDetails.text ||
        'Evaluation failed';
      throw new Error(`evaluate failed: ${msg}`);
    }
    return res.result ? res.result.value : undefined;
  }

  async function ensureDocumentHooks() {
    await evaluate(DOCUMENT_HOOK_SCRIPT);
  }

  async function goto(url, opts = {}) {
    const navTimeout = Number(opts.timeoutMs || timeoutMs);
    const waitUntil = opts.waitUntil || 'load';

    let loadResolved = false;
    let cancelLoadWait = () => {};
    const loadPromise = new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        off();
        reject(new Error(`Timed out after ${navTimeout}ms waiting for load on ${url}`));
      }, navTimeout);
      timer.unref();
      const off = on('Page.loadEventFired', () => {
        loadResolved = true;
        clearTimeout(timer);
        off();
        resolve();
      });
      cancelLoadWait = () => {
        clearTimeout(timer);
        off();
      };
    });

    let navRes;
    try {
      navRes = await send('Page.navigate', { url });
    } catch (err) {
      cancelLoadWait();
      throw err;
    }
    if (navRes.errorText) {
      cancelLoadWait();
      throw new Error(`Navigation error (${url}): ${navRes.errorText}`);
    }
    if (!loadResolved) {
      await loadPromise;
    }
    await ensureDocumentHooks();

    if (waitUntil === 'networkidle') {
      const idleDeadline = Date.now() + navTimeout;
      let quietSince = null;
      while (Date.now() < idleDeadline) {
        if (inflightRequests.size === 0) {
          if (quietSince === null) quietSince = Date.now();
          if (Date.now() - quietSince >= 300) break;
        } else {
          quietSince = null;
        }
        await delay(50);
      }
    } else if (waitUntil === 'flutter') {
      await waitForFlutterReady(opts.flutterTimeoutMs || Math.max(navTimeout, 30000));
    }
  }

  async function enableFlutterSemantics() {
    await send('Accessibility.enable');
    await evaluate(`(() => {
      const placeholder = document.querySelector('flt-semantics-placeholder');
      if (placeholder) {
        placeholder.click();
        return true;
      }
      return false;
    })()`);
  }

  async function waitForFlutterReady(waitMs = 30000) {
    const deadline = Date.now() + waitMs;
    while (Date.now() < deadline) {
      const ready = await evaluate(`Boolean(
        (window.__e2eHooks && window.__e2eHooks.flutterFirstFrame) ||
        document.querySelector('flutter-view, flt-glass-pane')
      )`).catch(() => false);
      if (ready) {
        await enableFlutterSemantics().catch(() => {});
        await delay(100);
        return true;
      }
      await delay(100);
    }
    throw new Error(`Timed out after ${waitMs}ms waiting for Flutter Web ready`);
  }

  async function getBodyText() {
    const text = await evaluate(
      'document.body ? (document.body.innerText || document.body.textContent || "") : ""',
    );
    return String(text || '');
  }

  async function getAccessibilityTree() {
    const res = await send('Accessibility.getFullAXTree');
    return Array.isArray(res.nodes) ? res.nodes : [];
  }

  function matchesText(haystack, textOrRegex, exact = false) {
    const str = String(haystack ?? '');
    if (textOrRegex instanceof RegExp) {
      return textOrRegex.test(str);
    }
    const needle = String(textOrRegex);
    return exact ? str.trim() === needle.trim() : str.includes(needle);
  }

  async function waitForSelector(selector, waitMs = 10000) {
    const deadline = Date.now() + waitMs;
    while (Date.now() < deadline) {
      const found = await evaluate(
        `Boolean(document.querySelector(${JSON.stringify(selector)}))`,
      ).catch(() => false);
      if (found) return true;
      await delay(50);
    }
    throw new Error(`Timed out after ${waitMs}ms waiting for selector: ${selector}`);
  }

  async function waitForText(textOrRegex, waitMs = 10000) {
    const deadline = Date.now() + waitMs;
    while (Date.now() < deadline) {
      const bodyText = await getBodyText().catch(() => '');
      if (matchesText(bodyText, textOrRegex, false)) return true;

      const axNodes = await getAccessibilityTree().catch(() => []);
      const inAx = axNodes.some(
        (n) => n?.name?.value && matchesText(n.name.value, textOrRegex, false),
      );
      if (inAx) return true;

      await delay(60);
    }
    throw new Error(`Timed out after ${waitMs}ms waiting for text: ${String(textOrRegex)}`);
  }

  async function waitForCondition(fnOrExpr, waitMs = 10000) {
    const expr =
      typeof fnOrExpr === 'function'
        ? `(${fnOrExpr.toString()})()`
        : String(fnOrExpr);
    const deadline = Date.now() + waitMs;
    while (Date.now() < deadline) {
      const val = await evaluate(`Boolean(${expr})`).catch(() => false);
      if (val) return true;
      await delay(50);
    }
    throw new Error(`Timed out after ${waitMs}ms waiting for condition: ${expr}`);
  }

  async function clickPoint(x, y) {
    const px = Math.round(Number(x));
    const py = Math.round(Number(y));
    await send('Input.dispatchMouseEvent', {
      type: 'mouseMoved',
      x: px,
      y: py,
      button: 'none',
    });
    await send('Input.dispatchMouseEvent', {
      type: 'mousePressed',
      x: px,
      y: py,
      button: 'left',
      clickCount: 1,
    });
    await send('Input.dispatchMouseEvent', {
      type: 'mouseReleased',
      x: px,
      y: py,
      button: 'left',
      clickCount: 1,
    });
  }

  async function clickSelector(selector) {
    const rect = await evaluate(`(() => {
      const el = document.querySelector(${JSON.stringify(selector)});
      if (!el) return null;
      const style = window.getComputedStyle(el);
      if (style.display === 'none' || style.visibility === 'hidden') return null;
      el.scrollIntoView({ block: 'center', inline: 'center' });
      const r = el.getBoundingClientRect();
      return { left: r.left, top: r.top, width: r.width, height: r.height };
    })()`);
    if (!rect || rect.width <= 0 || rect.height <= 0) {
      throw new Error(`clickSelector: element not found or invisible for selector "${selector}"`);
    }
    await clickPoint(rect.left + rect.width / 2, rect.top + rect.height / 2);
  }

  async function getBoxCenterForBackendNode(backendNodeId) {
    let model;
    try {
      ({ model } = await send('DOM.getBoxModel', { backendNodeId }));
    } catch {
      return null;
    }
    const quad = model?.content || model?.border;
    if (!quad || quad.length < 8) return null;
    const xs = [quad[0], quad[2], quad[4], quad[6]];
    const ys = [quad[1], quad[3], quad[5], quad[7]];
    const minX = Math.min(...xs);
    const maxX = Math.max(...xs);
    const minY = Math.min(...ys);
    const maxY = Math.max(...ys);
    const width = maxX - minX;
    const height = maxY - minY;
    if (width <= 0 || height <= 0) return null;
    return {
      x: (minX + maxX) / 2,
      y: (minY + maxY) / 2,
      width,
      height,
    };
  }

  async function clickText(textOrRegex, opts = {}) {
    const exact = Boolean(opts.exact);
    const serializedPattern =
      textOrRegex instanceof RegExp
        ? { source: textOrRegex.source, flags: textOrRegex.flags, isRegex: true }
        : { needle: String(textOrRegex), isRegex: false };

    const rect = await evaluate(`(() => {
      const pat = ${JSON.stringify(serializedPattern)};
      const exact = ${JSON.stringify(exact)};
      const match = (s) => {
        const str = String(s || '').trim();
        if (pat.isRegex) return new RegExp(pat.source, pat.flags).test(str);
        return exact ? str === pat.needle.trim() : str.includes(pat.needle);
      };
      const candidates = Array.from(document.querySelectorAll(
        'button, a, [role="button"], [role="menuitem"], [role="tab"], input[type="submit"], label, span, div, p, li, td'
      ));
      const matches = [];
      for (const el of candidates) {
        const txt = el.innerText || el.textContent || el.value || '';
        if (!match(txt)) continue;
        const r = el.getBoundingClientRect();
        if (r.width <= 0 || r.height <= 0) continue;
        const style = window.getComputedStyle(el);
        if (style.visibility === 'hidden' || style.display === 'none') continue;
        matches.push({ el, area: r.width * r.height, len: txt.trim().length });
      }
      if (matches.length === 0) return null;
      matches.sort((a, b) => a.len - b.len || a.area - b.area);
      const chosen = matches[0].el;
      chosen.scrollIntoView({ block: 'center', inline: 'center' });
      const r = chosen.getBoundingClientRect();
      return { left: r.left, top: r.top, width: r.width, height: r.height };
    })()`);

    if (rect) {
      await clickPoint(rect.left + rect.width / 2, rect.top + rect.height / 2);
      return;
    }

    // Fallback to Accessibility tree (e.g. Flutter Web semantics)
    const axNodes = await getAccessibilityTree();
    const matchingAxNodes = axNodes.filter((n) => {
      if (!n || n.ignored) return false;
      if (opts.role && n?.role?.value !== opts.role) return false;
      const nameVal = n?.name?.value;
      return Boolean(nameVal && matchesText(nameVal, textOrRegex, exact) && n.backendDOMNodeId);
    });
    for (const matchNode of matchingAxNodes) {
      const center = await getBoxCenterForBackendNode(matchNode.backendDOMNodeId);
      if (center && center.width > 0 && center.height > 0) {
        await clickPoint(center.x, center.y);
        return;
      }
    }

    throw new Error(`clickText: no matching visible element or AX node for ${String(textOrRegex)}`);
  }

  async function clearAndTypeValue(value) {
    const str = String(value ?? '');
    // Select all with Ctrl+A & Backspace
    await send('Input.dispatchKeyEvent', {
      type: 'keyDown',
      key: 'a',
      code: 'KeyA',
      modifiers: 2, // Ctrl
      windowsVirtualKeyCode: 65,
    });
    await send('Input.dispatchKeyEvent', {
      type: 'keyUp',
      key: 'a',
      code: 'KeyA',
      modifiers: 2,
      windowsVirtualKeyCode: 65,
    });
    await pressKey('Backspace');
    if (str.length > 0) {
      await send('Input.insertText', { text: str });
    }
  }

  async function fillSelector(selector, value) {
    const info = await evaluate(`(() => {
      const el = document.querySelector(${JSON.stringify(selector)});
      if (!el) return null;
      const tag = el.tagName ? el.tagName.toUpperCase() : '';
      const fillable =
        tag === 'INPUT' ||
        tag === 'TEXTAREA' ||
        tag === 'SELECT' ||
        Boolean(el.isContentEditable);
      if (!fillable) {
        return { fillable: false, tag: tag.toLowerCase() };
      }
      el.scrollIntoView({ block: 'center', inline: 'center' });
      const r = el.getBoundingClientRect();
      return {
        fillable: true,
        tag: tag.toLowerCase(),
        isContentEditable: Boolean(el.isContentEditable),
        left: r.left,
        top: r.top,
        width: r.width,
        height: r.height,
      };
    })()`);
    if (!info) {
      throw new Error(`fillSelector: element not found for selector "${selector}"`);
    }
    if (!info.fillable) {
      throw new Error(
        `fillSelector: element matching "${selector}" (<${info.tag}>) is not fillable (expected INPUT, TEXTAREA, SELECT, or contentEditable)`,
      );
    }

    if (info.tag === 'select') {
      await evaluate(`(() => {
        const el = document.querySelector(${JSON.stringify(selector)});
        el.value = ${JSON.stringify(String(value ?? ''))};
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      })()`);
      return;
    }

    if (info.width > 0 && info.height > 0) {
      await clickPoint(info.left + info.width / 2, info.top + info.height / 2);
    } else {
      await evaluate(`document.querySelector(${JSON.stringify(selector)})?.focus()`);
    }
    if (info.isContentEditable) {
      await clearAndTypeValue(value);
    } else {
      await evaluate(`(() => {
        const el = document.querySelector(${JSON.stringify(selector)});
        if (el && 'value' in el) el.value = '';
      })()`);
      if (String(value ?? '').length > 0) {
        await send('Input.insertText', { text: String(value) });
      }
    }
    await evaluate(`(() => {
      const el = document.querySelector(${JSON.stringify(selector)});
      if (el) {
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      }
    })()`);
  }

  async function fillInput(labelOrSelector, value) {
    const looksLikeSelector = await evaluate(`(() => {
      try {
        const el = document.querySelector(${JSON.stringify(labelOrSelector)});
        if (!el) return false;
        const tag = el.tagName ? el.tagName.toUpperCase() : '';
        return (
          tag === 'INPUT' ||
          tag === 'TEXTAREA' ||
          tag === 'SELECT' ||
          Boolean(el.isContentEditable)
        );
      } catch {
        return false;
      }
    })()`);
    if (looksLikeSelector) {
      await fillSelector(labelOrSelector, value);
      return;
    }

    const rect = await evaluate(`(() => {
      const labelText = ${JSON.stringify(String(labelOrSelector))};
      let target = null;
      for (const lbl of document.querySelectorAll('label')) {
        if ((lbl.innerText || lbl.textContent || '').includes(labelText)) {
          const forId = lbl.getAttribute('for');
          target = (forId && document.getElementById(forId)) || lbl.querySelector('input, textarea, select');
          if (target) break;
        }
      }
      if (!target) {
        for (const el of document.querySelectorAll('input, textarea')) {
          const ph = el.getAttribute('placeholder') || '';
          const aria = el.getAttribute('aria-label') || '';
          const name = el.getAttribute('name') || '';
          if (ph.includes(labelText) || aria.includes(labelText) || name.includes(labelText)) {
            target = el;
            break;
          }
        }
      }
      if (!target) return null;
      target.scrollIntoView({ block: 'center', inline: 'center' });
      target.focus();
      if ('value' in target) target.value = '';
      const r = target.getBoundingClientRect();
      return { left: r.left, top: r.top, width: r.width, height: r.height };
    })()`);

    if (rect && rect.width > 0 && rect.height > 0) {
      await clickPoint(rect.left + rect.width / 2, rect.top + rect.height / 2);
      await clearAndTypeValue(value);
      return;
    }

    const axNodes = await getAccessibilityTree();
    const axInputs = axNodes.filter(
      (n) =>
        n &&
        !n.ignored &&
        ['textbox', 'searchbox', 'combobox'].includes(n?.role?.value) &&
        n?.name?.value &&
        String(n.name.value).includes(String(labelOrSelector)) &&
        n.backendDOMNodeId,
    );
    for (const axInput of axInputs) {
      const center = await getBoxCenterForBackendNode(axInput.backendDOMNodeId);
      if (center && center.width > 0 && center.height > 0) {
        await clickPoint(center.x, center.y);
        await clearAndTypeValue(value);
        return;
      }
    }

    throw new Error(`fillInput: could not locate input for "${labelOrSelector}"`);
  }

  async function pressKey(key) {
    const spec = KEY_MAP[key] || {
      key: String(key),
      code: String(key).length === 1 ? `Key${String(key).toUpperCase()}` : String(key),
      windowsVirtualKeyCode: String(key).length === 1 ? String(key).toUpperCase().charCodeAt(0) : 0,
      text: String(key).length === 1 ? String(key) : undefined,
    };
    await send('Input.dispatchKeyEvent', {
      type: 'keyDown',
      key: spec.key,
      code: spec.code,
      windowsVirtualKeyCode: spec.windowsVirtualKeyCode,
      ...(spec.text ? { text: spec.text } : {}),
    });
    await send('Input.dispatchKeyEvent', {
      type: 'keyUp',
      key: spec.key,
      code: spec.code,
      windowsVirtualKeyCode: spec.windowsVirtualKeyCode,
    });
  }

  async function screenshot(outPath) {
    const res = await send('Page.captureScreenshot', { format: 'png' });
    const buf = Buffer.from(res.data || '', 'base64');
    if (outPath) {
      const resolvedOut = path.resolve(outPath);
      fs.mkdirSync(path.dirname(resolvedOut), { recursive: true });
      fs.writeFileSync(resolvedOut, buf);
    }
    return buf;
  }

  async function waitForDownload(triggerFn, waitMs = 15000) {
    const startIdx = downloads.length;
    let waiterObj = null;
    let clearWaitTimer = () => {};
    const waitPromise = new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        const idx = downloadWaiters.indexOf(waiterObj);
        if (idx >= 0) downloadWaiters.splice(idx, 1);
        reject(new Error(`Timed out after ${waitMs}ms waiting for download`));
      }, waitMs);
      timer.unref();
      clearWaitTimer = () => clearTimeout(timer);
      waiterObj = {
        resolve: (rec) => {
          clearTimeout(timer);
          const idx = downloadWaiters.indexOf(waiterObj);
          if (idx >= 0) downloadWaiters.splice(idx, 1);
          resolve(rec);
        },
        reject: (err) => {
          clearTimeout(timer);
          const idx = downloadWaiters.indexOf(waiterObj);
          if (idx >= 0) downloadWaiters.splice(idx, 1);
          reject(err);
        },
      };
      downloadWaiters.push(waiterObj);
    });

    try {
      if (typeof triggerFn === 'function') {
        await triggerFn();
      }
    } catch (err) {
      clearWaitTimer();
      const idx = downloadWaiters.indexOf(waiterObj);
      if (idx >= 0) downloadWaiters.splice(idx, 1);
      throw err;
    }

    if (downloads.length > startIdx) {
      clearWaitTimer();
      const idx = downloadWaiters.indexOf(waiterObj);
      if (idx >= 0) downloadWaiters.splice(idx, 1);
      return downloads[startIdx];
    }

    return waitPromise;
  }

  async function getPrintPopups() {
    const data = await evaluate(`(async () => {
      const hooks = window.__e2eHooks;
      if (!hooks) return { popups: [], printCalls: [], blobs: [] };
      const blobs = [];
      for (const [url, entry] of hooks.blobs.entries()) {
        if (entry.text === null && entry.textPromise) {
          try { await entry.textPromise; } catch {}
        }
        blobs.push({ url, type: entry.type, size: entry.size, text: entry.text });
      }
      const blobMap = new Map(blobs.map((b) => [b.url, b]));
      const popups = hooks.popups.map((p) => ({
        ...p,
        blob: blobMap.get(p.url) || null,
        printCount: hooks.printCalls.length,
      }));
      return { popups, printCalls: hooks.printCalls, blobs };
    })()`);
    return data?.popups || [];
  }

  async function interceptPopupsAndBlobs() {
    await ensureDocumentHooks();
    const popups = await getPrintPopups();
    const extra = await evaluate(`(() => {
      const hooks = window.__e2eHooks;
      if (!hooks) return { printCalls: [], blobs: [] };
      const blobs = [];
      for (const [url, entry] of hooks.blobs.entries()) {
        blobs.push({ url, type: entry.type, size: entry.size, text: entry.text });
      }
      return { printCalls: hooks.printCalls, blobs };
    })()`);
    return {
      popups,
      printCalls: extra?.printCalls || [],
      blobs: extra?.blobs || [],
    };
  }

  async function clearPrintPopups() {
    await evaluate(`(() => {
      const hooks = window.__e2eHooks;
      if (!hooks) return;
      hooks.popups.length = 0;
      hooks.printCalls.length = 0;
      hooks.blobs.clear();
    })()`);
  }

  function close() {
    if (closePromise) return closePromise;
    closePromise = (async () => {
      if (closed) return;
      closed = true;

      try {
        if (ws && ws.readyState === WebSocket.OPEN) {
          await send('Browser.close', {}, null, 3000).catch(() => {});
        }
      } catch {}

      try {
        if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
          ws.close();
        }
      } catch {}

      const exited = await waitForChromeExit(2000);
      if (!exited) {
        forceKillChrome();
        await waitForChromeExit(1500);
      }

      cleanupOwnedDirs();
    })();
    return closePromise;
  }

  return {
    pid: chrome.pid,
    wsUrl,
    userDataDir: resolvedUserDataDir,
    downloadDir: resolvedDownloadDir,
    sessionId,
    targetId,
    send,
    on,
    goto,
    waitForFlutterReady,
    enableFlutterSemantics,
    waitForText,
    waitForSelector,
    waitForCondition,
    waitForFunction: waitForCondition,
    evaluate,
    clickSelector,
    clickText,
    clickPoint,
    fillSelector,
    fillInput,
    pressKey,
    getAccessibilityTree,
    getAXTree: getAccessibilityTree,
    getBodyText,
    getVisibleText: getBodyText,
    screenshot,
    getConsoleErrors: () => [...consoleErrors],
    getPageErrors: () => [...pageErrors],
    getNetworkErrors: () => [...networkErrors],
    clearErrors: () => {
      consoleErrors.length = 0;
      pageErrors.length = 0;
      networkErrors.length = 0;
    },
    getDownloads: () => [...downloads],
    waitForDownload,
    interceptPopupsAndBlobs,
    getPrintPopups,
    clearPrintPopups,
    close,
  };
}

module.exports = {
  DEFAULT_CHROME_PATH,
  launchHeadlessChrome,
};
