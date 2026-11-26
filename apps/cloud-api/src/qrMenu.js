/**
 * Full-Tek Resto — Module Menu QR Code, Commande en Ligne & Appel Serveur
 *
 * Routes Publiques (sans JWT) :
 *  - GET  /m/:tenantCode                       -> Web App Mobile Client bilingue FR/AR
 *  - GET  /public/menu/:tenantCode             -> Catalogue JSON temps reel, zones & config QR
 *  - POST /public/orders/:tenantCode           -> Creation commande QR Table / Emporter / Livraison
 *  - GET  /public/orders/:tenantCode/:code     -> Suivi temps reel statut commande client
 *  - POST /public/call-waiter/:tenantCode      -> Appel serveur / Demande d'addition depuis table
 *
 * Routes POS (JWT Tenant) :
 *  - GET  /api/pos/qr/settings                 -> Lire parametres Menu QR
 *  - PUT  /api/pos/qr/settings                 -> Sauvegarder parametres Menu QR
 *  - GET  /api/pos/qr/incoming                 -> Commandes QR en attente + appels serveur actifs
 *  - POST /api/pos/qr/orders/:code/accept      -> Accepter une commande QR dans la caisse
 *  - POST /api/pos/qr/orders/:code/reject      -> Refuser une commande QR
 *  - POST /api/pos/qr/alerts/:id/ack           -> Acquitter un appel serveur / addition
 */

function parseJsonSafe(raw, fallback = []) {
  try {
    const v = JSON.parse(raw);
    return v ?? fallback;
  } catch {
    return fallback;
  }
}

function escapeHtml(str) {
  return String(str ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function ensureQrMenuSchema(database) {
  database.exec(`
    CREATE TABLE IF NOT EXISTS qr_settings (
      tenant_id INTEGER PRIMARY KEY,
      enabled INTEGER NOT NULL DEFAULT 1,
      allow_ordering INTEGER NOT NULL DEFAULT 1,
      require_pos_validation INTEGER NOT NULL DEFAULT 1,
      whatsapp_number TEXT NOT NULL DEFAULT '',
      welcome_fr TEXT NOT NULL DEFAULT 'Bienvenue ! Scannez, choisissez et commandez en un clic.',
      welcome_ar TEXT NOT NULL DEFAULT 'مرحباً بكم! تصفحوا القائمة واطلبوا بضغطة زر.',
      updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS qr_alerts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER NOT NULL,
      table_name TEXT NOT NULL,
      kind TEXT NOT NULL DEFAULT 'waiter',
      note TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL DEFAULT 'OPEN',
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS qr_payment_receipts (
      order_id INTEGER PRIMARY KEY,
      tenant_id INTEGER NOT NULL,
      pay_method TEXT NOT NULL DEFAULT 'PENDING',
      payment_ref TEXT NOT NULL DEFAULT '',
      receipt_image_data TEXT NOT NULL DEFAULT '',
      verified INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );

    CREATE INDEX IF NOT EXISTS idx_qr_alerts_tenant_status
      ON qr_alerts (tenant_id, status, created_at DESC);
  `);
}

function getOrCreateQrSettings(database, tenant) {
  ensureQrMenuSchema(database);
  const row = database
    .prepare('SELECT * FROM qr_settings WHERE tenant_id = ?')
    .get(tenant.id);
  if (row) {
    return {
      enabled: Number(row.enabled) === 1,
      allowOrdering: Number(row.allow_ordering) === 1,
      requirePosValidation: Number(row.require_pos_validation) === 1,
      whatsappNumber: String(row.whatsapp_number || tenant.phone || ''),
      welcomeFr: String(row.welcome_fr || ''),
      welcomeAr: String(row.welcome_ar || ''),
    };
  }
  const nowIso = new Date().toISOString();
  database
    .prepare(`
      INSERT OR IGNORE INTO qr_settings (tenant_id, enabled, allow_ordering, require_pos_validation, whatsapp_number, updated_at)
      VALUES (?, 1, 1, 1, ?, ?)
    `)
    .run(tenant.id, String(tenant.phone || ''), nowIso);
  return {
    enabled: true,
    allowOrdering: true,
    requirePosValidation: true,
    whatsappNumber: String(tenant.phone || ''),
    welcomeFr: 'Bienvenue ! Scannez, choisissez et commandez en un clic.',
    welcomeAr: 'مرحباً بكم! تصفحوا القائمة واطلبوا بضغطة زر.',
  };
}

function findTenantByCode(database, rawCode) {
  const clean = String(rawCode || '').trim();
  if (!clean) return null;
  return (
    database
      .prepare('SELECT * FROM tenants WHERE UPPER(tenant_code) = UPPER(?) LIMIT 1')
      .get(clean) ||
    database
      .prepare('SELECT * FROM tenants WHERE LOWER(username) = LOWER(?) LIMIT 1')
      .get(clean) ||
    null
  );
}

function buildPublicMenuPayload(database, tenant, DEFAULT_DELIVERY_ZONES) {
  const settings = getOrCreateQrSettings(database, tenant);
  const categories = database
    .prepare(
      'SELECT id, name_fr, name_ar, name_en, icon, image_url, sort_order FROM categories WHERE tenant_id = ? AND active = 1 ORDER BY sort_order ASC, id ASC'
    )
    .all(tenant.id)
    .map((c) => ({
      id: c.id,
      nameFr: c.name_fr,
      nameAr: c.name_ar || c.name_fr,
      nameEn: c.name_en || c.name_fr,
      icon: c.icon || '🍽',
      imageUrl: c.image_url || '',
    }));

  const products = database
    .prepare(
      `SELECT id, category_id, sku, name_fr, name_ar, name_en, price_retail, kitchen_station,
              is_out_of_stock, image_url, modifiers_json
       FROM products
       WHERE tenant_id = ? AND active = 1
       ORDER BY id ASC`
    )
    .all(tenant.id)
    .map((pr) => ({
      id: pr.id,
      categoryId: pr.category_id,
      sku: pr.sku,
      nameFr: pr.name_fr,
      nameAr: pr.name_ar || pr.name_fr,
      nameEn: pr.name_en || pr.name_fr,
      priceMru: Number(pr.price_retail || 0),
      kitchenStation: pr.kitchen_station || 'KITCHEN',
      available: Number(pr.is_out_of_stock || 0) === 0,
      imageUrl: pr.image_url || '',
      modifiers: parseJsonSafe(pr.modifiers_json, []),
    }));

  const parsedZones = parseJsonSafe(tenant.delivery_zones_json, []);
  const deliveryZones =
    Array.isArray(parsedZones) && parsedZones.length > 0
      ? parsedZones
      : DEFAULT_DELIVERY_ZONES;

  const parsedPayMethods = parseJsonSafe(tenant.pay_methods_json, []);
  const payMethods = Array.isArray(parsedPayMethods) && parsedPayMethods.length > 0
    ? parsedPayMethods
    : ['Cash', 'Bankily', 'Masrvi', 'Sedad', 'BIM-Bank', 'Click'];

  return {
    tenant: {
      tenantCode: tenant.tenant_code,
      name: tenant.name,
      city: tenant.city || 'Nouakchott',
      district: tenant.district || '',
      address: tenant.address || '',
      phone: tenant.phone || '',
      freeDeliveryAboveMru: Number(tenant.free_delivery_above_mru ?? 1500),
      payMethods,
    },
    settings,
    deliveryZones,
    categories,
    products,
  };
}

function renderMobileMenuHtml({ tenant, initialTable }) {
  const safeName = escapeHtml(tenant.name);
  const safeTable = escapeHtml(initialTable || '');

  return `<!DOCTYPE html>
<html lang="fr" dir="ltr" data-theme="dark">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" />
  <meta name="theme-color" content="#090f1c" />
  <title>${safeName} · Menu QR & Commande</title>
  <style>
    :root {
      --bg: #090f1c;
      --bg-hero: radial-gradient(circle at 18% 12%, rgba(245,158,11,0.22), transparent 46%),
                 radial-gradient(circle at 86% 18%, rgba(16,185,129,0.22), transparent 50%),
                 linear-gradient(160deg, #0d1629 0%, #090f1c 100%);
      --surface: #121b2f;
      --surface-alt: #1a2640;
      --glass: rgba(12, 19, 35, 0.86);
      --border: rgba(148, 163, 184, 0.16);
      --text: #f8fafc;
      --muted: #94a3b8;
      --primary: #10b981;
      --primary-2: #059669;
      --primary-ink: #032215;
      --gold: #f59e0b;
      --danger: #ef4444;
      --shadow: 0 14px 34px rgba(0, 0, 0, 0.38);
    }
    [data-theme="light"] {
      --bg: #f6f7fb;
      --bg-hero: radial-gradient(circle at 18% 12%, rgba(245,158,11,0.16), transparent 46%),
                 radial-gradient(circle at 86% 18%, rgba(16,185,129,0.16), transparent 50%),
                 linear-gradient(160deg, #ffffff 0%, #eef2f7 100%);
      --surface: #ffffff;
      --surface-alt: #f1f5f9;
      --glass: rgba(255, 255, 255, 0.90);
      --border: rgba(15, 23, 42, 0.10);
      --text: #0f172a;
      --muted: #64748b;
      --primary: #059669;
      --primary-2: #047857;
      --primary-ink: #ffffff;
      --gold: #d97706;
      --danger: #dc2626;
      --shadow: 0 10px 26px rgba(15, 23, 42, 0.08);
    }
    * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Noto Sans Arabic', sans-serif;
      background: var(--bg);
      color: var(--text);
      padding-bottom: 104px;
      transition: background 0.2s ease, color 0.2s ease;
    }
    .shell { max-width: 820px; margin: 0 auto; }

    /* Hero Header */
    .hero {
      background: var(--bg-hero);
      border-bottom: 1px solid var(--border);
      padding: 18px 16px 16px;
    }
    .hero-top { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; }
    .brand { display: flex; align-items: center; gap: 12px; min-width: 0; }
    .brand-mark {
      width: 50px; height: 50px; border-radius: 16px;
      background: linear-gradient(135deg, #10b981 0%, #059669 65%, #f59e0b 140%);
      display: flex; align-items: center; justify-content: center;
      font-size: 24px; color: #fff; flex-shrink: 0;
      box-shadow: 0 8px 20px rgba(16,185,129,0.32);
    }
    .brand-title {
      font-weight: 900; font-size: 19px; letter-spacing: -0.2px;
      line-height: 1.2;
    }
    .brand-meta {
      display: flex; align-items: center; gap: 8px; flex-wrap: wrap;
      margin-top: 4px; font-size: 12px; color: var(--muted); font-weight: 600;
    }
    .open-dot {
      display: inline-flex; align-items: center; gap: 5px;
      background: rgba(16,185,129,0.16); color: #34d399;
      padding: 2px 8px; border-radius: 999px; font-size: 11px; font-weight: 800;
    }
    [data-theme="light"] .open-dot { color: #047857; }
    .hero-controls { display: flex; gap: 6px; flex-shrink: 0; }
    .pill-btn {
      background: var(--surface); color: var(--text);
      border: 1px solid var(--border); border-radius: 12px;
      padding: 8px 11px; font-weight: 800; font-size: 12px; cursor: pointer;
      transition: transform 0.12s ease;
    }
    .pill-btn:active { transform: scale(0.95); }
    .welcome-msg {
      margin: 12px 0 0; font-size: 13px; color: var(--muted); line-height: 1.45;
    }

    /* Table / Service Card */
    .table-bar {
      margin-top: 12px; display: flex; align-items: center; justify-content: space-between; gap: 10px;
      background: linear-gradient(135deg, rgba(16,185,129,0.15), rgba(245,158,11,0.09));
      border: 1px solid rgba(16,185,129,0.38);
      border-radius: 14px; padding: 10px 12px; flex-wrap: wrap;
    }
    .table-pill { font-weight: 900; color: var(--primary); font-size: 13.5px; }
    .table-actions { display: flex; gap: 7px; }
    .action-chip {
      background: var(--surface); color: var(--text); border: 1px solid var(--border);
      border-radius: 10px; padding: 7px 11px; font-size: 12px; font-weight: 800; cursor: pointer;
    }
    .action-chip.gold { border-color: rgba(245,158,11,0.55); color: var(--gold); }

    /* Quick Service Mode Switcher (when no ?table=) */
    .quick-modes {
      margin-top: 12px; display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px;
      background: var(--surface); padding: 4px; border-radius: 14px; border: 1px solid var(--border);
    }
    .qmode {
      border: none; background: transparent; color: var(--muted);
      padding: 8px 6px; border-radius: 10px; font-weight: 800; font-size: 12px; cursor: pointer;
    }
    .qmode.active {
      background: var(--primary); color: var(--primary-ink);
      box-shadow: 0 4px 12px rgba(16,185,129,0.28);
    }

    /* Sticky Search + Categories */
    .sticky-nav {
      position: sticky; top: 0; z-index: 30;
      background: var(--glass); backdrop-filter: blur(14px);
      border-bottom: 1px solid var(--border);
      padding: 10px 0 8px;
    }
    .search-wrap { padding: 0 14px 8px; position: relative; }
    .search-input {
      width: 100%; background: var(--surface); color: var(--text);
      border: 1px solid var(--border); border-radius: 14px;
      padding: 11px 14px; font-size: 14px; outline: none; font-weight: 600;
    }
    .search-input:focus { border-color: var(--primary); }
    .cats {
      display: flex; gap: 8px; overflow-x: auto; padding: 2px 14px 2px;
      scrollbar-width: none;
    }
    .cats::-webkit-scrollbar { display: none; }
    .cat-chip {
      flex-shrink: 0; background: var(--surface); color: var(--muted);
      border: 1px solid var(--border); border-radius: 999px;
      padding: 8px 14px; font-weight: 800; font-size: 12.5px; cursor: pointer;
      transition: all 0.15s ease;
    }
    .cat-chip.active {
      background: var(--primary); color: var(--primary-ink); border-color: var(--primary);
      box-shadow: 0 4px 14px rgba(16,185,129,0.3);
    }

    /* Menu Grid & Editorial Cards */
    .section-title {
      padding: 14px 16px 6px; font-size: 15px; font-weight: 900;
      display: flex; align-items: center; justify-content: space-between;
    }
    .section-count { font-size: 12px; color: var(--muted); font-weight: 700; }
    .grid {
      display: grid; grid-template-columns: repeat(auto-fill, minmax(168px, 1fr));
      gap: 13px; padding: 6px 14px 18px;
    }
    .card {
      background: var(--surface); border: 1px solid var(--border);
      border-radius: 18px; overflow: hidden; display: flex; flex-direction: column;
      box-shadow: var(--shadow); transition: transform 0.14s ease, border-color 0.14s ease;
      cursor: pointer;
    }
    .card:active { transform: scale(0.985); }
    .card.in-cart { border-color: var(--primary); }
    .card.oos { opacity: 0.56; cursor: default; }
    .card-img {
      aspect-ratio: 4 / 3; width: 100%;
      background: linear-gradient(135deg, var(--surface-alt), rgba(16,185,129,0.12));
      display: flex; align-items: center; justify-content: center;
      font-size: 42px; position: relative; overflow: hidden;
    }
    .card-img img { width: 100%; height: 100%; object-fit: cover; display: block; }
    .card-img::after {
      content: ''; position: absolute; inset: 0;
      background: linear-gradient(180deg, transparent 52%, rgba(0,0,0,0.58) 100%);
      pointer-events: none;
    }
    .price-pill {
      position: absolute; bottom: 8px; left: 8px; z-index: 2;
      background: rgba(9,15,28,0.88); color: #34d399;
      padding: 4px 9px; border-radius: 9px; font-weight: 900; font-size: 12.5px;
      border: 1px solid rgba(52,211,153,0.35);
      backdrop-filter: blur(6px);
    }
    [dir="rtl"] .price-pill { left: auto; right: 8px; }
    .oos-tag {
      position: absolute; top: 8px; right: 8px; z-index: 2;
      background: rgba(239,68,68,0.95); color: #fff;
      font-size: 10px; font-weight: 900; padding: 4px 8px; border-radius: 8px;
      letter-spacing: 0.4px;
    }
    .card-body { padding: 11px; flex: 1; display: flex; flex-direction: column; justify-content: space-between; gap: 8px; }
    .card-name { font-weight: 900; font-size: 14px; line-height: 1.25; }
    .card-alt { font-size: 11.5px; color: var(--muted); margin-top: 2px; font-weight: 600; }
    .card-foot { display: flex; align-items: center; justify-content: flex-end; gap: 6px; margin-top: 2px; }
    .add-btn {
      width: 100%; background: var(--surface-alt); color: var(--primary);
      border: 1px solid rgba(16,185,129,0.4); border-radius: 11px;
      padding: 8px 10px; font-weight: 900; font-size: 12.5px; cursor: pointer;
    }
    .add-btn:disabled { opacity: 0.5; cursor: not-allowed; }
    .qty-box {
      width: 100%; display: flex; align-items: center; justify-content: space-between;
      background: rgba(16,185,129,0.14); border: 1px solid var(--primary);
      border-radius: 11px; padding: 3px;
    }
    .qty-b {
      width: 30px; height: 28px; border-radius: 8px; border: none;
      background: var(--primary); color: var(--primary-ink);
      font-weight: 900; font-size: 16px; cursor: pointer;
    }

    /* Floating Cart Bar */
    .cart-bar {
      position: fixed; left: 50%; transform: translateX(-50%); bottom: 16px; z-index: 40;
      width: calc(100% - 28px); max-width: 520px;
      background: linear-gradient(135deg, #10b981 0%, #059669 100%);
      color: #032215; border: none; border-radius: 18px;
      padding: 14px 18px; display: flex; align-items: center; justify-content: space-between;
      font-weight: 900; font-size: 15px; box-shadow: 0 14px 36px rgba(5,150,105,0.45);
      cursor: pointer;
    }
    .cart-badge {
      background: rgba(3,34,21,0.18); padding: 4px 10px; border-radius: 999px; font-size: 13px;
    }
    .hidden { display: none !important; }

    /* Bottom Sheet Modals */
    .modal-bg {
      position: fixed; inset: 0; z-index: 60;
      background: rgba(2,6,23,0.74); backdrop-filter: blur(6px);
      display: flex; align-items: flex-end; justify-content: center;
    }
    .sheet {
      width: 100%; max-width: 540px; max-height: 92vh; overflow-y: auto;
      background: var(--surface); border-top-left-radius: 24px; border-top-right-radius: 24px;
      border: 1px solid var(--border); padding: 18px;
      box-shadow: 0 -10px 40px rgba(0,0,0,0.4);
    }
    .sheet-handle {
      width: 42px; height: 4px; border-radius: 999px;
      background: var(--border); margin: 0 auto 12px;
    }
    .mode-row { display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; margin-bottom: 12px; }
    .mode-btn {
      background: var(--surface-alt); color: var(--muted); border: 1px solid var(--border);
      border-radius: 11px; padding: 10px 6px; font-weight: 800; font-size: 12px; cursor: pointer;
    }
    .mode-btn.active { background: rgba(16,185,129,0.18); border-color: var(--primary); color: var(--primary); }
    .field {
      width: 100%; background: var(--bg); color: var(--text);
      border: 1px solid var(--border); border-radius: 12px;
      padding: 11px 13px; font-size: 13.5px; margin-bottom: 8px; outline: none;
    }
    .field:focus { border-color: var(--primary); }
    .cart-line {
      display: flex; align-items: center; justify-content: space-between; gap: 10px;
      padding: 10px 0; border-bottom: 1px solid var(--border);
    }
    .free-bar {
      background: rgba(245,158,11,0.12); border: 1px solid rgba(245,158,11,0.35);
      color: var(--gold); border-radius: 12px; padding: 9px 12px;
      font-size: 12px; font-weight: 800; margin-bottom: 10px;
    }
    .submit-btn {
      width: 100%; background: linear-gradient(135deg, #10b981, #059669);
      color: #032215; border: none; border-radius: 15px; padding: 15px;
      font-weight: 900; font-size: 15.5px; cursor: pointer; margin-top: 10px;
      box-shadow: 0 8px 24px rgba(16,185,129,0.35);
    }

    /* 4-Step Live Order Tracker */
    .tracker {
      margin: 14px 14px 4px; background: var(--surface);
      border: 1px solid rgba(16,185,129,0.45);
      border-radius: 18px; padding: 16px; box-shadow: var(--shadow);
    }
    .steps {
      display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px; margin: 12px 0;
    }
    .step {
      text-align: center; font-size: 10.5px; font-weight: 800; color: var(--muted);
    }
    .step-bar {
      height: 5px; border-radius: 999px; background: var(--surface-alt); margin-bottom: 5px;
    }
    .step.done .step-bar { background: var(--primary); }
    .step.done { color: var(--primary); }

    .toast {
      position: fixed; top: 18px; left: 50%; transform: translateX(-50%); z-index: 90;
      background: #10b981; color: #032215; padding: 11px 18px; border-radius: 14px;
      font-weight: 900; font-size: 13px; box-shadow: 0 10px 28px rgba(0,0,0,0.4);
      max-width: 90vw; text-align: center;
    }
    .footer-brand {
      text-align: center; padding: 18px 14px 28px; font-size: 11.5px; color: var(--muted);
    }
  </style>
</head>
<body>
  <div id="toast" class="toast hidden"></div>

  <div class="shell">
    <section class="hero">
      <div class="hero-top">
        <div class="brand">
          <div class="brand-mark">🍽</div>
          <div>
            <div id="restName" class="brand-title">${safeName}</div>
            <div class="brand-meta">
              <span class="open-dot" id="openBadge">● Ouvert</span>
              <span id="restSub">Menu QR · Commande directe</span>
            </div>
          </div>
        </div>
        <div class="hero-controls">
          <button id="themeBtn" class="pill-btn" onclick="toggleTheme()" title="Mode clair/sombre">☀️</button>
          <button id="langBtn" class="pill-btn" onclick="toggleLang()">العربية</button>
        </div>
      </div>

      <p id="welcomeMsg" class="welcome-msg">Bienvenue ! Découvrez notre carte fraîche du jour et commandez en un clic.</p>

      <div id="tableBar" class="table-bar ${safeTable ? '' : 'hidden'}">
        <div id="tableLabel" class="table-pill">🍽 Table : ${safeTable}</div>
        <div class="table-actions">
          <button class="action-chip gold" onclick="callWaiter('waiter')" id="btnCallWaiter">🔔 Serveur</button>
          <button class="action-chip" onclick="callWaiter('bill')" id="btnCallBill">🧾 Addition</button>
        </div>
      </div>

      <div id="quickModes" class="quick-modes ${safeTable ? 'hidden' : ''}">
        <button class="qmode" data-mode="dine_in" onclick="setMode('dine_in')">🍽 Sur place</button>
        <button class="qmode active" data-mode="takeaway" onclick="setMode('takeaway')">🛍 Emporter</button>
        <button class="qmode" data-mode="delivery" onclick="setMode('delivery')">🛵 Livraison</button>
      </div>
    </section>

    <div id="trackerBox" class="tracker hidden"></div>

    <div class="sticky-nav">
      <div class="search-wrap">
        <input id="searchInput" class="search-input" type="search" placeholder="🔍 Rechercher un plat, grillade, boisson..." oninput="renderGrid()" />
      </div>
      <div id="catsBar" class="cats"></div>
    </div>

    <div class="section-title">
      <span id="activeCatTitle">Notre Carte</span>
      <span id="activeCatCount" class="section-count"></span>
    </div>
    <main id="menuGrid" class="grid"></main>

    <div class="footer-brand">Propulsé par <b>Full·Tek Resto</b> · Menu QR & Commande Directe</div>
  </div>

  <button id="cartBar" class="cart-bar hidden" onclick="openCart()">
    <span id="cartCountLabel" class="cart-badge">🛒 0</span>
    <span id="cartActionLabel">Voir ma commande</span>
    <span id="cartTotalLabel">0 MRU →</span>
  </button>

  <!-- Dish Detail Sheet -->
  <div id="dishModal" class="modal-bg hidden" onclick="if(event.target===this) closeDish()">
    <div class="sheet" id="dishSheetContent"></div>
  </div>

  <!-- Checkout Cart Sheet -->
  <div id="cartModal" class="modal-bg hidden" onclick="if(event.target===this) closeCart()">
    <div class="sheet">
      <div class="sheet-handle"></div>
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
        <h3 id="cartTitle" style="margin:0;font-size:18px;font-weight:900;">Votre commande</h3>
        <button class="action-chip" onclick="closeCart()">✕</button>
      </div>
      <div id="modeRow" class="mode-row">
        <button class="mode-btn" data-mode="dine_in" onclick="setMode('dine_in')">🍽 Sur place</button>
        <button class="mode-btn" data-mode="takeaway" onclick="setMode('takeaway')">🛍 Emporter</button>
        <button class="mode-btn" data-mode="delivery" onclick="setMode('delivery')">🛵 Livraison</button>
      </div>
      <div id="freeDeliveryHint" class="free-bar hidden"></div>
      <div id="tableInputWrap">
        <input id="tableInput" class="field" placeholder="N° de table (ex: T1, Khaima 1)" value="${safeTable}" />
      </div>
      <div id="customerFields" class="hidden">
        <input id="custName" class="field" placeholder="Votre nom *" />
        <input id="custPhone" class="field" type="tel" placeholder="Téléphone / WhatsApp (ex: 46 XX XX XX) *" />
      </div>
      <div id="deliveryFields" class="hidden">
        <select id="zoneSelect" class="field" onchange="renderCartSheet()"></select>
        <input id="custAddr" class="field" placeholder="Adresse / Quartier / Repère *" />
        <div style="margin-bottom:8px;">
          <button type="button" id="shareGpsBtn" class="action-chip" style="width:100%;justify-content:center;display:flex;align-items:center;gap:6px;padding:10px 14px;border-color:rgba(16,185,129,0.45);background:rgba(16,185,129,0.12);color:var(--primary);font-size:13px;" onclick="shareMyGpsLocation()">
            📍 <span id="shareGpsLabel">Partager ma position GPS exacte</span>
          </button>
          <div id="gpsStatusBox" class="hidden" style="margin-top:6px;padding:8px 11px;border-radius:10px;background:rgba(16,185,129,0.14);border:1px solid rgba(16,185,129,0.35);font-size:12px;display:flex;justify-content:space-between;align-items:center;gap:8px;">
            <span id="gpsStatusText" style="font-weight:800;color:var(--primary);"></span>
            <div style="display:flex;gap:6px;align-items:center;">
              <a id="gpsMapLink" href="#" target="_blank" rel="noopener" style="color:var(--gold);font-weight:800;text-decoration:underline;">Google Maps ↗</a>
              <button type="button" class="action-chip" style="padding:3px 8px;font-size:11px;" onclick="clearGpsLocation()">✕</button>
            </div>
          </div>
        </div>
      </div>
      <div id="cartItemsList"></div>
      <input id="orderNote" class="field" style="margin-top:10px;" placeholder="Note cuisine globale (ex: sans piment, bien cuit...)" />

      <!-- Mode de paiement & Reçu de paiement en ligne -->
      <div style="margin-top:10px;padding:10px;border-radius:12px;border:1px solid var(--border);background:var(--surface2);">
        <div id="paySectionTitle" style="font-size:12.5px;font-weight:900;margin-bottom:8px;">💳 Paiement</div>
        <div class="mode-row" style="margin-bottom:8px;">
          <button type="button" class="mode-btn active" data-paytype="later" onclick="setPaymentType('later')" id="payLaterBtn">💵 À la livraison / caisse</button>
          <button type="button" class="mode-btn" data-paytype="online" onclick="setPaymentType('online')" id="payOnlineBtn">📱 Paiement en ligne</button>
        </div>
        <div id="onlinePayFields" class="hidden">
          <div id="merchantPayInfo" style="font-size:11.5px;color:var(--primary);font-weight:800;margin-bottom:6px;"></div>
          <select id="payWalletSelect" class="field"></select>
          <input id="payRefInput" class="field" placeholder="N° de transaction / Référence (optionnel)" />
          <label for="payReceiptFile" class="action-chip" style="width:100%;display:flex;justify-content:center;align-items:center;gap:6px;padding:10px;border:1.5px dashed rgba(16,185,129,0.55);background:rgba(16,185,129,0.10);color:var(--primary);cursor:pointer;font-size:12.5px;">
            🧾 <span id="payReceiptBtnLabel">Joindre le reçu de paiement (capture d'écran)</span>
          </label>
          <input id="payReceiptFile" type="file" accept="image/*" class="hidden" onchange="onReceiptFilePicked(event)" />
          <div id="payReceiptPreviewBox" class="hidden" style="margin-top:8px;display:flex;align-items:center;gap:10px;padding:8px;border-radius:10px;border:1px solid var(--border);background:var(--surface);">
            <img id="payReceiptThumb" src="" alt="Reçu" style="width:52px;height:52px;object-fit:cover;border-radius:8px;border:1px solid var(--border);" />
            <div style="flex:1;min-width:0;">
              <div id="payReceiptReadyLbl" style="font-size:12px;font-weight:900;color:var(--primary);">✅ Reçu joint</div>
              <div style="font-size:11px;color:var(--muted);">Sera vérifié par la caisse</div>
            </div>
            <button type="button" class="action-chip" style="padding:4px 9px;font-size:11px;" onclick="clearReceiptFile()">✕</button>
          </div>
        </div>
      </div>

      <div id="cartSummary" style="display:flex;justify-content:space-between;font-weight:900;font-size:17px;margin-top:10px;"></div>
      <button id="submitOrderBtn" class="submit-btn" onclick="submitOrder()">Confirmer la commande</button>
    </div>
  </div>

  <!-- Customer Online Receipt Modal -->
  <div id="receiptModal" class="modal-bg hidden" onclick="if(event.target===this) closeReceiptModal()">
    <div class="sheet" id="receiptSheetContent"></div>
  </div>

  <script>
    const TENANT_CODE = ${JSON.stringify(tenant.tenant_code)};
    const INITIAL_TABLE = ${JSON.stringify(initialTable || '')};
    let lang = 'fr';
    let menuData = null;
    let activeCatId = 'all';
    let cart = {}; // productId -> { qty, note }
    let serviceMode = INITIAL_TABLE ? 'dine_in' : 'takeaway';
    let activeOrderCode = localStorage.getItem('ft_qr_order_' + TENANT_CODE) || '';
    let pollTimer = null;
    let deliveryGps = null; // { lat, lng, url }
    let paymentType = 'later'; // later | online
    let paymentReceiptDataUrl = '';
    let lastTrackedOrder = null;

    function setPaymentType(kind) {
      paymentType = kind === 'online' ? 'online' : 'later';
      document.querySelectorAll('[data-paytype]').forEach((b) => {
        b.classList.toggle('active', b.dataset.paytype === paymentType);
      });
      const box = document.getElementById('onlinePayFields');
      if (box) box.classList.toggle('hidden', paymentType !== 'online');
    }

    function onReceiptFilePicked(ev) {
      const file = ev?.target?.files?.[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = () => {
        const img = new Image();
        img.onload = () => {
          const maxDim = 900;
          let w = img.width;
          let h = img.height;
          if (w > maxDim || h > maxDim) {
            if (w >= h) { h = Math.round(h * maxDim / w); w = maxDim; }
            else { w = Math.round(w * maxDim / h); h = maxDim; }
          }
          const canvas = document.createElement('canvas');
          canvas.width = w;
          canvas.height = h;
          const ctx = canvas.getContext('2d');
          ctx.drawImage(img, 0, 0, w, h);
          paymentReceiptDataUrl = canvas.toDataURL('image/jpeg', 0.72);
          document.getElementById('payReceiptThumb').src = paymentReceiptDataUrl;
          document.getElementById('payReceiptPreviewBox').classList.remove('hidden');
          document.getElementById('payReceiptBtnLabel').textContent =
            lang === 'fr' ? 'Changer le reçu joint' : 'تغيير إيصال الدفع';
        };
        img.src = reader.result;
      };
      reader.readAsDataURL(file);
    }

    function clearReceiptFile() {
      paymentReceiptDataUrl = '';
      const inp = document.getElementById('payReceiptFile');
      if (inp) inp.value = '';
      document.getElementById('payReceiptPreviewBox').classList.add('hidden');
      document.getElementById('payReceiptBtnLabel').textContent =
        lang === 'fr' ? "Joindre le reçu de paiement (capture d'écran)" : 'إرفاق إيصال الدفع (لقطة شاشة)';
    }

    function shareMyGpsLocation() {
      const btn = document.getElementById('shareGpsBtn');
      const lbl = document.getElementById('shareGpsLabel');
      if (!navigator.geolocation) {
        showToast(lang === 'fr' ? 'Géolocalisation non supportée par ce navigateur.' : 'الموقع الجغرافي غير مدعوم في هذا المتصفح');
        return;
      }
      btn.disabled = true;
      lbl.textContent = lang === 'fr' ? 'Localisation GPS en cours...' : 'جاري تحديد موقعك...';
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          btn.disabled = false;
          const lat = Number(pos.coords.latitude.toFixed(6));
          const lng = Number(pos.coords.longitude.toFixed(6));
          const url = 'https://maps.google.com/?q=' + lat + ',' + lng;
          deliveryGps = { lat, lng, url };
          lbl.textContent = lang === 'fr' ? 'Actualiser ma position GPS' : 'تحديث موقعي الجغرافي GPS';
          const box = document.getElementById('gpsStatusBox');
          box.classList.remove('hidden');
          document.getElementById('gpsStatusText').textContent =
            (lang === 'fr' ? '✅ Position GPS prête (' : '✅ تم تحديد الموقع (') + lat.toFixed(5) + ', ' + lng.toFixed(5) + ')';
          document.getElementById('gpsMapLink').href = url;
          showToast(lang === 'fr' ? '📍 Position GPS jointe à votre commande !' : '📍 تم إرفاق موقعك الجغرافي بالطلب!');
        },
        (err) => {
          btn.disabled = false;
          lbl.textContent = lang === 'fr' ? 'Partager ma position GPS exacte' : 'مشاركة موقعي الجغرافي GPS';
          showToast(lang === 'fr'
            ? 'Autorisez la localisation GPS dans votre navigateur ou collez un lien Maps dans Adresse.'
            : 'يرجى السماح بتحديد الموقع الجغرافي في المتصفح');
        },
        { enableHighAccuracy: true, timeout: 12000, maximumAge: 0 }
      );
    }

    function clearGpsLocation() {
      deliveryGps = null;
      document.getElementById('gpsStatusBox').classList.add('hidden');
      document.getElementById('shareGpsLabel').textContent =
        lang === 'fr' ? 'Partager ma position GPS exacte' : 'مشاركة موقعي الجغرافي GPS';
    }

    function toggleTheme() {
      const root = document.documentElement;
      const next = root.getAttribute('data-theme') === 'light' ? 'dark' : 'light';
      root.setAttribute('data-theme', next);
      document.getElementById('themeBtn').textContent = next === 'light' ? '🌙' : '☀️';
    }

    function showToast(msg) {
      const t = document.getElementById('toast');
      t.textContent = msg;
      t.classList.remove('hidden');
      setTimeout(() => t.classList.add('hidden'), 3200);
    }

    function escapeAttr(s) {
      return String(s || '').replace(/"/g, '&quot;').replace(/</g, '&lt;');
    }

    function toggleLang() {
      lang = lang === 'fr' ? 'ar' : 'fr';
      document.documentElement.lang = lang;
      document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
      document.getElementById('langBtn').textContent = lang === 'fr' ? 'العربية' : 'Français';
      document.getElementById('openBadge').textContent = lang === 'fr' ? '● Ouvert' : '● مفتوح الآن';
      document.getElementById('searchInput').placeholder = lang === 'fr' ? '🔍 Rechercher un plat, grillade, boisson...' : '🔍 ابحث عن طبق أو مشروب...';
      document.getElementById('btnCallWaiter').textContent = lang === 'fr' ? '🔔 Serveur' : '🔔 نداء النادل';
      document.getElementById('btnCallBill').textContent = lang === 'fr' ? '🧾 Addition' : '🧾 الحساب';
      document.getElementById('cartActionLabel').textContent = lang === 'fr' ? 'Voir ma commande' : 'عرض طلبي';
      const gpsLbl = document.getElementById('shareGpsLabel');
      if (gpsLbl) {
        gpsLbl.textContent = deliveryGps
          ? (lang === 'fr' ? 'Actualiser ma position GPS' : 'تحديث موقعي الجغرافي GPS')
          : (lang === 'fr' ? 'Partager ma position GPS exacte' : 'مشاركة موقعي الجغرافي GPS');
      }
      if (menuData?.settings) {
        document.getElementById('welcomeMsg').textContent = lang === 'ar'
          ? (menuData.settings.welcomeAr || '')
          : (menuData.settings.welcomeFr || '');
      }
      renderCats();
      renderGrid();
      renderCartBar();
    }

    function labelOf(obj) {
      return lang === 'ar' ? (obj.nameAr || obj.nameFr) : obj.nameFr;
    }
    function altLabelOf(obj) {
      const alt = lang === 'ar' ? obj.nameFr : obj.nameAr;
      return alt && alt !== labelOf(obj) ? alt : '';
    }

    async function loadMenu() {
      try {
        const res = await fetch('/public/menu/' + encodeURIComponent(TENANT_CODE));
        menuData = await res.json();
        if (!res.ok) throw new Error(menuData.error || 'Menu indisponible');
        document.getElementById('restName').textContent = menuData.tenant.name;
        document.getElementById('restSub').textContent =
          (menuData.tenant.city || 'Nouakchott') + (menuData.tenant.phone ? ' · ' + menuData.tenant.phone : '');
        if (menuData.settings?.welcomeFr) {
          document.getElementById('welcomeMsg').textContent = menuData.settings.welcomeFr;
        }
        const zSel = document.getElementById('zoneSelect');
        zSel.innerHTML = (menuData.deliveryZones || []).map(z =>
          '<option value="' + escapeAttr(z.nameFr) + '" data-fee="' + Number(z.feeMru || 0) + '">' + escapeAttr(z.nameFr) + ' (+' + Number(z.feeMru || 0) + ' MRU)</option>'
        ).join('');
        const wSel = document.getElementById('payWalletSelect');
        if (wSel) {
          const rawMethods = Array.isArray(menuData.tenant?.payMethods) ? menuData.tenant.payMethods : [];
          const wallets = rawMethods.filter(m => !['cash', 'karni', 'especes'].includes(String(m).toLowerCase()));
          const list = wallets.length > 0 ? wallets : ['Bankily', 'Masrvi', 'Sedad', 'BIM-Bank', 'Click'];
          wSel.innerHTML = list.map(w => '<option value="' + escapeAttr(w) + '">📱 ' + escapeAttr(w) + '</option>').join('');
        }
        const mInfo = document.getElementById('merchantPayInfo');
        if (mInfo) {
          mInfo.textContent = menuData.tenant?.phone
            ? 'Transférez sur le numéro du restaurant : ' + menuData.tenant.phone + ' puis joignez le reçu.'
            : 'Effectuez votre transfert puis joignez la capture du reçu.';
        }
        renderCats();
        renderGrid();
        setMode(serviceMode);
        if (activeOrderCode) pollOrderStatus();
      } catch (e) {
        document.getElementById('menuGrid').innerHTML = '<p style="padding:24px;color:#ef4444;font-weight:800;">' + escapeAttr(e.message) + '</p>';
      }
    }

    function renderCats() {
      if (!menuData) return;
      const bar = document.getElementById('catsBar');
      const allLabel = (lang === 'fr' ? '🍽 Tout' : '🍽 الكل') + ' (' + menuData.products.length + ')';
      let html = '<button class="cat-chip ' + (activeCatId === 'all' ? 'active' : '') + '" onclick="selectCat(\\'all\\')">' + allLabel + '</button>';
      for (const c of menuData.categories) {
        const cnt = menuData.products.filter(p => String(p.categoryId) === String(c.id)).length;
        html += '<button class="cat-chip ' + (String(activeCatId) === String(c.id) ? 'active' : '') + '" onclick="selectCat(' + c.id + ')">' + (c.icon || '') + ' ' + escapeAttr(labelOf(c)) + ' (' + cnt + ')</button>';
      }
      bar.innerHTML = html;
    }

    function selectCat(id) {
      activeCatId = id;
      renderCats();
      renderGrid();
    }

    function renderGrid() {
      if (!menuData) return;
      const q = (document.getElementById('searchInput').value || '').trim().toLowerCase();
      const allowOrder = menuData.settings?.allowOrdering !== false;
      const items = menuData.products.filter(p => {
        if (activeCatId !== 'all' && String(p.categoryId) !== String(activeCatId)) return false;
        if (!q) return true;
        return (p.nameFr || '').toLowerCase().includes(q) || (p.nameAr || '').toLowerCase().includes(q);
      });
      const activeCat = menuData.categories.find(c => String(c.id) === String(activeCatId));
      document.getElementById('activeCatTitle').textContent = activeCat
        ? labelOf(activeCat)
        : (lang === 'fr' ? 'Notre Carte' : 'القائمة الكاملة');
      document.getElementById('activeCatCount').textContent = items.length + (lang === 'fr' ? ' plat(s)' : ' صنف');

      const grid = document.getElementById('menuGrid');
      if (items.length === 0) {
        grid.innerHTML = '<div style="grid-column:1/-1;text-align:center;color:var(--muted);padding:36px;font-weight:700;">' + (lang === 'fr' ? 'Aucun article trouvé.' : 'لا توجد نتائج') + '</div>';
        return;
      }
      grid.innerHTML = items.map(p => {
        const entry = cart[p.id];
        const qty = entry ? entry.qty : 0;
        const imgHtml = p.imageUrl ? '<img src="' + escapeAttr(p.imageUrl) + '" alt="" loading="lazy" />' : '🍽';
        const oosTag = !p.available ? '<span class="oos-tag">' + (lang === 'fr' ? 'ÉPUISÉ' : 'نفذ') + '</span>' : '';
        const alt = altLabelOf(p);
        let actionHtml = '';
        if (allowOrder) {
          if (qty > 0) {
            actionHtml = '<div class="qty-box" onclick="event.stopPropagation()"><button class="qty-b" onclick="changeQty(' + p.id + ',-1)">−</button><b>' + qty + '</b><button class="qty-b" onclick="changeQty(' + p.id + ',1)">+</button></div>';
          } else {
            actionHtml = '<button class="add-btn" ' + (!p.available ? 'disabled' : '') + ' onclick="event.stopPropagation();changeQty(' + p.id + ',1)">' + (lang === 'fr' ? '+ Ajouter' : '+ إضافة') + '</button>';
          }
        }
        return '<div class="card ' + (!p.available ? 'oos' : (qty > 0 ? 'in-cart' : '')) + '" onclick="' + (p.available ? 'openDish(' + p.id + ')' : '') + '">' +
          '<div class="card-img">' + imgHtml + oosTag + '<span class="price-pill">' + Number(p.priceMru).toFixed(0) + ' MRU</span></div>' +
          '<div class="card-body">' +
            '<div><div class="card-name">' + escapeAttr(labelOf(p)) + '</div>' +
            (alt ? '<div class="card-alt">' + escapeAttr(alt) + '</div>' : '') + '</div>' +
            '<div class="card-foot">' + actionHtml + '</div>' +
          '</div></div>';
      }).join('');
    }

    function openDish(prodId) {
      if (!menuData || menuData.settings?.allowOrdering === false) return;
      const p = menuData.products.find(x => String(x.id) === String(prodId));
      if (!p || !p.available) return;
      const existing = cart[p.id] || { qty: 1, note: '' };
      const imgHtml = p.imageUrl
        ? '<img src="' + escapeAttr(p.imageUrl) + '" style="width:100%;height:190px;object-fit:cover;border-radius:16px;margin-bottom:12px;" />'
        : '';
      document.getElementById('dishSheetContent').innerHTML =
        '<div class="sheet-handle"></div>' + imgHtml +
        '<div style="display:flex;justify-content:space-between;align-items:flex-start;gap:10px;">' +
          '<div><h3 style="margin:0;font-size:19px;font-weight:900;">' + escapeAttr(labelOf(p)) + '</h3>' +
          '<div style="color:var(--muted);font-size:13px;margin-top:2px;">' + escapeAttr(altLabelOf(p)) + '</div></div>' +
          '<div style="font-weight:900;font-size:18px;color:var(--primary);white-space:nowrap;">' + Number(p.priceMru).toFixed(0) + ' MRU</div>' +
        '</div>' +
        '<input id="dishNoteInput" class="field" style="margin-top:14px;" placeholder="' + (lang === 'fr' ? 'Instruction cuisine (ex: sans oignons, bien cuit...)' : 'ملاحظة للمطبخ (بدون بصل...)') + '" value="' + escapeAttr(existing.note || '') + '" />' +
        '<button class="submit-btn" onclick="saveDishFromModal(' + p.id + ')">' + (lang === 'fr' ? 'Ajouter au panier · ' : 'أضف إلى السلة · ') + Number(p.priceMru).toFixed(0) + ' MRU</button>';
      document.getElementById('dishModal').classList.remove('hidden');
    }

    function closeDish() {
      document.getElementById('dishModal').classList.add('hidden');
    }

    function saveDishFromModal(prodId) {
      const note = (document.getElementById('dishNoteInput')?.value || '').trim();
      const cur = cart[prodId];
      cart[prodId] = { qty: cur ? cur.qty + 1 : 1, note };
      closeDish();
      renderGrid();
      renderCartBar();
    }

    function changeQty(prodId, delta) {
      const cur = cart[prodId] || { qty: 0, note: '' };
      const next = cur.qty + delta;
      if (next <= 0) delete cart[prodId];
      else cart[prodId] = { qty: next, note: cur.note };
      renderGrid();
      renderCartBar();
      if (!document.getElementById('cartModal').classList.contains('hidden')) renderCartSheet();
    }

    function cartSubtotal() {
      if (!menuData) return 0;
      let sum = 0;
      for (const [id, entry] of Object.entries(cart)) {
        const pr = menuData.products.find(p => String(p.id) === String(id));
        if (pr) sum += pr.priceMru * entry.qty;
      }
      return sum;
    }

    function renderCartBar() {
      const count = Object.values(cart).reduce((a, b) => a + b.qty, 0);
      const bar = document.getElementById('cartBar');
      if (count <= 0) { bar.classList.add('hidden'); return; }
      bar.classList.remove('hidden');
      document.getElementById('cartCountLabel').textContent = '🛒 ' + count;
      document.getElementById('cartTotalLabel').textContent = cartSubtotal().toFixed(0) + ' MRU →';
    }

    function setMode(m) {
      serviceMode = m;
      document.querySelectorAll('.mode-btn, .qmode').forEach(b => b.classList.toggle('active', b.dataset.mode === m));
      document.getElementById('tableInputWrap').classList.toggle('hidden', m !== 'dine_in');
      document.getElementById('customerFields').classList.toggle('hidden', m === 'dine_in');
      document.getElementById('deliveryFields').classList.toggle('hidden', m !== 'delivery');
      if (!document.getElementById('cartModal').classList.contains('hidden')) renderCartSheet();
    }

    function openCart() {
      document.getElementById('cartModal').classList.remove('hidden');
      renderCartSheet();
    }
    function closeCart() {
      document.getElementById('cartModal').classList.add('hidden');
    }

    function currentDeliveryFee() {
      if (serviceMode !== 'delivery') return 0;
      const sel = document.getElementById('zoneSelect');
      const opt = sel.options[sel.selectedIndex];
      const fee = opt ? Number(opt.dataset.fee || 0) : 0;
      const freeAbove = Number(menuData?.tenant?.freeDeliveryAboveMru || 0);
      if (freeAbove > 0 && cartSubtotal() >= freeAbove) return 0;
      return fee;
    }

    function renderCartSheet() {
      if (!menuData) return;
      const list = document.getElementById('cartItemsList');
      const entries = Object.entries(cart);
      if (entries.length === 0) { closeCart(); return; }

      const freeBox = document.getElementById('freeDeliveryHint');
      const freeAbove = Number(menuData?.tenant?.freeDeliveryAboveMru || 0);
      if (serviceMode === 'delivery' && freeAbove > 0) {
        const diff = freeAbove - cartSubtotal();
        freeBox.classList.remove('hidden');
        freeBox.textContent = diff <= 0
          ? (lang === 'fr' ? '🎉 Livraison GRATUITE débloquée !' : '🎉 توصيل مجاني!')
          : (lang === 'fr' ? '🛵 Plus que ' + diff.toFixed(0) + ' MRU pour la livraison gratuite !' : '🛵 أضف ' + diff.toFixed(0) + ' أوقية للتوصيل المجاني!');
      } else {
        freeBox.classList.add('hidden');
      }

      list.innerHTML = entries.map(([id, entry]) => {
        const pr = menuData.products.find(p => String(p.id) === String(id));
        if (!pr) return '';
        return '<div class="cart-line">' +
          '<div><b>' + entry.qty + 'x ' + escapeAttr(labelOf(pr)) + '</b>' +
          (entry.note ? '<div style="font-size:11.5px;color:var(--gold);">📝 ' + escapeAttr(entry.note) + '</div>' : '') +
          '<div style="font-size:12px;color:var(--muted);">' + (pr.priceMru * entry.qty).toFixed(0) + ' MRU</div></div>' +
          '<div style="display:flex;gap:6px;"><button class="qty-b" onclick="changeQty(' + pr.id + ',-1)">−</button><button class="qty-b" onclick="changeQty(' + pr.id + ',1)">+</button></div>' +
        '</div>';
      }).join('');
      const fee = currentDeliveryFee();
      const total = cartSubtotal() + fee;
      document.getElementById('cartSummary').innerHTML =
        '<span>' + (lang === 'fr' ? 'Total à payer' : 'الإجمالي') + (fee > 0 ? ' (incl. +' + fee + ' MRU)' : '') + '</span><span style="color:var(--primary);">' + total.toFixed(0) + ' MRU</span>';
    }

    async function submitOrder() {
      const btn = document.getElementById('submitOrderBtn');
      const items = Object.entries(cart).map(([productId, entry]) => ({
        productId: Number(productId),
        qty: entry.qty,
        note: entry.note || '',
      }));
      if (items.length === 0) return;
      const tableName = (document.getElementById('tableInput').value || '').trim();
      const customerName = (document.getElementById('custName').value || '').trim();
      const customerPhone = (document.getElementById('custPhone').value || '').trim();
      const deliveryZone = document.getElementById('zoneSelect').value || '';
      const rawAddr = (document.getElementById('custAddr').value || '').trim();
      const deliveryGpsUrl = (serviceMode === 'delivery' && deliveryGps && deliveryGps.url) ? deliveryGps.url : '';
      const deliveryAddress = (serviceMode === 'delivery' && deliveryGpsUrl)
        ? (rawAddr ? (rawAddr.includes(deliveryGpsUrl) ? rawAddr : rawAddr + ' · 📍 GPS: ' + deliveryGpsUrl) : '📍 GPS: ' + deliveryGpsUrl)
        : rawAddr;
      const notes = (document.getElementById('orderNote').value || '').trim();
      const payMethod = paymentType === 'online'
        ? (document.getElementById('payWalletSelect')?.value || 'Bankily')
        : 'PENDING';
      const paymentRef = paymentType === 'online'
        ? (document.getElementById('payRefInput')?.value || '').trim()
        : '';

      if (serviceMode !== 'dine_in' && (!customerName || !customerPhone)) {
        showToast(lang === 'fr' ? 'Nom et téléphone requis.' : 'الاسم ورقم الهاتف مطلوبان');
        return;
      }
      if (paymentType === 'online' && !paymentRef && !paymentReceiptDataUrl) {
        showToast(lang === 'fr'
          ? 'Veuillez joindre la capture du reçu ou saisir le N° de transaction.'
          : 'يرجى إرفاق صورة إيصال الدفع أو إدخال رقم العملية.');
        return;
      }
      btn.disabled = true;
      btn.textContent = lang === 'fr' ? 'Envoi en cours...' : 'جاري الإرسال...';
      try {
        const res = await fetch('/public/orders/' + encodeURIComponent(TENANT_CODE), {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            serviceMode,
            tableName,
            customerName,
            customerPhone,
            deliveryZone,
            deliveryAddress,
            deliveryLat: deliveryGps ? deliveryGps.lat : undefined,
            deliveryLng: deliveryGps ? deliveryGps.lng : undefined,
            deliveryGpsUrl: deliveryGpsUrl || undefined,
            payMethod,
            paymentRef,
            paymentReceiptDataUrl: paymentType === 'online' ? paymentReceiptDataUrl : '',
            notes,
            items,
          }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || 'Erreur envoi');
        cart = {};
        clearReceiptFile();
        setPaymentType('later');
        if (document.getElementById('payRefInput')) document.getElementById('payRefInput').value = '';
        activeOrderCode = data.orderCode;
        localStorage.setItem('ft_qr_order_' + TENANT_CODE, activeOrderCode);
        closeCart();
        renderGrid();
        renderCartBar();
        showToast(lang === 'fr' ? '✅ Commande envoyée ! N° ' + activeOrderCode : '✅ تم إرسال طلبك! ' + activeOrderCode);
        pollOrderStatus();
      } catch (e) {
        showToast(e.message);
      } finally {
        btn.disabled = false;
        btn.textContent = lang === 'fr' ? 'Confirmer la commande' : 'تأكيد الطلب';
      }
    }

    async function pollOrderStatus() {
      if (!activeOrderCode) return;
      try {
        const res = await fetch('/public/orders/' + encodeURIComponent(TENANT_CODE) + '/' + encodeURIComponent(activeOrderCode));
        if (!res.ok) return;
        const d = await res.json();
        lastTrackedOrder = d;
        const box = document.getElementById('trackerBox');
        box.classList.remove('hidden');
        const stepIdx = { QR_PENDING: 1, OPEN: 2, KDS_PREP: 3, READY: 4, PAID: 4 }[d.status] || 1;
        const labels = lang === 'fr'
          ? ['Reçue', 'Validée', 'Cuisine', 'Prête !']
          : ['استُلمت', 'مؤكدة', 'بالمطبخ', 'جاهزة!'];
        const stepsHtml = labels.map((lb, i) =>
          '<div class="step ' + (i + 1 <= stepIdx ? 'done' : '') + '"><div class="step-bar"></div>' + lb + '</div>'
        ).join('');
        const payTag = (d.payMethod && d.payMethod !== 'PENDING')
          ? '<span style="font-size:11px;padding:3px 8px;border-radius:999px;background:rgba(16,185,129,0.16);color:var(--primary);font-weight:800;">💳 ' + escapeAttr(d.payMethod) + (d.hasReceipt ? ' · Reçu joint' : '') + '</span>'
          : '';
        box.innerHTML =
          '<div style="display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap;">' +
            '<span style="font-size:12px;color:var(--muted);font-weight:800;">SUIVI · ' + escapeAttr(d.orderCode) + '</span>' +
            payTag +
            '<b style="color:var(--primary);">' + Number(d.totalMru || 0).toFixed(0) + ' MRU</b>' +
          '</div>' +
          (d.status === 'CANCELLED'
            ? '<div style="color:var(--danger);font-weight:900;margin:10px 0;">❌ Commande annulée</div>'
            : '<div class="steps">' + stepsHtml + '</div>') +
          '<div style="display:flex;gap:8px;justify-content:flex-end;margin-top:8px;">' +
            '<button class="action-chip gold" onclick="openReceiptModal()">🧾 ' + (lang === 'fr' ? 'Voir Reçu' : 'عرض الإيصال') + '</button>' +
            ((d.status === 'PAID' || d.status === 'CANCELLED')
              ? '<button class="action-chip" onclick="clearTracker()">Fermer</button>'
              : '') +
          '</div>';
        if (d.status !== 'PAID' && d.status !== 'CANCELLED') {
          clearTimeout(pollTimer);
          pollTimer = setTimeout(pollOrderStatus, 8000);
        }
      } catch {}
    }

    function openReceiptModal() {
      const d = lastTrackedOrder;
      if (!d) return;
      const dtStr = d.createdAt ? new Date(d.createdAt).toLocaleString('fr-FR') : '';
      const linesHtml = (d.items || []).map(it =>
        '<div style="display:flex;justify-content:space-between;padding:5px 0;border-bottom:1px dashed var(--border);font-size:13px;">' +
          '<span><b>' + it.qty + 'x</b> ' + escapeAttr(it.nameFr) + '</span>' +
          '<b>' + (Number(it.unitPrice || 0) * Number(it.qty || 1)).toFixed(0) + ' MRU</b>' +
        '</div>'
      ).join('');
      const payLabel = (d.payMethod && d.payMethod !== 'PENDING')
        ? escapeAttr(d.payMethod) + (d.paymentRef ? ' · Réf: ' + escapeAttr(d.paymentRef) : '')
        : 'À régler à la livraison / caisse';
      const proofHtml = d.receiptImageData
        ? '<div style="margin-top:10px;"><div style="font-size:11.5px;font-weight:800;color:var(--muted);margin-bottom:4px;">Preuve de paiement jointe :</div><img src="' + d.receiptImageData + '" style="max-width:100%;max-height:220px;border-radius:10px;border:1px solid var(--border);object-fit:contain;" /></div>'
        : '';
      document.getElementById('receiptSheetContent').innerHTML =
        '<div class="sheet-handle"></div>' +
        '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;">' +
          '<h3 style="margin:0;font-size:17px;font-weight:900;">🧾 Reçu · ' + escapeAttr(d.orderCode) + '</h3>' +
          '<button class="action-chip" onclick="closeReceiptModal()">✕</button>' +
        '</div>' +
        '<div style="padding:12px;border-radius:12px;border:1px solid var(--border);background:var(--surface2);margin-bottom:10px;">' +
          '<div style="font-weight:900;font-size:14px;">' + escapeAttr(d.tenantName || menuData?.tenant?.name || '') + '</div>' +
          '<div style="font-size:11.5px;color:var(--muted);">' + escapeAttr(dtStr) + ' · Mode: ' + escapeAttr(d.serviceMode) + '</div>' +
          (d.customerName ? '<div style="font-size:12px;margin-top:4px;">👤 ' + escapeAttr(d.customerName) + (d.customerPhone ? ' · 📞 ' + escapeAttr(d.customerPhone) : '') + '</div>' : '') +
          (d.deliveryAddress ? '<div style="font-size:11.5px;color:var(--muted);margin-top:2px;">📍 ' + escapeAttr(d.deliveryAddress) + '</div>' : '') +
        '</div>' +
        linesHtml +
        (Number(d.deliveryFeeMru || 0) > 0
          ? '<div style="display:flex;justify-content:space-between;padding:6px 0;font-size:12.5px;color:var(--muted);"><span>Livraison (' + escapeAttr(d.deliveryZone || '') + ')</span><b>+' + Number(d.deliveryFeeMru).toFixed(0) + ' MRU</b></div>'
          : '') +
        '<div style="display:flex;justify-content:space-between;padding:10px 0 6px;font-size:17px;font-weight:900;">' +
          '<span>TOTAL</span><span style="color:var(--primary);">' + Number(d.totalMru || 0).toFixed(0) + ' MRU</span>' +
        '</div>' +
        '<div style="padding:8px 10px;border-radius:10px;background:rgba(16,185,129,0.12);border:1px solid rgba(16,185,129,0.35);font-size:12px;font-weight:800;color:var(--primary);">💳 Paiement : ' + payLabel + '</div>' +
        proofHtml +
        '<button class="submit-btn" style="margin-top:12px;" onclick="window.print()">🖨️ Imprimer / Enregistrer PDF</button>';
      document.getElementById('receiptModal').classList.remove('hidden');
    }
    function closeReceiptModal() {
      document.getElementById('receiptModal').classList.add('hidden');
    }

    function clearTracker() {
      activeOrderCode = '';
      localStorage.removeItem('ft_qr_order_' + TENANT_CODE);
      document.getElementById('trackerBox').classList.add('hidden');
    }

    async function callWaiter(kind) {
      const tableName = INITIAL_TABLE || (document.getElementById('tableInput').value || '').trim() || 'Table';
      try {
        const res = await fetch('/public/call-waiter/' + encodeURIComponent(TENANT_CODE), {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ tableName, kind }),
        });
        if (res.ok) {
          showToast(kind === 'bill'
            ? (lang === 'fr' ? '🧾 Demande d’addition envoyée !' : '🧾 تم طلب الحساب!')
            : (lang === 'fr' ? '🔔 Le serveur a été prévenu !' : '🔔 تم إشعار النادل!'));
        }
      } catch {}
    }

    loadMenu();
  </script>
</body>
</html>`;
}

async function handlePublicQrRoute({
  req,
  res,
  url,
  pathname,
  database,
  sendJson,
  readJsonBody,
  DEFAULT_DELIVERY_ZONES,
  standardLimit = 512 * 1024,
}) {
  let m;

  // 1. GET /m/:tenantCode — Mobile Web App Menu QR
  if (req.method === 'GET' && (m = pathname.match(/^\/m\/([^/]+)\/?$/))) {
    const code = decodeURIComponent(m[1]);
    const tenant = findTenantByCode(database, code);
    if (!tenant) {
      res.writeHead(404, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end('<h1>Restaurant introuvable</h1>');
      return true;
    }
    const tableParam = (url.searchParams.get('table') || '').trim();
    const html = renderMobileMenuHtml({ tenant, initialTable: tableParam });
    res.writeHead(200, {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
    });
    res.end(html);
    return true;
  }

  // 2. GET /public/menu/:tenantCode — Live Public JSON Catalog
  if (req.method === 'GET' && (m = pathname.match(/^\/public\/menu\/([^/]+)$/))) {
    const code = decodeURIComponent(m[1]);
    const tenant = findTenantByCode(database, code);
    if (!tenant) {
      sendJson(res, 404, { error: 'Restaurant introuvable' });
      return true;
    }
    const payload = buildPublicMenuPayload(database, tenant, DEFAULT_DELIVERY_ZONES);
    if (!payload.settings.enabled) {
      sendJson(res, 403, { error: 'Menu QR temporairement désactivé par le restaurant.' });
      return true;
    }
    sendJson(res, 200, payload);
    return true;
  }

  // 3. POST /public/orders/:tenantCode — Place QR / Online Order
  if (req.method === 'POST' && (m = pathname.match(/^\/public\/orders\/([^/]+)$/))) {
    const code = decodeURIComponent(m[1]);
    const tenant = findTenantByCode(database, code);
    if (!tenant) {
      sendJson(res, 404, { error: 'Restaurant introuvable' });
      return true;
    }
    const settings = getOrCreateQrSettings(database, tenant);
    if (!settings.enabled || !settings.allowOrdering) {
      sendJson(res, 403, { error: 'Commande en ligne désactivée (mode consultation seule).' });
      return true;
    }
    const b = (await readJsonBody(req, 2 * 1024 * 1024)) || {};
    const rawItems = Array.isArray(b.items) ? b.items : [];
    if (rawItems.length === 0) {
      sendJson(res, 400, { error: 'Le panier est vide.' });
      return true;
    }

    const serviceMode = ['dine_in', 'takeaway', 'delivery'].includes(b.serviceMode)
      ? b.serviceMode
      : 'dine_in';
    const tableName = String(b.tableName || '').trim();
    const customerName = String(b.customerName || '').trim();
    const customerPhone = String(b.customerPhone || '').trim();
    const deliveryZone = String(b.deliveryZone || '').trim();
    let deliveryAddress = String(b.deliveryAddress || '').trim();
    const latNum = Number(b.deliveryLat);
    const lngNum = Number(b.deliveryLng);
    const explicitGpsUrl = String(b.deliveryGpsUrl || '').trim();
    const resolvedGpsUrl = explicitGpsUrl ||
      (Number.isFinite(latNum) && Number.isFinite(lngNum) && (latNum !== 0 || lngNum !== 0)
        ? `https://maps.google.com/?q=${latNum.toFixed(6)},${lngNum.toFixed(6)}`
        : '');
    if (serviceMode === 'delivery' && resolvedGpsUrl && !deliveryAddress.includes(resolvedGpsUrl)) {
      deliveryAddress = deliveryAddress
        ? `${deliveryAddress} · 📍 GPS: ${resolvedGpsUrl}`
        : `📍 GPS: ${resolvedGpsUrl}`;
    }
    const notes = String(b.notes || '').trim();
    const rawPayMethod = String(b.payMethod || 'PENDING').trim();
    const payMethod = rawPayMethod && rawPayMethod.toUpperCase() !== 'PENDING' ? rawPayMethod.slice(0, 40) : 'PENDING';
    const paymentRef = String(b.paymentRef || '').trim().slice(0, 80);
    const rawReceipt = String(b.paymentReceiptDataUrl || '').trim();
    const receiptImageData = rawReceipt.startsWith('data:image/') && rawReceipt.length <= 1500000 ? rawReceipt : '';

    // Server-side price verification
    const resolvedItems = [];
    let subtotalMru = 0;
    for (const it of rawItems) {
      const pid = Number(it.productId);
      const qty = Math.max(1, Math.min(99, Number(it.qty || 1)));
      const prod = database
        .prepare('SELECT * FROM products WHERE id = ? AND tenant_id = ? AND active = 1')
        .get(pid, tenant.id);
      if (!prod) {
        sendJson(res, 400, { error: `Article invalide (#${pid})` });
        return true;
      }
      if (Number(prod.is_out_of_stock || 0) === 1) {
        sendJson(res, 409, { error: `Article épuisé : ${prod.name_fr}` });
        return true;
      }
      const unitPrice = Number(prod.price_retail || 0);
      subtotalMru += unitPrice * qty;
      resolvedItems.push({
        productId: prod.id,
        nameFr: prod.name_fr,
        qty,
        unitPrice,
        kitchenStation: prod.kitchen_station || 'KITCHEN',
        note: String(it.note || '').trim(),
      });
    }

    let deliveryFeeMru = 0;
    if (serviceMode === 'delivery') {
      const parsedZones = parseJsonSafe(tenant.delivery_zones_json, []);
      const zones =
        Array.isArray(parsedZones) && parsedZones.length > 0
          ? parsedZones
          : DEFAULT_DELIVERY_ZONES;
      const foundZ = zones.find(
        (z) => String(z.nameFr || '').toLowerCase() === deliveryZone.toLowerCase()
      );
      deliveryFeeMru = foundZ ? Number(foundZ.feeMru || 0) : 0;
      const freeAbove = Number(tenant.free_delivery_above_mru ?? 1500);
      if (freeAbove > 0 && subtotalMru >= freeAbove) deliveryFeeMru = 0;
    }

    const totalMru = subtotalMru + deliveryFeeMru;
    const nowIso = new Date().toISOString();
    const orderCode = `QR-${Date.now().toString().slice(-5)}`;
    const channel = serviceMode === 'dine_in' ? 'QR_TABLE' : 'ONLINE_WEB';
    const initialStatus = settings.requirePosValidation ? 'QR_PENDING' : 'OPEN';

    const ins = database
      .prepare(`
        INSERT INTO orders (
          tenant_id, order_code, table_name, channel, service_mode, delivery_zone,
          delivery_fee_mru, status, pay_method, total_mru, discount_mru,
          customer_name, customer_phone, delivery_address, notes, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?)
      `)
      .run(
        tenant.id,
        orderCode,
        tableName,
        channel,
        serviceMode,
        deliveryZone,
        deliveryFeeMru,
        initialStatus,
        payMethod,
        totalMru,
        customerName,
        customerPhone,
        deliveryAddress,
        notes,
        nowIso
      );

    const orderId = Number(ins.lastInsertRowid);
    if (payMethod !== 'PENDING' || paymentRef || receiptImageData) {
      database
        .prepare(`
          INSERT OR REPLACE INTO qr_payment_receipts (
            order_id, tenant_id, pay_method, payment_ref, receipt_image_data, verified, created_at
          ) VALUES (?, ?, ?, ?, ?, 0, ?)
        `)
        .run(orderId, tenant.id, payMethod, paymentRef, receiptImageData, nowIso);
    }
    const insItem = database.prepare(`
      INSERT INTO order_items (
        order_id, product_id, qty, unit_price, modifiers_json, kitchen_note, kitchen_station, kds_status
      ) VALUES (?, ?, ?, ?, '[]', ?, ?, 'PENDING')
    `);
    for (const ri of resolvedItems) {
      insItem.run(orderId, ri.productId, ri.qty, ri.unitPrice, ri.note, ri.kitchenStation);
    }

    sendJson(res, 201, {
      ok: true,
      orderCode,
      status: initialStatus,
      subtotalMru,
      deliveryFeeMru,
      totalMru,
      estimatedMinutes: 15,
    });
    return true;
  }

  // 4. GET /public/orders/:tenantCode/:orderCode — Customer Order Tracking
  if (req.method === 'GET' && (m = pathname.match(/^\/public\/orders\/([^/]+)\/([^/]+)$/))) {
    const code = decodeURIComponent(m[1]);
    const orderCode = decodeURIComponent(m[2]);
    const tenant = findTenantByCode(database, code);
    if (!tenant) {
      sendJson(res, 404, { error: 'Restaurant introuvable' });
      return true;
    }
    const order = database
      .prepare('SELECT * FROM orders WHERE tenant_id = ? AND order_code = ? LIMIT 1')
      .get(tenant.id, orderCode);
    if (!order) {
      sendJson(res, 404, { error: 'Commande introuvable' });
      return true;
    }
    const receiptRow = database
      .prepare('SELECT pay_method, payment_ref, receipt_image_data FROM qr_payment_receipts WHERE order_id = ? LIMIT 1')
      .get(order.id);
    const items = database
      .prepare(`
        SELECT oi.qty, oi.unit_price, p.name_fr, p.name_ar
        FROM order_items oi
        LEFT JOIN products p ON p.id = oi.product_id
        WHERE oi.order_id = ?
      `)
      .all(order.id)
      .map((it) => ({
        nameFr: it.name_fr || 'Article',
        nameAr: it.name_ar || '',
        qty: Number(it.qty || 1),
        unitPrice: Number(it.unit_price || 0),
      }));
    sendJson(res, 200, {
      orderCode: order.order_code,
      status: order.status,
      serviceMode: order.service_mode,
      tableName: order.table_name,
      tenantName: tenant.name,
      deliveryZone: order.delivery_zone || '',
      deliveryFeeMru: Number(order.delivery_fee_mru || 0),
      subtotalMru: Math.max(0, Number(order.total_mru || 0) - Number(order.delivery_fee_mru || 0)),
      totalMru: Number(order.total_mru || 0),
      customerName: order.customer_name || '',
      customerPhone: order.customer_phone || '',
      deliveryAddress: order.delivery_address || '',
      payMethod: receiptRow?.pay_method || order.pay_method || 'PENDING',
      paymentRef: receiptRow?.payment_ref || '',
      hasReceipt: Boolean(receiptRow?.receipt_image_data),
      receiptImageData: receiptRow?.receipt_image_data || '',
      items,
      createdAt: order.created_at,
    });
    return true;
  }

  // 5. POST /public/call-waiter/:tenantCode — Table Waiter / Bill Call
  if (req.method === 'POST' && (m = pathname.match(/^\/public\/call-waiter\/([^/]+)$/))) {
    const code = decodeURIComponent(m[1]);
    const tenant = findTenantByCode(database, code);
    if (!tenant) {
      sendJson(res, 404, { error: 'Restaurant introuvable' });
      return true;
    }
    ensureQrMenuSchema(database);
    const b = (await readJsonBody(req, standardLimit)) || {};
    const tableName = String(b.tableName || 'Table').trim().slice(0, 40);
    const kind = b.kind === 'bill' ? 'bill' : 'waiter';
    const note = String(b.note || '').trim().slice(0, 120);
    const nowIso = new Date().toISOString();
    const ins = database
      .prepare(
        `INSERT INTO qr_alerts (tenant_id, table_name, kind, note, status, created_at)
         VALUES (?, ?, ?, ?, 'OPEN', ?)`
      )
      .run(tenant.id, tableName, kind, note, nowIso);
    sendJson(res, 201, { ok: true, id: Number(ins.lastInsertRowid), tableName, kind });
    return true;
  }

  return false;
}

async function handlePosQrRoute({
  req,
  res,
  pathname,
  database,
  currentTenant,
  sendJson,
  readJsonBody,
  standardLimit = 512 * 1024,
}) {
  ensureQrMenuSchema(database);
  let m;

  // GET /api/pos/qr/settings
  if (req.method === 'GET' && pathname === '/api/pos/qr/settings') {
    const settings = getOrCreateQrSettings(database, currentTenant);
    sendJson(res, 200, { ok: true, settings });
    return true;
  }

  // PUT /api/pos/qr/settings
  if (req.method === 'PUT' && pathname === '/api/pos/qr/settings') {
    const cur = getOrCreateQrSettings(database, currentTenant);
    const b = (await readJsonBody(req, standardLimit)) || {};
    const enabled = typeof b.enabled === 'boolean' ? b.enabled : cur.enabled;
    const allowOrdering =
      typeof b.allowOrdering === 'boolean' ? b.allowOrdering : cur.allowOrdering;
    const requirePosValidation =
      typeof b.requirePosValidation === 'boolean'
        ? b.requirePosValidation
        : cur.requirePosValidation;
    const whatsappNumber =
      typeof b.whatsappNumber === 'string' ? b.whatsappNumber.trim() : cur.whatsappNumber;
    const welcomeFr = typeof b.welcomeFr === 'string' ? b.welcomeFr.trim() : cur.welcomeFr;
    const welcomeAr = typeof b.welcomeAr === 'string' ? b.welcomeAr.trim() : cur.welcomeAr;
    const nowIso = new Date().toISOString();

    database
      .prepare(`
        INSERT INTO qr_settings (
          tenant_id, enabled, allow_ordering, require_pos_validation,
          whatsapp_number, welcome_fr, welcome_ar, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(tenant_id) DO UPDATE SET
          enabled = excluded.enabled,
          allow_ordering = excluded.allow_ordering,
          require_pos_validation = excluded.require_pos_validation,
          whatsapp_number = excluded.whatsapp_number,
          welcome_fr = excluded.welcome_fr,
          welcome_ar = excluded.welcome_ar,
          updated_at = excluded.updated_at
      `)
      .run(
        currentTenant.id,
        enabled ? 1 : 0,
        allowOrdering ? 1 : 0,
        requirePosValidation ? 1 : 0,
        whatsappNumber,
        welcomeFr,
        welcomeAr,
        nowIso
      );

    sendJson(res, 200, {
      ok: true,
      settings: getOrCreateQrSettings(database, currentTenant),
    });
    return true;
  }

  // GET /api/pos/qr/incoming
  if (req.method === 'GET' && pathname === '/api/pos/qr/incoming') {
    const orders = database
      .prepare(`
        SELECT o.*,
               r.pay_method AS receipt_pay_method,
               r.payment_ref AS receipt_ref,
               r.receipt_image_data AS receipt_image_data
        FROM orders o
        LEFT JOIN qr_payment_receipts r ON r.order_id = o.id
        WHERE o.tenant_id = ? AND o.status = 'QR_PENDING'
        ORDER BY o.created_at DESC
        LIMIT 50
      `)
      .all(currentTenant.id);

    const itemStmt = database.prepare(`
      SELECT oi.id, oi.product_id, oi.qty, oi.unit_price, oi.kitchen_note,
             p.sku, p.name_fr, p.name_ar
      FROM order_items oi
      LEFT JOIN products p ON p.id = oi.product_id
      WHERE oi.order_id = ?
    `);

    const extractGpsUrl = (addr) => {
      const s = String(addr || '');
      const mUrl = s.match(/https?:\/\/(?:www\.)?(?:maps\.google\.com|google\.com\/maps|goo\.gl\/maps|maps\.app\.goo\.gl)\S*/i);
      if (mUrl) return mUrl[0];
      const mCoords = s.match(/(-?\d{1,2}\.\d{3,8})\s*,\s*(-?\d{1,3}\.\d{3,8})/);
      if (mCoords) return `https://maps.google.com/?q=${mCoords[1]},${mCoords[2]}`;
      return '';
    };

    const formattedOrders = orders.map((o) => ({
      id: o.id,
      orderCode: o.order_code,
      tableName: o.table_name || '',
      channel: o.channel || 'QR_TABLE',
      serviceMode: o.service_mode || 'dine_in',
      deliveryZone: o.delivery_zone || '',
      deliveryFeeMru: Number(o.delivery_fee_mru || 0),
      subtotalMru: Math.max(0, Number(o.total_mru || 0) - Number(o.delivery_fee_mru || 0)),
      totalMru: Number(o.total_mru || 0),
      customerName: o.customer_name || '',
      customerPhone: o.customer_phone || '',
      deliveryAddress: o.delivery_address || '',
      gpsUrl: extractGpsUrl(o.delivery_address),
      payMethod: o.receipt_pay_method || o.pay_method || 'PENDING',
      paymentRef: o.receipt_ref || '',
      hasReceipt: Boolean(o.receipt_image_data),
      paymentReceiptUrl: o.receipt_image_data || '',
      notes: o.notes || '',
      createdAt: o.created_at,
      items: itemStmt.all(o.id).map((it) => ({
        productId: it.product_id,
        sku: it.sku || '',
        nameFr: it.name_fr || 'Article',
        nameAr: it.name_ar || '',
        qty: Number(it.qty || 1),
        unitPrice: Number(it.unit_price || 0),
        kitchenNote: it.kitchen_note || '',
      })),
    }));

    const alerts = database
      .prepare(`
        SELECT id, table_name, kind, note, created_at
        FROM qr_alerts
        WHERE tenant_id = ? AND status = 'OPEN'
        ORDER BY created_at DESC
        LIMIT 30
      `)
      .all(currentTenant.id)
      .map((a) => ({
        id: a.id,
        tableName: a.table_name,
        kind: a.kind,
        note: a.note,
        createdAt: a.created_at,
      }));

    sendJson(res, 200, { ok: true, orders: formattedOrders, alerts });
    return true;
  }

  // POST /api/pos/qr/orders/:orderCode/accept
  if (
    req.method === 'POST' &&
    (m = pathname.match(/^\/api\/pos\/qr\/orders\/([^/]+)\/accept$/))
  ) {
    const orderCode = decodeURIComponent(m[1]);
    const row = database
      .prepare('SELECT id FROM orders WHERE tenant_id = ? AND order_code = ? LIMIT 1')
      .get(currentTenant.id, orderCode);
    if (!row) {
      sendJson(res, 404, { error: 'Commande QR introuvable' });
      return true;
    }
    database
      .prepare("UPDATE orders SET status = 'OPEN', kds_sent_at = ? WHERE id = ?")
      .run(new Date().toISOString(), row.id);
    sendJson(res, 200, { ok: true, orderCode, status: 'OPEN' });
    return true;
  }

  // POST /api/pos/qr/orders/:orderCode/status — Live progression (OPEN -> KDS_PREP -> READY -> PAID)
  if (
    req.method === 'POST' &&
    (m = pathname.match(/^\/api\/pos\/qr\/orders\/([^/]+)\/status$/))
  ) {
    const orderCode = decodeURIComponent(m[1]);
    const row = database
      .prepare('SELECT id FROM orders WHERE tenant_id = ? AND order_code = ? LIMIT 1')
      .get(currentTenant.id, orderCode);
    if (!row) {
      sendJson(res, 404, { error: 'Commande QR introuvable' });
      return true;
    }
    const b = (await readJsonBody(req, standardLimit)) || {};
    const allowed = ['QR_PENDING', 'OPEN', 'KDS_PREP', 'READY', 'PAID', 'CANCELLED'];
    const nextStatus = String(b.status || '').trim().toUpperCase();
    if (!allowed.includes(nextStatus)) {
      sendJson(res, 400, { error: 'Statut invalide' });
      return true;
    }
    database
      .prepare('UPDATE orders SET status = ? WHERE id = ?')
      .run(nextStatus, row.id);
    if (nextStatus === 'READY' || nextStatus === 'PAID') {
      database
        .prepare("UPDATE order_items SET kds_status = 'READY' WHERE order_id = ?")
        .run(row.id);
    }
    sendJson(res, 200, { ok: true, orderCode, status: nextStatus });
    return true;
  }

  // POST /api/pos/qr/orders/:orderCode/reject
  if (
    req.method === 'POST' &&
    (m = pathname.match(/^\/api\/pos\/qr\/orders\/([^/]+)\/reject$/))
  ) {
    const orderCode = decodeURIComponent(m[1]);
    const row = database
      .prepare('SELECT id FROM orders WHERE tenant_id = ? AND order_code = ? LIMIT 1')
      .get(currentTenant.id, orderCode);
    if (!row) {
      sendJson(res, 404, { error: 'Commande QR introuvable' });
      return true;
    }
    database.prepare("UPDATE orders SET status = 'CANCELLED' WHERE id = ?").run(row.id);
    sendJson(res, 200, { ok: true, orderCode, status: 'CANCELLED' });
    return true;
  }

  // POST /api/pos/qr/alerts/:id/ack
  if (req.method === 'POST' && (m = pathname.match(/^\/api\/pos\/qr\/alerts\/(\d+)\/ack$/))) {
    const alertId = Number(m[1]);
    database
      .prepare("UPDATE qr_alerts SET status = 'ACK' WHERE id = ? AND tenant_id = ?")
      .run(alertId, currentTenant.id);
    sendJson(res, 200, { ok: true, id: alertId });
    return true;
  }

  return false;
}

module.exports = {
  ensureQrMenuSchema,
  handlePublicQrRoute,
  handlePosQrRoute,
};
