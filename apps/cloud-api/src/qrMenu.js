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

  return {
    tenant: {
      tenantCode: tenant.tenant_code,
      name: tenant.name,
      city: tenant.city || 'Nouakchott',
      district: tenant.district || '',
      address: tenant.address || '',
      phone: tenant.phone || '',
      freeDeliveryAboveMru: Number(tenant.free_delivery_above_mru ?? 1500),
    },
    settings,
    deliveryZones,
    categories,
    products,
  };
}

function renderMobileMenuHtml({ tenant, initialTable }) {
  const safeCode = escapeHtml(tenant.tenant_code);
  const safeName = escapeHtml(tenant.name);
  const safeTable = escapeHtml(initialTable || '');

  return `<!DOCTYPE html>
<html lang="fr" dir="ltr">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" />
  <title>${safeName} · Menu QR & Commande</title>
  <style>
    :root {
      --bg: #0b1220;
      --surface: #131c2e;
      --surface-alt: #1b2740;
      --border: rgba(148,163,184,0.18);
      --text: #f8fafc;
      --muted: #94a3b8;
      --primary: #10b981;
      --primary-dark: #059669;
      --accent: #f59e0b;
      --danger: #ef4444;
    }
    * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Noto Sans Arabic', sans-serif;
      background: var(--bg);
      color: var(--text);
      padding-bottom: 92px;
    }
    .header {
      position: sticky; top: 0; z-index: 30;
      background: rgba(11,18,32,0.92);
      backdrop-filter: blur(12px);
      border-bottom: 1px solid var(--border);
      padding: 12px 14px;
    }
    .header-top { display: flex; align-items: center; justify-content: space-between; gap: 10px; }
    .brand { display: flex; align-items: center; gap: 10px; min-width: 0; }
    .brand-icon {
      width: 40px; height: 40px; border-radius: 12px;
      background: linear-gradient(135deg, #10b981, #059669);
      display: flex; align-items: center; justify-content: center;
      font-weight: 900; font-size: 18px; color: #fff; flex-shrink: 0;
    }
    .brand-title { font-weight: 900; font-size: 16px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .brand-sub { font-size: 11.5px; color: var(--muted); }
    .lang-btn {
      background: var(--surface-alt); color: var(--text);
      border: 1px solid var(--border); border-radius: 10px;
      padding: 7px 11px; font-weight: 800; font-size: 12px; cursor: pointer;
    }
    .table-bar {
      margin-top: 10px; display: flex; align-items: center; justify-content: space-between; gap: 8px;
      background: rgba(16,185,129,0.12); border: 1px solid rgba(16,185,129,0.35);
      border-radius: 12px; padding: 8px 10px; flex-wrap: wrap;
    }
    .table-pill { font-weight: 900; color: #34d399; font-size: 13px; }
    .table-actions { display: flex; gap: 6px; }
    .mini-btn {
      background: var(--surface); color: var(--text); border: 1px solid var(--border);
      border-radius: 8px; padding: 6px 10px; font-size: 11.5px; font-weight: 800; cursor: pointer;
    }
    .mini-btn.warn { border-color: rgba(245,158,11,0.5); color: #fbbf24; }
    .search-wrap { padding: 10px 14px 4px; }
    .search-input {
      width: 100%; background: var(--surface); color: var(--text);
      border: 1px solid var(--border); border-radius: 12px;
      padding: 11px 14px; font-size: 14px; outline: none;
    }
    .search-input:focus { border-color: var(--primary); }
    .cats {
      display: flex; gap: 8px; overflow-x: auto; padding: 10px 14px;
      scrollbar-width: none;
    }
    .cats::-webkit-scrollbar { display: none; }
    .cat-chip {
      flex-shrink: 0; background: var(--surface); color: var(--muted);
      border: 1px solid var(--border); border-radius: 999px;
      padding: 8px 14px; font-weight: 800; font-size: 12.5px; cursor: pointer;
    }
    .cat-chip.active {
      background: var(--primary); color: #052e16; border-color: var(--primary);
    }
    .grid {
      display: grid; grid-template-columns: repeat(auto-fill, minmax(162px, 1fr));
      gap: 12px; padding: 6px 14px 16px;
    }
    .card {
      background: var(--surface); border: 1px solid var(--border);
      border-radius: 16px; overflow: hidden; display: flex; flex-direction: column;
    }
    .card.oos { opacity: 0.55; }
    .card-img {
      height: 112px; background: var(--surface-alt);
      display: flex; align-items: center; justify-content: center;
      font-size: 34px; position: relative; overflow: hidden;
    }
    .card-img img { width: 100%; height: 100%; object-fit: cover; }
    .oos-tag {
      position: absolute; top: 8px; right: 8px;
      background: rgba(239,68,68,0.92); color: #fff;
      font-size: 10px; font-weight: 900; padding: 3px 7px; border-radius: 6px;
    }
    .card-body { padding: 10px; flex: 1; display: flex; flex-direction: column; justify-content: space-between; gap: 8px; }
    .card-name { font-weight: 800; font-size: 13.5px; line-height: 1.25; }
    .card-foot { display: flex; align-items: center; justify-content: space-between; gap: 6px; }
    .price { font-weight: 900; color: #34d399; font-size: 14px; }
    .add-btn {
      background: var(--primary); color: #052e16; border: none;
      border-radius: 10px; padding: 6px 12px; font-weight: 900; font-size: 13px; cursor: pointer;
    }
    .add-btn:disabled { background: #334155; color: #94a3b8; cursor: not-allowed; }
    .qty-box { display: flex; align-items: center; gap: 6px; }
    .qty-b {
      width: 28px; height: 28px; border-radius: 8px; border: 1px solid var(--border);
      background: var(--surface-alt); color: var(--text); font-weight: 900; cursor: pointer;
    }
    .cart-bar {
      position: fixed; left: 12px; right: 12px; bottom: 14px; z-index: 40;
      background: linear-gradient(135deg, #10b981, #059669);
      color: #052e16; border: none; border-radius: 16px;
      padding: 14px 18px; display: flex; align-items: center; justify-content: space-between;
      font-weight: 900; font-size: 15px; box-shadow: 0 12px 30px rgba(0,0,0,0.45);
      cursor: pointer;
    }
    .hidden { display: none !important; }
    .modal-bg {
      position: fixed; inset: 0; z-index: 60;
      background: rgba(2,6,23,0.78); backdrop-filter: blur(6px);
      display: flex; align-items: flex-end; justify-content: center;
    }
    .sheet {
      width: 100%; max-width: 520px; max-height: 90vh; overflow-y: auto;
      background: var(--surface); border-top-left-radius: 22px; border-top-right-radius: 22px;
      border: 1px solid var(--border); padding: 18px;
    }
    .sheet h3 { margin: 0 0 12px; font-size: 17px; font-weight: 900; }
    .mode-row { display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; margin-bottom: 12px; }
    .mode-btn {
      background: var(--surface-alt); color: var(--muted); border: 1px solid var(--border);
      border-radius: 10px; padding: 9px 6px; font-weight: 800; font-size: 12px; cursor: pointer;
    }
    .mode-btn.active { background: rgba(16,185,129,0.2); border-color: var(--primary); color: #34d399; }
    .field {
      width: 100%; background: var(--bg); color: var(--text);
      border: 1px solid var(--border); border-radius: 10px;
      padding: 10px 12px; font-size: 13.5px; margin-bottom: 8px;
    }
    .cart-line {
      display: flex; align-items: center; justify-content: space-between; gap: 8px;
      padding: 8px 0; border-bottom: 1px solid var(--border);
    }
    .submit-btn {
      width: 100%; background: var(--primary); color: #052e16; border: none;
      border-radius: 14px; padding: 14px; font-weight: 900; font-size: 15px; cursor: pointer;
      margin-top: 10px;
    }
    .tracker {
      margin: 16px 14px; background: var(--surface); border: 1px solid rgba(16,185,129,0.45);
      border-radius: 18px; padding: 18px; text-align: center;
    }
    .badge-status {
      display: inline-block; padding: 6px 14px; border-radius: 999px;
      background: rgba(16,185,129,0.18); color: #34d399; font-weight: 900; font-size: 13px;
      margin: 8px 0;
    }
    .toast {
      position: fixed; top: 18px; left: 50%; transform: translateX(-50%); z-index: 90;
      background: #10b981; color: #052e16; padding: 10px 16px; border-radius: 12px;
      font-weight: 900; font-size: 13px; box-shadow: 0 8px 24px rgba(0,0,0,0.4);
    }
  </style>
</head>
<body>
  <div id="toast" class="toast hidden"></div>

  <header class="header">
    <div class="header-top">
      <div class="brand">
        <div class="brand-icon">🍽</div>
        <div>
          <div id="restName" class="brand-title">${safeName}</div>
          <div id="restSub" class="brand-sub">Menu QR · Commande directe</div>
        </div>
      </div>
      <button id="langBtn" class="lang-btn" onclick="toggleLang()">العربية</button>
    </div>

    <div id="tableBar" class="table-bar ${safeTable ? '' : 'hidden'}">
      <div id="tableLabel" class="table-pill">🍽 Table : ${safeTable}</div>
      <div class="table-actions">
        <button class="mini-btn warn" onclick="callWaiter('waiter')" id="btnCallWaiter">🔔 Serveur</button>
        <button class="mini-btn" onclick="callWaiter('bill')" id="btnCallBill">🧾 Addition</button>
      </div>
    </div>
  </header>

  <div id="trackerBox" class="tracker hidden"></div>

  <div class="search-wrap">
    <input id="searchInput" class="search-input" type="search" placeholder="Rechercher un plat, boisson..." oninput="renderGrid()" />
  </div>

  <div id="catsBar" class="cats"></div>
  <main id="menuGrid" class="grid"></main>

  <button id="cartBar" class="cart-bar hidden" onclick="openCart()">
    <span id="cartCountLabel">🛒 0 articles</span>
    <span id="cartTotalLabel">0 MRU →</span>
  </button>

  <div id="cartModal" class="modal-bg hidden" onclick="if(event.target===this) closeCart()">
    <div class="sheet">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;">
        <h3 id="cartTitle" style="margin:0;">Votre commande</h3>
        <button class="mini-btn" onclick="closeCart()">✕</button>
      </div>
      <div id="modeRow" class="mode-row">
        <button class="mode-btn" data-mode="dine_in" onclick="setMode('dine_in')">🍽 Sur place</button>
        <button class="mode-btn" data-mode="takeaway" onclick="setMode('takeaway')">🛍 Emporter</button>
        <button class="mode-btn" data-mode="delivery" onclick="setMode('delivery')">🛵 Livraison</button>
      </div>
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
      </div>
      <div id="cartItemsList"></div>
      <input id="orderNote" class="field" style="margin-top:10px;" placeholder="Note cuisine (ex: sans piment, bien cuit...)" />
      <div id="cartSummary" style="display:flex;justify-content:space-between;font-weight:900;font-size:16px;margin-top:8px;"></div>
      <button id="submitOrderBtn" class="submit-btn" onclick="submitOrder()">Confirmer la commande</button>
    </div>
  </div>

  <script>
    const TENANT_CODE = ${JSON.stringify(tenant.tenant_code)};
    const INITIAL_TABLE = ${JSON.stringify(initialTable || '')};
    let lang = 'fr';
    let menuData = null;
    let activeCatId = 'all';
    let cart = {};
    let serviceMode = INITIAL_TABLE ? 'dine_in' : 'takeaway';
    let activeOrderCode = localStorage.getItem('ft_qr_order_' + TENANT_CODE) || '';
    let pollTimer = null;

    function showToast(msg) {
      const t = document.getElementById('toast');
      t.textContent = msg;
      t.classList.remove('hidden');
      setTimeout(() => t.classList.add('hidden'), 3200);
    }

    function toggleLang() {
      lang = lang === 'fr' ? 'ar' : 'fr';
      document.documentElement.lang = lang;
      document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
      document.getElementById('langBtn').textContent = lang === 'fr' ? 'العربية' : 'Français';
      document.getElementById('searchInput').placeholder = lang === 'fr' ? 'Rechercher un plat, boisson...' : 'ابحث عن طبق أو مشروب...';
      document.getElementById('btnCallWaiter').textContent = lang === 'fr' ? '🔔 Serveur' : '🔔 نداء النادل';
      document.getElementById('btnCallBill').textContent = lang === 'fr' ? '🧾 Addition' : '🧾 الحساب';
      renderCats();
      renderGrid();
      renderCartBar();
    }

    function labelOf(obj) {
      return lang === 'ar' ? (obj.nameAr || obj.nameFr) : obj.nameFr;
    }

    async function loadMenu() {
      try {
        const res = await fetch('/public/menu/' + encodeURIComponent(TENANT_CODE));
        menuData = await res.json();
        if (!res.ok) throw new Error(menuData.error || 'Menu indisponible');
        document.getElementById('restName').textContent = menuData.tenant.name;
        document.getElementById('restSub').textContent = (menuData.tenant.city || 'Nouakchott') + (menuData.tenant.phone ? ' · ' + menuData.tenant.phone : '');
        const zSel = document.getElementById('zoneSelect');
        zSel.innerHTML = (menuData.deliveryZones || []).map(z =>
          '<option value="' + escapeAttr(z.nameFr) + '" data-fee="' + Number(z.feeMru || 0) + '">' + escapeAttr(z.nameFr) + ' (+' + Number(z.feeMru || 0) + ' MRU)</option>'
        ).join('');
        renderCats();
        renderGrid();
        setMode(serviceMode);
        if (activeOrderCode) pollOrderStatus();
      } catch (e) {
        document.getElementById('menuGrid').innerHTML = '<p style="padding:20px;color:#ef4444;font-weight:800;">' + e.message + '</p>';
      }
    }

    function escapeAttr(s) {
      return String(s || '').replace(/"/g, '&quot;').replace(/</g, '&lt;');
    }

    function renderCats() {
      if (!menuData) return;
      const bar = document.getElementById('catsBar');
      const allLabel = lang === 'fr' ? '🍽 Tout' : '🍽 الكل';
      let html = '<button class="cat-chip ' + (activeCatId === 'all' ? 'active' : '') + '" onclick="selectCat(\\'all\\')">' + allLabel + '</button>';
      for (const c of menuData.categories) {
        html += '<button class="cat-chip ' + (String(activeCatId) === String(c.id) ? 'active' : '') + '" onclick="selectCat(' + c.id + ')">' + (c.icon || '') + ' ' + escapeAttr(labelOf(c)) + '</button>';
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
      const grid = document.getElementById('menuGrid');
      if (items.length === 0) {
        grid.innerHTML = '<div style="grid-column:1/-1;text-align:center;color:#94a3b8;padding:30px;">' + (lang === 'fr' ? 'Aucun article trouvé.' : 'لا توجد نتائج') + '</div>';
        return;
      }
      grid.innerHTML = items.map(p => {
        const qty = cart[p.id] || 0;
        const imgHtml = p.imageUrl ? '<img src="' + escapeAttr(p.imageUrl) + '" alt="" />' : '🍽';
        const oosTag = !p.available ? '<span class="oos-tag">' + (lang === 'fr' ? 'ÉPUISÉ' : 'نفذ') + '</span>' : '';
        let actionHtml = '';
        if (!allowOrder) {
          actionHtml = '';
        } else if (qty > 0) {
          actionHtml = '<div class="qty-box"><button class="qty-b" onclick="changeQty(' + p.id + ',-1)">−</button><b>' + qty + '</b><button class="qty-b" onclick="changeQty(' + p.id + ',1)">+</button></div>';
        } else {
          actionHtml = '<button class="add-btn" ' + (!p.available ? 'disabled' : '') + ' onclick="changeQty(' + p.id + ',1)">+</button>';
        }
        return '<div class="card ' + (!p.available ? 'oos' : '') + '">' +
          '<div class="card-img">' + imgHtml + oosTag + '</div>' +
          '<div class="card-body">' +
            '<div class="card-name">' + escapeAttr(labelOf(p)) + '</div>' +
            '<div class="card-foot"><span class="price">' + Number(p.priceMru).toFixed(0) + ' MRU</span>' + actionHtml + '</div>' +
          '</div></div>';
      }).join('');
    }

    function changeQty(prodId, delta) {
      const next = (cart[prodId] || 0) + delta;
      if (next <= 0) delete cart[prodId];
      else cart[prodId] = next;
      renderGrid();
      renderCartBar();
      if (!document.getElementById('cartModal').classList.contains('hidden')) renderCartSheet();
    }

    function cartSubtotal() {
      if (!menuData) return 0;
      let sum = 0;
      for (const [id, qty] of Object.entries(cart)) {
        const pr = menuData.products.find(p => String(p.id) === String(id));
        if (pr) sum += pr.priceMru * qty;
      }
      return sum;
    }

    function renderCartBar() {
      const count = Object.values(cart).reduce((a, b) => a + b, 0);
      const bar = document.getElementById('cartBar');
      if (count <= 0) { bar.classList.add('hidden'); return; }
      bar.classList.remove('hidden');
      document.getElementById('cartCountLabel').textContent = (lang === 'fr' ? '🛒 ' + count + ' article(s)' : '🛒 ' + count + ' صنف');
      document.getElementById('cartTotalLabel').textContent = cartSubtotal().toFixed(0) + ' MRU →';
    }

    function setMode(m) {
      serviceMode = m;
      document.querySelectorAll('.mode-btn').forEach(b => b.classList.toggle('active', b.dataset.mode === m));
      document.getElementById('tableInputWrap').classList.toggle('hidden', m !== 'dine_in');
      document.getElementById('customerFields').classList.toggle('hidden', m === 'dine_in');
      document.getElementById('deliveryFields').classList.toggle('hidden', m !== 'delivery');
      renderCartSheet();
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
      list.innerHTML = entries.map(([id, qty]) => {
        const pr = menuData.products.find(p => String(p.id) === String(id));
        if (!pr) return '';
        return '<div class="cart-line">' +
          '<div><b>' + qty + 'x ' + escapeAttr(labelOf(pr)) + '</b><div style="font-size:12px;color:#94a3b8;">' + (pr.priceMru * qty).toFixed(0) + ' MRU</div></div>' +
          '<div class="qty-box"><button class="qty-b" onclick="changeQty(' + pr.id + ',-1)">−</button><button class="qty-b" onclick="changeQty(' + pr.id + ',1)">+</button></div>' +
        '</div>';
      }).join('');
      const total = cartSubtotal() + currentDeliveryFee();
      document.getElementById('cartSummary').innerHTML =
        '<span>' + (lang === 'fr' ? 'Total à payer' : 'الإجمالي') + '</span><span style="color:#34d399;">' + total.toFixed(0) + ' MRU</span>';
    }

    async function submitOrder() {
      const btn = document.getElementById('submitOrderBtn');
      const items = Object.entries(cart).map(([productId, qty]) => ({ productId: Number(productId), qty }));
      if (items.length === 0) return;
      const tableName = (document.getElementById('tableInput').value || '').trim();
      const customerName = (document.getElementById('custName').value || '').trim();
      const customerPhone = (document.getElementById('custPhone').value || '').trim();
      const deliveryZone = document.getElementById('zoneSelect').value || '';
      const deliveryAddress = (document.getElementById('custAddr').value || '').trim();
      const notes = (document.getElementById('orderNote').value || '').trim();

      if (serviceMode !== 'dine_in' && (!customerName || !customerPhone)) {
        showToast(lang === 'fr' ? 'Nom et téléphone requis.' : 'الاسم ورقم الهاتف مطلوبان');
        return;
      }
      btn.disabled = true;
      btn.textContent = lang === 'fr' ? 'Envoi en cours...' : 'جاري الإرسال...';
      try {
        const res = await fetch('/public/orders/' + encodeURIComponent(TENANT_CODE), {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ serviceMode, tableName, customerName, customerPhone, deliveryZone, deliveryAddress, notes, items }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || 'Erreur envoi');
        cart = {};
        activeOrderCode = data.orderCode;
        localStorage.setItem('ft_qr_order_' + TENANT_CODE, activeOrderCode);
        closeCart();
        renderGrid();
        renderCartBar();
        showToast(lang === 'fr' ? 'Commande envoyée ! N° ' + activeOrderCode : 'تم إرسال طلبك بنجاح! ' + activeOrderCode);
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
        const box = document.getElementById('trackerBox');
        box.classList.remove('hidden');
        const map = {
          QR_PENDING: lang === 'fr' ? '⏳ Reçue — En attente de validation caisse' : '⏳ تم الاستلام — في انتظار تأكيد الكاشير',
          OPEN: lang === 'fr' ? '👨‍🍳 Validée — En préparation en cuisine' : '👨‍🍳 تم التأكيد — قيد التحضير',
          KDS_PREP: lang === 'fr' ? '🔥 En cours de cuisson en cuisine' : '🔥 جاري التحضير في المطبخ',
          READY: lang === 'fr' ? '✅ Votre commande est PRÊTE !' : '✅ طلبك جاهز الآن!',
          PAID: lang === 'fr' ? '🎉 Commande terminée — Merci !' : '🎉 شكراً لزيارتكم!',
          CANCELLED: lang === 'fr' ? '❌ Commande annulée' : '❌ تم إلغاء الطلب',
        };
        box.innerHTML =
          '<div style="font-size:12px;color:#94a3b8;font-weight:800;">SUIVI COMMANDE · ' + escapeAttr(d.orderCode) + '</div>' +
          '<div class="badge-status">' + (map[d.status] || d.status) + '</div>' +
          '<div style="font-weight:900;font-size:15px;">' + Number(d.totalMru || 0).toFixed(0) + ' MRU</div>' +
          ((d.status === 'PAID' || d.status === 'CANCELLED')
            ? '<button class="mini-btn" style="margin-top:8px;" onclick="clearTracker()">Fermer</button>'
            : '');
        if (d.status !== 'PAID' && d.status !== 'CANCELLED') {
          clearTimeout(pollTimer);
          pollTimer = setTimeout(pollOrderStatus, 8000);
        }
      } catch {}
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
    const b = (await readJsonBody(req, standardLimit)) || {};
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
    const deliveryAddress = String(b.deliveryAddress || '').trim();
    const notes = String(b.notes || '').trim();

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
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'PENDING', ?, 0, ?, ?, ?, ?, ?)
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
        totalMru,
        customerName,
        customerPhone,
        deliveryAddress,
        notes,
        nowIso
      );

    const orderId = Number(ins.lastInsertRowid);
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
    sendJson(res, 200, {
      orderCode: order.order_code,
      status: order.status,
      serviceMode: order.service_mode,
      tableName: order.table_name,
      totalMru: Number(order.total_mru || 0),
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
        SELECT * FROM orders
        WHERE tenant_id = ? AND status = 'QR_PENDING'
        ORDER BY created_at DESC
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
