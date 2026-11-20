const http = require('node:http');
const {
  createDb,
  getDb,
  DEFAULT_DB_PATH,
  DEFAULT_DELIVERY_ZONES,
  hashPassword,
  verifyPassword,
} = require('./db');
const { createPgBackupManager } = require('./pg_sync');
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
  requireTenantAuth,
} = require('./auth');
const { importCatalog } = require('./catalogImport');
const { handleCommercialRoute, ensureCommercialDefaults } = require('./commercial');

const DEFAULT_ENABLED_THEMES = ['01', '04', '06', '07', '11'];
const DEFAULT_PAY_METHODS = ['Cash', 'Bankily', 'Masrivi', 'Sedad', 'Bimbank', 'Click', 'Karni'];
const VALID_KDS_STATIONS = new Set(['ALL', 'GRILL', 'KITCHEN', 'BAR']);

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
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
  const parsedZones = parseJson(r.delivery_zones_json, []);
  const deliveryZones =
    parsedZones.length > 0 ? parsedZones : (r.module === 'resto' ? DEFAULT_DELIVERY_ZONES : []);
  return {
    id: r.id,
    tenantId: r.tenant_code,
    tenantCode: r.tenant_code,
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
    enabledThemes: parseJson(r.enabled_themes, DEFAULT_ENABLED_THEMES),
    features: parseJson(r.features),
    payMethods: parseJson(r.pay_methods, DEFAULT_PAY_METHODS),
    deliveryZones,
    freeDeliveryAboveMru: Number(r.free_delivery_above_mru ?? 1500),
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

  if (!options.dbPath && resolvedDbPath === DEFAULT_DB_PATH) {
    const singletonDb = getDb();
    if (singletonDb && singletonDb.isOpen !== false) {
      return {
        database: singletonDb,
        dbPath: resolvedDbPath,
        ownsDb: false,
      };
    }
  }

  return {
    database: createDb(resolvedDbPath),
    dbPath: resolvedDbPath,
    ownsDb: true,
  };
}

function pick(obj, ...keys) {
  if (!obj || typeof obj !== 'object') return undefined;
  for (const k of keys) {
    if (obj[k] !== undefined && obj[k] !== null) return obj[k];
  }
  return undefined;
}

function normalizeServiceMode(raw) {
  const s = String(raw || '').trim().toLowerCase().replace(/[\s-]+/g, '_');
  if (s === 'takeaway' || s === 'emporter') {
    return { dbMode: 'takeaway', channel: 'TAKEAWAY' };
  }
  if (s === 'delivery' || s === 'livraison') {
    return { dbMode: 'delivery', channel: 'DELIVERY' };
  }
  if (s === 'retail') {
    return { dbMode: 'retail', channel: 'RETAIL' };
  }
  return { dbMode: 'dine_in', channel: 'DINE_IN' };
}

function normalizePayMethod(raw) {
  const s = String(raw || '').trim().toLowerCase();
  if (s === 'cash' || s === 'especes' || s === 'espèces') return 'Cash';
  if (s === 'bankily') return 'Bankily';
  if (s === 'masrivi') return 'Masrivi';
  if (s === 'sedad') return 'Sedad';
  if (s === 'bimbank') return 'Bimbank';
  if (s === 'click') return 'Click';
  if (s === 'karni' || s === 'credit' || s === 'crédit') return 'Karni';
  if (s === 'mixte' || s === 'mixed' || s === 'split') return 'Mixte';
  if (s === 'gimtel' || s === 'carte gimtel') return 'Gimtel';
  return String(raw || 'Cash').trim() || 'Cash';
}

function normalizePayKey(raw) {
  const s = String(raw || '').trim().toLowerCase();
  if (s === 'cash' || s === 'especes' || s === 'espèces') return 'cash';
  if (s === 'bankily') return 'bankily';
  if (s === 'masrivi') return 'masrivi';
  if (s === 'sedad') return 'sedad';
  if (s === 'bimbank') return 'bimbank';
  if (s === 'click') return 'click';
  if (s === 'karni' || s === 'credit' || s === 'crédit') return 'karni';
  return null;
}

function toUtcIso(raw) {
  const s = String(raw || '').trim();
  if (!s) return new Date().toISOString();
  if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/.test(s)) {
    return `${s.replace(' ', 'T')}Z`;
  }
  const ms = Date.parse(s);
  return Number.isNaN(ms) ? new Date().toISOString() : new Date(ms).toISOString();
}

function extractModifierKeys(rawModifiers) {
  let mods = rawModifiers;
  if (typeof mods === 'string') {
    try {
      mods = JSON.parse(mods);
    } catch {
      mods = [];
    }
  }
  const modKeys = new Set();
  if (Array.isArray(mods)) {
    for (const m of mods) {
      if (typeof m === 'string' && m.trim()) {
        modKeys.add(m.trim().toLowerCase());
      } else if (m && typeof m === 'object') {
        for (const k of [m.bomKey, m.bom_key, m.id, m.key, m.nameFr, m.name_fr, m.nameEn, m.name_en, m.name]) {
          if (typeof k === 'string' && k.trim()) {
            modKeys.add(k.trim().toLowerCase());
          }
        }
      }
    }
  }
  return modKeys;
}

function resolveProductForTenant(database, tenantId, line) {
  if (!line || typeof line !== 'object') return null;
  const rawProdId = pick(line, 'product_id', 'productId');
  if (rawProdId !== undefined && rawProdId !== '' && /^\d+$/.test(String(rawProdId).trim())) {
    const byId = database
      .prepare('SELECT id, sku, name_fr, price_retail, kitchen_station FROM products WHERE tenant_id = ? AND id = ? LIMIT 1')
      .get(tenantId, Number(rawProdId));
    if (byId) return byId;
  }
  const sku = String(pick(line, 'sku', 'product_sku', 'productSku') ?? '').trim();
  if (sku) {
    const bySku = database
      .prepare('SELECT id, sku, name_fr, price_retail, kitchen_station FROM products WHERE tenant_id = ? AND sku = ? LIMIT 1')
      .get(tenantId, sku);
    if (bySku) return bySku;
  }
  const name = String(pick(line, 'name', 'name_fr', 'nameFr', 'item', 'item_name', 'itemName') ?? '').trim();
  if (name) {
    const byName = database
      .prepare('SELECT id, sku, name_fr, price_retail, kitchen_station FROM products WHERE tenant_id = ? AND LOWER(name_fr) = LOWER(?) LIMIT 1')
      .get(tenantId, name);
    if (byName) return byName;
  }
  return null;
}

function resolveKarniCustomer(database, tenantId, criteria = {}, createIfMissing = false) {
  const rawCustId = pick(criteria, 'karni_customer_id', 'karniCustomerId', 'customer_id', 'customerId');
  if (rawCustId !== undefined && String(rawCustId).trim() !== '') {
    const idStr = String(rawCustId).trim();
    if (!/^\d+$/.test(idStr) || Number(idStr) <= 0) {
      throw createHttpError(400, 'Invalid Karni customerId');
    }
    const byId = database
      .prepare('SELECT * FROM customer_credits_karni WHERE tenant_id = ? AND id = ? LIMIT 1')
      .get(tenantId, Number(idStr));
    if (!byId) {
      throw createHttpError(404, 'Karni customer not found');
    }
    return byId;
  }
  const custName = String(pick(criteria, 'customer_name', 'customerName', 'name') ?? '').trim();
  if (custName) {
    const byName = database
      .prepare('SELECT * FROM customer_credits_karni WHERE tenant_id = ? AND LOWER(customer_name) = LOWER(?) LIMIT 1')
      .get(tenantId, custName);
    if (byName) return byName;
  }
  const custPhone = String(pick(criteria, 'customer_phone', 'customerPhone', 'phone_whatsapp', 'phone') ?? '').trim();
  if (custPhone) {
    const byPhone = database
      .prepare('SELECT * FROM customer_credits_karni WHERE tenant_id = ? AND phone_whatsapp = ? LIMIT 1')
      .get(tenantId, custPhone);
    if (byPhone) return byPhone;
  }
  if (createIfMissing && custName) {
    const info = database.prepare(`
      INSERT INTO customer_credits_karni (
        tenant_id, customer_name, phone_whatsapp, credit_limit_mru, current_debt_mru, status
      ) VALUES (?, ?, ?, 10000, 0, 'active')
    `).run(tenantId, custName, custPhone);
    return database.prepare('SELECT * FROM customer_credits_karni WHERE id = ? LIMIT 1').get(Number(info.lastInsertRowid));
  }
  return null;
}

function deductBomForProduct(database, tenantId, productId, qty, channelUpper, rawModifiers = []) {
  if (!productId || !(qty > 0)) return 0;
  const bomRows = database.prepare(`
    SELECT rb.id, rb.ingredient_id, rb.qty_per_unit, rb.condition_channel, rb.modifier_key,
           i.sku AS ing_sku, i.name_fr AS ing_name, i.pmp_cost_mru
    FROM recipes_bom rb
    JOIN ingredients i ON i.id = rb.ingredient_id
    WHERE rb.tenant_id = ? AND rb.product_id = ?
  `).all(tenantId, productId);

  if (bomRows.length === 0) return 0;

  const modKeys = extractModifierKeys(rawModifiers);
  const updateStock = database.prepare(`
    UPDATE ingredients
    SET current_stock = MAX(0, ROUND(current_stock - ?, 6)),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = ? AND tenant_id = ?
  `);

  let totalCostMru = 0;
  for (const b of bomRows) {
    const ch = String(b.condition_channel || 'ALL').trim().toUpperCase();
    const channelMatches =
      ch === 'ALL' ||
      ch === '' ||
      ch === channelUpper ||
      (ch === 'TAKEAWAY_DELIVERY' && (channelUpper === 'TAKEAWAY' || channelUpper === 'DELIVERY'));
    if (!channelMatches) continue;

    const mk = String(b.modifier_key || '').trim().toLowerCase();
    if (mk !== '') {
      if (!modKeys.has(mk)) continue;
    } else {
      const exclSku = `-${String(b.ing_sku || '').trim().toLowerCase()}`;
      const exclName = `-${String(b.ing_name || '').trim().toLowerCase()}`;
      if ((b.ing_sku && modKeys.has(exclSku)) || (b.ing_name && modKeys.has(exclName))) continue;
    }

    const delta = Number(b.qty_per_unit) * qty;
    if (!Number.isFinite(delta) || delta === 0) continue;
    updateStock.run(delta, b.ingredient_id, tenantId);
    totalCostMru += delta * Number(b.pmp_cost_mru || 0);
  }
  return Math.round(totalCostMru);
}

function synthesizeTablesForZone(z) {
  const count = Math.max(0, Number(z.table_count || 0));
  const isVip = Boolean(z.is_vip);
  const cols = Math.max(1, Math.min(4, count));
  const out = [];
  for (let i = 0; i < count; i++) {
    const col = i % cols;
    const row = Math.floor(i / cols);
    const prefix = isVip ? 'KHAIMA' : 'T';
    out.push({
      id: `z${z.id}-t${i + 1}`,
      code: `${prefix}-${String(i + 1).padStart(2, '0')}`,
      seats: isVip ? 10 : 4,
      shape: isVip ? 'khaima' : (i % 2 === 0 ? 'round' : 'square'),
      x: Number((0.18 + col * 0.22).toFixed(2)),
      y: Number((0.25 + row * 0.3).toFixed(2)),
      status: 'free',
    });
  }
  return out;
}

function handlePosSyncItem(database, tenantId, item, nowIso, insertAudit) {
  if (!item || typeof item !== 'object' || Array.isArray(item)) {
    throw createHttpError(400, 'Each sync item must be a JSON object');
  }

  const entityType = String(item.entity_type || 'event').trim().toLowerCase().slice(0, 40) || 'event';
  const p = item.payload && typeof item.payload === 'object' && !Array.isArray(item.payload)
    ? item.payload
    : {};
  const externalId = String(pick(p, 'order_code', 'orderCode', 'ticket_number', 'ticketNumber', 'id') ?? item.id ?? '').trim();
  const actor = String(pick(p, 'staff_name', 'staffName', 'cashier_name', 'cashierName', 'approved_by', 'approvedBy') ?? 'POS Terminal').trim() || 'POS Terminal';
  const hm = nowHM();

  const isTraining =
    p.is_training === true ||
    p.isTraining === true ||
    p.is_training === 1 ||
    p.isTraining === 1;

  if (isTraining) {
    insertAudit.run(
      tenantId,
      actor,
      `POS_SYNC_TRAINING_${entityType.toUpperCase()}`,
      `POS Formation · ${entityType.toUpperCase()}`,
      `[MODE FORMATION] Ignoré des comptes réels · ${externalId || '-'}`,
      entityType,
      externalId,
      JSON.stringify(p),
      hm,
      1,
      nowIso,
    );
    return;
  }

  if (entityType === 'order') {
    const orderCode = externalId || `ORD-${Date.now()}`;
    const rawStatus = String(pick(p, 'status') ?? 'PAID').trim().toUpperCase();
    const status =
      rawStatus === 'COMPLETED' ? 'PAID'
        : rawStatus === 'PREPARING' ? 'KDS_PREP'
          : rawStatus === 'CANCELLED' ? 'VOID'
            : (['OPEN', 'KDS_PREP', 'READY', 'PAID', 'VOID'].includes(rawStatus) ? rawStatus : 'PAID');

    const rawModeInput = pick(p, 'service_mode', 'serviceMode', 'channel');
    const hasServiceMode = rawModeInput !== undefined;
    const rawMode = rawModeInput ?? 'dine_in';
    const { dbMode: serviceMode, channel } = normalizeServiceMode(rawMode);

    const rawDz = pick(p, 'delivery_zone', 'deliveryZone');
    const hasDeliveryZone = rawDz !== undefined;
    let deliveryZone = '';
    let dzFee = 0;
    if (rawDz && typeof rawDz === 'object') {
      deliveryZone = String(pick(rawDz, 'nameFr', 'name_fr', 'name', 'id') ?? '').trim();
      dzFee = Math.round(Number(pick(rawDz, 'feeMru', 'fee_mru') ?? 0));
    } else if (rawDz !== undefined) {
      deliveryZone = String(rawDz).trim();
    }
    const rawDeliveryFee = pick(p, 'delivery_fee_mru', 'deliveryFeeMru');
    const hasDeliveryFee =
      rawDeliveryFee !== undefined ||
      (rawDz && typeof rawDz === 'object' && pick(rawDz, 'feeMru', 'fee_mru') !== undefined);
    const deliveryFeeMru = Math.round(Number(rawDeliveryFee ?? dzFee ?? 0)) || 0;

    const rawCustomerName = pick(p, 'customer_name', 'customerName');
    const hasCustomerName = rawCustomerName !== undefined;
    const customerName = hasCustomerName ? String(rawCustomerName).trim() : '';
    const rawCustomerPhone = pick(p, 'customer_phone', 'customerPhone');
    const hasCustomerPhone = rawCustomerPhone !== undefined;
    const customerPhone = hasCustomerPhone ? String(rawCustomerPhone).trim() : '';
    const rawDeliveryAddress = pick(p, 'delivery_address', 'deliveryAddress');
    const hasDeliveryAddress = rawDeliveryAddress !== undefined;
    const deliveryAddress = hasDeliveryAddress ? String(rawDeliveryAddress).trim() : '';
    const tableName = String(pick(p, 'table_name', 'tableName', 'table_code', 'tableCode') ?? '').trim();
    const rawNotes = pick(p, 'notes', 'note');
    const hasNotes = rawNotes !== undefined;
    const notes = hasNotes ? String(rawNotes).trim() : '';
    const createdAtRaw = String(pick(p, 'created_at', 'createdAt') ?? '').trim();
    const orderCreatedAt = createdAtRaw || nowIso;

    const itemsList = Array.isArray(p.items) ? p.items : [];
    const computedSubtotal = itemsList.reduce((sum, l) => {
      if (!l || typeof l !== 'object') return sum;
      if (l.is_comp === true || l.isComp === true) return sum;
      const q = Math.max(0, Number(pick(l, 'qty', 'quantity') ?? 1));
      const up = Number(pick(l, 'unit_price', 'unitPrice', 'price_mru', 'priceMru') ?? 0);
      const lt = pick(l, 'line_total', 'lineTotal');
      return sum + (lt !== undefined ? Number(lt) : q * up);
    }, 0);

    const subtotalMru = Math.round(Number(pick(p, 'subtotal_mru', 'subtotalMru') ?? computedSubtotal)) || 0;
    const hasDiscount = pick(p, 'discount_mru', 'discountMru', 'discount_percent', 'discountPercent') !== undefined;
    const discountPct = Number(pick(p, 'discount_percent', 'discountPercent') ?? 0) || 0;
    const discountMru = Math.round(
      Number(pick(p, 'discount_mru', 'discountMru') ?? Math.round((subtotalMru * discountPct) / 100)),
    ) || 0;
    const arbounMru = Math.round(Number(pick(p, 'arboun_mru', 'arbounMru') ?? 0)) || 0;

    const explicitTotal = pick(p, 'total_mru', 'totalMru', 'net_total', 'netTotal');
    const hasTotal = explicitTotal !== undefined || itemsList.length > 0;
    const totalMru = Math.round(
      Number(explicitTotal !== undefined ? explicitTotal : Math.max(0, subtotalMru - discountMru - arbounMru + deliveryFeeMru)),
    ) || 0;

    const explicitTva = pick(p, 'tva_mru', 'tvaMru', 'tva_amount_mru', 'tvaAmountMru');
    const hasTva = explicitTva !== undefined || hasTotal;
    const tvaMru = Math.round(
      Number(explicitTva !== undefined ? explicitTva : Math.round((totalMru * 16) / 116)),
    ) || 0;

    const rawPayments = Array.isArray(p.payments) ? p.payments : [];
    const normalizedPayments = rawPayments
      .filter((pe) => pe && typeof pe === 'object')
      .map((pe) => {
        const refVal = pick(pe, 'reference', 'ref');
        return {
          method: normalizePayMethod(pe.method),
          amount_mru: Math.round(Number(pick(pe, 'amount_mru', 'amountMru', 'amount') ?? 0)) || 0,
          reference: refVal !== undefined && String(refVal).trim() !== '' ? String(refVal).trim() : undefined,
          karni_customer_id: pick(pe, 'karni_customer_id', 'karniCustomerId', 'customer_id', 'customerId'),
          customer_name: pick(pe, 'customer_name', 'customerName'),
          customer_phone: pick(pe, 'customer_phone', 'customerPhone'),
        };
      })
      .filter((pe) => pe.amount_mru > 0);

    const hasPayMethod = normalizedPayments.length > 0 || pick(p, 'pay_method', 'payMethod') !== undefined;
    const hasPaymentsJson = rawPayments.length > 0 || p.payments !== undefined;
    const payMethod =
      normalizedPayments.length > 1
        ? 'Mixte'
        : normalizedPayments.length === 1
          ? normalizedPayments[0].method
          : normalizePayMethod(pick(p, 'pay_method', 'payMethod') ?? 'Cash');
    const paymentsJson = JSON.stringify(normalizedPayments);

    const kdsSentAtRaw = String(pick(p, 'kds_sent_at', 'kdsSentAt') ?? '').trim();
    const hasPendingItem = itemsList.some((l) => {
      const st = String(pick(l, 'kds_status', 'kdsStatus') ?? '').trim().toUpperCase();
      return st === 'PENDING' || st === 'PREPARING';
    });
    const kdsSentAt = kdsSentAtRaw || ((status === 'OPEN' || status === 'KDS_PREP' || hasPendingItem) ? orderCreatedAt : '');

    const applyOrderKarniCharges = (
      orderId,
      fallbackCustomerName = customerName,
      fallbackCustomerPhone = customerPhone,
      effectiveTotalMru = totalMru,
      effectivePayMethod = payMethod,
    ) => {
      if (status !== 'PAID') return;
      const karniEntries = normalizedPayments.filter((pe) => pe.method === 'Karni' && pe.amount_mru > 0);
      if (karniEntries.length === 0 && effectivePayMethod === 'Karni' && effectiveTotalMru > 0) {
        karniEntries.push({ method: 'Karni', amount_mru: effectiveTotalMru });
      }
      for (const ke of karniEntries) {
        const cust = resolveKarniCustomer(database, tenantId, {
          karni_customer_id: ke.karni_customer_id ?? pick(p, 'karni_customer_id', 'karniCustomerId', 'customer_id', 'customerId'),
          customer_name: ke.customer_name ?? fallbackCustomerName,
          customer_phone: ke.customer_phone ?? fallbackCustomerPhone,
        }, true);
        if (!cust) {
          throw createHttpError(400, 'Karni customer is required');
        }
        const curDebt = Number(cust.current_debt_mru || 0);
        const creditLimit = Number(cust.credit_limit_mru || 0);
        if (creditLimit > 0 && curDebt + ke.amount_mru > creditLimit) {
          throw createHttpError(400, 'Karni credit limit exceeded');
        }
        database.prepare(`
          UPDATE customer_credits_karni
          SET current_debt_mru = current_debt_mru + ?, updated_at = CURRENT_TIMESTAMP
          WHERE id = ? AND tenant_id = ?
        `).run(ke.amount_mru, cust.id, tenantId);
        database.prepare(`
          INSERT INTO karni_transactions (
            tenant_id, customer_id, order_id, tx_type, amount_mru, pay_method, ref, approved_by, notes, created_at
          ) VALUES (?, ?, ?, 'CHARGE', ?, 'Karni', ?, ?, ?, ?)
        `).run(tenantId, cust.id, orderId, ke.amount_mru, ke.reference || orderCode, actor, `Commande ${orderCode}`, nowIso);
      }
    };

    const existing = database
      .prepare('SELECT * FROM orders WHERE tenant_id = ? AND order_code = ? LIMIT 1')
      .get(tenantId, orderCode);

    if (existing) {
      const existingUpper = String(existing.status || '').toUpperCase();
      if (existingUpper === 'PAID' || existingUpper === status) {
        insertAudit.run(
          tenantId,
          actor,
          'POS_SYNC_ORDER_DEDUP',
          `POS Sync · Commande ${orderCode} (dédupliquée)`,
          `${payMethod} · ${totalMru} MRU`,
          'order',
          orderCode,
          JSON.stringify(p),
          hm,
          0,
          nowIso,
        );
        return;
      }

      if (status === 'PAID' || status === 'READY' || status === 'VOID') {
        const nextServiceMode = hasServiceMode ? serviceMode : (existing.service_mode || 'dine_in');
        const nextChannel = hasServiceMode ? channel : (existing.channel || 'DINE_IN');
        const nextDeliveryZone = hasDeliveryZone ? deliveryZone : (existing.delivery_zone || '');
        const nextDeliveryFeeMru = hasDeliveryFee ? deliveryFeeMru : Number(existing.delivery_fee_mru ?? 0);
        const nextCustomerName = hasCustomerName ? customerName : (existing.customer_name || '');
        const nextCustomerPhone = hasCustomerPhone ? customerPhone : (existing.customer_phone || '');
        const nextDeliveryAddress = hasDeliveryAddress ? deliveryAddress : (existing.delivery_address || '');
        const nextNotes = hasNotes ? notes : (existing.notes || '');
        const nextDiscountMru = hasDiscount ? discountMru : Number(existing.discount_mru ?? 0);
        const nextTotalMru = hasTotal ? totalMru : Number(existing.total_mru ?? 0);
        const nextTvaMru = hasTva ? tvaMru : Number(existing.tva_mru ?? 0);
        const nextPayMethod = hasPayMethod ? payMethod : (existing.pay_method || 'Cash');
        const nextPaymentsJson = hasPaymentsJson ? paymentsJson : (existing.payments_json || '[]');

        database.prepare(`
          UPDATE orders SET
            status = ?, pay_method = ?, payments_json = ?, total_mru = ?, tva_mru = ?,
            discount_mru = ?, delivery_fee_mru = ?, service_mode = ?, channel = ?,
            delivery_zone = ?, customer_name = ?, customer_phone = ?, delivery_address = ?,
            notes = ?
          WHERE id = ? AND tenant_id = ?
        `).run(
          status, nextPayMethod, nextPaymentsJson, nextTotalMru, nextTvaMru,
          nextDiscountMru, nextDeliveryFeeMru, nextServiceMode, nextChannel,
          nextDeliveryZone, nextCustomerName, nextCustomerPhone, nextDeliveryAddress,
          nextNotes, existing.id, tenantId,
        );
        if (status === 'READY') {
          database.prepare("UPDATE order_items SET kds_status = 'READY' WHERE order_id = ?").run(existing.id);
        }
        if (existingUpper !== 'PAID' && status === 'PAID') {
          applyOrderKarniCharges(existing.id, nextCustomerName, nextCustomerPhone, nextTotalMru, nextPayMethod);
        }
        insertAudit.run(
          tenantId,
          actor,
          'POS_SYNC_ORDER_UPDATE',
          `POS Sync · Commande ${orderCode} (${status})`,
          `${nextPayMethod} · ${nextTotalMru} MRU`,
          'order',
          orderCode,
          JSON.stringify(p),
          hm,
          0,
          nowIso,
        );
        return;
      }
    }

    const orderInfo = database.prepare(`
      INSERT INTO orders (
        tenant_id, order_code, table_name, channel, service_mode, delivery_zone, delivery_fee_mru,
        status, pay_method, payments_json, total_mru, tva_mru, discount_mru,
        customer_name, customer_phone, delivery_address, is_training, kds_sent_at, notes, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)
    `).run(
      tenantId, orderCode, tableName, channel, serviceMode, deliveryZone, deliveryFeeMru,
      status, payMethod, paymentsJson, totalMru, tvaMru, discountMru,
      customerName, customerPhone, deliveryAddress, kdsSentAt, notes, orderCreatedAt,
    );
    const orderId = Number(orderInfo.lastInsertRowid);

    const insOrderItem = database.prepare(`
      INSERT INTO order_items (
        order_id, product_id, qty, unit_price, modifiers_json, kitchen_note, kitchen_station, kds_status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `);

    for (const line of itemsList) {
      if (!line || typeof line !== 'object') continue;
      const prod = resolveProductForTenant(database, tenantId, line);
      if (!prod) continue;
      const qty = Math.max(1, Math.round(Number(pick(line, 'qty', 'quantity') ?? 1)));
      const unitPrice = Math.round(Number(pick(line, 'unit_price', 'unitPrice', 'price_mru', 'priceMru') ?? prod.price_retail ?? 0)) || 0;
      const rawMods = pick(line, 'modifiers', 'modifiers_json', 'selectedModifiers') ?? [];
      const modsJson = typeof rawMods === 'string' ? rawMods : JSON.stringify(Array.isArray(rawMods) ? rawMods : []);
      const kitchenNote = String(pick(line, 'kitchen_note', 'kitchenNote', 'note') ?? '').trim();
      const station = String(pick(line, 'kitchen_station', 'kitchenStation') ?? prod.kitchen_station ?? 'KITCHEN').trim().toUpperCase() || 'KITCHEN';
      const rawItemKds = String(pick(line, 'kds_status', 'kdsStatus') ?? '').trim().toUpperCase();
      const itemKdsStatus = ['PENDING', 'PREPARING', 'READY'].includes(rawItemKds)
        ? rawItemKds
        : ((status === 'PAID' || status === 'READY') ? 'READY' : 'PENDING');

      insOrderItem.run(orderId, prod.id, qty, unitPrice, modsJson, kitchenNote, station, itemKdsStatus);
      if (status !== 'VOID') {
        deductBomForProduct(database, tenantId, prod.id, qty, channel, rawMods);
      }
    }

    applyOrderKarniCharges(orderId);

    insertAudit.run(
      tenantId,
      actor,
      'POS_SYNC_ORDER',
      `POS Sync · Commande ${orderCode}`,
      `${payMethod} · ${totalMru} MRU`,
      'order',
      orderCode,
      JSON.stringify(p),
      hm,
      0,
      nowIso,
    );
    return;
  }

  if (entityType === 'remake') {
    const extId = String(pick(p, 'id') ?? item.id ?? '').trim();
    if (extId) {
      const dup = database
        .prepare("SELECT id FROM audit_logs WHERE tenant_id = ? AND action = 'POS_SYNC_REMAKE' AND entity_id = ? LIMIT 1")
        .get(tenantId, extId);
      if (dup) {
        insertAudit.run(tenantId, actor, 'POS_SYNC_REMAKE_DEDUP', 'POS Sync · Remake (dédupliqué)', extId, 'remake', extId, JSON.stringify(p), hm, 0, nowIso);
        return;
      }
    }
    const actionType = String(pick(p, 'action_type', 'actionType', 'type') ?? 'REMAKE').trim().toUpperCase() || 'REMAKE';
    const reason = String(pick(p, 'reason') ?? '').trim();
    const qty = Math.max(1, Math.round(Number(pick(p, 'qty', 'quantity') ?? 1)));
    const amountMru = Math.round(Number(pick(p, 'amount_mru', 'amountMru') ?? 0)) || 0;
    const approvedBy = String(pick(p, 'approved_by', 'approvedBy') ?? actor).trim();

    const orderRef = String(pick(p, 'order_code', 'orderCode', 'ticket', 'orderTicket') ?? '').trim();
    let orderId = pick(p, 'order_id', 'orderId') ?? null;
    if (!orderId && orderRef) {
      const ord = database.prepare('SELECT id FROM orders WHERE tenant_id = ? AND order_code = ? LIMIT 1').get(tenantId, orderRef);
      if (ord) orderId = ord.id;
    }

    const prod = resolveProductForTenant(database, tenantId, p);
    const productId = prod ? prod.id : null;
    const { channel } = normalizeServiceMode(pick(p, 'service_mode', 'serviceMode', 'channel') ?? 'dine_in');
    let bomCost = 0;
    if (actionType === 'REMAKE' && productId) {
      bomCost = deductBomForProduct(database, tenantId, productId, qty, channel, pick(p, 'modifiers', 'modifiers_json') ?? []);
    }
    const costValueMru = Math.round(Number(pick(p, 'cost_value_mru', 'costValueMru') ?? bomCost)) || 0;

    database.prepare(`
      INSERT INTO returns_remakes_comps (
        tenant_id, order_id, product_id, type, reason, qty, amount_mru, cost_value_mru, restock, approved_by, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(tenantId, orderId, productId, actionType, reason, qty, amountMru, costValueMru, actionType === 'RETURN' && p.restock ? 1 : 0, approvedBy, nowIso);

    insertAudit.run(
      tenantId,
      actor,
      'POS_SYNC_REMAKE',
      `POS Sync · ${actionType}`,
      `${reason || 'Exception cuisine'} · ${amountMru} MRU`,
      'remake',
      extId || orderRef || '-',
      JSON.stringify(p),
      hm,
      0,
      nowIso,
    );
    return;
  }

  if (entityType === 'closing_z') {
    const extId = String(pick(p, 'id') ?? item.id ?? '').trim();
    if (extId) {
      const dup = database
        .prepare("SELECT id FROM audit_logs WHERE tenant_id = ? AND action = 'POS_SYNC_CLOSING_Z' AND entity_id = ? LIMIT 1")
        .get(tenantId, extId);
      if (dup) {
        insertAudit.run(tenantId, actor, 'POS_SYNC_CLOSING_Z_DEDUP', 'POS Sync · Clôture Z (dédupliquée)', extId, 'closing_z', extId, JSON.stringify(p), hm, 0, nowIso);
        return;
      }
    }
    const expectedMru = Math.round(Number(pick(p, 'expected_mru', 'expectedMru', 'expected_cash_mru', 'expectedCashMru') ?? 0)) || 0;
    const countedMru = Math.round(Number(pick(p, 'counted_mru', 'countedMru', 'counted_cash_mru', 'countedCashMru') ?? 0)) || 0;
    const explicitDigital = pick(p, 'digital_mru', 'digitalMru');
    const digitalMru = Math.round(Number(
      explicitDigital !== undefined
        ? explicitDigital
        : (
          Number(pick(p, 'expected_bankily_mru', 'expectedBankilyMru') ?? 0) +
          Number(pick(p, 'expected_masrivi_mru', 'expectedMasriviMru') ?? 0) +
          Number(pick(p, 'expected_sedad_mru', 'expectedSedadMru') ?? 0) +
          Number(pick(p, 'expected_bimbank_mru', 'expectedBimbankMru') ?? 0) +
          Number(pick(p, 'expected_click_mru', 'expectedClickMru') ?? 0)
        ),
    )) || 0;
    const varianceMru = Math.round(Number(
      pick(p, 'variance_mru', 'varianceMru', 'cash_variance_mru', 'cashVarianceMru') ?? (countedMru - expectedMru),
    )) || 0;
    const closedAt = String(pick(p, 'closed_at', 'closedAt') ?? nowIso);
    const openedAt = String(pick(p, 'opened_at', 'openedAt') ?? '');
    const approvedBy = String(pick(p, 'approved_by', 'approvedBy', 'cashier_name', 'cashierName') ?? actor);
    const notes = String(pick(p, 'notes', 'note') ?? '');

    database.prepare(`
      INSERT INTO cash_closings_z (
        tenant_id, expected_mru, counted_mru, digital_mru, variance_mru, approved_by, opened_at, closed_at, notes, is_training, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
    `).run(tenantId, expectedMru, countedMru, digitalMru, varianceMru, approvedBy, openedAt, closedAt, notes, nowIso);

    insertAudit.run(
      tenantId,
      actor,
      'POS_SYNC_CLOSING_Z',
      'POS Sync · Clôture Z',
      `Compté ${countedMru} MRU · Écart ${varianceMru} MRU`,
      'closing_z',
      extId || closedAt,
      JSON.stringify(p),
      hm,
      0,
      nowIso,
    );
    return;
  }

  if (entityType === 'karni') {
    const extId = String(pick(p, 'id') ?? item.id ?? '').trim();
    if (extId) {
      const dup = database
        .prepare("SELECT id FROM audit_logs WHERE tenant_id = ? AND action = 'POS_SYNC_KARNI' AND entity_id = ? LIMIT 1")
        .get(tenantId, extId);
      if (dup) {
        insertAudit.run(tenantId, actor, 'POS_SYNC_KARNI_DEDUP', 'POS Sync · Karni (dédupliqué)', extId, 'karni', extId, JSON.stringify(p), hm, 0, nowIso);
        return;
      }
    }
    const hasPaidField = pick(p, 'paid_mru', 'paidMru') !== undefined;
    const txType = String(pick(p, 'tx_type', 'txType') ?? (hasPaidField ? 'REPAYMENT' : 'CHARGE')).trim().toUpperCase();
    const rawAmount = pick(p, 'amount_mru', 'amountMru', 'paid_mru', 'paidMru');
    const rem = pick(p, 'remaining_balance_mru', 'remainingBalanceMru');
    let amountMru = 0;
    if (rawAmount !== undefined) {
      const parsedAmount = typeof rawAmount === 'boolean' || String(rawAmount).trim() === '' ? NaN : Number(rawAmount);
      if (!Number.isFinite(parsedAmount) || parsedAmount < 0) {
        throw createHttpError(400, 'Invalid Karni amountMru');
      }
      amountMru = Math.round(parsedAmount);
    } else if (rem === undefined) {
      throw createHttpError(400, 'Karni amountMru is required');
    }

    const cust = resolveKarniCustomer(database, tenantId, p, true);
    if (!cust) {
      throw createHttpError(400, 'Karni customer is required');
    }
    const curDebt = Number(cust.current_debt_mru || 0);
    let nextDebt = curDebt;
    if (txType === 'REPAYMENT') {
      nextDebt = Math.max(0, curDebt - amountMru);
    } else if (txType === 'CHARGE') {
      nextDebt = curDebt + amountMru;
      const creditLimit = Number(cust.credit_limit_mru || 0);
      if (creditLimit > 0 && nextDebt > creditLimit) {
        throw createHttpError(400, 'Karni credit limit exceeded');
      }
    } else {
      nextDebt = rem !== undefined ? Math.max(0, Math.round(Number(rem))) : Math.max(0, curDebt + amountMru);
    }
    database.prepare('UPDATE customer_credits_karni SET current_debt_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND tenant_id = ?')
      .run(nextDebt, cust.id, tenantId);
    database.prepare(`
      INSERT INTO karni_transactions (
        tenant_id, customer_id, tx_type, amount_mru, pay_method, ref, approved_by, notes, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      tenantId,
      cust.id,
      txType,
      amountMru,
      normalizePayMethod(pick(p, 'pay_method', 'payMethod') ?? 'Cash'),
      String(pick(p, 'ref', 'reference') ?? ''),
      actor,
      String(pick(p, 'notes', 'note') ?? ''),
      nowIso,
    );

    insertAudit.run(
      tenantId,
      actor,
      'POS_SYNC_KARNI',
      `POS Sync · Karni (${txType})`,
      `${cust ? cust.customer_name : 'Client'} · ${amountMru} MRU`,
      'karni',
      extId || String(cust ? cust.id : '-'),
      JSON.stringify(p),
      hm,
      0,
      nowIso,
    );
    return;
  }

  if (entityType === 'reservation') {
    const extId = String(pick(p, 'id') ?? item.id ?? '').trim();
    if (extId) {
      const dup = database
        .prepare("SELECT id FROM audit_logs WHERE tenant_id = ? AND action = 'POS_SYNC_RESERVATION' AND entity_id = ? LIMIT 1")
        .get(tenantId, extId);
      if (dup) {
        insertAudit.run(tenantId, actor, 'POS_SYNC_RESERVATION_DEDUP', 'POS Sync · Réservation (dédupliquée)', extId, 'reservation', extId, JSON.stringify(p), hm, 0, nowIso);
        return;
      }
    }
    const customerName = String(pick(p, 'customer_name', 'customerName', 'customer') ?? 'Client VIP').trim();
    const customerPhone = String(pick(p, 'customer_phone', 'customerPhone', 'phone') ?? '').trim();
    const tableLabel = String(pick(p, 'table_label', 'tableLabel', 'table_id', 'tableId') ?? '').trim();
    const guestsCount = Math.max(1, Math.round(Number(pick(p, 'guests_count', 'guestsCount', 'guests') ?? 2)));
    const reservedAt = String(pick(p, 'reserved_at', 'reservedAt') ?? nowIso);
    const depositMru = Math.round(Number(pick(p, 'deposit_mru', 'depositMru', 'arboun_mru', 'arbounMru') ?? 0)) || 0;
    const depositMethod = String(pick(p, 'deposit_method', 'depositMethod') ?? '');
    const status = String(pick(p, 'status') ?? 'CONFIRMED').trim().toUpperCase();
    const notes = String(pick(p, 'notes', 'note') ?? '');

    database.prepare(`
      INSERT INTO reservations_vip (
        tenant_id, table_label, customer_name, customer_phone, guests_count,
        reserved_at, deposit_mru, deposit_method, status, notes, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(tenantId, tableLabel, customerName, customerPhone, guestsCount, reservedAt, depositMru, depositMethod, status, notes, nowIso);

    insertAudit.run(
      tenantId,
      actor,
      'POS_SYNC_RESERVATION',
      `POS Sync · Réservation VIP ${customerName}`,
      `Table ${tableLabel || '-'} · Arboun ${depositMru} MRU`,
      'reservation',
      extId || customerName,
      JSON.stringify(p),
      hm,
      0,
      nowIso,
    );
    return;
  }

  if (entityType === 'stock_86') {
    const prod = resolveProductForTenant(database, tenantId, {
      product_id: pick(p, 'product_id', 'productId', 'id'),
      sku: pick(p, 'sku', 'product_sku', 'productSku'),
      name: pick(p, 'name', 'name_fr', 'nameFr'),
    });
    const rawOos = pick(p, 'is_out_of_stock', 'isOutOfStock');
    const rawAvail = pick(p, 'available');
    const outOfStock = rawOos !== undefined
      ? (rawOos === true || rawOos === 1 || rawOos === 'true' ? 1 : 0)
      : (rawAvail !== undefined ? (rawAvail === false || rawAvail === 0 || rawAvail === 'false' ? 1 : 0) : 1);
    if (prod) {
      database.prepare('UPDATE products SET is_out_of_stock = ?, updated_at = ? WHERE id = ? AND tenant_id = ?')
        .run(outOfStock, nowIso, prod.id, tenantId);
    }
    insertAudit.run(
      tenantId,
      actor,
      'POS_SYNC_STOCK_86',
      `POS Sync · Rupture 86 (${outOfStock ? 'ÉPUISÉ' : 'DISPO'})`,
      prod ? `${prod.name_fr} (${prod.sku || prod.id})` : (externalId || '-'),
      'product',
      prod ? String(prod.id) : (externalId || '-'),
      JSON.stringify(p),
      hm,
      0,
      nowIso,
    );
    return;
  }

  if (entityType === 'kds_ready') {
    const rawOrdKey = String(pick(p, 'order_id', 'orderId', 'order_code', 'orderCode', 'ticket_number', 'ticketNumber', 'id') ?? item.id ?? '').trim();
    const station = String(pick(p, 'station') ?? 'ALL').trim().toUpperCase() || 'ALL';
    let order = null;
    if (rawOrdKey) {
      if (/^\d+$/.test(rawOrdKey)) {
        order = database
          .prepare('SELECT id, order_code, status FROM orders WHERE tenant_id = ? AND COALESCE(is_training, 0) = 0 AND (id = ? OR order_code = ?) ORDER BY CASE WHEN id = ? THEN 0 ELSE 1 END LIMIT 1')
          .get(tenantId, Number(rawOrdKey), rawOrdKey, Number(rawOrdKey));
      } else {
        order = database
          .prepare('SELECT id, order_code, status FROM orders WHERE tenant_id = ? AND COALESCE(is_training, 0) = 0 AND order_code = ? LIMIT 1')
          .get(tenantId, rawOrdKey);
      }
    }
    if (order) {
      if (station === 'ALL') {
        database.prepare("UPDATE order_items SET kds_status = 'READY' WHERE order_id = ?").run(order.id);
      } else {
        database.prepare(`
          UPDATE order_items
          SET kds_status = 'READY'
          WHERE order_id = ?
            AND UPPER(COALESCE(
              NULLIF(kitchen_station, ''),
              (SELECT NULLIF(p.kitchen_station, '') FROM products p WHERE p.id = order_items.product_id),
              'KITCHEN'
            )) = ?
        `).run(order.id, station);
      }
      const { cnt: remaining } = database
        .prepare("SELECT COUNT(*) AS cnt FROM order_items WHERE order_id = ? AND UPPER(COALESCE(NULLIF(kds_status, ''), 'PENDING')) != 'READY'")
        .get(order.id);
      if (remaining === 0 && ['OPEN', 'KDS_PREP'].includes(String(order.status || '').toUpperCase())) {
        database.prepare("UPDATE orders SET status = 'READY' WHERE id = ? AND tenant_id = ?").run(order.id, tenantId);
      }
    }
    insertAudit.run(
      tenantId,
      actor,
      'POS_SYNC_KDS_READY',
      `POS Sync · KDS Prêt (${station})`,
      order ? order.order_code : (rawOrdKey || '-'),
      'order',
      order ? String(order.id) : (rawOrdKey || '-'),
      JSON.stringify(p),
      hm,
      0,
      nowIso,
    );
    return;
  }

  insertAudit.run(
    tenantId,
    actor,
    `POS_SYNC_${entityType.toUpperCase()}`,
    `POS Sync · ${entityType.toUpperCase()}`,
    externalId || 'Événement POS',
    entityType,
    externalId,
    JSON.stringify(p),
    hm,
    0,
    nowIso,
  );
}

function createApp(options = {}) {
  const { database, dbPath, ownsDb } = resolveDatabase(options);
  const pgBackup = options.pgBackup || null;
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

    if (pgBackup && ['POST', 'PATCH', 'PUT', 'DELETE'].includes(req.method)) {
      res.once('finish', () => {
        if (res.statusCode < 400) {
          pgBackup.schedulePush(database, dbPath);
        }
      });
    }

    const url = new URL(req.url || '/', 'http://localhost');
    const p = url.pathname;

    try {
      // 1. Health check (Public)
      if (req.method === 'GET' && (p === '/health' || p === '/healthz')) {
        const { cnt } = database.prepare('SELECT COUNT(*) AS cnt FROM tenants').get();
        return sendJson(res, 200, {
          ok: true,
          service: 'fulltek-cloud-api',
          dbPath,
          tenants: cnt,
          pgBackup: pgBackup ? pgBackup.getStatus() : { enabled: false },
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
        if (row.status === 'locked') {
          return sendJson(res, 403, { error: 'Tenant account is locked' });
        }
        const userRow = database
          .prepare('SELECT id, full_name, username, role, email, phone FROM users WHERE tenant_id = ? AND LOWER(username) = LOWER(?) LIMIT 1')
          .get(row.id, row.username);
        const token = signJwt(
          {
            tenantId: row.id,
            tenantCode: row.tenant_code,
            module: row.module,
            role: userRow?.role || 'OWNER',
          },
          DEFAULT_EXPIRES_IN_SEC,
          effectiveJwtSecret,
        );
        return sendJson(res, 200, {
          token,
          tenant: serializeTenant(row),
          user: {
            id: userRow?.id ?? null,
            username: userRow?.username || row.username,
            fullName: userRow?.full_name || row.manager || row.name,
            role: userRow?.role || 'OWNER',
            email: userRow?.email || row.email || '',
            phone: userRow?.phone || row.phone || '',
          },
        });
      }

      let m;

      // 2b. Centralized Tenant JWT Auth Guard for ALL /api/pos/* routes
      let currentTenant = null;
      if (p === '/api/pos' || p.startsWith('/api/pos/')) {
        currentTenant = requireTenantAuth(req, res, database, {
          jwtSecret: effectiveJwtSecret,
          sendJson,
        });
        if (!currentTenant) return;
      }

      // 2c. GET /api/pos/catalog — Full POS Bootstrap Catalog (Tenant-scoped)
      if (req.method === 'GET' && p === '/api/pos/catalog') {
        const tenantId = currentTenant.id;
        const enabledThemes = parseJson(currentTenant.enabled_themes, DEFAULT_ENABLED_THEMES);
        const payMethods = parseJson(currentTenant.pay_methods, DEFAULT_PAY_METHODS);
        const parsedDz = parseJson(currentTenant.delivery_zones_json, []);
        const deliveryZones = parsedDz.length > 0 ? parsedDz : (currentTenant.module === 'resto' ? DEFAULT_DELIVERY_ZONES : []);

        const categories = database
          .prepare('SELECT * FROM categories WHERE tenant_id = ? AND active = 1 ORDER BY sort_order ASC, id ASC')
          .all(tenantId)
          .map((c) => ({
            id: c.id,
            code: String(c.name_fr || '')
              .normalize('NFD')
              .replace(/[\u0300-\u036f]/g, '')
              .toUpperCase()
              .replace(/[^A-Z0-9]+/g, '_')
              .replace(/^_+|_+$/g, ''),
            nameFr: c.name_fr,
            nameAr: c.name_ar || '',
            nameEn: c.name_en || '',
            icon: c.icon || '🍽️',
            sortOrder: Number(c.sort_order ?? 0),
            active: Boolean(c.active),
          }));

        const products = database
          .prepare(`
            SELECT p.*
            FROM products p
            LEFT JOIN categories c ON c.id = p.category_id
            WHERE p.tenant_id = ? AND p.active = 1
            ORDER BY COALESCE(c.sort_order, 999) ASC, p.id ASC
          `)
          .all(tenantId)
          .map((prod) => ({
            id: prod.id,
            categoryId: prod.category_id ?? null,
            sku: prod.sku || '',
            barcode: prod.barcode || '',
            nameFr: prod.name_fr,
            nameAr: prod.name_ar || '',
            nameEn: prod.name_en || '',
            icon: prod.icon || '🍽️',
            imageUrl: prod.image_url || '',
            priceMru: Number(prod.price_retail ?? 0),
            priceCostMru: Number(prod.price_cost ?? 0),
            kitchenStation: String(prod.kitchen_station || 'KITCHEN').toUpperCase(),
            manualPrice: Boolean(prod.manual_price),
            isTop: Boolean(prod.is_top),
            isOutOfStock: Boolean(prod.is_out_of_stock),
            available: !Boolean(prod.is_out_of_stock),
            modifiers: parseJson(prod.modifiers_json, []),
          }));

        const diningZones = database
          .prepare('SELECT * FROM dining_zones WHERE tenant_id = ? AND active = 1 ORDER BY id ASC')
          .all(tenantId)
          .map((z) => {
            const rawTables = parseJson(z.tables_json, []);
            const tables = rawTables.length > 0 ? rawTables : synthesizeTablesForZone(z);
            return {
              id: z.id,
              nameFr: z.name_fr,
              nameAr: z.name_ar || '',
              nameEn: z.name_en || z.name_fr,
              zoneType: z.zone_type || 'SALLE',
              isVip: Boolean(z.is_vip),
              minSpendMru: Number(z.min_spend_mru ?? 0),
              hourlyFeeMru: Number(z.hourly_fee_mru ?? 0),
              tables,
            };
          });

        const reservationsVip = database
          .prepare("SELECT * FROM reservations_vip WHERE tenant_id = ? AND status NOT IN ('CANCELLED', 'COMPLETED') ORDER BY reserved_at ASC, id ASC")
          .all(tenantId)
          .map((r) => ({
            id: r.id,
            zoneId: r.zone_id,
            tableLabel: r.table_label || '',
            customerName: r.customer_name,
            customerPhone: r.customer_phone || '',
            phone: r.customer_phone || '',
            guestsCount: Number(r.guests_count ?? 2),
            guests: Number(r.guests_count ?? 2),
            reservedAt: r.reserved_at,
            timeSlot: String(r.reserved_at || '').includes('T') ? String(r.reserved_at).slice(11, 16) : '20:30',
            durationMin: Number(r.duration_min ?? 120),
            depositMru: Number(r.deposit_mru ?? 0),
            arbounMru: Number(r.deposit_mru ?? 0),
            depositMethod: r.deposit_method || '',
            depositDeducted: Boolean(r.deposit_deducted),
            minSpendMru: Number(r.min_spend_mru ?? 0),
            status: r.status || 'CONFIRMED',
            isCatering: Boolean(r.is_catering),
            notes: r.notes || '',
            note: r.notes || '',
          }));

        const ingredients = database
          .prepare('SELECT * FROM ingredients WHERE tenant_id = ? ORDER BY id ASC')
          .all(tenantId)
          .map((ing) => ({
            id: ing.id,
            sku: ing.sku || '',
            nameFr: ing.name_fr,
            nameAr: ing.name_ar || '',
            nameEn: ing.name_en || '',
            unit: ing.unit || 'kg',
            pmpCostMru: Number(ing.pmp_cost_mru ?? 0),
            currentStock: Number(ing.current_stock ?? 0),
            minStock: Number(ing.min_stock ?? 0),
          }));

        const recipesBom = database
          .prepare(`
            SELECT rb.*, p.sku AS product_sku, i.sku AS ingredient_sku
            FROM recipes_bom rb
            JOIN products p ON p.id = rb.product_id
            JOIN ingredients i ON i.id = rb.ingredient_id
            WHERE rb.tenant_id = ?
            ORDER BY rb.id ASC
          `)
          .all(tenantId)
          .map((rb) => ({
            id: rb.id,
            productId: rb.product_id,
            productSku: rb.product_sku || '',
            ingredientId: rb.ingredient_id,
            ingredientSku: rb.ingredient_sku || '',
            qtyPerUnit: Number(rb.qty_per_unit ?? 0),
            unit: rb.unit || 'g',
            conditionChannel: rb.condition_channel || 'ALL',
            modifierKey: rb.modifier_key || '',
          }));

        const karniCustomers = database
          .prepare("SELECT * FROM customer_credits_karni WHERE tenant_id = ? AND status != 'archived' ORDER BY id ASC")
          .all(tenantId)
          .map((k) => ({
            id: k.id,
            name: k.customer_name,
            phone: k.phone_whatsapp || '',
            companyName: k.company_name || '',
            isB2b: Boolean(k.is_b2b),
            creditLimitMru: Number(k.credit_limit_mru ?? 0),
            balanceDueMru: Number(k.current_debt_mru ?? 0),
            status: k.status || 'active',
          }));

        return sendJson(res, 200, {
          ok: true,
          tenantId,
          tenant: {
            id: currentTenant.id,
            code: currentTenant.tenant_code,
            name: currentTenant.name,
            module: currentTenant.module,
            defaultLang: currentTenant.default_lang || 'fr',
            enabledThemes,
            payMethods,
            daysLeft: Number(currentTenant.days_left ?? 0),
            ownerPin: currentTenant.owner_pin || '4242',
            deliveryZones,
            freeDeliveryAboveMru: Number(currentTenant.free_delivery_above_mru ?? 1500),
            city: currentTenant.city || '',
            address: currentTenant.address || '',
            phone: currentTenant.phone || '',
            nif: currentTenant.nif || '',
            status: currentTenant.status || 'active',
          },
          categories,
          products,
          diningZones,
          reservationsVip,
          ingredients,
          recipesBom,
          karniCustomers,
        });
      }

      // 2c-bis. POS Categories / Familles CRUD
      if (req.method === 'POST' && p === '/api/pos/categories') {
        const parsed = await readJsonBody(req, standardLimit);
        const b = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        const nameFr = typeof b.nameFr === 'string' ? b.nameFr.trim() : '';
        if (!nameFr) return sendJson(res, 400, { error: 'nameFr is required' });
        const nameAr = typeof b.nameAr === 'string' && b.nameAr.trim() ? b.nameAr.trim() : nameFr;
        const nameEn = typeof b.nameEn === 'string' && b.nameEn.trim() ? b.nameEn.trim() : nameFr;
        const icon = typeof b.icon === 'string' && b.icon.trim() ? b.icon.trim() : '🍽';
        const sortOrder = Number.isFinite(Number(b.sortOrder)) ? Number(b.sortOrder) : 99;
        const ins = database.prepare(`
          INSERT INTO categories (tenant_id, name_fr, name_ar, name_en, icon, sort_order, active, created_at)
          VALUES (?, ?, ?, ?, ?, ?, 1, ?)
        `).run(currentTenant.id, nameFr, nameAr, nameEn, icon, sortOrder, new Date().toISOString());
        const created = database.prepare('SELECT * FROM categories WHERE id = ?').get(ins.lastInsertRowid);
        return sendJson(res, 201, { ok: true, category: created });
      }

      if (req.method === 'PATCH' && (m = p.match(/^\/api\/pos\/categories\/(\d+)$/))) {
        const catId = Number(m[1]);
        const cur = database.prepare('SELECT * FROM categories WHERE id = ? AND tenant_id = ? AND active = 1').get(catId, currentTenant.id);
        if (!cur) return sendJson(res, 404, { error: 'Category not found' });
        const parsed = await readJsonBody(req, standardLimit);
        const b = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        const nameFr = typeof b.nameFr === 'string' && b.nameFr.trim() ? b.nameFr.trim() : cur.name_fr;
        const nameAr = typeof b.nameAr === 'string' && b.nameAr.trim() ? b.nameAr.trim() : cur.name_ar;
        const nameEn = typeof b.nameEn === 'string' && b.nameEn.trim() ? b.nameEn.trim() : cur.name_en;
        const icon = typeof b.icon === 'string' && b.icon.trim() ? b.icon.trim() : cur.icon;
        database.prepare('UPDATE categories SET name_fr = ?, name_ar = ?, name_en = ?, icon = ? WHERE id = ? AND tenant_id = ?')
          .run(nameFr, nameAr, nameEn, icon, catId, currentTenant.id);
        const updated = database.prepare('SELECT * FROM categories WHERE id = ?').get(catId);
        return sendJson(res, 200, { ok: true, category: updated });
      }

      if (req.method === 'DELETE' && (m = p.match(/^\/api\/pos\/categories\/(\d+)$/))) {
        const catId = Number(m[1]);
        const cur = database.prepare('SELECT * FROM categories WHERE id = ? AND tenant_id = ? AND active = 1').get(catId, currentTenant.id);
        if (!cur) return sendJson(res, 404, { error: 'Category not found' });
        database.prepare('UPDATE categories SET active = 0 WHERE id = ? AND tenant_id = ?').run(catId, currentTenant.id);
        return sendJson(res, 200, { ok: true, categoryId: catId });
      }

      // 2d. PATCH /api/pos/products/:id/availability — Stock-86 / ÉPUISÉ toggle
      if (req.method === 'PATCH' && (m = p.match(/^\/api\/pos\/products\/([^/]+)\/availability$/))) {
        let rawKey;
        try {
          rawKey = decodeURIComponent(m[1]).trim();
        } catch {
          return sendJson(res, 400, { error: 'Invalid product identifier' });
        }
        if (!rawKey) {
          return sendJson(res, 400, { error: 'Invalid product identifier' });
        }

        const parsed = await readJsonBody(req, standardLimit);
        const b = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        const hasAvail = typeof b.available === 'boolean';
        const oosVal = typeof b.isOutOfStock === 'boolean' ? b.isOutOfStock : b.is_out_of_stock;
        const hasOos = typeof oosVal === 'boolean';
        if (!hasAvail && !hasOos) {
          return sendJson(res, 400, { error: 'Boolean available or isOutOfStock is required' });
        }
        if (hasAvail && hasOos && b.available === oosVal) {
          return sendJson(res, 400, { error: 'Conflicting available and isOutOfStock values' });
        }
        const nextOutOfStock = hasAvail ? (b.available ? 0 : 1) : (oosVal ? 1 : 0);

        const product = /^\d+$/.test(rawKey)
          ? database
              .prepare(`
                SELECT * FROM products
                WHERE tenant_id = ? AND (id = ? OR sku = ?)
                ORDER BY CASE WHEN id = ? THEN 0 ELSE 1 END
                LIMIT 1
              `)
              .get(currentTenant.id, Number(rawKey), rawKey, Number(rawKey))
          : database
              .prepare('SELECT * FROM products WHERE tenant_id = ? AND sku = ? LIMIT 1')
              .get(currentTenant.id, rawKey);

        if (!product) {
          return sendJson(res, 404, { error: 'Product not found' });
        }

        const nowIso = new Date().toISOString();
        database
          .prepare('UPDATE products SET is_out_of_stock = ?, updated_at = ? WHERE id = ? AND tenant_id = ?')
          .run(nextOutOfStock, nowIso, product.id, currentTenant.id);

        database.prepare(`
          INSERT INTO audit_logs (
            tenant_id, actor, action, title, subtitle, entity_type, entity_id, after_json, time_label, created_at
          ) VALUES (?, ?, 'STOCK_86_UPDATE', ?, ?, 'product', ?, ?, ?, ?)
        `).run(
          currentTenant.id,
          currentTenant.manager || currentTenant.name,
          `Rupture 86 · ${product.name_fr}`,
          nextOutOfStock ? 'Marqué ÉPUISÉ (bloqué caisse)' : 'Remis disponible',
          String(product.id),
          JSON.stringify({ productId: product.id, sku: product.sku, isOutOfStock: nextOutOfStock === 1 }),
          nowHM(),
          nowIso,
        );

        return sendJson(res, 200, {
          ok: true,
          productId: product.id,
          sku: product.sku || '',
          available: nextOutOfStock === 0,
          isOutOfStock: nextOutOfStock === 1,
        });
      }

      // 2d-bis. POST /api/pos/products — Create new menu item (Tenant Owner/Manager)
      if (req.method === 'POST' && p === '/api/pos/products') {
        const parsed = await readJsonBody(req, standardLimit);
        const b = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        const nameFr = typeof b.nameFr === 'string' ? b.nameFr.trim() : (typeof b.name_fr === 'string' ? b.name_fr.trim() : '');
        if (!nameFr) {
          return sendJson(res, 400, { error: 'nameFr is required' });
        }
        const priceRetail = Math.round(Number(b.priceMru ?? b.price_retail ?? 0));
        if (!Number.isFinite(priceRetail) || priceRetail < 0) {
          return sendJson(res, 400, { error: 'Valid priceMru is required' });
        }
        const nameAr = typeof b.nameAr === 'string' ? b.nameAr.trim() : (typeof b.name_ar === 'string' ? b.name_ar.trim() : nameFr);
        const nameEn = typeof b.nameEn === 'string' ? b.nameEn.trim() : (typeof b.name_en === 'string' ? b.name_en.trim() : nameFr);
        const kitchenStation = (typeof b.kitchenStation === 'string' ? b.kitchenStation : 'KITCHEN').trim().toUpperCase();
        const icon = typeof b.icon === 'string' && b.icon.trim() ? b.icon.trim() : '🍽';
        const imageUrl = typeof b.imageUrl === 'string' ? b.imageUrl.trim() : (typeof b.image_url === 'string' ? b.image_url.trim() : '');
        const manualPrice = b.manualPrice === true ? 1 : 0;
        const isTop = b.isTop === true ? 1 : 0;
        const isOutOfStock = b.available === false ? 1 : 0;

        let categoryId = null;
        if (b.categoryId != null && /^\d+$/.test(String(b.categoryId))) {
          const catRow = database.prepare('SELECT id FROM categories WHERE id = ? AND tenant_id = ?').get(Number(b.categoryId), currentTenant.id);
          if (catRow) categoryId = catRow.id;
        }
        if (categoryId == null && typeof b.categoryName === 'string' && b.categoryName.trim()) {
          const catName = b.categoryName.trim();
          const existingCat = database.prepare('SELECT id FROM categories WHERE tenant_id = ? AND LOWER(name_fr) = LOWER(?) LIMIT 1').get(currentTenant.id, catName);
          if (existingCat) {
            categoryId = existingCat.id;
          } else {
            const insCat = database.prepare('INSERT INTO categories (tenant_id, name_fr, name_ar, name_en, icon, active, created_at) VALUES (?, ?, ?, ?, ?, 1, ?)').run(currentTenant.id, catName, catName, catName, '🍽', new Date().toISOString());
            categoryId = Number(insCat.lastInsertRowid);
          }
        }
        if (categoryId == null) {
          const firstCat = database.prepare('SELECT id FROM categories WHERE tenant_id = ? AND active = 1 ORDER BY sort_order, id LIMIT 1').get(currentTenant.id);
          if (firstCat) categoryId = firstCat.id;
        }

        const skuRaw = typeof b.sku === 'string' && b.sku.trim() ? b.sku.trim() : `SKU-${Date.now().toString().slice(-6)}`;
        const nowIso = new Date().toISOString();
        const ins = database.prepare(`
          INSERT INTO products (
            tenant_id, category_id, sku, name_fr, name_ar, name_en, icon, image_url,
            unit, price_retail, kitchen_station, manual_price, is_top, is_out_of_stock,
            modifiers_json, active, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'portion', ?, ?, ?, ?, ?, '[]', 1, ?, ?)
        `).run(currentTenant.id, categoryId, skuRaw, nameFr, nameAr, nameEn, icon, imageUrl, priceRetail, kitchenStation, manualPrice, isTop, isOutOfStock, nowIso, nowIso);
        const created = database.prepare('SELECT * FROM products WHERE id = ?').get(ins.lastInsertRowid);

        database.prepare(`
          INSERT INTO audit_logs (
            tenant_id, actor, action, title, subtitle, entity_type, entity_id, after_json, time_label, created_at
          ) VALUES (?, ?, 'PRODUCT_CREATED', ?, ?, 'product', ?, ?, ?, ?)
        `).run(currentTenant.id, currentTenant.manager || currentTenant.name, `Plat ajouté · ${nameFr}`, `${priceRetail} MRU (${kitchenStation})`, String(created.id), JSON.stringify(created), nowHM(), nowIso);

        return sendJson(res, 201, { ok: true, product: created });
      }

      // 2d-ter. PATCH /api/pos/products/:id — Update menu item
      if (req.method === 'PATCH' && (m = p.match(/^\/api\/pos\/products\/([^/]+)$/))) {
        let rawKey;
        try { rawKey = decodeURIComponent(m[1]).trim(); } catch { return sendJson(res, 400, { error: 'Invalid id' }); }
        const product = /^\d+$/.test(rawKey)
          ? database.prepare('SELECT * FROM products WHERE tenant_id = ? AND (id = ? OR sku = ?) LIMIT 1').get(currentTenant.id, Number(rawKey), rawKey)
          : database.prepare('SELECT * FROM products WHERE tenant_id = ? AND sku = ? LIMIT 1').get(currentTenant.id, rawKey);
        if (!product) return sendJson(res, 404, { error: 'Product not found' });

        const parsed = await readJsonBody(req, standardLimit);
        const b = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        const nameFr = typeof b.nameFr === 'string' && b.nameFr.trim() ? b.nameFr.trim() : product.name_fr;
        const nameAr = typeof b.nameAr === 'string' && b.nameAr.trim() ? b.nameAr.trim() : product.name_ar;
        const nameEn = typeof b.nameEn === 'string' && b.nameEn.trim() ? b.nameEn.trim() : product.name_en;
        const priceRetail = b.priceMru != null ? Math.round(Number(b.priceMru)) : product.price_retail;
        if (!Number.isFinite(priceRetail) || priceRetail < 0) return sendJson(res, 400, { error: 'Invalid priceMru' });
        const kitchenStation = typeof b.kitchenStation === 'string' && b.kitchenStation.trim() ? b.kitchenStation.trim().toUpperCase() : product.kitchen_station;
        const icon = typeof b.icon === 'string' && b.icon.trim() ? b.icon.trim() : product.icon;
        const imageUrl = typeof b.imageUrl === 'string' ? b.imageUrl.trim() : (typeof b.image_url === 'string' ? b.image_url.trim() : (product.image_url || ''));
        const manualPrice = typeof b.manualPrice === 'boolean' ? (b.manualPrice ? 1 : 0) : Number(product.manual_price || 0);
        const isTop = typeof b.isTop === 'boolean' ? (b.isTop ? 1 : 0) : product.is_top;
        const isOutOfStock = typeof b.available === 'boolean' ? (b.available ? 0 : 1) : product.is_out_of_stock;
        let categoryId = product.category_id;
        if (b.categoryId != null && /^\d+$/.test(String(b.categoryId))) {
          const catRow = database.prepare('SELECT id FROM categories WHERE id = ? AND tenant_id = ?').get(Number(b.categoryId), currentTenant.id);
          if (catRow) categoryId = catRow.id;
        }
        const nowIso = new Date().toISOString();
        database.prepare(`
          UPDATE products SET name_fr = ?, name_ar = ?, name_en = ?, price_retail = ?,
            category_id = ?, kitchen_station = ?, icon = ?, image_url = ?, manual_price = ?, is_top = ?, is_out_of_stock = ?, updated_at = ?
          WHERE id = ? AND tenant_id = ?
        `).run(nameFr, nameAr, nameEn, priceRetail, categoryId, kitchenStation, icon, imageUrl, manualPrice, isTop, isOutOfStock, nowIso, product.id, currentTenant.id);
        const updated = database.prepare('SELECT * FROM products WHERE id = ?').get(product.id);
        return sendJson(res, 200, { ok: true, product: updated });
      }

      // 2d-quater. DELETE /api/pos/products/:id — Soft-deactivate menu item
      if (req.method === 'DELETE' && (m = p.match(/^\/api\/pos\/products\/([^/]+)$/))) {
        let rawKey;
        try { rawKey = decodeURIComponent(m[1]).trim(); } catch { return sendJson(res, 400, { error: 'Invalid id' }); }
        const product = /^\d+$/.test(rawKey)
          ? database.prepare('SELECT * FROM products WHERE tenant_id = ? AND (id = ? OR sku = ?) LIMIT 1').get(currentTenant.id, Number(rawKey), rawKey)
          : database.prepare('SELECT * FROM products WHERE tenant_id = ? AND sku = ? LIMIT 1').get(currentTenant.id, rawKey);
        if (!product) return sendJson(res, 404, { error: 'Product not found' });
        database.prepare('UPDATE products SET active = 0, updated_at = ? WHERE id = ? AND tenant_id = ?').run(new Date().toISOString(), product.id, currentTenant.id);
        return sendJson(res, 200, { ok: true, productId: product.id, active: false });
      }

      // 2d-5. POST /api/pos/ingredients — Create ingredient
      if (req.method === 'POST' && p === '/api/pos/ingredients') {
        const parsed = await readJsonBody(req, standardLimit);
        const b = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        const nameFr = typeof b.nameFr === 'string' ? b.nameFr.trim() : '';
        if (!nameFr) return sendJson(res, 400, { error: 'nameFr is required' });
        const nameAr = typeof b.nameAr === 'string' && b.nameAr.trim() ? b.nameAr.trim() : nameFr;
        const nameEn = typeof b.nameEn === 'string' && b.nameEn.trim() ? b.nameEn.trim() : nameFr;
        const unit = typeof b.unit === 'string' && b.unit.trim() ? b.unit.trim() : 'kg';
        const currentStock = Number(b.currentStock ?? 0);
        const minStock = Number(b.minStock ?? b.minThreshold ?? 0);
        const pmpCost = Number(b.pmpCostMru ?? 0);
        const sku = typeof b.sku === 'string' && b.sku.trim() ? b.sku.trim() : `ING-${Date.now().toString().slice(-6)}`;
        const nowIso = new Date().toISOString();
        const ins = database.prepare(`
          INSERT INTO ingredients (tenant_id, sku, name_fr, name_ar, name_en, unit, pmp_cost_mru, current_stock, min_stock, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(currentTenant.id, sku, nameFr, nameAr, nameEn, unit, pmpCost, currentStock, minStock, nowIso, nowIso);
        const created = database.prepare('SELECT * FROM ingredients WHERE id = ?').get(ins.lastInsertRowid);
        return sendJson(res, 201, { ok: true, ingredient: created });
      }

      // 2d-6. POST /api/pos/ingredients/:id/restock — Stock entry / inventory adjustment
      if (req.method === 'POST' && (m = p.match(/^\/api\/pos\/ingredients\/([^/]+)\/restock$/))) {
        let rawKey;
        try { rawKey = decodeURIComponent(m[1]).trim(); } catch { return sendJson(res, 400, { error: 'Invalid id' }); }
        const ing = /^\d+$/.test(rawKey)
          ? database.prepare('SELECT * FROM ingredients WHERE tenant_id = ? AND (id = ? OR sku = ?) LIMIT 1').get(currentTenant.id, Number(rawKey), rawKey)
          : database.prepare('SELECT * FROM ingredients WHERE tenant_id = ? AND sku = ? LIMIT 1').get(currentTenant.id, rawKey);
        if (!ing) return sendJson(res, 404, { error: 'Ingredient not found' });

        const parsed = await readJsonBody(req, standardLimit);
        const b = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        const oldStock = Number(ing.current_stock || 0);
        const oldPmp = Number(ing.pmp_cost_mru || 0);
        let nextStock = oldStock;
        let nextPmp = oldPmp;

        if (b.newStock != null && Number.isFinite(Number(b.newStock))) {
          nextStock = Math.max(0, Number(b.newStock));
        } else if (b.deltaQty != null && Number.isFinite(Number(b.deltaQty))) {
          const delta = Number(b.deltaQty);
          nextStock = Math.max(0, oldStock + delta);
          if (delta > 0 && b.unitCostMru != null && Number(b.unitCostMru) > 0) {
            const unitCost = Number(b.unitCostMru);
            nextPmp = (oldStock + delta) > 0
              ? ((oldStock * oldPmp) + (delta * unitCost)) / (oldStock + delta)
              : unitCost;
          }
        } else {
          return sendJson(res, 400, { error: 'deltaQty or newStock is required' });
        }

        const nextMin = b.minStock != null && Number.isFinite(Number(b.minStock)) ? Number(b.minStock) : ing.min_stock;
        const nowIso = new Date().toISOString();
        database.prepare('UPDATE ingredients SET current_stock = ?, pmp_cost_mru = ?, min_stock = ?, updated_at = ? WHERE id = ? AND tenant_id = ?')
          .run(nextStock, nextPmp, nextMin, nowIso, ing.id, currentTenant.id);
        const updated = database.prepare('SELECT * FROM ingredients WHERE id = ?').get(ing.id);

        database.prepare(`
          INSERT INTO audit_logs (
            tenant_id, actor, action, title, subtitle, entity_type, entity_id, after_json, time_label, created_at
          ) VALUES (?, ?, 'INGREDIENT_RESTOCK', ?, ?, 'ingredient', ?, ?, ?, ?)
        `).run(currentTenant.id, currentTenant.manager || currentTenant.name, `Stock · ${ing.name_fr}`, `${oldStock.toFixed(2)} → ${nextStock.toFixed(2)} ${ing.unit}`, String(ing.id), JSON.stringify(updated), nowHM(), nowIso);

        return sendJson(res, 200, { ok: true, ingredient: updated });
      }

      // 2d-7. POST /api/pos/zones — Create dining zone
      if (req.method === 'POST' && p === '/api/pos/zones') {
        const parsed = await readJsonBody(req, standardLimit);
        const b = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        const nameFr = typeof b.nameFr === 'string' ? b.nameFr.trim() : '';
        if (!nameFr) return sendJson(res, 400, { error: 'nameFr is required' });
        const nameAr = typeof b.nameAr === 'string' && b.nameAr.trim() ? b.nameAr.trim() : nameFr;
        const nameEn = typeof b.nameEn === 'string' && b.nameEn.trim() ? b.nameEn.trim() : nameFr;
        const isVip = b.isVip === true ? 1 : 0;
        const zoneType = isVip ? 'VIP' : 'SALLE';
        const ins = database.prepare(`
          INSERT INTO dining_zones (tenant_id, name_fr, name_ar, name_en, zone_type, is_vip, table_count, tables_json, active)
          VALUES (?, ?, ?, ?, ?, ?, 0, '[]', 1)
        `).run(currentTenant.id, nameFr, nameAr, nameEn, zoneType, isVip);
        const created = database.prepare('SELECT * FROM dining_zones WHERE id = ?').get(ins.lastInsertRowid);
        return sendJson(res, 201, { ok: true, zone: created });
      }

      // 2d-8. POST /api/pos/tables — Add dining table to zone
      if (req.method === 'POST' && p === '/api/pos/tables') {
        const parsed = await readJsonBody(req, standardLimit);
        const b = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        const code = typeof b.code === 'string' ? b.code.trim() : '';
        if (!code) return sendJson(res, 400, { error: 'Table code is required' });
        const capacity = Math.max(1, Math.round(Number(b.capacity ?? 4)));
        const shape = typeof b.shape === 'string' && b.shape.trim() ? b.shape.trim().toLowerCase() : 'square';

        let zone = null;
        if (b.zoneId != null && /^\d+$/.test(String(b.zoneId))) {
          zone = database.prepare('SELECT * FROM dining_zones WHERE id = ? AND tenant_id = ? AND active = 1').get(Number(b.zoneId), currentTenant.id);
        }
        if (!zone && typeof b.zoneName === 'string' && b.zoneName.trim()) {
          zone = database.prepare('SELECT * FROM dining_zones WHERE tenant_id = ? AND active = 1 AND LOWER(name_fr) = LOWER(?) LIMIT 1').get(currentTenant.id, b.zoneName.trim());
          if (!zone) {
            const zn = b.zoneName.trim();
            const insZ = database.prepare(`
              INSERT INTO dining_zones (tenant_id, name_fr, name_ar, name_en, zone_type, is_vip, table_count, tables_json, active)
              VALUES (?, ?, ?, ?, 'SALLE', 0, 0, '[]', 1)
            `).run(currentTenant.id, zn, zn, zn);
            zone = database.prepare('SELECT * FROM dining_zones WHERE id = ?').get(insZ.lastInsertRowid);
          }
        }
        if (!zone) {
          zone = database.prepare('SELECT * FROM dining_zones WHERE tenant_id = ? AND active = 1 ORDER BY id ASC LIMIT 1').get(currentTenant.id);
        }
        if (!zone) {
          const insZ = database.prepare(`
            INSERT INTO dining_zones (tenant_id, name_fr, name_ar, name_en, zone_type, is_vip, table_count, tables_json, active)
            VALUES (?, 'Salle Principale', 'القاعة الرئيسية', 'Main Hall', 'SALLE', 0, 0, '[]', 1)
          `).run(currentTenant.id);
          zone = database.prepare('SELECT * FROM dining_zones WHERE id = ?').get(insZ.lastInsertRowid);
        }

        const rawTables = parseJson(zone.tables_json, []);
        const currentTables = rawTables.length > 0 ? rawTables : synthesizeTablesForZone(zone);
        const tableId = typeof b.id === 'string' && b.id.trim() ? b.id.trim() : `TBL-${Date.now()}`;
        const newTable = { id: tableId, code, capacity, shape, status: 'free' };
        currentTables.push(newTable);
        database.prepare('UPDATE dining_zones SET tables_json = ?, table_count = ? WHERE id = ? AND tenant_id = ?')
          .run(JSON.stringify(currentTables), currentTables.length, zone.id, currentTenant.id);
        return sendJson(res, 201, { ok: true, table: { ...newTable, zoneId: zone.id } });
      }

      // 2d-9. PATCH /api/pos/tables/:id — Update table
      if (req.method === 'PATCH' && (m = p.match(/^\/api\/pos\/tables\/([^/]+)$/))) {
        let targetId;
        try { targetId = decodeURIComponent(m[1]).trim(); } catch { return sendJson(res, 400, { error: 'Invalid table id' }); }
        const parsed = await readJsonBody(req, standardLimit);
        const b = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        const zonesList = database.prepare('SELECT * FROM dining_zones WHERE tenant_id = ? AND active = 1').all(currentTenant.id);
        for (const z of zonesList) {
          const rawTables = parseJson(z.tables_json, []);
          const currentTables = rawTables.length > 0 ? rawTables : synthesizeTablesForZone(z);
          const idx = currentTables.findIndex((t) => String(t.id) === targetId || String(t.code) === targetId);
          if (idx !== -1) {
            const cur = currentTables[idx];
            currentTables[idx] = {
              ...cur,
              code: typeof b.code === 'string' && b.code.trim() ? b.code.trim() : cur.code,
              capacity: b.capacity != null ? Math.max(1, Math.round(Number(b.capacity))) : cur.capacity,
              shape: typeof b.shape === 'string' && b.shape.trim() ? b.shape.trim().toLowerCase() : (cur.shape || 'square'),
            };
            database.prepare('UPDATE dining_zones SET tables_json = ?, table_count = ? WHERE id = ? AND tenant_id = ?')
              .run(JSON.stringify(currentTables), currentTables.length, z.id, currentTenant.id);
            return sendJson(res, 200, { ok: true, table: currentTables[idx] });
          }
        }
        return sendJson(res, 404, { error: 'Table not found' });
      }

      // 2d-10. DELETE /api/pos/tables/:id — Remove table
      if (req.method === 'DELETE' && (m = p.match(/^\/api\/pos\/tables\/([^/]+)$/))) {
        let targetId;
        try { targetId = decodeURIComponent(m[1]).trim(); } catch { return sendJson(res, 400, { error: 'Invalid table id' }); }
        const zonesList = database.prepare('SELECT * FROM dining_zones WHERE tenant_id = ? AND active = 1').all(currentTenant.id);
        for (const z of zonesList) {
          const rawTables = parseJson(z.tables_json, []);
          const currentTables = rawTables.length > 0 ? rawTables : synthesizeTablesForZone(z);
          const nextTables = currentTables.filter((t) => String(t.id) !== targetId && String(t.code) !== targetId);
          if (nextTables.length !== currentTables.length) {
            database.prepare('UPDATE dining_zones SET tables_json = ?, table_count = ? WHERE id = ? AND tenant_id = ?')
              .run(JSON.stringify(nextTables), nextTables.length, z.id, currentTenant.id);
            return sendJson(res, 200, { ok: true, tableId: targetId });
          }
        }
        return sendJson(res, 404, { error: 'Table not found' });
      }

      // 2d-11. PATCH /api/pos/tenant-profile — Update restaurant basic info & receipt header
      if (req.method === 'PATCH' && p === '/api/pos/tenant-profile') {
        const parsed = await readJsonBody(req, standardLimit);
        const b = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        const name = typeof b.name === 'string' && b.name.trim() ? b.name.trim() : currentTenant.name;
        const address = typeof b.address === 'string' ? b.address.trim() : (currentTenant.address || '');
        const city = typeof b.city === 'string' && b.city.trim() ? b.city.trim() : (currentTenant.city || '');
        const phone = typeof b.phone === 'string' && b.phone.trim() ? b.phone.trim() : (currentTenant.phone || '');
        const nif = typeof b.nif === 'string' ? b.nif.trim() : (currentTenant.nif || '');
        const rc = typeof b.rc === 'string' ? b.rc.trim() : (currentTenant.rc || '');
        database.prepare(`
          UPDATE tenants SET name = ?, address = ?, city = ?, phone = ?, nif = ?, rc = ?
          WHERE id = ?
        `).run(name, address, city, phone, nif, rc, currentTenant.id);
        const updated = database.prepare('SELECT * FROM tenants WHERE id = ?').get(currentTenant.id);
        return sendJson(res, 200, { ok: true, tenant: serializeTenant(updated) });
      }

      // 2e. GET /api/pos/kds[?station=ALL|GRILL|KITCHEN|BAR]
      if (req.method === 'GET' && p === '/api/pos/kds') {
        const station = (url.searchParams.get('station') || 'ALL').trim().toUpperCase();
        if (!VALID_KDS_STATIONS.has(station)) {
          return sendJson(res, 400, { error: 'Invalid station parameter (expected ALL, GRILL, KITCHEN, or BAR)' });
        }

        const rows = database.prepare(`
          SELECT
            o.id AS order_id,
            o.order_code,
            o.table_name,
            o.channel,
            COALESCE(NULLIF(o.service_mode, ''), NULLIF(o.channel, ''), 'dine_in') AS service_mode,
            COALESCE(o.delivery_zone, '') AS delivery_zone,
            o.status AS order_status,
            o.notes AS order_notes,
            COALESCE(NULLIF(o.kds_sent_at, ''), o.created_at) AS sent_at,
            oi.id AS item_id,
            oi.product_id,
            oi.qty,
            oi.unit_price,
            COALESCE(oi.modifiers_json, '[]') AS modifiers_json,
            COALESCE(oi.kitchen_note, '') AS kitchen_note,
            UPPER(COALESCE(NULLIF(oi.kitchen_station, ''), NULLIF(p.kitchen_station, ''), 'KITCHEN')) AS effective_station,
            UPPER(COALESCE(NULLIF(oi.kds_status, ''), 'PENDING')) AS item_kds_status,
            COALESCE(p.sku, '') AS product_sku,
            p.name_fr,
            COALESCE(p.name_ar, '') AS name_ar,
            COALESCE(p.name_en, '') AS name_en
          FROM orders o
          JOIN order_items oi ON oi.order_id = o.id
          JOIN products p ON p.id = oi.product_id
          WHERE o.tenant_id = ?
            AND COALESCE(o.is_training, 0) = 0
            AND UPPER(o.status) IN ('OPEN', 'KDS_PREP', 'PAID')
            AND UPPER(COALESCE(NULLIF(oi.kds_status, ''), 'PENDING')) IN ('PENDING', 'PREPARING')
          ORDER BY sent_at ASC, o.id ASC, oi.id ASC
        `).all(currentTenant.id);

        const nowMs = Date.now();
        const ticketMap = new Map();
        for (const r of rows) {
          if (station !== 'ALL' && r.effective_station !== station) continue;
          let ticket = ticketMap.get(r.order_id);
          if (!ticket) {
            const sentAtIso = toUtcIso(r.sent_at);
            const sentMs = Date.parse(sentAtIso);
            const elapsedMinutes = Number.isNaN(sentMs) ? 0 : Math.max(0, Math.floor((nowMs - sentMs) / 60000));
            const urgency = elapsedMinutes < 10 ? 'GREEN' : (elapsedMinutes <= 20 ? 'ORANGE' : 'RED');
            ticket = {
              orderId: r.order_id,
              orderCode: r.order_code,
              tableName: r.table_name || '',
              serviceMode: r.service_mode,
              deliveryZone: r.delivery_zone || '',
              status: r.order_status,
              notes: r.order_notes || '',
              sentAt: sentAtIso,
              elapsedMinutes,
              urgency,
              items: [],
            };
            ticketMap.set(r.order_id, ticket);
          }
          ticket.items.push({
            id: r.item_id,
            productId: r.product_id,
            sku: r.product_sku,
            nameFr: r.name_fr,
            nameAr: r.name_ar,
            nameEn: r.name_en,
            qty: Number(r.qty),
            station: r.effective_station,
            kdsStatus: r.item_kds_status,
            kitchenNote: r.kitchen_note || '',
            modifiers: parseJson(r.modifiers_json, []),
          });
        }

        return sendJson(res, 200, {
          ok: true,
          tenantId: currentTenant.id,
          station,
          tickets: Array.from(ticketMap.values()),
        });
      }

      // 2f. PATCH /api/pos/kds/:orderId — Mark KDS order/station READY or PREPARING
      if (req.method === 'PATCH' && (m = p.match(/^\/api\/pos\/kds\/([^/]+)$/))) {
        let rawOrderKey;
        try {
          rawOrderKey = decodeURIComponent(m[1]).trim();
        } catch {
          return sendJson(res, 400, { error: 'Invalid order identifier' });
        }
        if (!rawOrderKey) {
          return sendJson(res, 400, { error: 'Invalid order identifier' });
        }

        const parsed = await readJsonBody(req, standardLimit);
        const b = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        const targetStatus = String(b.status || 'READY').trim().toUpperCase();
        if (targetStatus !== 'READY' && targetStatus !== 'PREPARING') {
          return sendJson(res, 400, { error: 'Invalid KDS status (expected READY or PREPARING)' });
        }
        const station = String(b.station || 'ALL').trim().toUpperCase();
        if (!VALID_KDS_STATIONS.has(station)) {
          return sendJson(res, 400, { error: 'Invalid station (expected ALL, GRILL, KITCHEN, or BAR)' });
        }

        const order = /^\d+$/.test(rawOrderKey)
          ? database
              .prepare(`
                SELECT * FROM orders
                WHERE tenant_id = ? AND COALESCE(is_training, 0) = 0 AND (id = ? OR order_code = ?)
                ORDER BY CASE WHEN id = ? THEN 0 ELSE 1 END
                LIMIT 1
              `)
              .get(currentTenant.id, Number(rawOrderKey), rawOrderKey, Number(rawOrderKey))
          : database
              .prepare('SELECT * FROM orders WHERE tenant_id = ? AND COALESCE(is_training, 0) = 0 AND order_code = ? LIMIT 1')
              .get(currentTenant.id, rawOrderKey);

        if (!order) {
          return sendJson(res, 404, { error: 'Order not found' });
        }
        if (String(order.status || '').toUpperCase() === 'VOID') {
          return sendJson(res, 400, { error: 'Cannot update KDS status of voided order' });
        }

        let updatedItems = 0;
        let remaining = 0;
        let nextOrderStatus = order.status;

        database.exec('BEGIN IMMEDIATE');
        try {
          if (station === 'ALL') {
            const info = database.prepare('UPDATE order_items SET kds_status = ? WHERE order_id = ?').run(targetStatus, order.id);
            updatedItems = Number(info.changes || 0);
          } else {
            const info = database.prepare(`
              UPDATE order_items
              SET kds_status = ?
              WHERE order_id = ?
                AND UPPER(COALESCE(
                  NULLIF(kitchen_station, ''),
                  (SELECT NULLIF(p.kitchen_station, '') FROM products p WHERE p.id = order_items.product_id),
                  'KITCHEN'
                )) = ?
            `).run(targetStatus, order.id, station);
            updatedItems = Number(info.changes || 0);
          }

          remaining = database
            .prepare("SELECT COUNT(*) AS cnt FROM order_items WHERE order_id = ? AND UPPER(COALESCE(NULLIF(kds_status, ''), 'PENDING')) != 'READY'")
            .get(order.id).cnt;

          if (remaining === 0 && ['OPEN', 'KDS_PREP'].includes(String(order.status || '').toUpperCase())) {
            database.prepare("UPDATE orders SET status = 'READY' WHERE id = ? AND tenant_id = ?").run(order.id, currentTenant.id);
            nextOrderStatus = 'READY';
          }
          database.exec('COMMIT');
        } catch (err) {
          database.exec('ROLLBACK');
          throw err;
        }

        return sendJson(res, 200, {
          ok: true,
          orderId: order.id,
          orderCode: order.order_code,
          station,
          status: targetStatus,
          orderStatus: nextOrderStatus,
          updatedItems,
          remainingPendingItems: remaining,
        });
      }

      // 2g. GET /api/pos/kpis — Owner Live Daily KPIs (strictly excluding is_training = 1)
      if (req.method === 'GET' && p === '/api/pos/kpis') {
        const rawDate = url.searchParams.get('date');
        const targetDate = rawDate ? rawDate.trim() : new Date().toISOString().slice(0, 10);
        if (!/^\d{4}-\d{2}-\d{2}$/.test(targetDate)) {
          return sendJson(res, 400, { error: 'Invalid date format (expected YYYY-MM-DD)' });
        }

        const paidOrders = database.prepare(`
          SELECT id, total_mru, pay_method, payments_json, service_mode, channel
          FROM orders
          WHERE tenant_id = ?
            AND COALESCE(is_training, 0) = 0
            AND UPPER(status) = 'PAID'
            AND substr(created_at, 1, 10) = ?
          ORDER BY id ASC
        `).all(currentTenant.id, targetDate);

        const todayTicketsCount = paidOrders.length;
        const todayRevenueMru = paidOrders.reduce((s, o) => s + Number(o.total_mru || 0), 0);
        const averageBasketMru = todayTicketsCount > 0 ? Math.round(todayRevenueMru / todayTicketsCount) : 0;

        const paymentBreakdown = {
          cash: 0,
          bankily: 0,
          masrivi: 0,
          sedad: 0,
          bimbank: 0,
          click: 0,
          karni: 0,
        };

        for (const o of paidOrders) {
          const entries = parseJson(o.payments_json, []);
          if (entries.length > 0) {
            const orderPay = {};
            let totalTendered = 0;
            for (const e of entries) {
              const key = normalizePayKey(e?.method);
              const amt = Number(e?.amount_mru ?? e?.amountMru ?? e?.amount ?? 0);
              if (key && Number.isFinite(amt) && amt > 0) {
                orderPay[key] = (orderPay[key] || 0) + amt;
                totalTendered += amt;
              }
            }
            const netOrderTotal = Number(o.total_mru || 0);
            if (totalTendered > netOrderTotal && (orderPay.cash || 0) > 0) {
              orderPay.cash -= Math.min(orderPay.cash, totalTendered - netOrderTotal);
            }
            for (const [k, v] of Object.entries(orderPay)) {
              paymentBreakdown[k] += v;
            }
          } else {
            const key = normalizePayKey(o.pay_method);
            if (key) {
              paymentBreakdown[key] += Number(o.total_mru || 0);
            }
          }
        }

        const orderItems = database.prepare(`
          SELECT oi.product_id, oi.qty, oi.modifiers_json,
                 COALESCE(NULLIF(o.service_mode, ''), NULLIF(o.channel, ''), 'dine_in') AS service_mode,
                 p.price_cost
          FROM order_items oi
          JOIN orders o ON o.id = oi.order_id
          JOIN products p ON p.id = oi.product_id
          WHERE o.tenant_id = ?
            AND COALESCE(o.is_training, 0) = 0
            AND UPPER(o.status) = 'PAID'
            AND substr(o.created_at, 1, 10) = ?
        `).all(currentTenant.id, targetDate);

        const bomAll = database.prepare(`
          SELECT rb.product_id, rb.qty_per_unit, rb.condition_channel, rb.modifier_key,
                 i.sku AS ing_sku, i.name_fr AS ing_name, i.pmp_cost_mru
          FROM recipes_bom rb
          JOIN ingredients i ON i.id = rb.ingredient_id
          WHERE rb.tenant_id = ?
        `).all(currentTenant.id);
        const bomByProduct = new Map();
        for (const rb of bomAll) {
          if (!bomByProduct.has(rb.product_id)) bomByProduct.set(rb.product_id, []);
          bomByProduct.get(rb.product_id).push(rb);
        }

        let foodCostMru = 0;
        for (const oi of orderItems) {
          const bomRows = bomByProduct.get(oi.product_id) || [];
          const qty = Number(oi.qty || 0);
          if (bomRows.length > 0) {
            const selectedModKeys = extractModifierKeys(oi.modifiers_json);
            const { channel: chUpper } = normalizeServiceMode(oi.service_mode);
            const isTakeawayOrDelivery = chUpper === 'TAKEAWAY' || chUpper === 'DELIVERY';
            let unitBomCost = 0;
            for (const rb of bomRows) {
              const condCh = String(rb.condition_channel || 'ALL').trim().toUpperCase();
              const chOk = condCh === 'ALL' || condCh === '' || condCh === chUpper || (condCh === 'TAKEAWAY_DELIVERY' && isTakeawayOrDelivery);
              if (!chOk) continue;
              const mk = String(rb.modifier_key || '').trim().toLowerCase();
              if (mk !== '') {
                if (!selectedModKeys.has(mk)) continue;
              } else {
                const exclSku = `-${String(rb.ing_sku || '').trim().toLowerCase()}`;
                const exclName = `-${String(rb.ing_name || '').trim().toLowerCase()}`;
                if ((rb.ing_sku && selectedModKeys.has(exclSku)) || (rb.ing_name && selectedModKeys.has(exclName))) continue;
              }
              unitBomCost += Number(rb.qty_per_unit || 0) * Number(rb.pmp_cost_mru || 0);
            }
            foodCostMru += unitBomCost * qty;
          } else {
            foodCostMru += Number(oi.price_cost || 0) * qty;
          }
        }

        const { waste_mru: wasteMru } = database.prepare(`
          SELECT COALESCE(SUM(cost_value_mru), 0) AS waste_mru
          FROM returns_remakes_comps
          WHERE tenant_id = ? AND UPPER(type) = 'REMAKE' AND substr(created_at, 1, 10) = ?
        `).get(currentTenant.id, targetDate);

        foodCostMru = Number((foodCostMru + Number(wasteMru || 0)).toFixed(2));
        const grossMarginPercent = todayRevenueMru > 0
          ? Number((((todayRevenueMru - foodCostMru) / todayRevenueMru) * 100).toFixed(2))
          : 0;

        const lowStockAlerts = database.prepare(`
          SELECT id, sku, name_fr, name_ar, name_en, unit, pmp_cost_mru, current_stock, min_stock
          FROM ingredients
          WHERE tenant_id = ? AND current_stock <= min_stock
          ORDER BY (current_stock - min_stock) ASC, id ASC
        `).all(currentTenant.id).map((ing) => ({
          id: ing.id,
          sku: ing.sku || '',
          nameFr: ing.name_fr,
          nameAr: ing.name_ar || '',
          nameEn: ing.name_en || '',
          unit: ing.unit || 'kg',
          currentStock: Number(ing.current_stock ?? 0),
          minStock: Number(ing.min_stock ?? 0),
          pmpCostMru: Number(ing.pmp_cost_mru ?? 0),
        }));

        return sendJson(res, 200, {
          ok: true,
          date: targetDate,
          todayRevenueMru,
          todayTicketsCount,
          averageBasketMru,
          paymentBreakdown,
          foodCostMru,
          grossMarginPercent,
          lowStockAlerts,
        });
      }

      // 2h. POST /api/pos/sync — Transactional Offline-First SyncQueue Endpoint
      if (req.method === 'POST' && p === '/api/pos/sync') {
        const parsed = await readJsonBody(req, standardLimit);
        const items = parsed && Array.isArray(parsed.items) ? parsed.items : null;
        if (!items) {
          return sendJson(res, 400, { error: 'items array is required' });
        }

        const tenantId = currentTenant.id;
        const insertAudit = database.prepare(`
          INSERT INTO audit_logs (
            tenant_id, actor, action, title, subtitle, entity_type, entity_id, after_json, time_label, is_training, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `);
        const nowIso = new Date().toISOString();

        database.exec('BEGIN IMMEDIATE');
        try {
          for (const item of items) {
            handlePosSyncItem(database, tenantId, item, nowIso, insertAudit);
          }
          database.exec('COMMIT');
        } catch (err) {
          try {
            database.exec('ROLLBACK');
          } catch {
            // ignore rollback error
          }
          throw err;
        }

        return sendJson(res, 200, {
          ok: true,
          tenantId,
          synced: items.length,
          syncedAt: nowIso,
        });
      }

      // 2i. Centralized Tenant JWT Auth Guard & Router for ALL /api/commercial/* routes
      if (p === '/api/commercial' || p.startsWith('/api/commercial/')) {
        currentTenant = requireTenantAuth(req, res, database, {
          jwtSecret: effectiveJwtSecret,
          sendJson,
        });
        if (!currentTenant) return;

        if (currentTenant.module !== 'commercial') {
          return sendJson(res, 403, { error: 'Commercial module is not enabled for this tenant' });
        }

        ensureCommercialDefaults(database, currentTenant.id);

        const handled = await handleCommercialRoute({
          req,
          res,
          url,
          pathname: p,
          database,
          currentTenant,
          standardLimit,
          readJsonBody,
          readRawBody,
          sendJson,
          createHttpError,
          pick,
          parseJson,
          nowHM,
          serializeTenant,
        });
        if (handled) return;
        return sendJson(res, 404, { error: 'Route not found' });
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
        const mod = b.module || 'resto';
        const deliveryZonesJson = JSON.stringify(
          Array.isArray(b.deliveryZones)
            ? b.deliveryZones
            : (mod === 'resto' ? DEFAULT_DELIVERY_ZONES : []),
        );
        const freeDeliveryAboveMru = Number(b.freeDeliveryAboveMru ?? 1500);

        const payMethodsList =
          Array.isArray(b.payMethods) && b.payMethods.length > 0 ? b.payMethods : DEFAULT_PAY_METHODS;

        const info = database.prepare(`
          INSERT INTO tenants (
            tenant_code, name, module, sub_type, city, district, address, legal_name,
            nif, rc, phone, email, manager, default_lang, plan, billing, mrr, tills,
            days_left, status, enabled_themes, features, pay_methods, delivery_zones_json,
            free_delivery_above_mru, hardware, notes,
            username, password_hash, account_password, owner_pin,
            initial_pay_method, initial_pay_ref, initial_offline_code
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(
          tenantCode, b.name, mod, b.subType || '', b.city || 'Tevragh Zeina',
          b.district || '', b.address || '', b.legalName || '', b.nif || '', b.rc || '',
          b.phone, b.email || '', b.manager || '', b.defaultLang || 'fr',
          b.plan || 'Pro', b.billing || 'monthly', Number(b.mrr ?? 3000), Number(b.tills ?? 1),
          Number(b.daysLeft ?? 30), b.status || 'active',
          JSON.stringify(b.enabledThemes || DEFAULT_ENABLED_THEMES),
          JSON.stringify(b.features || []),
          JSON.stringify(payMethodsList),
          deliveryZonesJson,
          freeDeliveryAboveMru,
          JSON.stringify(b.hardware || []),
          b.notes || '', b.username, pwHash, String(b.accountPassword), String(b.ownerPin || '4242'),
          b.initialPayMethod || '', b.initialPayRef || '', b.initialOfflineCode || '',
        );
        const id = Number(info.lastInsertRowid);
        database.prepare(`
          INSERT INTO users (tenant_id, full_name, username, pass_hash, pin_code, role)
          VALUES (?, ?, ?, ?, ?, 'OWNER')
        `).run(id, b.manager || b.name, b.username, pwHash, String(b.ownerPin || '4242'));

        if (mod === 'commercial') {
          ensureCommercialDefaults(database, id);
        }

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

        const nextPayMethods =
          b.payMethods !== undefined
            ? JSON.stringify(
                Array.isArray(b.payMethods) && b.payMethods.length > 0
                  ? b.payMethods
                  : DEFAULT_PAY_METHODS,
              )
            : cur.pay_methods;

        database.prepare(`
          UPDATE tenants SET
            name = ?, legal_name = ?, manager = ?, phone = ?, city = ?, district = ?, nif = ?, rc = ?,
            notes = ?, username = ?, account_password = ?, password_hash = ?, owner_pin = ?,
            tills = ?, enabled_themes = ?, pay_methods = ?, updated_at = CURRENT_TIMESTAMP
          WHERE id = ?
        `).run(
          b.name ?? cur.name,
          b.legalName ?? cur.legal_name,
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
          nextPayMethods,
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
      const finalize = async () => {
        if (pgBackup) {
          await pgBackup.flushAndClose(database, dbPath).catch(() => {});
        }
        closeDb();
        resolve();
      };
      if (!server.listening) {
        finalize();
        return;
      }
      server.closeAllConnections?.();
      server.close(() => {
        finalize();
      });
    });

  return { server, handler, db: database, dbPath, close };
}

async function startServer(options = {}) {
  const port = options.port !== undefined ? Number(options.port) : Number(process.env.PORT || 4000);
  const host = options.host || process.env.HOST || '0.0.0.0';
  let pgBackup = options.pgBackup || null;
  let initialNeedsPush = false;

  if (!pgBackup && !options.db && !options.dbPath && process.env.DATABASE_URL) {
    pgBackup = createPgBackupManager(process.env.DATABASE_URL);
    if (pgBackup) {
      const resolvedDbPath =
        process.env.DB_PATH || process.env.FULLTEK_DB_PATH || DEFAULT_DB_PATH;
      try {
        const { restored, hasRemoteSnapshot } =
          await pgBackup.restoreIfNeeded(resolvedDbPath);
        initialNeedsPush = !restored && !hasRemoteSnapshot;
      } catch (err) {
        console.error('[PG-SYNC] Startup restore failed:', err?.message || err);
      }
    }
  }

  const app = createApp(pgBackup ? { ...options, pgBackup } : options);
  if (pgBackup && initialNeedsPush) {
    await pgBackup.pushNow(app.db, app.dbPath).catch(() => {});
  }

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
        console.log(`Full·Tek Cloud API (SQLite WAL${pgBackup ? ' + PostgreSQL Sync' : ''}) running on http://${displayHost}:${actualPort} (DB: ${app.dbPath})`);
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
  startServer()
    .then((app) => {
      const shutdown = () => {
        app.close().finally(() => process.exit(0));
      };
      process.once('SIGTERM', shutdown);
      process.once('SIGINT', shutdown);
    })
    .catch((err) => {
      console.error('Failed to start cloud-api server:', err);
      process.exit(1);
    });
}

module.exports = {
  createApp,
  startServer,
};
