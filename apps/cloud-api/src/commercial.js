const crypto = require('node:crypto');

const VALID_PRESETS = new Set([
  'this_month',
  'last_month',
  'this_quarter',
  'this_year',
  'last_12_months',
  'last_year',
]);

const SALES_DOC_TYPES = new Set(['DEVIS', 'COMMANDE', 'BL', 'FACTURE', 'AVOIR']);
const SALES_DOC_PREFIX = {
  DEVIS: 'DEV',
  COMMANDE: 'CMD',
  BL: 'BL',
  FACTURE: 'FAC',
  AVOIR: 'AVR',
};

const PURCHASE_DOC_TYPES = new Set([
  'COMMANDE_FOURNISSEUR',
  'RECEPTION',
  'FACTURE_FOURNISSEUR',
  'AVOIR_FOURNISSEUR',
]);
const PURCHASE_DOC_PREFIX = {
  COMMANDE_FOURNISSEUR: 'CF',
  RECEPTION: 'REC',
  FACTURE_FOURNISSEUR: 'FF',
  AVOIR_FOURNISSEUR: 'AF',
};

const ACCOUNT_TYPES = new Set(['CAISSE', 'BANQUE', 'MOBILE_MONEY']);
const POS_PAY_METHODS = new Set(['Cash', 'Bankily', 'Masrivi', 'Sedad', 'Bimbank', 'Click', 'Karni']);

const FRENCH_MONTHS_SHORT = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

function round1(n) {
  const v = Number(n) || 0;
  const r = Math.round((v + Math.sign(v) * 1e-9) * 10) / 10;
  return Object.is(r, -0) ? 0 : r;
}

function round2(n) {
  const v = Number(n) || 0;
  const r = Math.round((v + Math.sign(v) * 1e-9) * 100) / 100;
  return Object.is(r, -0) ? 0 : r;
}

function round3(n) {
  const v = Number(n) || 0;
  const r = Math.round((v + Math.sign(v) * 1e-9) * 1000) / 1000;
  return Object.is(r, -0) ? 0 : r;
}

function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

function isValidIsoDate(s) {
  if (typeof s !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const [y, m, d] = s.split('-').map(Number);
  if (m < 1 || m > 12 || d < 1 || d > 31) return false;
  const dt = new Date(Date.UTC(y, m - 1, d));
  return (
    dt.getUTCFullYear() === y &&
    dt.getUTCMonth() === m - 1 &&
    dt.getUTCDate() === d
  );
}

function pad2(n) {
  return String(n).padStart(2, '0');
}

function lastDayOfMonth(year, month) {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

function formatYmd(year, month, day) {
  return `${year}-${pad2(month)}-${pad2(day)}`;
}

function addDaysIso(dateStr, days) {
  const [y, m, d] = dateStr.split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d + days));
  return dt.toISOString().slice(0, 10);
}

function shiftYearBack(dateStr) {
  const [y, m, d] = dateStr.split('-').map(Number);
  const prevY = y - 1;
  const maxD = lastDayOfMonth(prevY, m);
  return formatYmd(prevY, m, Math.min(d, maxD));
}

function monthsInRange(from, to) {
  const [fy, fm] = from.split('-').map(Number);
  const [ty, tm] = to.split('-').map(Number);
  const out = [];
  let y = fy;
  let m = fm;
  let guard = 0;
  while ((y < ty || (y === ty && m <= tm)) && guard < 120) {
    guard++;
    out.push({
      year: y,
      month: m,
      monthKey: `${y}-${pad2(m)}`,
      prevMonthKey: `${y - 1}-${pad2(m)}`,
      label: `${FRENCH_MONTHS_SHORT[m - 1]} ${String(y).slice(-2)}`,
    });
    m++;
    if (m > 12) {
      m = 1;
      y++;
    }
  }
  return out;
}

function resolveDateRange(presetRaw, fromRaw, toRaw, createHttpError) {
  const hasFrom = fromRaw !== undefined && fromRaw !== null && String(fromRaw).trim() !== '';
  const hasTo = toRaw !== undefined && toRaw !== null && String(toRaw).trim() !== '';

  if (hasFrom || hasTo) {
    const f = hasFrom ? String(fromRaw).trim() : String(toRaw).trim();
    const t = hasTo ? String(toRaw).trim() : todayIso();
    if (!isValidIsoDate(f) || !isValidIsoDate(t)) {
      throw createHttpError(400, 'Format de date invalide (attendu YYYY-MM-DD)');
    }
    if (f > t) {
      throw createHttpError(400, 'La date de début doit être antérieure ou égale à la date de fin');
    }
    return {
      preset: 'custom',
      from: f,
      to: t,
      prevFrom: shiftYearBack(f),
      prevTo: shiftYearBack(t),
    };
  }

  const preset = presetRaw ? String(presetRaw).trim() : 'this_year';
  if (!VALID_PRESETS.has(preset)) {
    throw createHttpError(400, `Preset de période invalide: ${preset}`);
  }

  const now = new Date();
  const curY = now.getUTCFullYear();
  const curM = now.getUTCMonth() + 1;
  let from;
  let to;

  if (preset === 'this_month') {
    from = formatYmd(curY, curM, 1);
    to = formatYmd(curY, curM, lastDayOfMonth(curY, curM));
  } else if (preset === 'last_month') {
    const lm = curM === 1 ? 12 : curM - 1;
    const ly = curM === 1 ? curY - 1 : curY;
    from = formatYmd(ly, lm, 1);
    to = formatYmd(ly, lm, lastDayOfMonth(ly, lm));
  } else if (preset === 'this_quarter') {
    const qStart = Math.floor((curM - 1) / 3) * 3 + 1;
    const qEnd = qStart + 2;
    from = formatYmd(curY, qStart, 1);
    to = formatYmd(curY, qEnd, lastDayOfMonth(curY, qEnd));
  } else if (preset === 'last_12_months') {
    let startM = curM - 11;
    let startY = curY;
    if (startM <= 0) {
      startM += 12;
      startY -= 1;
    }
    from = formatYmd(startY, startM, 1);
    to = formatYmd(curY, curM, lastDayOfMonth(curY, curM));
  } else if (preset === 'last_year') {
    from = formatYmd(curY - 1, 1, 1);
    to = formatYmd(curY - 1, 12, 31);
  } else {
    // this_year
    from = formatYmd(curY, 1, 1);
    to = formatYmd(curY, 12, 31);
  }

  return {
    preset,
    from,
    to,
    prevFrom: shiftYearBack(from),
    prevTo: shiftYearBack(to),
  };
}

function withTransaction(database, fn) {
  database.exec('BEGIN IMMEDIATE');
  try {
    const out = fn();
    database.exec('COMMIT');
    return out;
  } catch (err) {
    try {
      database.exec('ROLLBACK');
    } catch {
      // ignore rollback errors
    }
    throw err;
  }
}

function normalizeCommercialPayMethod(raw, createHttpError) {
  const s = String(raw || '').trim().toLowerCase();
  if (!s || s === 'cash' || s === 'especes' || s === 'espèces') return 'Cash';
  if (s === 'bankily') return 'Bankily';
  if (s === 'masrivi') return 'Masrivi';
  if (s === 'sedad') return 'Sedad';
  if (s === 'bimbank') return 'Bimbank';
  if (s === 'click') return 'Click';
  if (s === 'karni' || s === 'credit' || s === 'crédit') return 'Karni';
  if (s === 'cheque' || s === 'chèque') return 'Chèque';
  if (s === 'traite') return 'Traite';
  if (s === 'virement') return 'Virement';
  if (s === 'mixte' || s === 'mixed' || s === 'split') return 'Mixte';
  if (createHttpError) {
    throw createHttpError(400, `Mode de paiement invalide: ${raw}`);
  }
  return String(raw).trim();
}

function ensureCommercialDefaults(database, tenantId) {
  const existing = database
    .prepare('SELECT 1 FROM commercial_treasury_accounts WHERE tenant_id = ? LIMIT 1')
    .get(tenantId);
  if (existing) return;

  const ins = database.prepare(`
    INSERT OR IGNORE INTO commercial_treasury_accounts (
      tenant_id, code, name, account_type, initial_balance_mru, current_balance_mru, is_default, active
    ) VALUES (?, ?, ?, ?, 0, 0, ?, 1)
  `);
  ins.run(tenantId, 'CAISSE-01', 'Caisse Principale', 'CAISSE', 1);
  ins.run(tenantId, 'BANQUE-01', 'Banque Principale', 'BANQUE', 0);
}

function nextSequenceCode(database, table, col, tenantId, prefix, padLen = 4) {
  const rows = database
    .prepare(`SELECT ${col} AS code FROM ${table} WHERE tenant_id = ? AND ${col} LIKE ?`)
    .all(tenantId, `${prefix}-%`);
  let maxSeq = 0;
  const escaped = prefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const re = new RegExp(`^${escaped}-(\\d+)$`);
  for (const r of rows) {
    const m = String(r.code || '').match(re);
    if (m) {
      const n = Number(m[1]);
      if (Number.isInteger(n) && n > maxSeq) maxSeq = n;
    }
  }
  return `${prefix}-${String(maxSeq + 1).padStart(padLen, '0')}`;
}

function nextDocNumber(database, table, col, tenantId, prefix, dateStr) {
  const year = /^\d{4}/.test(String(dateStr || '')) ? String(dateStr).slice(0, 4) : todayIso().slice(0, 4);
  const fullPrefix = `${prefix}-${year}-`;
  const rows = database
    .prepare(`SELECT ${col} AS num FROM ${table} WHERE tenant_id = ? AND ${col} LIKE ?`)
    .all(tenantId, `${fullPrefix}%`);
  let maxSeq = 0;
  for (const r of rows) {
    const tail = String(r.num || '').slice(fullPrefix.length);
    if (/^\d+$/.test(tail)) {
      const n = Number(tail);
      if (n > maxSeq) maxSeq = n;
    }
  }
  return `${fullPrefix}${String(maxSeq + 1).padStart(4, '0')}`;
}

function resolveDefaultTreasuryAccount(database, tenantId, payMethod) {
  const preferredType = payMethod === 'Cash' ? 'CAISSE' : 'BANQUE';
  let acc = database
    .prepare(
      'SELECT * FROM commercial_treasury_accounts WHERE tenant_id = ? AND active = 1 AND account_type = ? ORDER BY is_default DESC, id ASC LIMIT 1',
    )
    .get(tenantId, preferredType);
  if (!acc) {
    acc = database
      .prepare(
        'SELECT * FROM commercial_treasury_accounts WHERE tenant_id = ? AND active = 1 ORDER BY is_default DESC, id ASC LIMIT 1',
      )
      .get(tenantId);
  }
  return acc || null;
}

function getClientInvoiceEncours(database, tenantId, clientId) {
  if (!clientId) return 0;
  const row = database
    .prepare(`
      SELECT COALESCE(SUM(MAX(0, total_ttc_mru - paid_mru - credited_mru)), 0) AS s
      FROM commercial_sales_docs
      WHERE tenant_id = ? AND client_id = ? AND doc_type = 'FACTURE' AND status IN ('VALIDEE', 'PARTIELLE')
    `)
    .get(tenantId, clientId);
  return round2(row ? row.s : 0);
}

function insertAudit(
  database,
  tenantId,
  actor,
  action,
  title,
  subtitle,
  entityType,
  entityId,
  beforeObj,
  afterObj,
  nowHM,
) {
  database
    .prepare(`
      INSERT INTO audit_logs (
        tenant_id, actor, action, title, subtitle, entity_type, entity_id,
        before_json, after_json, time_label, is_training, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
    `)
    .run(
      tenantId,
      actor,
      action,
      title,
      subtitle,
      entityType,
      String(entityId ?? ''),
      beforeObj ? JSON.stringify(beforeObj) : '',
      afterObj ? JSON.stringify(afterObj) : '',
      nowHM(),
      new Date().toISOString(),
    );
}

// ============================================================================
// SERIALIZERS (camelCase DTOs)
// ============================================================================

function serializeClient(r, invoiceEncoursMru = 0) {
  const karniDebtMru = round2(r.current_debt_mru);
  const invEncours = round2(invoiceEncoursMru);
  const encoursTtcMru = round2(invEncours + karniDebtMru);
  const creditLimitMru = round2(r.credit_limit_mru);
  return {
    id: r.id,
    tenantId: r.tenant_id,
    branchId: r.branch_id,
    code: r.code,
    name: r.name,
    isB2b: Boolean(r.is_b2b),
    nif: r.nif,
    rc: r.rc,
    phone: r.phone,
    email: r.email,
    address: r.address,
    city: r.city,
    paymentTermsDays: Number(r.payment_terms_days || 0),
    creditLimitMru,
    currentDebtMru: karniDebtMru,
    karniDebtMru,
    invoiceEncoursMru: invEncours,
    encoursTtcMru,
    creditAvailableMru: creditLimitMru > 0 ? round2(Math.max(0, creditLimitMru - encoursTtcMru)) : null,
    notes: r.notes,
    active: Boolean(r.active),
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

function serializeSupplier(r, computedBalanceDueMru = null) {
  const balanceDueMru =
    computedBalanceDueMru !== null ? round2(computedBalanceDueMru) : round2(r.balance_due_mru);
  return {
    id: r.id,
    tenantId: r.tenant_id,
    branchId: r.branch_id,
    code: r.code,
    name: r.name,
    nif: r.nif,
    rc: r.rc,
    contactName: r.contact_name,
    phone: r.phone,
    email: r.email,
    address: r.address,
    city: r.city,
    paymentTermsDays: Number(r.payment_terms_days || 0),
    balanceDueMru,
    notes: r.notes,
    active: Boolean(r.active),
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

function serializeArticle(r) {
  const tvaRate = r.is_exempt ? 0 : Number(r.tva_rate ?? 16);
  const priceRetailHt = round2(r.price_retail_ht);
  const priceWholeHt = round2(r.price_whole_ht);
  const pmpCostMru = round2(r.pmp_cost_mru);
  const stockQty = round3(r.stock_qty);
  const minStock = round3(r.min_stock);
  const trackStock = Boolean(r.track_stock);
  return {
    id: r.id,
    tenantId: r.tenant_id,
    branchId: r.branch_id,
    sku: r.sku,
    barcode: r.barcode,
    name: r.name,
    nameAr: r.name_ar,
    category: r.category,
    unit: r.unit,
    priceRetailHt,
    priceWholeHt,
    priceRetailTtc: r.is_exempt ? priceRetailHt : round2(priceRetailHt * (1 + tvaRate / 100)),
    priceWholeTtc: r.is_exempt ? priceWholeHt : round2(priceWholeHt * (1 + tvaRate / 100)),
    priceCostMru: round2(r.price_cost_mru),
    pmpCostMru,
    stockQty,
    minStock,
    tvaRate,
    isExempt: Boolean(r.is_exempt),
    trackStock,
    active: Boolean(r.active),
    stockValuePmpMru: trackStock ? round2(Math.max(0, stockQty) * pmpCostMru) : 0,
    isLowStock: Boolean(r.active) && trackStock && stockQty <= minStock,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

function serializeStockMovement(r) {
  return {
    id: r.id,
    tenantId: r.tenant_id,
    branchId: r.branch_id,
    articleId: r.article_id,
    articleName: r.article_name || '',
    sku: r.article_sku || '',
    unit: r.article_unit || 'unité',
    userId: r.user_id,
    movementType: r.movement_type,
    qtyDelta: round3(r.qty_delta),
    unitCostMru: round2(r.unit_cost_mru),
    pmpBeforeMru: round2(r.pmp_before_mru),
    pmpAfterMru: round2(r.pmp_after_mru),
    stockBefore: round3(r.stock_before),
    stockAfter: round3(r.stock_after),
    sourceType: r.source_type,
    sourceId: r.source_id,
    sourceNumber: r.source_number,
    reason: r.reason,
    createdAt: r.created_at,
  };
}

function serializeSalesDoc(r) {
  const totalTtc = round2(r.total_ttc_mru);
  const paid = round2(r.paid_mru);
  const credited = round2(r.credited_mru);
  const totalHt = round2(r.total_ht_mru);
  const totalCost = round2(r.total_cost_mru);
  return {
    id: r.id,
    tenantId: r.tenant_id,
    branchId: r.branch_id,
    clientId: r.client_id,
    userId: r.user_id,
    docType: r.doc_type,
    docNumber: r.doc_number,
    status: r.status,
    issueDate: r.issue_date,
    dueDate: r.due_date,
    sourceDocId: r.source_doc_id,
    sourceDocType: r.source_doc_type,
    convertedToDocId: r.converted_to_doc_id,
    convertedToType: r.converted_to_type,
    clientName: r.client_name,
    clientNif: r.client_nif,
    clientRc: r.client_rc,
    deliveryAddress: r.delivery_address,
    globalDiscountPct: round2(r.global_discount_pct),
    subtotalHtMru: round2(r.subtotal_ht_mru),
    discountHtMru: round2(r.discount_ht_mru),
    totalHtMru: totalHt,
    totalTvaMru: round2(r.total_tva_mru),
    totalTtcMru: totalTtc,
    totalCostMru: totalCost,
    grossMarginMru: round2(totalHt - totalCost),
    paidMru: paid,
    creditedMru: credited,
    remainingMru: round2(Math.max(0, totalTtc - paid - credited)),
    stockDeducted: Boolean(r.stock_deducted),
    restockOnValidate: Boolean(r.restock_on_validate),
    reason: r.reason,
    notes: r.notes,
    validatedAt: r.validated_at,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

function serializeSalesLine(r) {
  return {
    id: r.id,
    tenantId: r.tenant_id,
    docId: r.doc_id,
    articleId: r.article_id,
    lineOrder: r.line_order,
    sku: r.sku,
    designation: r.designation,
    unit: r.unit,
    qty: round3(r.qty),
    unitPriceHtMru: round2(r.unit_price_ht_mru),
    discountPct: round2(r.discount_pct),
    tvaRate: Number(r.tva_rate),
    isExempt: Boolean(r.is_exempt),
    costPmpMru: round2(r.cost_pmp_mru),
    lineHtMru: round2(r.line_ht_mru),
    lineTvaMru: round2(r.line_tva_mru),
    lineTtcMru: round2(r.line_ttc_mru),
    lineCostMru: round2(r.line_cost_mru),
  };
}

function serializePurchaseDoc(r) {
  const totalTtc = round2(r.total_ttc_mru);
  const paid = round2(r.paid_mru);
  const credited = round2(r.credited_mru);
  return {
    id: r.id,
    tenantId: r.tenant_id,
    branchId: r.branch_id,
    supplierId: r.supplier_id,
    userId: r.user_id,
    docType: r.doc_type,
    docNumber: r.doc_number,
    supplierRef: r.supplier_ref,
    status: r.status,
    issueDate: r.issue_date,
    dueDate: r.due_date,
    sourceDocId: r.source_doc_id,
    sourceDocType: r.source_doc_type,
    convertedToDocId: r.converted_to_doc_id,
    convertedToType: r.converted_to_type,
    supplierName: r.supplier_name,
    supplierNif: r.supplier_nif,
    globalDiscountPct: round2(r.global_discount_pct),
    subtotalHtMru: round2(r.subtotal_ht_mru),
    discountHtMru: round2(r.discount_ht_mru),
    totalHtMru: round2(r.total_ht_mru),
    totalTvaMru: round2(r.total_tva_mru),
    totalTtcMru: totalTtc,
    paidMru: paid,
    creditedMru: credited,
    remainingMru: round2(Math.max(0, totalTtc - paid - credited)),
    stockApplied: Boolean(r.stock_applied),
    deductStockOnValidate: Boolean(r.deduct_stock_on_validate),
    reason: r.reason,
    notes: r.notes,
    validatedAt: r.validated_at,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

function serializePurchaseLine(r) {
  return {
    id: r.id,
    tenantId: r.tenant_id,
    docId: r.doc_id,
    articleId: r.article_id,
    lineOrder: r.line_order,
    sku: r.sku,
    designation: r.designation,
    unit: r.unit,
    qty: round3(r.qty),
    unitCostHtMru: round2(r.unit_cost_ht_mru),
    discountPct: round2(r.discount_pct),
    tvaRate: Number(r.tva_rate),
    isExempt: Boolean(r.is_exempt),
    lineHtMru: round2(r.line_ht_mru),
    lineTvaMru: round2(r.line_tva_mru),
    lineTtcMru: round2(r.line_ttc_mru),
  };
}

function serializePosSession(r) {
  return {
    id: r.id,
    tenantId: r.tenant_id,
    branchId: r.branch_id,
    registerId: r.register_id,
    userId: r.user_id,
    sessionNumber: r.session_number,
    registerCode: r.register_code,
    cashierName: r.cashier_name,
    status: r.status,
    openingFloatMru: round2(r.opening_float_mru),
    cashSalesMru: round2(r.cash_sales_mru),
    bankilyMru: round2(r.bankily_mru),
    masriviMru: round2(r.masrivi_mru),
    sedadMru: round2(r.sedad_mru),
    bimbankMru: round2(r.bimbank_mru),
    clickMru: round2(r.click_mru),
    karniMru: round2(r.karni_mru),
    refundCashMru: round2(r.refund_cash_mru),
    totalSalesHtMru: round2(r.total_sales_ht_mru),
    totalSalesTvaMru: round2(r.total_sales_tva_mru),
    totalSalesTtcMru: round2(r.total_sales_ttc_mru),
    ticketsCount: Number(r.tickets_count || 0),
    expectedCashMru: round2(r.expected_cash_mru),
    countedCashMru: r.counted_cash_mru !== null && r.counted_cash_mru !== undefined ? round2(r.counted_cash_mru) : null,
    varianceMru: round2(r.variance_mru),
    notes: r.notes,
    openedAt: r.opened_at,
    closedAt: r.closed_at,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

function serializePosTicket(r, lines = [], parseJson) {
  return {
    id: r.id,
    tenantId: r.tenant_id,
    branchId: r.branch_id,
    sessionId: r.session_id,
    clientId: r.client_id,
    userId: r.user_id,
    ticketNumber: r.ticket_number,
    priceTier: r.price_tier,
    status: r.status,
    payMethod: r.pay_method,
    payments: parseJson ? parseJson(r.payments_json, []) : [],
    subtotalHtMru: round2(r.subtotal_ht_mru),
    discountMru: round2(r.discount_mru),
    totalHtMru: round2(r.total_ht_mru),
    totalTvaMru: round2(r.total_tva_mru),
    totalTtcMru: round2(r.total_ttc_mru),
    totalCostMru: round2(r.total_cost_mru),
    amountTenderedMru: round2(r.amount_tendered_mru),
    changeMru: round2(r.change_mru),
    customerName: r.customer_name,
    voidReason: r.void_reason,
    voidedAt: r.voided_at,
    createdAt: r.created_at,
    lines,
  };
}

function serializePosTicketLine(r) {
  return {
    id: r.id,
    tenantId: r.tenant_id,
    ticketId: r.ticket_id,
    articleId: r.article_id,
    sku: r.sku,
    designation: r.designation,
    unit: r.unit,
    qty: round3(r.qty),
    unitPriceHtMru: round2(r.unit_price_ht_mru),
    unitPriceTtcMru: round2(r.unit_price_ttc_mru),
    discountPct: round2(r.discount_pct),
    tvaRate: Number(r.tva_rate),
    isExempt: Boolean(r.is_exempt),
    costPmpMru: round2(r.cost_pmp_mru),
    lineHtMru: round2(r.line_ht_mru),
    lineTvaMru: round2(r.line_tva_mru),
    lineTtcMru: round2(r.line_ttc_mru),
    lineCostMru: round2(r.line_cost_mru),
  };
}

function serializeTreasuryAccount(r) {
  return {
    id: r.id,
    tenantId: r.tenant_id,
    branchId: r.branch_id,
    code: r.code,
    name: r.name,
    accountType: r.account_type,
    bankName: r.bank_name,
    accountNumber: r.account_number,
    initialBalanceMru: round2(r.initial_balance_mru),
    currentBalanceMru: round2(r.current_balance_mru),
    isDefault: Boolean(r.is_default),
    active: Boolean(r.active),
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

function serializeTreasuryMovement(r) {
  return {
    id: r.id,
    tenantId: r.tenant_id,
    branchId: r.branch_id,
    accountId: r.account_id,
    accountName: r.account_name || '',
    transferAccountId: r.transfer_account_id,
    transferGroupId: r.transfer_group_id,
    userId: r.user_id,
    movementDate: r.movement_date,
    direction: r.direction,
    amountMru: round2(r.amount_mru),
    balanceAfterMru: round2(r.balance_after_mru),
    payMethod: r.pay_method,
    category: r.category,
    label: r.label,
    ref: r.ref,
    sourceType: r.source_type,
    sourceId: r.source_id,
    createdAt: r.created_at,
  };
}

function serializeCheque(r) {
  return {
    id: r.id,
    tenantId: r.tenant_id,
    branchId: r.branch_id,
    direction: r.direction,
    instrumentType: r.instrument_type,
    number: r.number,
    bankName: r.bank_name,
    clientId: r.client_id,
    supplierId: r.supplier_id,
    salesDocId: r.sales_doc_id,
    purchaseDocId: r.purchase_doc_id,
    treasuryAccountId: r.treasury_account_id,
    partyName: r.party_name,
    issueDate: r.issue_date,
    dueDate: r.due_date,
    amountMru: round2(r.amount_mru),
    status: r.status,
    collectedAt: r.collected_at,
    notes: r.notes,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

function serializePayment(r) {
  return {
    id: r.id,
    tenantId: r.tenant_id,
    branchId: r.branch_id,
    paymentNumber: r.payment_number,
    direction: r.direction,
    clientId: r.client_id,
    supplierId: r.supplier_id,
    salesDocId: r.sales_doc_id,
    purchaseDocId: r.purchase_doc_id,
    treasuryAccountId: r.treasury_account_id,
    chequeDraftId: r.cheque_draft_id,
    userId: r.user_id,
    paymentDate: r.payment_date,
    payMethod: r.pay_method,
    amountMru: round2(r.amount_mru),
    ref: r.ref,
    status: r.status,
    notes: r.notes,
    createdAt: r.created_at,
  };
}

// ============================================================================
// DOMAIN COMPUTATIONS
// ============================================================================

function resolveLineTva(rawIsExempt, rawTvaRate, fallbackArticle, createHttpError) {
  const isExempt =
    rawIsExempt !== undefined
      ? Boolean(rawIsExempt)
      : fallbackArticle
      ? Boolean(fallbackArticle.is_exempt)
      : false;
  if (isExempt) return { isExempt: true, tvaRate: 0 };
  const rate =
    rawTvaRate !== undefined
      ? Number(rawTvaRate)
      : fallbackArticle
      ? Number(fallbackArticle.tva_rate ?? 16)
      : 16;
  if (!Number.isFinite(rate) || (rate !== 0 && rate !== 16)) {
    throw createHttpError(400, `Taux TVA invalide (attendu 0 ou 16): ${rawTvaRate}`);
  }
  return { isExempt: rate === 0, tvaRate: rate };
}

function computeDocLinesAndTotals(
  rawLines,
  globalDiscountPctRaw,
  database,
  tenantId,
  mode, // 'sales' | 'purchase'
  pick,
  createHttpError,
) {
  if (!Array.isArray(rawLines) || rawLines.length === 0) {
    throw createHttpError(400, 'Au moins une ligne de document est requise');
  }
  const globalDiscountPct = Number(globalDiscountPctRaw ?? 0);
  if (!Number.isFinite(globalDiscountPct) || globalDiscountPct < 0 || globalDiscountPct > 100) {
    throw createHttpError(400, 'Remise globale invalide (0 à 100%)');
  }

  const getArticle = database.prepare(
    'SELECT * FROM commercial_articles WHERE id = ? AND tenant_id = ? LIMIT 1',
  );

  const computedLines = [];
  let subtotalHt = 0;
  let sumLineTva = 0;
  let totalCostMru = 0;

  for (let i = 0; i < rawLines.length; i++) {
    const l = rawLines[i];
    if (!l || typeof l !== 'object') {
      throw createHttpError(400, `Ligne ${i + 1} invalide`);
    }
    const rawArticleId = pick(l, 'articleId', 'article_id');
    let article = null;
    if (rawArticleId !== undefined && rawArticleId !== '') {
      const aid = Number(rawArticleId);
      if (!Number.isInteger(aid) || aid <= 0) {
        throw createHttpError(400, `articleId invalide sur la ligne ${i + 1}`);
      }
      article = getArticle.get(aid, tenantId);
      if (!article) {
        throw createHttpError(404, `Article introuvable (#${aid})`);
      }
    }

    const qty = Number(pick(l, 'qty', 'quantity') ?? 1);
    if (!Number.isFinite(qty) || qty <= 0) {
      throw createHttpError(400, `Quantité invalide sur la ligne ${i + 1}`);
    }

    const rawPrice =
      mode === 'sales'
        ? pick(l, 'unitPriceHtMru', 'unit_price_ht_mru', 'unitPriceHt', 'unit_price_ht', 'priceHt')
        : pick(l, 'unitCostHtMru', 'unit_cost_ht_mru', 'unitCostHt', 'unit_cost_ht', 'unitPriceHt');

    const defaultPrice =
      mode === 'sales'
        ? article
          ? Number(article.price_retail_ht)
          : 0
        : article
        ? Number(article.pmp_cost_mru || article.price_cost_mru || 0)
        : 0;

    const unitPrice = rawPrice !== undefined ? Number(rawPrice) : defaultPrice;
    if (!Number.isFinite(unitPrice) || unitPrice < 0) {
      throw createHttpError(400, `Prix unitaire invalide sur la ligne ${i + 1}`);
    }

    const discountPct = Number(pick(l, 'discountPct', 'discount_pct') ?? 0);
    if (!Number.isFinite(discountPct) || discountPct < 0 || discountPct > 100) {
      throw createHttpError(400, `Remise ligne invalide sur la ligne ${i + 1}`);
    }

    const { isExempt, tvaRate } = resolveLineTva(
      pick(l, 'isExempt', 'is_exempt'),
      pick(l, 'tvaRate', 'tva_rate'),
      article,
      createHttpError,
    );

    const designation = String(
      pick(l, 'designation', 'name') ?? (article ? article.name : ''),
    ).trim();
    if (!designation) {
      throw createHttpError(400, `Désignation requise sur la ligne ${i + 1}`);
    }
    const sku = String(pick(l, 'sku') ?? (article ? article.sku : '')).trim();
    const unit = String(pick(l, 'unit') ?? (article ? article.unit : 'unité')).trim() || 'unité';

    const lineHt = round2(qty * unitPrice * (1 - discountPct / 100));
    const lineTva = isExempt || tvaRate === 0 ? 0 : round2(lineHt * (tvaRate / 100));
    const lineTtc = round2(lineHt + lineTva);
    const costPmpMru = article ? round2(article.pmp_cost_mru) : 0;
    const lineCostMru = mode === 'sales' ? round2(qty * costPmpMru) : 0;

    subtotalHt = round2(subtotalHt + lineHt);
    sumLineTva = round2(sumLineTva + lineTva);
    totalCostMru = round2(totalCostMru + lineCostMru);

    computedLines.push({
      lineOrder: i,
      articleId: article ? article.id : null,
      sku,
      designation,
      unit,
      qty: round3(qty),
      unitPrice: round2(unitPrice),
      discountPct: round2(discountPct),
      tvaRate,
      isExempt: isExempt ? 1 : 0,
      costPmpMru,
      lineHt,
      lineTva,
      lineTtc,
      lineCostMru,
    });
  }

  const discountHt = round2(subtotalHt * (globalDiscountPct / 100));
  const totalHt = round2(subtotalHt - discountHt);
  const totalTva = round2(sumLineTva * (1 - globalDiscountPct / 100));
  const totalTtc = round2(totalHt + totalTva);

  return {
    lines: computedLines,
    globalDiscountPct: round2(globalDiscountPct),
    subtotalHt,
    discountHt,
    totalHt,
    totalTva,
    totalTtc,
    totalCostMru,
  };
}

function queryMetricsForPeriod(database, tenantId, from, to) {
  const fac = database
    .prepare(`
      SELECT
        COALESCE(SUM(total_ht_mru), 0) AS ht,
        COALESCE(SUM(total_ttc_mru), 0) AS ttc,
        COALESCE(SUM(total_cost_mru), 0) AS cost,
        COUNT(*) AS cnt
      FROM commercial_sales_docs
      WHERE tenant_id = ?
        AND doc_type = 'FACTURE'
        AND status IN ('VALIDEE', 'PARTIELLE', 'PAYEE')
        AND issue_date >= ? AND issue_date <= ?
    `)
    .get(tenantId, from, to);

  const avoir = database
    .prepare(`
      SELECT
        COALESCE(SUM(total_ht_mru), 0) AS ht,
        COALESCE(SUM(total_ttc_mru), 0) AS ttc,
        COALESCE(SUM(CASE WHEN restock_on_validate = 1 THEN total_cost_mru ELSE 0 END), 0) AS restock_cost,
        COUNT(*) AS cnt
      FROM commercial_sales_docs
      WHERE tenant_id = ?
        AND doc_type = 'AVOIR'
        AND status = 'VALIDEE'
        AND issue_date >= ? AND issue_date <= ?
    `)
    .get(tenantId, from, to);

  const pos = database
    .prepare(`
      SELECT
        COALESCE(SUM(total_ht_mru), 0) AS ht,
        COALESCE(SUM(total_ttc_mru), 0) AS ttc,
        COALESCE(SUM(total_cost_mru), 0) AS cost,
        COUNT(*) AS cnt
      FROM commercial_pos_tickets
      WHERE tenant_id = ?
        AND status = 'PAID'
        AND substr(created_at, 1, 10) >= ? AND substr(created_at, 1, 10) <= ?
    `)
    .get(tenantId, from, to);

  const caHtMru = round2(fac.ht + pos.ht - avoir.ht);
  const caTtcMru = round2(fac.ttc + pos.ttc - avoir.ttc);
  const totalCostMru = round2(fac.cost + pos.cost - avoir.restock_cost);
  const grossMarginMru = round2(caHtMru - totalCostMru);
  const marginRatePct = caHtMru > 0 ? round1((grossMarginMru / caHtMru) * 100) : null;

  const treso = database
    .prepare(`
      SELECT
        COALESCE(SUM(CASE WHEN direction = 'IN' THEN amount_mru ELSE 0 END), 0) AS inflows,
        COALESCE(SUM(CASE WHEN direction = 'OUT' THEN amount_mru ELSE 0 END), 0) AS outflows
      FROM commercial_treasury_movements
      WHERE tenant_id = ?
        AND category != 'INTERNAL_TRANSFER'
        AND movement_date >= ? AND movement_date <= ?
    `)
    .get(tenantId, from, to);

  const purchFac = database
    .prepare(`
      SELECT
        COALESCE(SUM(total_ht_mru), 0) AS ht,
        COALESCE(SUM(total_ttc_mru), 0) AS ttc,
        COUNT(*) AS cnt
      FROM commercial_purchase_docs
      WHERE tenant_id = ?
        AND doc_type = 'FACTURE_FOURNISSEUR'
        AND status IN ('VALIDEE', 'PARTIELLE', 'PAYEE')
        AND issue_date >= ? AND issue_date <= ?
    `)
    .get(tenantId, from, to);

  const purchAvoir = database
    .prepare(`
      SELECT
        COALESCE(SUM(total_ht_mru), 0) AS ht,
        COALESCE(SUM(total_ttc_mru), 0) AS ttc
      FROM commercial_purchase_docs
      WHERE tenant_id = ?
        AND doc_type = 'AVOIR_FOURNISSEUR'
        AND status = 'VALIDEE'
        AND issue_date >= ? AND issue_date <= ?
    `)
    .get(tenantId, from, to);

  const purchasesHtMru = round2(purchFac.ht - purchAvoir.ht);
  const purchasesTtcMru = round2(purchFac.ttc - purchAvoir.ttc);

  const devis = database
    .prepare(`
      SELECT
        COALESCE(SUM(total_ht_mru), 0) AS ht,
        COUNT(*) AS total_cnt,
        COALESCE(SUM(CASE WHEN status = 'CONVERTI' THEN 1 ELSE 0 END), 0) AS conv_cnt
      FROM commercial_sales_docs
      WHERE tenant_id = ?
        AND doc_type = 'DEVIS'
        AND status != 'ANNULE'
        AND issue_date >= ? AND issue_date <= ?
    `)
    .get(tenantId, from, to);

  return {
    caHtMru,
    caTtcMru,
    totalCostMru,
    grossMarginMru,
    marginRatePct,
    invoiceCount: Number(fac.cnt || 0),
    posTicketCount: Number(pos.cnt || 0),
    creditNoteCount: Number(avoir.cnt || 0),
    receiptsMru: round2(treso.inflows),
    disbursementsMru: round2(treso.outflows),
    purchasesHtMru,
    purchasesTtcMru,
    purchaseInvoiceCount: Number(purchFac.cnt || 0),
    quotesEmittedHtMru: round2(devis.ht),
    quotesCount: Number(devis.total_cnt || 0),
    quotesConvertedCount: Number(devis.conv_cnt || 0),
    quoteConversionRatePct:
      devis.total_cnt > 0 ? round1((devis.conv_cnt / devis.total_cnt) * 100) : null,
  };
}

function queryMonthlyCaMap(database, tenantId, from, to) {
  const map = new Map();
  const add = (ym, delta) => {
    map.set(ym, round2((map.get(ym) || 0) + delta));
  };

  const facRows = database
    .prepare(`
      SELECT substr(issue_date, 1, 7) AS ym, COALESCE(SUM(total_ht_mru), 0) AS ht
      FROM commercial_sales_docs
      WHERE tenant_id = ? AND doc_type = 'FACTURE'
        AND status IN ('VALIDEE', 'PARTIELLE', 'PAYEE')
        AND issue_date >= ? AND issue_date <= ?
      GROUP BY ym
    `)
    .all(tenantId, from, to);
  for (const r of facRows) add(r.ym, Number(r.ht));

  const posRows = database
    .prepare(`
      SELECT substr(created_at, 1, 7) AS ym, COALESCE(SUM(total_ht_mru), 0) AS ht
      FROM commercial_pos_tickets
      WHERE tenant_id = ? AND status = 'PAID'
        AND substr(created_at, 1, 10) >= ? AND substr(created_at, 1, 10) <= ?
      GROUP BY ym
    `)
    .all(tenantId, from, to);
  for (const r of posRows) add(r.ym, Number(r.ht));

  const avoirRows = database
    .prepare(`
      SELECT substr(issue_date, 1, 7) AS ym, COALESCE(SUM(total_ht_mru), 0) AS ht
      FROM commercial_sales_docs
      WHERE tenant_id = ? AND doc_type = 'AVOIR'
        AND status = 'VALIDEE'
        AND issue_date >= ? AND issue_date <= ?
      GROUP BY ym
    `)
    .all(tenantId, from, to);
  for (const r of avoirRows) add(r.ym, -Number(r.ht));

  return map;
}

function buildZReport(sessionRow, tickets) {
  let voidedCount = 0;
  for (const t of tickets) {
    if (t.status === 'VOID') voidedCount++;
  }
  const cashSales = round2(sessionRow.cash_sales_mru);
  const bankily = round2(sessionRow.bankily_mru);
  const masrivi = round2(sessionRow.masrivi_mru);
  const sedad = round2(sessionRow.sedad_mru);
  const bimbank = round2(sessionRow.bimbank_mru);
  const click = round2(sessionRow.click_mru);
  const karni = round2(sessionRow.karni_mru);
  const openingFloat = round2(sessionRow.opening_float_mru);
  const refundCash = round2(sessionRow.refund_cash_mru);
  const expectedCash = round2(openingFloat + cashSales - refundCash);

  return {
    sessionId: sessionRow.id,
    sessionNumber: sessionRow.session_number,
    registerCode: sessionRow.register_code,
    cashierName: sessionRow.cashier_name,
    status: sessionRow.status,
    openedAt: sessionRow.opened_at,
    closedAt: sessionRow.closed_at,
    ticketsCount: Number(sessionRow.tickets_count || 0),
    voidedCount,
    totalSalesHtMru: round2(sessionRow.total_sales_ht_mru),
    totalSalesTvaMru: round2(sessionRow.total_sales_tva_mru),
    totalSalesTtcMru: round2(sessionRow.total_sales_ttc_mru),
    openingFloatMru: openingFloat,
    refundCashMru: refundCash,
    expectedCashMru: expectedCash,
    countedCashMru:
      sessionRow.counted_cash_mru !== null && sessionRow.counted_cash_mru !== undefined
        ? round2(sessionRow.counted_cash_mru)
        : null,
    varianceMru: round2(sessionRow.variance_mru),
    byPaymentMethod: {
      cash: cashSales,
      bankily,
      masrivi,
      sedad,
      bimbank,
      click,
      karni,
    },
  };
}

function pctDelta(cur, prev) {
  if (!prev || Math.abs(prev) < 0.005) return null;
  return round1(((cur - prev) / Math.abs(prev)) * 100);
}

// ============================================================================
// MAIN ROUTE HANDLER
// ============================================================================

async function handleCommercialRoute(ctx) {
  const {
    req,
    res,
    url,
    pathname: p,
    database,
    currentTenant,
    standardLimit,
    readJsonBody,
    sendJson,
    createHttpError,
    pick,
    parseJson,
    nowHM,
    serializeTenant,
  } = ctx;

  const tenantId = currentTenant.id;
  const actor = currentTenant.manager || currentTenant.name || currentTenant.username;
  const method = req.method;
  let m;

  // --------------------------------------------------------------------------
  // 1. BOOTSTRAP
  // --------------------------------------------------------------------------
  if (method === 'GET' && p === '/api/commercial/bootstrap') {
    ensureCommercialDefaults(database, tenantId);
    const accounts = database
      .prepare('SELECT * FROM commercial_treasury_accounts WHERE tenant_id = ? AND active = 1 ORDER BY is_default DESC, id ASC')
      .all(tenantId)
      .map(serializeTreasuryAccount);
    const openSessionRow = database
      .prepare("SELECT * FROM commercial_pos_sessions WHERE tenant_id = ? AND status = 'OPEN' ORDER BY id DESC LIMIT 1")
      .get(tenantId);

    const today = todayIso();
    const in7d = addDaysIso(today, 7);

    const counts = {
      clients: database.prepare('SELECT COUNT(*) AS cnt FROM commercial_clients WHERE tenant_id = ? AND active = 1').get(tenantId).cnt,
      suppliers: database.prepare('SELECT COUNT(*) AS cnt FROM commercial_suppliers WHERE tenant_id = ? AND active = 1').get(tenantId).cnt,
      articles: database.prepare('SELECT COUNT(*) AS cnt FROM commercial_articles WHERE tenant_id = ? AND active = 1').get(tenantId).cnt,
      openDevis: database.prepare("SELECT COUNT(*) AS cnt FROM commercial_sales_docs WHERE tenant_id = ? AND doc_type = 'DEVIS' AND status IN ('BROUILLON','ENVOYE','ACCEPTE')").get(tenantId).cnt,
      unpaidInvoices: database.prepare("SELECT COUNT(*) AS cnt FROM commercial_sales_docs WHERE tenant_id = ? AND doc_type = 'FACTURE' AND status IN ('VALIDEE','PARTIELLE') AND (total_ttc_mru - paid_mru - credited_mru) > 0.01").get(tenantId).cnt,
      overdueInvoices: database.prepare("SELECT COUNT(*) AS cnt FROM commercial_sales_docs WHERE tenant_id = ? AND doc_type = 'FACTURE' AND status IN ('VALIDEE','PARTIELLE') AND (total_ttc_mru - paid_mru - credited_mru) > 0.01 AND due_date != '' AND due_date < ?").get(tenantId, today).cnt,
      dueCheques7d: database.prepare("SELECT COUNT(*) AS cnt FROM commercial_cheques_drafts WHERE tenant_id = ? AND status IN ('EN_PORTEFEUILLE','DEPOSE','EMIS') AND due_date <= ?").get(tenantId, in7d).cnt,
      lowStockArticles: database.prepare('SELECT COUNT(*) AS cnt FROM commercial_articles WHERE tenant_id = ? AND active = 1 AND track_stock = 1 AND stock_qty <= min_stock').get(tenantId).cnt,
    };

    const tenantDto = serializeTenant(currentTenant);
    return sendJson(res, 200, {
      ok: true,
      tenant: tenantDto,
      payMethods: tenantDto.payMethods,
      treasuryAccounts: accounts,
      openPosSession: openSessionRow ? serializePosSession(openSessionRow) : null,
      counts,
    }) || true;
  }

  // --------------------------------------------------------------------------
  // 2. DASHBOARD & ANALYTICS
  // --------------------------------------------------------------------------
  if (method === 'GET' && p === '/api/commercial/dashboard') {
    const range = resolveDateRange(
      url.searchParams.get('preset'),
      url.searchParams.get('from'),
      url.searchParams.get('to'),
      createHttpError,
    );
    const cur = queryMetricsForPeriod(database, tenantId, range.from, range.to);
    const prev = queryMetricsForPeriod(database, tenantId, range.prevFrom, range.prevTo);

    const buckets = monthsInRange(range.from, range.to);
    const curMonthlyMap = queryMonthlyCaMap(database, tenantId, range.from, range.to);
    const prevMonthlyMap = queryMonthlyCaMap(database, tenantId, range.prevFrom, range.prevTo);

    const objRows = database
      .prepare('SELECT year, month, target_ca_ht_mru FROM commercial_objectives WHERE tenant_id = ?')
      .all(tenantId);
    const objMap = new Map(objRows.map((r) => [`${r.year}-${pad2(r.month)}`, Number(r.target_ca_ht_mru)]));

    let objectiveTargetMru = 0;
    const series = buckets.map((b) => {
      const targetCaHtMru = round2(objMap.get(b.monthKey) || 0);
      objectiveTargetMru = round2(objectiveTargetMru + targetCaHtMru);
      return {
        monthKey: b.monthKey,
        label: b.label,
        periodCaHtMru: round2(curMonthlyMap.get(b.monthKey) || 0),
        prevCaHtMru: round2(prevMonthlyMap.get(b.prevMonthKey) || 0),
        targetCaHtMru,
      };
    });

    const objectiveAttainmentPct =
      objectiveTargetMru > 0 ? round1((cur.caHtMru / objectiveTargetMru) * 100) : null;

    // Point-in-time balance sheet KPIs
    const invRecRow = database
      .prepare(`
        SELECT COALESCE(SUM(MAX(0, total_ttc_mru - paid_mru - credited_mru)), 0) AS inv_rec
        FROM commercial_sales_docs
        WHERE tenant_id = ? AND doc_type = 'FACTURE' AND status IN ('VALIDEE', 'PARTIELLE')
      `)
      .get(tenantId);
    const karniRow = database
      .prepare('SELECT COALESCE(SUM(MAX(0, current_debt_mru)), 0) AS karni_rec FROM commercial_clients WHERE tenant_id = ?')
      .get(tenantId);
    const clientReceivablesTtcMru = round2(invRecRow.inv_rec + karniRow.karni_rec);

    const pendingEffRow = database
      .prepare(`
        SELECT COALESCE(SUM(amount_mru), 0) AS s
        FROM commercial_cheques_drafts
        WHERE tenant_id = ? AND direction = 'CLIENT' AND status IN ('EN_PORTEFEUILLE', 'DEPOSE')
      `)
      .get(tenantId);
    const pendingEffectsMru = round2(pendingEffRow.s);

    const supDebtRow = database
      .prepare(`
        SELECT COALESCE(SUM(MAX(0, total_ttc_mru - paid_mru - credited_mru)), 0) AS s
        FROM commercial_purchase_docs
        WHERE tenant_id = ? AND doc_type = 'FACTURE_FOURNISSEUR' AND status IN ('VALIDEE', 'PARTIELLE')
      `)
      .get(tenantId);
    const supplierDebtMru = round2(supDebtRow.s);

    const tresoBalRow = database
      .prepare('SELECT COALESCE(SUM(current_balance_mru), 0) AS s FROM commercial_treasury_accounts WHERE tenant_id = ? AND active = 1')
      .get(tenantId);
    const treasuryBalanceMru = round2(tresoBalRow.s);

    const stockValRow = database
      .prepare(`
        SELECT COALESCE(SUM(MAX(0, stock_qty) * pmp_cost_mru), 0) AS s
        FROM commercial_articles
        WHERE tenant_id = ? AND active = 1 AND track_stock = 1
      `)
      .get(tenantId);
    const stockValuePmpMru = round2(stockValRow.s);

    // Alerts (À traiter)
    const today = todayIso();
    const in7d = addDaysIso(today, 7);

    const overdueClientRows = database
      .prepare(`
        SELECT id, doc_number, client_id, client_name, due_date,
               (total_ttc_mru - paid_mru - credited_mru) AS remaining_mru
        FROM commercial_sales_docs
        WHERE tenant_id = ? AND doc_type = 'FACTURE' AND status IN ('VALIDEE', 'PARTIELLE')
          AND (total_ttc_mru - paid_mru - credited_mru) > 0.01
          AND due_date != '' AND due_date < ?
        ORDER BY due_date ASC, id ASC
      `)
      .all(tenantId, today);

    const dueChequeRows = database
      .prepare(`
        SELECT id, direction, instrument_type, number, party_name, due_date, amount_mru, status
        FROM commercial_cheques_drafts
        WHERE tenant_id = ? AND status IN ('EN_PORTEFEUILLE', 'DEPOSE', 'EMIS')
          AND due_date <= ?
        ORDER BY due_date ASC, id ASC
      `)
      .all(tenantId, in7d);

    const overdueSupplierRows = database
      .prepare(`
        SELECT id, doc_number, supplier_id, supplier_name, due_date,
               (total_ttc_mru - paid_mru - credited_mru) AS remaining_mru
        FROM commercial_purchase_docs
        WHERE tenant_id = ? AND doc_type = 'FACTURE_FOURNISSEUR' AND status IN ('VALIDEE', 'PARTIELLE')
          AND (total_ttc_mru - paid_mru - credited_mru) > 0.01
          AND due_date != '' AND due_date < ?
        ORDER BY due_date ASC, id ASC
      `)
      .all(tenantId, today);

    const lowStockRows = database
      .prepare(`
        SELECT id, sku, name, category, unit, stock_qty, min_stock, pmp_cost_mru
        FROM commercial_articles
        WHERE tenant_id = ? AND active = 1 AND track_stock = 1 AND stock_qty <= min_stock
        ORDER BY (stock_qty - min_stock) ASC, id ASC
      `)
      .all(tenantId);

    return sendJson(res, 200, {
      ok: true,
      range,
      kpis: {
        caHtMru: cur.caHtMru,
        caVsN1Pct: pctDelta(cur.caHtMru, prev.caHtMru),
        objectiveTargetMru,
        objectiveAttainmentPct,
        grossMarginMru: cur.grossMarginMru,
        marginRatePct: cur.marginRatePct,
        marginRatePrevPct: prev.marginRatePct,
        marginVsN1Pct: pctDelta(cur.grossMarginMru, prev.grossMarginMru),
        receiptsMru: cur.receiptsMru,
        receiptsVsN1Pct: pctDelta(cur.receiptsMru, prev.receiptsMru),
        disbursementsMru: cur.disbursementsMru,
        purchasesHtMru: cur.purchasesHtMru,
        purchasesVsN1Pct: pctDelta(cur.purchasesHtMru, prev.purchasesHtMru),
        supplierDebtMru,
        clientReceivablesTtcMru,
        pendingEffectsMru,
        treasuryBalanceMru,
        stockValuePmpMru,
        quotesEmittedHtMru: cur.quotesEmittedHtMru,
        quotesCount: cur.quotesCount,
        quoteConversionRatePct: cur.quoteConversionRatePct,
      },
      series,
      alerts: {
        overdueClientInvoices: {
          count: overdueClientRows.length,
          totalMru: round2(overdueClientRows.reduce((s, r) => s + Number(r.remaining_mru), 0)),
          items: overdueClientRows.slice(0, 10).map((r) => ({
            id: r.id,
            docNumber: r.doc_number,
            clientId: r.client_id,
            clientName: r.client_name,
            dueDate: r.due_date,
            remainingMru: round2(r.remaining_mru),
          })),
        },
        dueCheques7d: {
          count: dueChequeRows.length,
          totalMru: round2(dueChequeRows.reduce((s, r) => s + Number(r.amount_mru), 0)),
          items: dueChequeRows.slice(0, 10).map((r) => ({
            id: r.id,
            direction: r.direction,
            instrumentType: r.instrument_type,
            number: r.number,
            partyName: r.party_name,
            dueDate: r.due_date,
            amountMru: round2(r.amount_mru),
            status: r.status,
          })),
        },
        overdueSupplierInvoices: {
          count: overdueSupplierRows.length,
          totalMru: round2(overdueSupplierRows.reduce((s, r) => s + Number(r.remaining_mru), 0)),
          items: overdueSupplierRows.slice(0, 10).map((r) => ({
            id: r.id,
            docNumber: r.doc_number,
            supplierId: r.supplier_id,
            supplierName: r.supplier_name,
            dueDate: r.due_date,
            remainingMru: round2(r.remaining_mru),
          })),
        },
        lowStockArticles: {
          count: lowStockRows.length,
          items: lowStockRows.slice(0, 10).map((r) => ({
            id: r.id,
            sku: r.sku,
            name: r.name,
            category: r.category,
            unit: r.unit,
            stockQty: round3(r.stock_qty),
            minStock: round3(r.min_stock),
            pmpCostMru: round2(r.pmp_cost_mru),
          })),
        },
      },
    }) || true;
  }

  if (method === 'GET' && p === '/api/commercial/analytics/sales') {
    const range = resolveDateRange(
      url.searchParams.get('preset'),
      url.searchParams.get('from'),
      url.searchParams.get('to'),
      createHttpError,
    );
    const cur = queryMetricsForPeriod(database, tenantId, range.from, range.to);
    const buckets = monthsInRange(range.from, range.to);
    const curMonthlyMap = queryMonthlyCaMap(database, tenantId, range.from, range.to);
    const prevMonthlyMap = queryMonthlyCaMap(database, tenantId, range.prevFrom, range.prevTo);
    const monthly = buckets.map((b) => ({
      monthKey: b.monthKey,
      label: b.label,
      caHtMru: round2(curMonthlyMap.get(b.monthKey) || 0),
      prevCaHtMru: round2(prevMonthlyMap.get(b.prevMonthKey) || 0),
    }));

    // Top articles from Factures + POS Tickets
    const artMap = new Map();
    const salesArtRows = database
      .prepare(`
        SELECT l.article_id, COALESCE(a.sku, l.sku) AS art_sku, COALESCE(a.name, l.designation) AS art_name,
               SUM(l.qty) AS qty, SUM(l.line_ht_mru * (1 - d.global_discount_pct / 100.0)) AS ca_ht,
               SUM(l.line_cost_mru) AS cost
        FROM commercial_sales_lines l
        JOIN commercial_sales_docs d ON d.id = l.doc_id
        LEFT JOIN commercial_articles a ON a.id = l.article_id
        WHERE d.tenant_id = ? AND d.doc_type = 'FACTURE' AND d.status IN ('VALIDEE','PARTIELLE','PAYEE')
          AND d.issue_date >= ? AND d.issue_date <= ?
        GROUP BY l.article_id, COALESCE(a.sku, l.sku), COALESCE(a.name, l.designation)
      `)
      .all(tenantId, range.from, range.to);
    for (const r of salesArtRows) {
      const k = r.article_id ? `A:${r.article_id}` : `N:${r.art_name}`;
      const curItem = artMap.get(k) || { articleId: r.article_id, sku: r.art_sku, name: r.art_name, qty: 0, caHtMru: 0, costMru: 0 };
      curItem.qty = round3(curItem.qty + Number(r.qty));
      curItem.caHtMru = round2(curItem.caHtMru + Number(r.ca_ht));
      curItem.costMru = round2(curItem.costMru + Number(r.cost));
      artMap.set(k, curItem);
    }

    const posArtRows = database
      .prepare(`
        SELECT l.article_id, COALESCE(a.sku, l.sku) AS art_sku, COALESCE(a.name, l.designation) AS art_name,
               SUM(l.qty) AS qty,
               SUM(CASE WHEN t.subtotal_ht_mru > 0 THEN l.line_ht_mru * (t.total_ht_mru / t.subtotal_ht_mru) ELSE l.line_ht_mru END) AS ca_ht,
               SUM(l.line_cost_mru) AS cost
        FROM commercial_pos_ticket_lines l
        JOIN commercial_pos_tickets t ON t.id = l.ticket_id
        LEFT JOIN commercial_articles a ON a.id = l.article_id
        WHERE t.tenant_id = ? AND t.status = 'PAID'
          AND substr(t.created_at, 1, 10) >= ? AND substr(t.created_at, 1, 10) <= ?
        GROUP BY l.article_id, COALESCE(a.sku, l.sku), COALESCE(a.name, l.designation)
      `)
      .all(tenantId, range.from, range.to);
    for (const r of posArtRows) {
      const k = r.article_id ? `A:${r.article_id}` : `N:${r.art_name}`;
      const curItem = artMap.get(k) || { articleId: r.article_id, sku: r.art_sku, name: r.art_name, qty: 0, caHtMru: 0, costMru: 0 };
      curItem.qty = round3(curItem.qty + Number(r.qty));
      curItem.caHtMru = round2(curItem.caHtMru + Number(r.ca_ht));
      curItem.costMru = round2(curItem.costMru + Number(r.cost));
      artMap.set(k, curItem);
    }
    const topArticles = [...artMap.values()]
      .map((a) => ({
        ...a,
        marginMru: round2(a.caHtMru - a.costMru),
      }))
      .sort((a, b) => b.caHtMru - a.caHtMru)
      .slice(0, 10);

    const topClients = database
      .prepare(`
        SELECT d.client_id AS clientId, COALESCE(c.name, d.client_name) AS cli_name,
               COUNT(*) AS invoiceCount,
               COALESCE(SUM(d.total_ht_mru), 0) AS caHtMru,
               COALESCE(SUM(d.total_ttc_mru), 0) AS caTtcMru
        FROM commercial_sales_docs d
        LEFT JOIN commercial_clients c ON c.id = d.client_id
        WHERE d.tenant_id = ? AND d.doc_type = 'FACTURE' AND d.status IN ('VALIDEE','PARTIELLE','PAYEE')
          AND d.issue_date >= ? AND d.issue_date <= ?
        GROUP BY d.client_id, COALESCE(c.name, d.client_name)
        ORDER BY caHtMru DESC
        LIMIT 10
      `)
      .all(tenantId, range.from, range.to)
      .map((r) => ({
        clientId: r.clientId,
        name: r.cli_name,
        invoiceCount: Number(r.invoiceCount),
        caHtMru: round2(r.caHtMru),
        caTtcMru: round2(r.caTtcMru),
      }));

    const byPaymentMethod = database
      .prepare(`
        SELECT pay_method AS payMethod, COALESCE(SUM(amount_mru), 0) AS amountMru, COUNT(*) AS count
        FROM commercial_payments
        WHERE tenant_id = ? AND direction = 'IN' AND status = 'POSTED'
          AND payment_date >= ? AND payment_date <= ?
        GROUP BY pay_method
        ORDER BY amountMru DESC
      `)
      .all(tenantId, range.from, range.to)
      .map((r) => ({
        payMethod: r.payMethod,
        amountMru: round2(r.amountMru),
        count: Number(r.count),
      }));

    return sendJson(res, 200, {
      ok: true,
      range,
      summary: {
        caHtMru: cur.caHtMru,
        caTtcMru: cur.caTtcMru,
        grossMarginMru: cur.grossMarginMru,
        marginRatePct: cur.marginRatePct,
        invoiceCount: cur.invoiceCount,
        posTicketCount: cur.posTicketCount,
        creditNoteCount: cur.creditNoteCount,
      },
      monthly,
      topArticles,
      topClients,
      byPaymentMethod,
    }) || true;
  }

  if (method === 'GET' && p === '/api/commercial/analytics/purchases-stock') {
    const range = resolveDateRange(
      url.searchParams.get('preset'),
      url.searchParams.get('from'),
      url.searchParams.get('to'),
      createHttpError,
    );
    const cur = queryMetricsForPeriod(database, tenantId, range.from, range.to);
    const recRow = database
      .prepare(`
        SELECT COUNT(*) AS cnt FROM commercial_purchase_docs
        WHERE tenant_id = ? AND doc_type = 'RECEPTION' AND status = 'VALIDEE'
          AND issue_date >= ? AND issue_date <= ?
      `)
      .get(tenantId, range.from, range.to);

    const stockSummary = database
      .prepare(`
        SELECT
          COUNT(*) AS totalSkus,
          COALESCE(SUM(CASE WHEN track_stock = 1 AND stock_qty <= min_stock THEN 1 ELSE 0 END), 0) AS lowStockCount,
          COALESCE(SUM(CASE WHEN track_stock = 1 THEN MAX(0, stock_qty) * pmp_cost_mru ELSE 0 END), 0) AS stockValuePmpMru
        FROM commercial_articles
        WHERE tenant_id = ? AND active = 1
      `)
      .get(tenantId);

    const buckets = monthsInRange(range.from, range.to);
    const purchMap = new Map();
    const purchRows = database
      .prepare(`
        SELECT substr(issue_date, 1, 7) AS ym, doc_type, COALESCE(SUM(total_ht_mru), 0) AS ht
        FROM commercial_purchase_docs
        WHERE tenant_id = ? AND doc_type IN ('FACTURE_FOURNISSEUR','AVOIR_FOURNISSEUR')
          AND status IN ('VALIDEE','PARTIELLE','PAYEE')
          AND issue_date >= ? AND issue_date <= ?
        GROUP BY ym, doc_type
      `)
      .all(tenantId, range.from, range.to);
    for (const r of purchRows) {
      const sign = r.doc_type === 'AVOIR_FOURNISSEUR' ? -1 : 1;
      purchMap.set(r.ym, round2((purchMap.get(r.ym) || 0) + sign * Number(r.ht)));
    }
    const monthly = buckets.map((b) => ({
      monthKey: b.monthKey,
      label: b.label,
      purchasesHtMru: round2(purchMap.get(b.monthKey) || 0),
    }));

    const topSuppliers = database
      .prepare(`
        SELECT d.supplier_id AS supplierId, COALESCE(s.name, d.supplier_name) AS sup_name,
               COUNT(*) AS invoiceCount,
               COALESCE(SUM(d.total_ht_mru), 0) AS purchasesHtMru,
               COALESCE(SUM(d.total_ttc_mru), 0) AS purchasesTtcMru
        FROM commercial_purchase_docs d
        LEFT JOIN commercial_suppliers s ON s.id = d.supplier_id
        WHERE d.tenant_id = ? AND d.doc_type = 'FACTURE_FOURNISSEUR' AND d.status IN ('VALIDEE','PARTIELLE','PAYEE')
          AND d.issue_date >= ? AND d.issue_date <= ?
        GROUP BY d.supplier_id, COALESCE(s.name, d.supplier_name)
        ORDER BY purchasesHtMru DESC
        LIMIT 10
      `)
      .all(tenantId, range.from, range.to)
      .map((r) => ({
        supplierId: r.supplierId,
        name: r.sup_name,
        invoiceCount: Number(r.invoiceCount),
        purchasesHtMru: round2(r.purchasesHtMru),
        purchasesTtcMru: round2(r.purchasesTtcMru),
      }));

    const stockByCategory = database
      .prepare(`
        SELECT category, COUNT(*) AS skuCount,
               COALESCE(SUM(MAX(0, stock_qty)), 0) AS totalQty,
               COALESCE(SUM(MAX(0, stock_qty) * pmp_cost_mru), 0) AS stockValuePmpMru
        FROM commercial_articles
        WHERE tenant_id = ? AND active = 1 AND track_stock = 1
        GROUP BY category
        ORDER BY stockValuePmpMru DESC
      `)
      .all(tenantId)
      .map((r) => ({
        category: r.category,
        skuCount: Number(r.skuCount),
        totalQty: round3(r.totalQty),
        stockValuePmpMru: round2(r.stockValuePmpMru),
      }));

    const lowStockArticles = database
      .prepare(`
        SELECT id, sku, name, category, unit, stock_qty, min_stock, pmp_cost_mru
        FROM commercial_articles
        WHERE tenant_id = ? AND active = 1 AND track_stock = 1 AND stock_qty <= min_stock
        ORDER BY (stock_qty - min_stock) ASC, id ASC
        LIMIT 20
      `)
      .all(tenantId)
      .map((r) => ({
        id: r.id,
        sku: r.sku,
        name: r.name,
        category: r.category,
        unit: r.unit,
        stockQty: round3(r.stock_qty),
        minStock: round3(r.min_stock),
        pmpCostMru: round2(r.pmp_cost_mru),
      }));

    return sendJson(res, 200, {
      ok: true,
      range,
      summary: {
        purchasesHtMru: cur.purchasesHtMru,
        purchasesTtcMru: cur.purchasesTtcMru,
        receptionsCount: Number(recRow.cnt || 0),
        stockValuePmpMru: round2(stockSummary.stockValuePmpMru),
        lowStockCount: Number(stockSummary.lowStockCount || 0),
        totalSkus: Number(stockSummary.totalSkus || 0),
      },
      monthly,
      topSuppliers,
      stockByCategory,
      lowStockArticles,
    }) || true;
  }

  if (method === 'GET' && p === '/api/commercial/analytics/treasury') {
    const range = resolveDateRange(
      url.searchParams.get('preset'),
      url.searchParams.get('from'),
      url.searchParams.get('to'),
      createHttpError,
    );
    const cur = queryMetricsForPeriod(database, tenantId, range.from, range.to);
    const accounts = database
      .prepare('SELECT * FROM commercial_treasury_accounts WHERE tenant_id = ? AND active = 1 ORDER BY is_default DESC, id ASC')
      .all(tenantId)
      .map(serializeTreasuryAccount);
    const totalBalanceMru = round2(accounts.reduce((s, a) => s + a.currentBalanceMru, 0));

    const pendingClientChequesMru = round2(
      database
        .prepare("SELECT COALESCE(SUM(amount_mru), 0) AS s FROM commercial_cheques_drafts WHERE tenant_id = ? AND direction = 'CLIENT' AND status IN ('EN_PORTEFEUILLE','DEPOSE')")
        .get(tenantId).s,
    );
    const pendingSupplierChequesMru = round2(
      database
        .prepare("SELECT COALESCE(SUM(amount_mru), 0) AS s FROM commercial_cheques_drafts WHERE tenant_id = ? AND direction = 'FOURNISSEUR' AND status = 'EMIS'")
        .get(tenantId).s,
    );

    const buckets = monthsInRange(range.from, range.to);
    const mvtRows = database
      .prepare(`
        SELECT substr(movement_date, 1, 7) AS ym, direction, COALESCE(SUM(amount_mru), 0) AS amt
        FROM commercial_treasury_movements
        WHERE tenant_id = ? AND category != 'INTERNAL_TRANSFER'
          AND movement_date >= ? AND movement_date <= ?
        GROUP BY ym, direction
      `)
      .all(tenantId, range.from, range.to);
    const inMap = new Map();
    const outMap = new Map();
    for (const r of mvtRows) {
      if (r.direction === 'IN') inMap.set(r.ym, round2(r.amt));
      else outMap.set(r.ym, round2(r.amt));
    }
    const monthly = buckets.map((b) => {
      const inflows = inMap.get(b.monthKey) || 0;
      const outflows = outMap.get(b.monthKey) || 0;
      return {
        monthKey: b.monthKey,
        label: b.label,
        inflowsMru: inflows,
        outflowsMru: outflows,
        netCashflowMru: round2(inflows - outflows),
      };
    });

    const byPaymentMethod = database
      .prepare(`
        SELECT pay_method AS payMethod, direction, COALESCE(SUM(amount_mru), 0) AS amountMru, COUNT(*) AS count
        FROM commercial_treasury_movements
        WHERE tenant_id = ? AND category != 'INTERNAL_TRANSFER'
          AND movement_date >= ? AND movement_date <= ?
        GROUP BY pay_method, direction
        ORDER BY amountMru DESC
      `)
      .all(tenantId, range.from, range.to)
      .map((r) => ({
        payMethod: r.payMethod,
        direction: r.direction,
        amountMru: round2(r.amountMru),
        count: Number(r.count),
      }));

    const upcomingCheques = database
      .prepare(`
        SELECT * FROM commercial_cheques_drafts
        WHERE tenant_id = ? AND status IN ('EN_PORTEFEUILLE','DEPOSE','EMIS')
        ORDER BY due_date ASC, id ASC
        LIMIT 20
      `)
      .all(tenantId)
      .map(serializeCheque);

    return sendJson(res, 200, {
      ok: true,
      range,
      summary: {
        totalBalanceMru,
        inflowsMru: cur.receiptsMru,
        outflowsMru: cur.disbursementsMru,
        netCashflowMru: round2(cur.receiptsMru - cur.disbursementsMru),
        pendingClientChequesMru,
        pendingSupplierChequesMru,
      },
      accounts,
      monthly,
      byPaymentMethod,
      upcomingCheques,
    }) || true;
  }

  if (method === 'GET' && p === '/api/commercial/analytics/objectives') {
    const rawYear = url.searchParams.get('year');
    const year = rawYear ? Number(rawYear) : new Date().getUTCFullYear();
    if (!Number.isInteger(year) || year < 2000 || year > 2100) {
      throw createHttpError(400, 'Année invalide (2000-2100)');
    }
    const payload = buildObjectivesPayload(database, tenantId, year);
    return sendJson(res, 200, payload) || true;
  }

  // --------------------------------------------------------------------------
  // 3. CLIENTS
  // --------------------------------------------------------------------------
  if (method === 'GET' && p === '/api/commercial/clients') {
    const q = String(url.searchParams.get('q') || '').trim().toLowerCase();
    const typeFilter = String(url.searchParams.get('type') || 'all').trim().toLowerCase();
    const includeInactive = url.searchParams.get('includeInactive') === '1';

    let sql = 'SELECT * FROM commercial_clients WHERE tenant_id = ?';
    const params = [tenantId];
    if (!includeInactive) sql += ' AND active = 1';
    if (typeFilter === 'b2b') sql += ' AND is_b2b = 1';
    if (typeFilter === 'karni') sql += ' AND (credit_limit_mru > 0 OR current_debt_mru > 0)';
    if (q) {
      sql += ' AND (LOWER(name) LIKE ? OR LOWER(code) LIKE ? OR LOWER(phone) LIKE ? OR LOWER(nif) LIKE ?)';
      const pat = `%${q}%`;
      params.push(pat, pat, pat, pat);
    }
    sql += ' ORDER BY name ASC, id ASC';

    const rows = database.prepare(sql).all(...params);
    const encRows = database
      .prepare(`
        SELECT client_id, COALESCE(SUM(MAX(0, total_ttc_mru - paid_mru - credited_mru)), 0) AS inv_encours
        FROM commercial_sales_docs
        WHERE tenant_id = ? AND doc_type = 'FACTURE' AND status IN ('VALIDEE', 'PARTIELLE')
        GROUP BY client_id
      `)
      .all(tenantId);
    const encMap = new Map(encRows.map((r) => [r.client_id, Number(r.inv_encours)]));

    return sendJson(res, 200, {
      ok: true,
      clients: rows.map((r) => serializeClient(r, encMap.get(r.id) || 0)),
    }) || true;
  }

  if (method === 'POST' && p === '/api/commercial/clients') {
    const b = await readJsonBody(req, standardLimit);
    const name = String(pick(b, 'name') ?? '').trim();
    if (!name) throw createHttpError(400, 'Le nom du client est requis');

    const creditLimitMru = Number(pick(b, 'creditLimitMru', 'credit_limit_mru') ?? 0);
    if (!Number.isFinite(creditLimitMru) || creditLimitMru < 0) {
      throw createHttpError(400, 'Plafond crédit invalide');
    }
    const paymentTermsDays = Number(pick(b, 'paymentTermsDays', 'payment_terms_days') ?? 0);
    if (!Number.isFinite(paymentTermsDays) || paymentTermsDays < 0) {
      throw createHttpError(400, 'Délai de paiement invalide');
    }

    const rawCode = String(pick(b, 'code') ?? '').trim();
    const code = rawCode || nextSequenceCode(database, 'commercial_clients', 'code', tenantId, 'CLI');
    const isB2b = Boolean(pick(b, 'isB2b', 'is_b2b')) ? 1 : 0;

    const info = database
      .prepare(`
        INSERT INTO commercial_clients (
          tenant_id, code, name, is_b2b, nif, rc, phone, email, address, city,
          payment_terms_days, credit_limit_mru, current_debt_mru, notes, active
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, 1)
      `)
      .run(
        tenantId,
        code,
        name,
        isB2b,
        String(pick(b, 'nif') ?? '').trim(),
        String(pick(b, 'rc') ?? '').trim(),
        String(pick(b, 'phone') ?? '').trim(),
        String(pick(b, 'email') ?? '').trim(),
        String(pick(b, 'address') ?? '').trim(),
        String(pick(b, 'city') ?? '').trim(),
        Math.round(paymentTermsDays),
        round2(creditLimitMru),
        String(pick(b, 'notes') ?? '').trim(),
      );

    const created = database.prepare('SELECT * FROM commercial_clients WHERE id = ?').get(Number(info.lastInsertRowid));
    return sendJson(res, 201, { ok: true, client: serializeClient(created, 0) }) || true;
  }

  if (method === 'PATCH' && (m = p.match(/^\/api\/commercial\/clients\/(\d+)$/))) {
    const id = Number(m[1]);
    const cur = database.prepare('SELECT * FROM commercial_clients WHERE id = ? AND tenant_id = ?').get(id, tenantId);
    if (!cur) throw createHttpError(404, 'Client introuvable');

    const b = await readJsonBody(req, standardLimit);
    const name = pick(b, 'name') !== undefined ? String(pick(b, 'name')).trim() : cur.name;
    if (!name) throw createHttpError(400, 'Le nom du client ne peut pas être vide');

    const creditLimit =
      pick(b, 'creditLimitMru', 'credit_limit_mru') !== undefined
        ? Number(pick(b, 'creditLimitMru', 'credit_limit_mru'))
        : cur.credit_limit_mru;
    if (!Number.isFinite(creditLimit) || creditLimit < 0) {
      throw createHttpError(400, 'Plafond crédit invalide');
    }

    const terms =
      pick(b, 'paymentTermsDays', 'payment_terms_days') !== undefined
        ? Number(pick(b, 'paymentTermsDays', 'payment_terms_days'))
        : cur.payment_terms_days;
    if (!Number.isFinite(terms) || terms < 0) {
      throw createHttpError(400, 'Délai de paiement invalide');
    }

    const isB2b =
      pick(b, 'isB2b', 'is_b2b') !== undefined ? (Boolean(pick(b, 'isB2b', 'is_b2b')) ? 1 : 0) : cur.is_b2b;
    const active = pick(b, 'active') !== undefined ? (Boolean(pick(b, 'active')) ? 1 : 0) : cur.active;

    database
      .prepare(`
        UPDATE commercial_clients SET
          code = ?, name = ?, is_b2b = ?, nif = ?, rc = ?, phone = ?, email = ?,
          address = ?, city = ?, payment_terms_days = ?, credit_limit_mru = ?,
          notes = ?, active = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ? AND tenant_id = ?
      `)
      .run(
        pick(b, 'code') !== undefined ? String(pick(b, 'code')).trim() : cur.code,
        name,
        isB2b,
        pick(b, 'nif') !== undefined ? String(pick(b, 'nif')).trim() : cur.nif,
        pick(b, 'rc') !== undefined ? String(pick(b, 'rc')).trim() : cur.rc,
        pick(b, 'phone') !== undefined ? String(pick(b, 'phone')).trim() : cur.phone,
        pick(b, 'email') !== undefined ? String(pick(b, 'email')).trim() : cur.email,
        pick(b, 'address') !== undefined ? String(pick(b, 'address')).trim() : cur.address,
        pick(b, 'city') !== undefined ? String(pick(b, 'city')).trim() : cur.city,
        Math.round(terms),
        round2(creditLimit),
        pick(b, 'notes') !== undefined ? String(pick(b, 'notes')).trim() : cur.notes,
        active,
        id,
        tenantId,
      );

    const updated = database.prepare('SELECT * FROM commercial_clients WHERE id = ?').get(id);
    const invEnc = database
      .prepare("SELECT COALESCE(SUM(MAX(0, total_ttc_mru - paid_mru - credited_mru)), 0) AS s FROM commercial_sales_docs WHERE tenant_id = ? AND client_id = ? AND doc_type = 'FACTURE' AND status IN ('VALIDEE','PARTIELLE')")
      .get(tenantId, id).s;
    return sendJson(res, 200, { ok: true, client: serializeClient(updated, invEnc) }) || true;
  }

  if (method === 'DELETE' && (m = p.match(/^\/api\/commercial\/clients\/(\d+)$/))) {
    const id = Number(m[1]);
    const cur = database.prepare('SELECT * FROM commercial_clients WHERE id = ? AND tenant_id = ?').get(id, tenantId);
    if (!cur) throw createHttpError(404, 'Client introuvable');

    const refDocs = database.prepare('SELECT COUNT(*) AS cnt FROM commercial_sales_docs WHERE tenant_id = ? AND client_id = ?').get(tenantId, id).cnt;
    const refTkt = database.prepare('SELECT COUNT(*) AS cnt FROM commercial_pos_tickets WHERE tenant_id = ? AND client_id = ?').get(tenantId, id).cnt;
    const refChq = database.prepare('SELECT COUNT(*) AS cnt FROM commercial_cheques_drafts WHERE tenant_id = ? AND client_id = ?').get(tenantId, id).cnt;

    if (refDocs > 0 || refTkt > 0 || refChq > 0 || Number(cur.current_debt_mru) > 0.01) {
      database
        .prepare('UPDATE commercial_clients SET active = 0, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND tenant_id = ?')
        .run(id, tenantId);
      const updated = database.prepare('SELECT * FROM commercial_clients WHERE id = ?').get(id);
      const invEnc = getClientInvoiceEncours(database, tenantId, id);
      return sendJson(res, 200, { ok: true, archived: true, client: serializeClient(updated, invEnc) }) || true;
    }

    database.prepare('DELETE FROM commercial_clients WHERE id = ? AND tenant_id = ?').run(id, tenantId);
    return sendJson(res, 200, { ok: true, deleted: true, id }) || true;
  }

  if (method === 'POST' && (m = p.match(/^\/api\/commercial\/clients\/(\d+)\/karni-pay$/))) {
    const id = Number(m[1]);
    const b = await readJsonBody(req, standardLimit);
    const rawAmount = pick(b, 'amountMru', 'amount_mru', 'amount');
    const amountNum = Number(rawAmount);
    if (rawAmount === undefined || rawAmount === null || rawAmount === '' || typeof rawAmount === 'boolean' || !Number.isFinite(amountNum)) {
      throw createHttpError(400, 'Montant de règlement Karni invalide');
    }
    const amountMru = round2(amountNum);
    if (amountMru <= 0) {
      throw createHttpError(400, 'Montant de règlement Karni invalide');
    }
    const payMethod = normalizeCommercialPayMethod(pick(b, 'payMethod', 'pay_method') ?? 'Cash', createHttpError);
    if (payMethod === 'Karni') {
      throw createHttpError(400, 'Impossible de régler un solde Karni par Karni');
    }
    const paymentDate = String(pick(b, 'paymentDate', 'payment_date') ?? todayIso()).trim();
    if (!isValidIsoDate(paymentDate)) throw createHttpError(400, 'Date de paiement invalide');
    const ref = String(pick(b, 'ref', 'reference') ?? '').trim();
    const notes = String(pick(b, 'notes') ?? '').trim();
    const reqAccountId = pick(b, 'treasuryAccountId', 'treasury_account_id');

    const result = withTransaction(database, () => {
      const client = database.prepare('SELECT * FROM commercial_clients WHERE id = ? AND tenant_id = ?').get(id, tenantId);
      if (!client) throw createHttpError(404, 'Client introuvable');
      if (amountMru > Number(client.current_debt_mru) + 0.01) {
        throw createHttpError(400, 'Le montant dépasse la dette Karni actuelle du client');
      }

      const acc = reqAccountId
        ? database.prepare('SELECT * FROM commercial_treasury_accounts WHERE id = ? AND tenant_id = ?').get(Number(reqAccountId), tenantId)
        : resolveDefaultTreasuryAccount(database, tenantId, payMethod);
      if (!acc) throw createHttpError(404, 'Compte de trésorerie introuvable');

      const newDebt = round2(Math.max(0, Number(client.current_debt_mru) - amountMru));
      database
        .prepare('UPDATE commercial_clients SET current_debt_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND tenant_id = ?')
        .run(newDebt, id, tenantId);

      const newBal = round2(Number(acc.current_balance_mru) + amountMru);
      database
        .prepare('UPDATE commercial_treasury_accounts SET current_balance_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND tenant_id = ?')
        .run(newBal, acc.id, tenantId);

      const payNum = nextDocNumber(database, 'commercial_payments', 'payment_number', tenantId, 'PAY', paymentDate);
      const pInfo = database
        .prepare(`
          INSERT INTO commercial_payments (
            tenant_id, payment_number, direction, client_id, treasury_account_id,
            payment_date, pay_method, amount_mru, ref, status, notes
          ) VALUES (?, ?, 'IN', ?, ?, ?, ?, ?, ?, 'POSTED', ?)
        `)
        .run(tenantId, payNum, id, acc.id, paymentDate, payMethod, amountMru, ref, notes || 'Règlement Karni');

      database
        .prepare(`
          INSERT INTO commercial_treasury_movements (
            tenant_id, account_id, movement_date, direction, amount_mru, balance_after_mru,
            pay_method, category, label, ref, source_type, source_id
          ) VALUES (?, ?, ?, 'IN', ?, ?, ?, 'REGLEMENT_KARNI', ?, ?, 'KARNI_PAY', ?)
        `)
        .run(
          tenantId,
          acc.id,
          paymentDate,
          amountMru,
          newBal,
          payMethod,
          `Règlement Karni · ${client.name}`,
          ref || payNum,
          Number(pInfo.lastInsertRowid),
        );

      const updatedClient = database.prepare('SELECT * FROM commercial_clients WHERE id = ?').get(id);
      const payment = database.prepare('SELECT * FROM commercial_payments WHERE id = ?').get(Number(pInfo.lastInsertRowid));
      const invEnc = getClientInvoiceEncours(database, tenantId, id);
      return {
        client: serializeClient(updatedClient, invEnc),
        payment: serializePayment(payment),
      };
    });

    return sendJson(res, 200, { ok: true, ...result }) || true;
  }

  // --------------------------------------------------------------------------
  // 4. SUPPLIERS (FOURNISSEURS)
  // --------------------------------------------------------------------------
  if (method === 'GET' && p === '/api/commercial/suppliers') {
    const q = String(url.searchParams.get('q') || '').trim().toLowerCase();
    const includeInactive = url.searchParams.get('includeInactive') === '1';

    let sql = 'SELECT * FROM commercial_suppliers WHERE tenant_id = ?';
    const params = [tenantId];
    if (!includeInactive) sql += ' AND active = 1';
    if (q) {
      sql += ' AND (LOWER(name) LIKE ? OR LOWER(code) LIKE ? OR LOWER(phone) LIKE ? OR LOWER(nif) LIKE ?)';
      const pat = `%${q}%`;
      params.push(pat, pat, pat, pat);
    }
    sql += ' ORDER BY name ASC, id ASC';

    const rows = database.prepare(sql).all(...params);
    const debtRows = database
      .prepare(`
        SELECT supplier_id, COALESCE(SUM(MAX(0, total_ttc_mru - paid_mru - credited_mru)), 0) AS bal
        FROM commercial_purchase_docs
        WHERE tenant_id = ? AND doc_type = 'FACTURE_FOURNISSEUR' AND status IN ('VALIDEE', 'PARTIELLE')
        GROUP BY supplier_id
      `)
      .all(tenantId);
    const debtMap = new Map(debtRows.map((r) => [r.supplier_id, Number(r.bal)]));

    return sendJson(res, 200, {
      ok: true,
      suppliers: rows.map((r) => serializeSupplier(r, debtMap.get(r.id) || 0)),
    }) || true;
  }

  if (method === 'POST' && p === '/api/commercial/suppliers') {
    const b = await readJsonBody(req, standardLimit);
    const name = String(pick(b, 'name') ?? '').trim();
    if (!name) throw createHttpError(400, 'Le nom du fournisseur est requis');

    const paymentTermsDays = Number(pick(b, 'paymentTermsDays', 'payment_terms_days') ?? 30);
    if (!Number.isFinite(paymentTermsDays) || paymentTermsDays < 0) {
      throw createHttpError(400, 'Délai de paiement invalide');
    }

    const rawCode = String(pick(b, 'code') ?? '').trim();
    const code = rawCode || nextSequenceCode(database, 'commercial_suppliers', 'code', tenantId, 'FRN');

    const info = database
      .prepare(`
        INSERT INTO commercial_suppliers (
          tenant_id, code, name, nif, rc, contact_name, phone, email, address, city,
          payment_terms_days, balance_due_mru, notes, active
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, 1)
      `)
      .run(
        tenantId,
        code,
        name,
        String(pick(b, 'nif') ?? '').trim(),
        String(pick(b, 'rc') ?? '').trim(),
        String(pick(b, 'contactName', 'contact_name') ?? '').trim(),
        String(pick(b, 'phone') ?? '').trim(),
        String(pick(b, 'email') ?? '').trim(),
        String(pick(b, 'address') ?? '').trim(),
        String(pick(b, 'city') ?? '').trim(),
        Math.round(paymentTermsDays),
        String(pick(b, 'notes') ?? '').trim(),
      );

    const created = database.prepare('SELECT * FROM commercial_suppliers WHERE id = ?').get(Number(info.lastInsertRowid));
    return sendJson(res, 201, { ok: true, supplier: serializeSupplier(created, 0) }) || true;
  }

  if (method === 'PATCH' && (m = p.match(/^\/api\/commercial\/suppliers\/(\d+)$/))) {
    const id = Number(m[1]);
    const cur = database.prepare('SELECT * FROM commercial_suppliers WHERE id = ? AND tenant_id = ?').get(id, tenantId);
    if (!cur) throw createHttpError(404, 'Fournisseur introuvable');

    const b = await readJsonBody(req, standardLimit);
    const name = pick(b, 'name') !== undefined ? String(pick(b, 'name')).trim() : cur.name;
    if (!name) throw createHttpError(400, 'Le nom du fournisseur ne peut pas être vide');

    const terms =
      pick(b, 'paymentTermsDays', 'payment_terms_days') !== undefined
        ? Number(pick(b, 'paymentTermsDays', 'payment_terms_days'))
        : cur.payment_terms_days;
    if (!Number.isFinite(terms) || terms < 0) {
      throw createHttpError(400, 'Délai de paiement invalide');
    }
    const active = pick(b, 'active') !== undefined ? (Boolean(pick(b, 'active')) ? 1 : 0) : cur.active;

    database
      .prepare(`
        UPDATE commercial_suppliers SET
          code = ?, name = ?, nif = ?, rc = ?, contact_name = ?, phone = ?, email = ?,
          address = ?, city = ?, payment_terms_days = ?, notes = ?, active = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ? AND tenant_id = ?
      `)
      .run(
        pick(b, 'code') !== undefined ? String(pick(b, 'code')).trim() : cur.code,
        name,
        pick(b, 'nif') !== undefined ? String(pick(b, 'nif')).trim() : cur.nif,
        pick(b, 'rc') !== undefined ? String(pick(b, 'rc')).trim() : cur.rc,
        pick(b, 'contactName', 'contact_name') !== undefined
          ? String(pick(b, 'contactName', 'contact_name')).trim()
          : cur.contact_name,
        pick(b, 'phone') !== undefined ? String(pick(b, 'phone')).trim() : cur.phone,
        pick(b, 'email') !== undefined ? String(pick(b, 'email')).trim() : cur.email,
        pick(b, 'address') !== undefined ? String(pick(b, 'address')).trim() : cur.address,
        pick(b, 'city') !== undefined ? String(pick(b, 'city')).trim() : cur.city,
        Math.round(terms),
        pick(b, 'notes') !== undefined ? String(pick(b, 'notes')).trim() : cur.notes,
        active,
        id,
        tenantId,
      );

    const updated = database.prepare('SELECT * FROM commercial_suppliers WHERE id = ?').get(id);
    const bal = database
      .prepare("SELECT COALESCE(SUM(MAX(0, total_ttc_mru - paid_mru - credited_mru)), 0) AS s FROM commercial_purchase_docs WHERE tenant_id = ? AND supplier_id = ? AND doc_type = 'FACTURE_FOURNISSEUR' AND status IN ('VALIDEE','PARTIELLE')")
      .get(tenantId, id).s;
    return sendJson(res, 200, { ok: true, supplier: serializeSupplier(updated, bal) }) || true;
  }

  if (method === 'DELETE' && (m = p.match(/^\/api\/commercial\/suppliers\/(\d+)$/))) {
    const id = Number(m[1]);
    const cur = database.prepare('SELECT * FROM commercial_suppliers WHERE id = ? AND tenant_id = ?').get(id, tenantId);
    if (!cur) throw createHttpError(404, 'Fournisseur introuvable');

    const refDocs = database.prepare('SELECT COUNT(*) AS cnt FROM commercial_purchase_docs WHERE tenant_id = ? AND supplier_id = ?').get(tenantId, id).cnt;
    const refChq = database.prepare('SELECT COUNT(*) AS cnt FROM commercial_cheques_drafts WHERE tenant_id = ? AND supplier_id = ?').get(tenantId, id).cnt;

    if (refDocs > 0 || refChq > 0 || Number(cur.balance_due_mru) > 0.01) {
      database
        .prepare('UPDATE commercial_suppliers SET active = 0, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND tenant_id = ?')
        .run(id, tenantId);
      const updated = database.prepare('SELECT * FROM commercial_suppliers WHERE id = ?').get(id);
      return sendJson(res, 200, { ok: true, archived: true, supplier: serializeSupplier(updated) }) || true;
    }

    database.prepare('DELETE FROM commercial_suppliers WHERE id = ? AND tenant_id = ?').run(id, tenantId);
    return sendJson(res, 200, { ok: true, deleted: true, id }) || true;
  }

  // --------------------------------------------------------------------------
  // 5. ARTICLES & STOCK MOVEMENTS
  // --------------------------------------------------------------------------
  if (method === 'GET' && p === '/api/commercial/articles') {
    const q = String(url.searchParams.get('q') || '').trim().toLowerCase();
    const category = String(url.searchParams.get('category') || '').trim();
    const lowStock = url.searchParams.get('lowStock') === '1';
    const includeInactive = url.searchParams.get('includeInactive') === '1';

    let sql = 'SELECT * FROM commercial_articles WHERE tenant_id = ?';
    const params = [tenantId];
    if (!includeInactive) sql += ' AND active = 1';
    if (category) {
      sql += ' AND category = ?';
      params.push(category);
    }
    if (lowStock) {
      sql += ' AND track_stock = 1 AND stock_qty <= min_stock';
    }
    if (q) {
      sql += ' AND (LOWER(name) LIKE ? OR LOWER(sku) LIKE ? OR LOWER(barcode) LIKE ? OR LOWER(category) LIKE ?)';
      const pat = `%${q}%`;
      params.push(pat, pat, pat, pat);
    }
    sql += ' ORDER BY name ASC, id ASC';

    const rows = database.prepare(sql).all(...params);
    return sendJson(res, 200, { ok: true, articles: rows.map(serializeArticle) }) || true;
  }

  if (method === 'POST' && p === '/api/commercial/articles') {
    const b = await readJsonBody(req, standardLimit);
    const name = String(pick(b, 'name') ?? '').trim();
    if (!name) throw createHttpError(400, "Le nom de l'article est requis");

    const { isExempt, tvaRate } = resolveLineTva(
      pick(b, 'isExempt', 'is_exempt'),
      pick(b, 'tvaRate', 'tva_rate'),
      null,
      createHttpError,
    );

    const rawRetailHt = pick(b, 'priceRetailHt', 'price_retail_ht');
    const rawRetailTtc = pick(b, 'priceRetailTtc', 'price_retail_ttc');
    let priceRetailHt = 0;
    if (rawRetailHt !== undefined) {
      priceRetailHt = Number(rawRetailHt);
    } else if (rawRetailTtc !== undefined) {
      const retailTtcNum = Number(rawRetailTtc);
      if (!Number.isFinite(retailTtcNum)) throw createHttpError(400, 'Prix détail TTC invalide');
      priceRetailHt = isExempt ? round2(retailTtcNum) : round2(retailTtcNum / (1 + tvaRate / 100));
    }

    const rawWholeHt = pick(b, 'priceWholeHt', 'price_whole_ht');
    const rawWholeTtc = pick(b, 'priceWholeTtc', 'price_whole_ttc');
    let priceWholeHt = priceRetailHt;
    if (rawWholeHt !== undefined) {
      priceWholeHt = Number(rawWholeHt);
    } else if (rawWholeTtc !== undefined) {
      const wholeTtcNum = Number(rawWholeTtc);
      if (!Number.isFinite(wholeTtcNum)) throw createHttpError(400, 'Prix gros TTC invalide');
      priceWholeHt = isExempt ? round2(wholeTtcNum) : round2(wholeTtcNum / (1 + tvaRate / 100));
    }

    const priceCostMru = Number(pick(b, 'priceCostMru', 'price_cost_mru') ?? 0);
    const rawPmp = pick(b, 'pmpCostMru', 'pmp_cost_mru');
    const pmpCostMru = rawPmp !== undefined ? Number(rawPmp) : priceCostMru;
    const stockQty = Number(pick(b, 'stockQty', 'stock_qty') ?? 0);
    const minStock = Number(pick(b, 'minStock', 'min_stock') ?? 0);

    for (const [label, val] of [
      ['Prix détail HT', priceRetailHt],
      ['Prix gros HT', priceWholeHt],
      ["Coût d'achat", priceCostMru],
      ['PMP', pmpCostMru],
      ['Stock initial', stockQty],
      ['Stock minimum', minStock],
    ]) {
      if (!Number.isFinite(val) || val < 0) {
        throw createHttpError(400, `${label} invalide`);
      }
    }

    const trackStock = pick(b, 'trackStock', 'track_stock') !== undefined ? (Boolean(pick(b, 'trackStock', 'track_stock')) ? 1 : 0) : 1;
    const sku = String(pick(b, 'sku') ?? '').trim();
    const barcode = String(pick(b, 'barcode') ?? '').trim();

    const created = withTransaction(database, () => {
      const info = database
        .prepare(`
          INSERT INTO commercial_articles (
            tenant_id, sku, barcode, name, name_ar, category, unit,
            price_retail_ht, price_whole_ht, price_cost_mru, pmp_cost_mru,
            stock_qty, min_stock, tva_rate, is_exempt, track_stock, active
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
        `)
        .run(
          tenantId,
          sku,
          barcode,
          name,
          String(pick(b, 'nameAr', 'name_ar') ?? '').trim(),
          String(pick(b, 'category') ?? 'Général').trim() || 'Général',
          String(pick(b, 'unit') ?? 'unité').trim() || 'unité',
          round2(priceRetailHt),
          round2(priceWholeHt),
          round2(priceCostMru),
          round2(pmpCostMru),
          round3(stockQty),
          round3(minStock),
          tvaRate,
          isExempt ? 1 : 0,
          trackStock,
        );

      const aid = Number(info.lastInsertRowid);
      if (trackStock && stockQty > 0) {
        database
          .prepare(`
            INSERT INTO commercial_stock_movements (
              tenant_id, article_id, movement_type, qty_delta, unit_cost_mru,
              pmp_before_mru, pmp_after_mru, stock_before, stock_after,
              source_type, source_id, source_number, reason
            ) VALUES (?, ?, 'IN_INITIAL', ?, ?, 0, ?, 0, ?, 'ARTICLE_INIT', ?, ?, 'Stock initial')
          `)
          .run(
            tenantId,
            aid,
            round3(stockQty),
            round2(pmpCostMru),
            round2(pmpCostMru),
            round3(stockQty),
            aid,
            sku || `ART-${aid}`,
          );
      }

      return database.prepare('SELECT * FROM commercial_articles WHERE id = ?').get(aid);
    });

    return sendJson(res, 201, { ok: true, article: serializeArticle(created) }) || true;
  }

  if (method === 'PATCH' && (m = p.match(/^\/api\/commercial\/articles\/(\d+)$/))) {
    const id = Number(m[1]);
    const cur = database.prepare('SELECT * FROM commercial_articles WHERE id = ? AND tenant_id = ?').get(id, tenantId);
    if (!cur) throw createHttpError(404, 'Article introuvable');

    const b = await readJsonBody(req, standardLimit);
    const name = pick(b, 'name') !== undefined ? String(pick(b, 'name')).trim() : cur.name;
    if (!name) throw createHttpError(400, "Le nom de l'article ne peut pas être vide");

    const { isExempt, tvaRate } = resolveLineTva(
      pick(b, 'isExempt', 'is_exempt'),
      pick(b, 'tvaRate', 'tva_rate'),
      cur,
      createHttpError,
    );

    const priceRetailHt =
      pick(b, 'priceRetailHt', 'price_retail_ht') !== undefined
        ? Number(pick(b, 'priceRetailHt', 'price_retail_ht'))
        : cur.price_retail_ht;
    const priceWholeHt =
      pick(b, 'priceWholeHt', 'price_whole_ht') !== undefined
        ? Number(pick(b, 'priceWholeHt', 'price_whole_ht'))
        : cur.price_whole_ht;
    const priceCostMru =
      pick(b, 'priceCostMru', 'price_cost_mru') !== undefined
        ? Number(pick(b, 'priceCostMru', 'price_cost_mru'))
        : cur.price_cost_mru;
    const minStock =
      pick(b, 'minStock', 'min_stock') !== undefined
        ? Number(pick(b, 'minStock', 'min_stock'))
        : cur.min_stock;

    for (const val of [priceRetailHt, priceWholeHt, priceCostMru, minStock]) {
      if (!Number.isFinite(val) || val < 0) {
        throw createHttpError(400, 'Valeur numérique invalide');
      }
    }

    const trackStock =
      pick(b, 'trackStock', 'track_stock') !== undefined
        ? Boolean(pick(b, 'trackStock', 'track_stock'))
          ? 1
          : 0
        : cur.track_stock;
    const active = pick(b, 'active') !== undefined ? (Boolean(pick(b, 'active')) ? 1 : 0) : cur.active;

    database
      .prepare(`
        UPDATE commercial_articles SET
          sku = ?, barcode = ?, name = ?, name_ar = ?, category = ?, unit = ?,
          price_retail_ht = ?, price_whole_ht = ?, price_cost_mru = ?,
          min_stock = ?, tva_rate = ?, is_exempt = ?, track_stock = ?, active = ?,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = ? AND tenant_id = ?
      `)
      .run(
        pick(b, 'sku') !== undefined ? String(pick(b, 'sku')).trim() : cur.sku,
        pick(b, 'barcode') !== undefined ? String(pick(b, 'barcode')).trim() : cur.barcode,
        name,
        pick(b, 'nameAr', 'name_ar') !== undefined ? String(pick(b, 'nameAr', 'name_ar')).trim() : cur.name_ar,
        pick(b, 'category') !== undefined ? String(pick(b, 'category')).trim() || 'Général' : cur.category,
        pick(b, 'unit') !== undefined ? String(pick(b, 'unit')).trim() || 'unité' : cur.unit,
        round2(priceRetailHt),
        round2(priceWholeHt),
        round2(priceCostMru),
        round3(minStock),
        tvaRate,
        isExempt ? 1 : 0,
        trackStock,
        active,
        id,
        tenantId,
      );

    const updated = database.prepare('SELECT * FROM commercial_articles WHERE id = ?').get(id);
    return sendJson(res, 200, { ok: true, article: serializeArticle(updated) }) || true;
  }

  if (method === 'DELETE' && (m = p.match(/^\/api\/commercial\/articles\/(\d+)$/))) {
    const id = Number(m[1]);
    const cur = database.prepare('SELECT * FROM commercial_articles WHERE id = ? AND tenant_id = ?').get(id, tenantId);
    if (!cur) throw createHttpError(404, 'Article introuvable');

    database
      .prepare('UPDATE commercial_articles SET active = 0, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND tenant_id = ?')
      .run(id, tenantId);
    const updated = database.prepare('SELECT * FROM commercial_articles WHERE id = ?').get(id);
    return sendJson(res, 200, { ok: true, article: serializeArticle(updated) }) || true;
  }

  if (method === 'POST' && (m = p.match(/^\/api\/commercial\/articles\/(\d+)\/adjust-stock$/))) {
    const id = Number(m[1]);
    const b = await readJsonBody(req, standardLimit);
    const rawDelta = pick(b, 'deltaQty', 'delta_qty', 'delta');
    const rawNewStock = pick(b, 'newStock', 'new_stock', 'stockQty', 'stock_qty');
    const rawUnitCost = pick(b, 'unitCostHt', 'unit_cost_ht', 'unitCostMru', 'unit_cost_mru');
    const reason = String(pick(b, 'reason', 'notes') ?? '').trim();

    if (rawDelta === undefined && rawNewStock === undefined) {
      throw createHttpError(400, 'deltaQty ou newStock est requis');
    }

    const result = withTransaction(database, () => {
      const art = database.prepare('SELECT * FROM commercial_articles WHERE id = ? AND tenant_id = ?').get(id, tenantId);
      if (!art) throw createHttpError(404, 'Article introuvable');

      const stockBefore = round3(art.stock_qty);
      let rawDeltaNum;
      if (rawDelta !== undefined) {
        if (rawDelta === null || rawDelta === '' || typeof rawDelta === 'boolean' || !Number.isFinite(Number(rawDelta))) {
          throw createHttpError(400, 'deltaQty invalide');
        }
        rawDeltaNum = Number(rawDelta);
      } else {
        if (rawNewStock === null || rawNewStock === '' || typeof rawNewStock === 'boolean' || !Number.isFinite(Number(rawNewStock))) {
          throw createHttpError(400, 'newStock invalide');
        }
        rawDeltaNum = Number(rawNewStock) - stockBefore;
      }
      const delta = round3(rawDeltaNum);
      if (!Number.isFinite(delta) || delta === 0) {
        throw createHttpError(400, "La variation de stock doit être non nulle");
      }
      const stockAfter = round3(stockBefore + delta);
      if (stockAfter < 0) {
        throw createHttpError(400, 'Le stock ne peut pas devenir négatif');
      }

      const pmpBefore = round2(art.pmp_cost_mru);
      let pmpAfter = pmpBefore;
      let priceCostAfter = round2(art.price_cost_mru);
      let unitCost = pmpBefore;

      if (delta > 0 && rawUnitCost !== undefined && rawUnitCost !== '') {
        const c = Number(rawUnitCost);
        if (!Number.isFinite(c) || c < 0) {
          throw createHttpError(400, 'Coût unitaire invalide');
        }
        unitCost = round2(c);
        const s0 = Math.max(0, stockBefore);
        pmpAfter = s0 + delta > 0 ? round2((s0 * pmpBefore + delta * unitCost) / (s0 + delta)) : unitCost;
        priceCostAfter = unitCost;
      }

      database
        .prepare(`
          UPDATE commercial_articles SET
            stock_qty = ?, pmp_cost_mru = ?, price_cost_mru = ?, updated_at = CURRENT_TIMESTAMP
          WHERE id = ? AND tenant_id = ?
        `)
        .run(stockAfter, pmpAfter, priceCostAfter, id, tenantId);

      const mvtType = delta > 0 ? 'ADJUSTMENT_IN' : 'ADJUSTMENT_OUT';
      const mInfo = database
        .prepare(`
          INSERT INTO commercial_stock_movements (
            tenant_id, article_id, movement_type, qty_delta, unit_cost_mru,
            pmp_before_mru, pmp_after_mru, stock_before, stock_after,
            source_type, source_id, source_number, reason
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'MANUAL_ADJUSTMENT', ?, ?, ?)
        `)
        .run(
          tenantId,
          id,
          mvtType,
          delta,
          unitCost,
          pmpBefore,
          pmpAfter,
          stockBefore,
          stockAfter,
          id,
          art.sku || `ART-${id}`,
          reason || 'Ajustement manuel',
        );

      insertAudit(
        database,
        tenantId,
        actor,
        'COMM_STOCK_ADJUST',
        `Ajustement stock · ${art.name}`,
        `${delta > 0 ? '+' : ''}${delta} ${art.unit} (PMP ${pmpAfter} MRU)`,
        'commercial_article',
        id,
        { stockQty: stockBefore, pmpCostMru: pmpBefore },
        { stockQty: stockAfter, pmpCostMru: pmpAfter, reason },
        nowHM,
      );

      const updatedArt = database.prepare('SELECT * FROM commercial_articles WHERE id = ?').get(id);
      const movement = database
        .prepare(`
          SELECT m.*, a.name AS article_name, a.sku AS article_sku, a.unit AS article_unit
          FROM commercial_stock_movements m
          JOIN commercial_articles a ON a.id = m.article_id
          WHERE m.id = ?
        `)
        .get(Number(mInfo.lastInsertRowid));

      return {
        article: serializeArticle(updatedArt),
        movement: serializeStockMovement(movement),
      };
    });

    return sendJson(res, 200, { ok: true, ...result }) || true;
  }

  if (method === 'GET' && p === '/api/commercial/stock-movements') {
    const articleId = url.searchParams.get('articleId');
    const mvtType = String(url.searchParams.get('type') || '').trim();
    const from = String(url.searchParams.get('from') || '').trim();
    const to = String(url.searchParams.get('to') || '').trim();
    if (from && !isValidIsoDate(from)) throw createHttpError(400, 'Date from invalide');
    if (to && !isValidIsoDate(to)) throw createHttpError(400, 'Date to invalide');

    let sql = `
      SELECT m.*, a.name AS article_name, a.sku AS article_sku, a.unit AS article_unit
      FROM commercial_stock_movements m
      LEFT JOIN commercial_articles a ON a.id = m.article_id
      WHERE m.tenant_id = ?
    `;
    const params = [tenantId];
    if (articleId) {
      sql += ' AND m.article_id = ?';
      params.push(Number(articleId));
    }
    if (mvtType) {
      sql += ' AND m.movement_type = ?';
      params.push(mvtType);
    }
    if (from) {
      sql += ' AND substr(m.created_at, 1, 10) >= ?';
      params.push(from);
    }
    if (to) {
      sql += ' AND substr(m.created_at, 1, 10) <= ?';
      params.push(to);
    }
    sql += ' ORDER BY m.created_at DESC, m.id DESC LIMIT 300';

    const rows = database.prepare(sql).all(...params);
    return sendJson(res, 200, { ok: true, movements: rows.map(serializeStockMovement) }) || true;
  }

  // --------------------------------------------------------------------------
  // 6. SALES CYCLE (DEVIS, COMMANDE, BL, FACTURE, AVOIR)
  // --------------------------------------------------------------------------
  if (method === 'GET' && p === '/api/commercial/sales-docs') {
    const docType = String(url.searchParams.get('docType') || '').trim().toUpperCase();
    const status = String(url.searchParams.get('status') || '').trim().toUpperCase();
    const clientId = url.searchParams.get('clientId');
    const q = String(url.searchParams.get('q') || '').trim().toLowerCase();
    const from = String(url.searchParams.get('from') || '').trim();
    const to = String(url.searchParams.get('to') || '').trim();
    if (from && !isValidIsoDate(from)) throw createHttpError(400, 'Date from invalide');
    if (to && !isValidIsoDate(to)) throw createHttpError(400, 'Date to invalide');

    let sql = 'SELECT * FROM commercial_sales_docs WHERE tenant_id = ?';
    const params = [tenantId];
    if (docType) {
      sql += ' AND doc_type = ?';
      params.push(docType);
    }
    if (status) {
      sql += ' AND status = ?';
      params.push(status);
    }
    if (clientId) {
      sql += ' AND client_id = ?';
      params.push(Number(clientId));
    }
    if (from) {
      sql += ' AND issue_date >= ?';
      params.push(from);
    }
    if (to) {
      sql += ' AND issue_date <= ?';
      params.push(to);
    }
    if (q) {
      sql += ' AND (LOWER(doc_number) LIKE ? OR LOWER(client_name) LIKE ?)';
      params.push(`%${q}%`, `%${q}%`);
    }
    sql += ' ORDER BY issue_date DESC, id DESC LIMIT 500';

    const docs = database.prepare(sql).all(...params).map(serializeSalesDoc);
    return sendJson(res, 200, { ok: true, docs }) || true;
  }

  if (method === 'POST' && p === '/api/commercial/sales-docs') {
    const b = await readJsonBody(req, standardLimit);
    const docType = String(pick(b, 'docType', 'doc_type') ?? '').trim().toUpperCase();
    if (!SALES_DOC_TYPES.has(docType)) {
      throw createHttpError(400, `Type de document vente invalide: ${docType}`);
    }
    const rawClientId = pick(b, 'clientId', 'client_id');
    if (!rawClientId) throw createHttpError(400, 'clientId est requis');
    const clientId = Number(rawClientId);

    const issueDate = String(pick(b, 'issueDate', 'issue_date') ?? todayIso()).trim();
    if (!isValidIsoDate(issueDate)) throw createHttpError(400, 'issueDate invalide');
    const rawDue = String(pick(b, 'dueDate', 'due_date') ?? '').trim();
    if (rawDue && !isValidIsoDate(rawDue)) throw createHttpError(400, 'dueDate invalide');

    const sourceDocIdRaw = pick(b, 'sourceDocId', 'source_doc_id');
    const validateNow = Boolean(pick(b, 'validateNow', 'validate_now'));
    const restockOnValidate = Boolean(pick(b, 'restockOnValidate', 'restock_on_validate', 'restock'));

    const created = withTransaction(database, () => {
      const client = database.prepare('SELECT * FROM commercial_clients WHERE id = ? AND tenant_id = ?').get(clientId, tenantId);
      if (!client) throw createHttpError(404, 'Client introuvable');

      const computed = computeDocLinesAndTotals(
        b.lines,
        pick(b, 'globalDiscountPct', 'global_discount_pct'),
        database,
        tenantId,
        'sales',
        pick,
        createHttpError,
      );

      let sourceDoc = null;
      if (sourceDocIdRaw !== undefined && sourceDocIdRaw !== null && sourceDocIdRaw !== '') {
        sourceDoc = database
          .prepare('SELECT * FROM commercial_sales_docs WHERE id = ? AND tenant_id = ?')
          .get(Number(sourceDocIdRaw), tenantId);
        if (!sourceDoc) throw createHttpError(404, 'Document source introuvable');
        if (docType === 'AVOIR') {
          if (sourceDoc.doc_type !== 'FACTURE' || !['VALIDEE', 'PARTIELLE', 'PAYEE'].includes(sourceDoc.status)) {
            throw createHttpError(400, "Un avoir doit être lié à une facture validée");
          }
          const maxCredit = round2(sourceDoc.total_ttc_mru - sourceDoc.credited_mru);
          if (computed.totalTtc > maxCredit + 0.01) {
            throw createHttpError(400, `Montant de l'avoir (${computed.totalTtc}) supérieur au solde créditable (${maxCredit})`);
          }
        }
      }

      const dueDate =
        rawDue ||
        (docType === 'FACTURE' && Number(client.payment_terms_days) > 0
          ? addDaysIso(issueDate, Number(client.payment_terms_days))
          : '');
      const docNumber = nextDocNumber(
        database,
        'commercial_sales_docs',
        'doc_number',
        tenantId,
        SALES_DOC_PREFIX[docType],
        issueDate,
      );

      const info = database
        .prepare(`
          INSERT INTO commercial_sales_docs (
            tenant_id, client_id, doc_type, doc_number, status, issue_date, due_date,
            source_doc_id, source_doc_type, client_name, client_nif, client_rc, delivery_address,
            global_discount_pct, subtotal_ht_mru, discount_ht_mru, total_ht_mru, total_tva_mru,
            total_ttc_mru, total_cost_mru, paid_mru, credited_mru, stock_deducted,
            restock_on_validate, reason, notes
          ) VALUES (?, ?, ?, ?, 'BROUILLON', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, ?, ?, ?)
        `)
        .run(
          tenantId,
          client.id,
          docType,
          docNumber,
          issueDate,
          dueDate,
          sourceDoc ? sourceDoc.id : null,
          sourceDoc ? sourceDoc.doc_type : '',
          client.name,
          client.nif,
          client.rc,
          String(pick(b, 'deliveryAddress', 'delivery_address') ?? client.address ?? '').trim(),
          computed.globalDiscountPct,
          computed.subtotalHt,
          computed.discountHt,
          computed.totalHt,
          computed.totalTva,
          computed.totalTtc,
          computed.totalCostMru,
          restockOnValidate ? 1 : 0,
          String(pick(b, 'reason') ?? '').trim(),
          String(pick(b, 'notes') ?? '').trim(),
        );
      const docId = Number(info.lastInsertRowid);
      insertSalesLines(database, tenantId, docId, computed.lines);

      if (validateNow) {
        return validateSalesDocTx(database, tenantId, docId, actor, nowHM, createHttpError);
      }

      const doc = database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ?').get(docId);
      const lines = database.prepare('SELECT * FROM commercial_sales_lines WHERE doc_id = ? ORDER BY line_order ASC').all(docId);
      return {
        doc: serializeSalesDoc(doc),
        lines: lines.map(serializeSalesLine),
      };
    });

    return sendJson(res, 201, { ok: true, ...created }) || true;
  }

  if (method === 'GET' && (m = p.match(/^\/api\/commercial\/sales-docs\/(\d+)$/))) {
    const id = Number(m[1]);
    const doc = database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ? AND tenant_id = ?').get(id, tenantId);
    if (!doc) throw createHttpError(404, 'Document vente introuvable');

    const lines = database.prepare('SELECT * FROM commercial_sales_lines WHERE doc_id = ? ORDER BY line_order ASC').all(id);
    const payments = database.prepare('SELECT * FROM commercial_payments WHERE tenant_id = ? AND sales_doc_id = ? ORDER BY id DESC').all(tenantId, id);
    const cheques = database.prepare('SELECT * FROM commercial_cheques_drafts WHERE tenant_id = ? AND sales_doc_id = ? ORDER BY id DESC').all(tenantId, id);
    const client = doc.client_id ? database.prepare('SELECT * FROM commercial_clients WHERE id = ?').get(doc.client_id) : null;
    const sourceDoc = doc.source_doc_id ? database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ?').get(doc.source_doc_id) : null;

    const clientInvEnc = client ? getClientInvoiceEncours(database, tenantId, client.id) : 0;

    return sendJson(res, 200, {
      ok: true,
      doc: serializeSalesDoc(doc),
      lines: lines.map(serializeSalesLine),
      payments: payments.map(serializePayment),
      cheques: cheques.map(serializeCheque),
      client: client ? serializeClient(client, clientInvEnc) : null,
      sourceDoc: sourceDoc ? serializeSalesDoc(sourceDoc) : null,
    }) || true;
  }

  if (method === 'PATCH' && (m = p.match(/^\/api\/commercial\/sales-docs\/(\d+)$/))) {
    const id = Number(m[1]);
    const b = await readJsonBody(req, standardLimit);

    const updated = withTransaction(database, () => {
      const cur = database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ? AND tenant_id = ?').get(id, tenantId);
      if (!cur) throw createHttpError(404, 'Document vente introuvable');

      const requestedStatus = pick(b, 'status') !== undefined ? String(pick(b, 'status')).trim().toUpperCase() : undefined;
      if (
        cur.doc_type === 'DEVIS' &&
        requestedStatus &&
        !b.lines &&
        ['BROUILLON', 'ENVOYE', 'ACCEPTE', 'REFUSE', 'EXPIRE', 'ANNULE'].includes(requestedStatus)
      ) {
        if (['ANNULE', 'REFUSE', 'EXPIRE', 'CONVERTI'].includes(cur.status)) {
          throw createHttpError(400, `Impossible de modifier le statut d'un devis clôturé (${cur.status})`);
        }
        database
          .prepare('UPDATE commercial_sales_docs SET status = ?, notes = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND tenant_id = ?')
          .run(requestedStatus, pick(b, 'notes') !== undefined ? String(pick(b, 'notes')).trim() : cur.notes, id, tenantId);
        const doc = database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ?').get(id);
        const lines = database.prepare('SELECT * FROM commercial_sales_lines WHERE doc_id = ? ORDER BY line_order ASC').all(id);
        return { doc: serializeSalesDoc(doc), lines: lines.map(serializeSalesLine) };
      }

      if (cur.status !== 'BROUILLON') {
        throw createHttpError(400, 'Seuls les documents en brouillon peuvent être modifiés');
      }

      let clientId = cur.client_id;
      let clientName = cur.client_name;
      let clientNif = cur.client_nif;
      let clientRc = cur.client_rc;
      const rawClientId = pick(b, 'clientId', 'client_id');
      if (rawClientId !== undefined) {
        const client = database.prepare('SELECT * FROM commercial_clients WHERE id = ? AND tenant_id = ?').get(Number(rawClientId), tenantId);
        if (!client) throw createHttpError(404, 'Client introuvable');
        clientId = client.id;
        clientName = client.name;
        clientNif = client.nif;
        clientRc = client.rc;
      }

      const issueDate = pick(b, 'issueDate', 'issue_date') !== undefined ? String(pick(b, 'issueDate', 'issue_date')).trim() : cur.issue_date;
      if (!isValidIsoDate(issueDate)) throw createHttpError(400, 'issueDate invalide');
      const dueDate = pick(b, 'dueDate', 'due_date') !== undefined ? String(pick(b, 'dueDate', 'due_date')).trim() : cur.due_date;
      if (dueDate && !isValidIsoDate(dueDate)) throw createHttpError(400, 'dueDate invalide');

      if (Array.isArray(b.lines)) {
        const computed = computeDocLinesAndTotals(
          b.lines,
          pick(b, 'globalDiscountPct', 'global_discount_pct') ?? cur.global_discount_pct,
          database,
          tenantId,
          'sales',
          pick,
          createHttpError,
        );
        database.prepare('DELETE FROM commercial_sales_lines WHERE doc_id = ?').run(id);
        insertSalesLines(database, tenantId, id, computed.lines);

        database
          .prepare(`
            UPDATE commercial_sales_docs SET
              client_id = ?, client_name = ?, client_nif = ?, client_rc = ?,
              issue_date = ?, due_date = ?, delivery_address = ?,
              global_discount_pct = ?, subtotal_ht_mru = ?, discount_ht_mru = ?,
              total_ht_mru = ?, total_tva_mru = ?, total_ttc_mru = ?, total_cost_mru = ?,
              restock_on_validate = ?, reason = ?, notes = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id = ? AND tenant_id = ?
          `)
          .run(
            clientId,
            clientName,
            clientNif,
            clientRc,
            issueDate,
            dueDate,
            pick(b, 'deliveryAddress', 'delivery_address') !== undefined
              ? String(pick(b, 'deliveryAddress', 'delivery_address')).trim()
              : cur.delivery_address,
            computed.globalDiscountPct,
            computed.subtotalHt,
            computed.discountHt,
            computed.totalHt,
            computed.totalTva,
            computed.totalTtc,
            computed.totalCostMru,
            pick(b, 'restockOnValidate', 'restock_on_validate', 'restock') !== undefined
              ? (Boolean(pick(b, 'restockOnValidate', 'restock_on_validate', 'restock')) ? 1 : 0)
              : cur.restock_on_validate,
            pick(b, 'reason') !== undefined ? String(pick(b, 'reason')).trim() : cur.reason,
            pick(b, 'notes') !== undefined ? String(pick(b, 'notes')).trim() : cur.notes,
            id,
            tenantId,
          );
      } else {
        database
          .prepare(`
            UPDATE commercial_sales_docs SET
              client_id = ?, client_name = ?, client_nif = ?, client_rc = ?,
              issue_date = ?, due_date = ?, delivery_address = ?,
              reason = ?, notes = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id = ? AND tenant_id = ?
          `)
          .run(
            clientId,
            clientName,
            clientNif,
            clientRc,
            issueDate,
            dueDate,
            pick(b, 'deliveryAddress', 'delivery_address') !== undefined
              ? String(pick(b, 'deliveryAddress', 'delivery_address')).trim()
              : cur.delivery_address,
            pick(b, 'reason') !== undefined ? String(pick(b, 'reason')).trim() : cur.reason,
            pick(b, 'notes') !== undefined ? String(pick(b, 'notes')).trim() : cur.notes,
            id,
            tenantId,
          );
      }

      const doc = database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ?').get(id);
      const lines = database.prepare('SELECT * FROM commercial_sales_lines WHERE doc_id = ? ORDER BY line_order ASC').all(id);
      return { doc: serializeSalesDoc(doc), lines: lines.map(serializeSalesLine) };
    });

    return sendJson(res, 200, { ok: true, ...updated }) || true;
  }

  if (method === 'DELETE' && (m = p.match(/^\/api\/commercial\/sales-docs\/(\d+)$/))) {
    const id = Number(m[1]);
    withTransaction(database, () => {
      const cur = database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ? AND tenant_id = ?').get(id, tenantId);
      if (!cur) throw createHttpError(404, 'Document vente introuvable');
      if (cur.status !== 'BROUILLON') {
        throw createHttpError(400, 'Seuls les documents en brouillon peuvent être supprimés');
      }
      if (cur.source_doc_id) {
        const src = database
          .prepare('SELECT * FROM commercial_sales_docs WHERE id = ? AND tenant_id = ?')
          .get(cur.source_doc_id, tenantId);
        if (src && Number(src.converted_to_doc_id) === cur.id) {
          if (src.doc_type === 'FACTURE') {
            database
              .prepare("UPDATE commercial_sales_docs SET converted_to_doc_id = NULL, converted_to_type = '', updated_at = CURRENT_TIMESTAMP WHERE id = ? AND tenant_id = ?")
              .run(src.id, tenantId);
          } else {
            const priorStatus =
              src.doc_type === 'DEVIS'
                ? 'ACCEPTE'
                : src.doc_type === 'COMMANDE'
                ? 'CONFIRMEE'
                : src.doc_type === 'BL'
                ? src.validated_at || src.stock_deducted
                  ? 'VALIDE'
                  : 'BROUILLON'
                : src.status;
            database
              .prepare("UPDATE commercial_sales_docs SET status = ?, converted_to_doc_id = NULL, converted_to_type = '', updated_at = CURRENT_TIMESTAMP WHERE id = ? AND tenant_id = ?")
              .run(priorStatus, src.id, tenantId);
          }
        }
      }
      database.prepare('DELETE FROM commercial_sales_docs WHERE id = ? AND tenant_id = ?').run(id, tenantId);
    });
    return sendJson(res, 200, { ok: true, deleted: true, id }) || true;
  }

  if (method === 'POST' && (m = p.match(/^\/api\/commercial\/sales-docs\/(\d+)\/validate$/))) {
    const id = Number(m[1]);
    const result = withTransaction(database, () =>
      validateSalesDocTx(database, tenantId, id, actor, nowHM, createHttpError),
    );
    return sendJson(res, 200, { ok: true, ...result }) || true;
  }

  if (method === 'POST' && (m = p.match(/^\/api\/commercial\/sales-docs\/(\d+)\/convert$/))) {
    const id = Number(m[1]);
    const b = await readJsonBody(req, standardLimit);
    const targetType = String(pick(b, 'targetType', 'target_type') ?? '').trim().toUpperCase();
    const issueDate = String(pick(b, 'issueDate', 'issue_date') ?? todayIso()).trim();
    if (!isValidIsoDate(issueDate)) throw createHttpError(400, 'issueDate invalide');
    const rawDue = String(pick(b, 'dueDate', 'due_date') ?? '').trim();
    if (rawDue && !isValidIsoDate(rawDue)) throw createHttpError(400, 'dueDate invalide');
    const restock = Boolean(pick(b, 'restock', 'restockOnValidate', 'restock_on_validate'));
    const validateNow = Boolean(pick(b, 'validateNow', 'validate_now'));

    const allowedTargets = {
      DEVIS: new Set(['COMMANDE', 'BL', 'FACTURE']),
      COMMANDE: new Set(['BL', 'FACTURE']),
      BL: new Set(['FACTURE']),
      FACTURE: new Set(['AVOIR']),
    };

    const result = withTransaction(database, () => {
      const src = database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ? AND tenant_id = ?').get(id, tenantId);
      if (!src) throw createHttpError(404, 'Document source introuvable');
      if (!allowedTargets[src.doc_type] || !allowedTargets[src.doc_type].has(targetType)) {
        throw createHttpError(400, `Conversion impossible: ${src.doc_type} -> ${targetType}`);
      }
      if (['ANNULE', 'REFUSE', 'EXPIRE', 'CONVERTI', 'LIVREE', 'FACTURE', 'FACTUREE'].includes(src.status)) {
        throw createHttpError(400, `Document source déjà clôturé (${src.status})`);
      }
      if (src.doc_type === 'FACTURE' && !['VALIDEE', 'PARTIELLE', 'PAYEE'].includes(src.status)) {
        throw createHttpError(400, "La facture source doit être validée avant d'émettre un avoir");
      }

      const srcLines = database.prepare('SELECT * FROM commercial_sales_lines WHERE doc_id = ? ORDER BY line_order ASC').all(id);
      if (srcLines.length === 0) throw createHttpError(400, 'Aucune ligne à convertir');

      let docGlobalDisc = Number(src.global_discount_pct);
      let docSubtotalHt = Number(src.subtotal_ht_mru);
      let docDiscountHt = Number(src.discount_ht_mru);
      let docTotalHt = Number(src.total_ht_mru);
      let docTotalTva = Number(src.total_tva_mru);
      let docTotalTtc = Number(src.total_ttc_mru);
      let docTotalCost = Number(src.total_cost_mru);
      let linesToInsert = srcLines.map((l) => ({
        article_id: l.article_id,
        line_order: l.line_order,
        sku: l.sku,
        designation: l.designation,
        unit: l.unit,
        qty: l.qty,
        unit_price_ht_mru: l.unit_price_ht_mru,
        discount_pct: l.discount_pct,
        tva_rate: l.tva_rate,
        is_exempt: l.is_exempt,
        cost_pmp_mru: l.cost_pmp_mru,
        line_ht_mru: l.line_ht_mru,
        line_tva_mru: l.line_tva_mru,
        line_ttc_mru: l.line_ttc_mru,
        line_cost_mru: l.line_cost_mru,
      }));

      if (src.doc_type === 'FACTURE' && targetType === 'AVOIR') {
        const remainingCreditTtc = round2(Number(src.total_ttc_mru) - Number(src.credited_mru));
        if (remainingCreditTtc <= 0.01) {
          throw createHttpError(400, 'Cette facture est déjà intégralement créditée');
        }
        if (Array.isArray(b.lines) && b.lines.length > 0) {
          const computed = computeDocLinesAndTotals(
            b.lines,
            pick(b, 'globalDiscountPct', 'global_discount_pct') ?? src.global_discount_pct,
            database,
            tenantId,
            'sales',
            pick,
            createHttpError,
          );
          if (computed.totalTtc > remainingCreditTtc + 0.01) {
            throw createHttpError(400, `Montant de l'avoir (${computed.totalTtc}) supérieur au solde créditable (${remainingCreditTtc})`);
          }
          docGlobalDisc = computed.globalDiscountPct;
          docSubtotalHt = computed.subtotalHt;
          docDiscountHt = computed.discountHt;
          docTotalHt = computed.totalHt;
          docTotalTva = computed.totalTva;
          docTotalTtc = computed.totalTtc;
          docTotalCost = computed.totalCostMru;
          linesToInsert = computed.lines.map((l) => ({
            article_id: l.articleId,
            line_order: l.lineOrder,
            sku: l.sku,
            designation: l.designation,
            unit: l.unit,
            qty: l.qty,
            unit_price_ht_mru: l.unitPrice,
            discount_pct: l.discountPct,
            tva_rate: l.tvaRate,
            is_exempt: l.isExempt,
            cost_pmp_mru: l.costPmpMru,
            line_ht_mru: l.lineHt,
            line_tva_mru: l.lineTva,
            line_ttc_mru: l.lineTtc,
            line_cost_mru: l.lineCostMru,
          }));
        } else if (remainingCreditTtc < Number(src.total_ttc_mru) - 0.01) {
          const ratio = Number(src.total_ttc_mru) > 0 ? remainingCreditTtc / Number(src.total_ttc_mru) : 0;
          docTotalTtc = remainingCreditTtc;
          docTotalHt = round2(Number(src.total_ht_mru) * ratio);
          docTotalTva = round2(Math.max(0, docTotalTtc - docTotalHt));
          docSubtotalHt = round2(Number(src.subtotal_ht_mru) * ratio);
          docDiscountHt = round2(Math.max(0, docSubtotalHt - docTotalHt));
          docTotalCost = round2(Number(src.total_cost_mru) * ratio);
          linesToInsert = linesToInsert.map((l) => ({
            ...l,
            unit_price_ht_mru: round2(Number(l.unit_price_ht_mru) * ratio),
            line_ht_mru: round2(Number(l.line_ht_mru) * ratio),
            line_tva_mru: round2(Number(l.line_tva_mru) * ratio),
            line_ttc_mru: round2(Number(l.line_ttc_mru) * ratio),
            line_cost_mru: round2(Number(l.line_cost_mru) * ratio),
          }));
        }
      }

      let dueDate = rawDue;
      if (!dueDate && targetType === 'FACTURE' && src.client_id) {
        const client = database.prepare('SELECT payment_terms_days FROM commercial_clients WHERE id = ?').get(src.client_id);
        if (client && Number(client.payment_terms_days) > 0) {
          dueDate = addDaysIso(issueDate, Number(client.payment_terms_days));
        }
      }

      const newNumber = nextDocNumber(
        database,
        'commercial_sales_docs',
        'doc_number',
        tenantId,
        SALES_DOC_PREFIX[targetType],
        issueDate,
      );

      // Copy stock_deducted from BL -> FACTURE so validating FACTURE never deducts twice!
      const inheritStockDeducted = src.doc_type === 'BL' && targetType === 'FACTURE' ? Number(src.stock_deducted) : 0;

      const info = database
        .prepare(`
          INSERT INTO commercial_sales_docs (
            tenant_id, client_id, doc_type, doc_number, status, issue_date, due_date,
            source_doc_id, source_doc_type, client_name, client_nif, client_rc, delivery_address,
            global_discount_pct, subtotal_ht_mru, discount_ht_mru, total_ht_mru, total_tva_mru,
            total_ttc_mru, total_cost_mru, paid_mru, credited_mru, stock_deducted,
            restock_on_validate, reason, notes
          ) VALUES (?, ?, ?, ?, 'BROUILLON', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?, ?)
        `)
        .run(
          tenantId,
          src.client_id,
          targetType,
          newNumber,
          issueDate,
          dueDate,
          src.id,
          src.doc_type,
          src.client_name,
          src.client_nif,
          src.client_rc,
          src.delivery_address,
          docGlobalDisc,
          docSubtotalHt,
          docDiscountHt,
          docTotalHt,
          docTotalTva,
          docTotalTtc,
          docTotalCost,
          inheritStockDeducted,
          targetType === 'AVOIR' && restock ? 1 : 0,
          String(pick(b, 'reason') ?? '').trim(),
          String(pick(b, 'notes') ?? src.notes ?? '').trim(),
        );
      const newDocId = Number(info.lastInsertRowid);

      const insLine = database.prepare(`
        INSERT INTO commercial_sales_lines (
          tenant_id, doc_id, article_id, line_order, sku, designation, unit, qty,
          unit_price_ht_mru, discount_pct, tva_rate, is_exempt, cost_pmp_mru,
          line_ht_mru, line_tva_mru, line_ttc_mru, line_cost_mru
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);
      for (const l of linesToInsert) {
        insLine.run(
          tenantId,
          newDocId,
          l.article_id,
          l.line_order,
          l.sku,
          l.designation,
          l.unit,
          l.qty,
          l.unit_price_ht_mru,
          l.discount_pct,
          l.tva_rate,
          l.is_exempt,
          l.cost_pmp_mru,
          l.line_ht_mru,
          l.line_tva_mru,
          l.line_ttc_mru,
          l.line_cost_mru,
        );
      }

      if (src.doc_type !== 'FACTURE') {
        const nextSrcStatus =
          src.doc_type === 'DEVIS'
            ? 'CONVERTI'
            : src.doc_type === 'COMMANDE'
            ? targetType === 'BL'
              ? 'LIVREE'
              : 'FACTUREE'
            : 'FACTURE';
        database
          .prepare(`
            UPDATE commercial_sales_docs SET
              status = ?, converted_to_doc_id = ?, converted_to_type = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id = ? AND tenant_id = ?
          `)
          .run(nextSrcStatus, newDocId, targetType, src.id, tenantId);
      } else {
        database
          .prepare('UPDATE commercial_sales_docs SET converted_to_doc_id = ?, converted_to_type = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
          .run(newDocId, targetType, src.id);
      }

      let out;
      if (validateNow) {
        out = validateSalesDocTx(database, tenantId, newDocId, actor, nowHM, createHttpError);
      } else {
        const newDoc = database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ?').get(newDocId);
        const newLines = database.prepare('SELECT * FROM commercial_sales_lines WHERE doc_id = ? ORDER BY line_order ASC').all(newDocId);
        out = { doc: serializeSalesDoc(newDoc), lines: newLines.map(serializeSalesLine) };
      }
      const updatedSrc = database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ?').get(src.id);
      return { ...out, sourceDoc: serializeSalesDoc(updatedSrc) };
    });

    return sendJson(res, 201, { ok: true, ...result }) || true;
  }

  if (method === 'POST' && (m = p.match(/^\/api\/commercial\/sales-docs\/(\d+)\/payments$/))) {
    const id = Number(m[1]);
    const b = await readJsonBody(req, standardLimit);
    const rawAmount = pick(b, 'amountMru', 'amount_mru', 'amount');
    const amountNum = Number(rawAmount);
    if (rawAmount === undefined || rawAmount === null || rawAmount === '' || typeof rawAmount === 'boolean' || !Number.isFinite(amountNum)) {
      throw createHttpError(400, 'Montant de paiement invalide');
    }
    const amountMru = round2(amountNum);
    if (amountMru <= 0) {
      throw createHttpError(400, 'Montant de paiement invalide');
    }
    const payMethod = normalizeCommercialPayMethod(pick(b, 'payMethod', 'pay_method') ?? 'Cash', createHttpError);
    if (payMethod === 'Mixte') {
      throw createHttpError(400, 'Utilisez des règlements séparés par mode de paiement');
    }
    const paymentDate = String(pick(b, 'paymentDate', 'payment_date') ?? todayIso()).trim();
    if (!isValidIsoDate(paymentDate)) throw createHttpError(400, 'paymentDate invalide');
    const ref = String(pick(b, 'ref', 'reference', 'chequeNumber', 'number') ?? '').trim();
    const notes = String(pick(b, 'notes') ?? '').trim();
    const reqAccountId = pick(b, 'treasuryAccountId', 'treasury_account_id');
    const dueDateRaw = String(pick(b, 'dueDate', 'due_date') ?? paymentDate).trim();
    if (!isValidIsoDate(dueDateRaw)) throw createHttpError(400, 'dueDate invalide');
    const bankName = String(pick(b, 'bankName', 'bank_name') ?? '').trim();

    const result = withTransaction(database, () => {
      const doc = database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ? AND tenant_id = ?').get(id, tenantId);
      if (!doc) throw createHttpError(404, 'Facture introuvable');
      if (doc.doc_type !== 'FACTURE' || !['VALIDEE', 'PARTIELLE'].includes(doc.status)) {
        throw createHttpError(400, 'Les paiements sont autorisés uniquement sur une facture validée non soldée');
      }

      const pendingChq = database
        .prepare(`
          SELECT COALESCE(SUM(amount_mru), 0) AS s FROM commercial_cheques_drafts
          WHERE tenant_id = ? AND sales_doc_id = ? AND status IN ('EN_PORTEFEUILLE', 'DEPOSE')
        `)
        .get(tenantId, id).s;
      const remaining = round2(doc.total_ttc_mru - doc.paid_mru - doc.credited_mru - pendingChq);
      if (amountMru > remaining + 0.01) {
        throw createHttpError(400, `Montant (${amountMru}) supérieur au solde payable (${remaining})`);
      }

      const payNum = nextDocNumber(database, 'commercial_payments', 'payment_number', tenantId, 'PAY', paymentDate);

      if (payMethod === 'Karni') {
        if (!doc.client_id) throw createHttpError(400, 'Client requis pour un règlement Karni');
        const client = database.prepare('SELECT * FROM commercial_clients WHERE id = ? AND tenant_id = ?').get(doc.client_id, tenantId);
        if (!client) throw createHttpError(404, 'Client introuvable');
        if (Number(client.credit_limit_mru) > 0 && round2(Number(client.current_debt_mru) + amountMru) > Number(client.credit_limit_mru) + 0.01) {
          throw createHttpError(400, 'Plafond crédit Karni dépassé');
        }
        database
          .prepare('UPDATE commercial_clients SET current_debt_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
          .run(round2(Number(client.current_debt_mru) + amountMru), client.id);

        const nextPaid = round2(Number(doc.paid_mru) + amountMru);
        const nextStatus = nextPaid + Number(doc.credited_mru) >= Number(doc.total_ttc_mru) - 0.01 ? 'PAYEE' : 'PARTIELLE';
        database
          .prepare('UPDATE commercial_sales_docs SET paid_mru = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
          .run(nextPaid, nextStatus, id);

        const pInfo = database
          .prepare(`
            INSERT INTO commercial_payments (
              tenant_id, payment_number, direction, client_id, sales_doc_id,
              payment_date, pay_method, amount_mru, ref, status, notes
            ) VALUES (?, ?, 'IN', ?, ?, ?, 'Karni', ?, ?, 'POSTED', ?)
          `)
          .run(tenantId, payNum, client.id, id, paymentDate, amountMru, ref, notes);

        const updatedDoc = database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ?').get(id);
        const payment = database.prepare('SELECT * FROM commercial_payments WHERE id = ?').get(Number(pInfo.lastInsertRowid));
        return { doc: serializeSalesDoc(updatedDoc), payment: serializePayment(payment), cheque: null };
      }

      if (payMethod === 'Chèque' || payMethod === 'Traite') {
        const chqNumber = ref || `CHQ-${Date.now().toString().slice(-6)}`;
        const instType = payMethod === 'Traite' ? 'TRAITE' : 'CHEQUE';
        const cInfo = database
          .prepare(`
            INSERT INTO commercial_cheques_drafts (
              tenant_id, direction, instrument_type, number, bank_name, client_id,
              sales_doc_id, party_name, issue_date, due_date, amount_mru, status, notes
            ) VALUES (?, 'CLIENT', ?, ?, ?, ?, ?, ?, ?, ?, ?, 'EN_PORTEFEUILLE', ?)
          `)
          .run(
            tenantId,
            instType,
            chqNumber,
            bankName,
            doc.client_id,
            id,
            doc.client_name,
            paymentDate,
            dueDateRaw,
            amountMru,
            notes,
          );
        const chequeId = Number(cInfo.lastInsertRowid);
        const pInfo = database
          .prepare(`
            INSERT INTO commercial_payments (
              tenant_id, payment_number, direction, client_id, sales_doc_id, cheque_draft_id,
              payment_date, pay_method, amount_mru, ref, status, notes
            ) VALUES (?, ?, 'IN', ?, ?, ?, ?, ?, ?, ?, 'PENDING', ?)
          `)
          .run(tenantId, payNum, doc.client_id, id, chequeId, paymentDate, payMethod, amountMru, chqNumber, notes);

        const updatedDoc = database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ?').get(id);
        const payment = database.prepare('SELECT * FROM commercial_payments WHERE id = ?').get(Number(pInfo.lastInsertRowid));
        const cheque = database.prepare('SELECT * FROM commercial_cheques_drafts WHERE id = ?').get(chequeId);
        return { doc: serializeSalesDoc(updatedDoc), payment: serializePayment(payment), cheque: serializeCheque(cheque) };
      }

      // Cash / Digital / Virement
      const acc = reqAccountId
        ? database.prepare('SELECT * FROM commercial_treasury_accounts WHERE id = ? AND tenant_id = ?').get(Number(reqAccountId), tenantId)
        : resolveDefaultTreasuryAccount(database, tenantId, payMethod);
      if (!acc) throw createHttpError(404, 'Compte de trésorerie introuvable');

      const newBal = round2(Number(acc.current_balance_mru) + amountMru);
      database
        .prepare('UPDATE commercial_treasury_accounts SET current_balance_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
        .run(newBal, acc.id);

      const nextPaid = round2(Number(doc.paid_mru) + amountMru);
      const nextStatus = nextPaid + Number(doc.credited_mru) >= Number(doc.total_ttc_mru) - 0.01 ? 'PAYEE' : 'PARTIELLE';
      database
        .prepare('UPDATE commercial_sales_docs SET paid_mru = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
        .run(nextPaid, nextStatus, id);

      const pInfo = database
        .prepare(`
          INSERT INTO commercial_payments (
            tenant_id, payment_number, direction, client_id, sales_doc_id, treasury_account_id,
            payment_date, pay_method, amount_mru, ref, status, notes
          ) VALUES (?, ?, 'IN', ?, ?, ?, ?, ?, ?, ?, 'POSTED', ?)
        `)
        .run(tenantId, payNum, doc.client_id, id, acc.id, paymentDate, payMethod, amountMru, ref, notes);

      database
        .prepare(`
          INSERT INTO commercial_treasury_movements (
            tenant_id, account_id, movement_date, direction, amount_mru, balance_after_mru,
            pay_method, category, label, ref, source_type, source_id
          ) VALUES (?, ?, ?, 'IN', ?, ?, ?, 'ENCAISSEMENT_CLIENT', ?, ?, 'SALES_DOC', ?)
        `)
        .run(
          tenantId,
          acc.id,
          paymentDate,
          amountMru,
          newBal,
          payMethod,
          `Encaissement ${doc.doc_number} · ${doc.client_name}`,
          ref || payNum,
          id,
        );

      const updatedDoc = database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ?').get(id);
      const payment = database.prepare('SELECT * FROM commercial_payments WHERE id = ?').get(Number(pInfo.lastInsertRowid));
      return { doc: serializeSalesDoc(updatedDoc), payment: serializePayment(payment), cheque: null };
    });

    return sendJson(res, 201, { ok: true, ...result }) || true;
  }

  // --------------------------------------------------------------------------
  // 7. PURCHASES CYCLE (CF, RECEPTION, FACTURE_FOURNISSEUR, AVOIR_FOURNISSEUR)
  // --------------------------------------------------------------------------
  if (method === 'GET' && p === '/api/commercial/purchase-docs') {
    const docType = String(url.searchParams.get('docType') || '').trim().toUpperCase();
    const status = String(url.searchParams.get('status') || '').trim().toUpperCase();
    const supplierId = url.searchParams.get('supplierId');
    const q = String(url.searchParams.get('q') || '').trim().toLowerCase();
    const from = String(url.searchParams.get('from') || '').trim();
    const to = String(url.searchParams.get('to') || '').trim();
    if (from && !isValidIsoDate(from)) throw createHttpError(400, 'Date from invalide');
    if (to && !isValidIsoDate(to)) throw createHttpError(400, 'Date to invalide');

    let sql = 'SELECT * FROM commercial_purchase_docs WHERE tenant_id = ?';
    const params = [tenantId];
    if (docType) {
      sql += ' AND doc_type = ?';
      params.push(docType);
    }
    if (status) {
      sql += ' AND status = ?';
      params.push(status);
    }
    if (supplierId) {
      sql += ' AND supplier_id = ?';
      params.push(Number(supplierId));
    }
    if (from) {
      sql += ' AND issue_date >= ?';
      params.push(from);
    }
    if (to) {
      sql += ' AND issue_date <= ?';
      params.push(to);
    }
    if (q) {
      sql += ' AND (LOWER(doc_number) LIKE ? OR LOWER(supplier_name) LIKE ? OR LOWER(supplier_ref) LIKE ?)';
      params.push(`%${q}%`, `%${q}%`, `%${q}%`);
    }
    sql += ' ORDER BY issue_date DESC, id DESC LIMIT 500';

    const docs = database.prepare(sql).all(...params).map(serializePurchaseDoc);
    return sendJson(res, 200, { ok: true, docs }) || true;
  }

  if (method === 'POST' && p === '/api/commercial/purchase-docs') {
    const b = await readJsonBody(req, standardLimit);
    const docType = String(pick(b, 'docType', 'doc_type') ?? '').trim().toUpperCase();
    if (!PURCHASE_DOC_TYPES.has(docType)) {
      throw createHttpError(400, `Type de document achat invalide: ${docType}`);
    }
    const rawSupplierId = pick(b, 'supplierId', 'supplier_id');
    if (!rawSupplierId) throw createHttpError(400, 'supplierId est requis');
    const supplierId = Number(rawSupplierId);

    const issueDate = String(pick(b, 'issueDate', 'issue_date') ?? todayIso()).trim();
    if (!isValidIsoDate(issueDate)) throw createHttpError(400, 'issueDate invalide');
    const rawDue = String(pick(b, 'dueDate', 'due_date') ?? '').trim();
    if (rawDue && !isValidIsoDate(rawDue)) throw createHttpError(400, 'dueDate invalide');

    const sourceDocIdRaw = pick(b, 'sourceDocId', 'source_doc_id');
    const validateNow = Boolean(pick(b, 'validateNow', 'validate_now'));
    const deductStockOnValidate = Boolean(
      pick(b, 'deductStockOnValidate', 'deduct_stock_on_validate', 'restock'),
    );

    const created = withTransaction(database, () => {
      const supplier = database
        .prepare('SELECT * FROM commercial_suppliers WHERE id = ? AND tenant_id = ?')
        .get(supplierId, tenantId);
      if (!supplier) throw createHttpError(404, 'Fournisseur introuvable');

      const computed = computeDocLinesAndTotals(
        b.lines,
        pick(b, 'globalDiscountPct', 'global_discount_pct'),
        database,
        tenantId,
        'purchase',
        pick,
        createHttpError,
      );

      let sourceDoc = null;
      if (sourceDocIdRaw !== undefined && sourceDocIdRaw !== null && sourceDocIdRaw !== '') {
        sourceDoc = database
          .prepare('SELECT * FROM commercial_purchase_docs WHERE id = ? AND tenant_id = ?')
          .get(Number(sourceDocIdRaw), tenantId);
        if (!sourceDoc) throw createHttpError(404, 'Document achat source introuvable');
        if (docType === 'AVOIR_FOURNISSEUR') {
          if (sourceDoc.doc_type !== 'FACTURE_FOURNISSEUR' || !['VALIDEE', 'PARTIELLE', 'PAYEE'].includes(sourceDoc.status)) {
            throw createHttpError(400, "Un avoir fournisseur doit être lié à une facture fournisseur validée");
          }
          const maxCredit = round2(sourceDoc.total_ttc_mru - sourceDoc.credited_mru);
          if (computed.totalTtc > maxCredit + 0.01) {
            throw createHttpError(400, `Montant de l'avoir (${computed.totalTtc}) supérieur au solde créditable (${maxCredit})`);
          }
        }
      }

      const dueDate =
        rawDue ||
        (docType === 'FACTURE_FOURNISSEUR' && Number(supplier.payment_terms_days) > 0
          ? addDaysIso(issueDate, Number(supplier.payment_terms_days))
          : '');
      const docNumber = nextDocNumber(
        database,
        'commercial_purchase_docs',
        'doc_number',
        tenantId,
        PURCHASE_DOC_PREFIX[docType],
        issueDate,
      );

      const info = database
        .prepare(`
          INSERT INTO commercial_purchase_docs (
            tenant_id, supplier_id, doc_type, doc_number, supplier_ref, status, issue_date, due_date,
            source_doc_id, source_doc_type, supplier_name, supplier_nif,
            global_discount_pct, subtotal_ht_mru, discount_ht_mru, total_ht_mru, total_tva_mru,
            total_ttc_mru, paid_mru, credited_mru, stock_applied, deduct_stock_on_validate, reason, notes
          ) VALUES (?, ?, ?, ?, ?, 'BROUILLON', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, ?, ?, ?)
        `)
        .run(
          tenantId,
          supplier.id,
          docType,
          docNumber,
          String(pick(b, 'supplierRef', 'supplier_ref') ?? '').trim(),
          issueDate,
          dueDate,
          sourceDoc ? sourceDoc.id : null,
          sourceDoc ? sourceDoc.doc_type : '',
          supplier.name,
          supplier.nif,
          computed.globalDiscountPct,
          computed.subtotalHt,
          computed.discountHt,
          computed.totalHt,
          computed.totalTva,
          computed.totalTtc,
          deductStockOnValidate ? 1 : 0,
          String(pick(b, 'reason') ?? '').trim(),
          String(pick(b, 'notes') ?? '').trim(),
        );
      const docId = Number(info.lastInsertRowid);
      insertPurchaseLines(database, tenantId, docId, computed.lines);

      if (validateNow) {
        return validatePurchaseDocTx(database, tenantId, docId, actor, nowHM, createHttpError);
      }

      const doc = database.prepare('SELECT * FROM commercial_purchase_docs WHERE id = ?').get(docId);
      const lines = database.prepare('SELECT * FROM commercial_purchase_lines WHERE doc_id = ? ORDER BY line_order ASC').all(docId);
      return {
        doc: serializePurchaseDoc(doc),
        lines: lines.map(serializePurchaseLine),
      };
    });

    return sendJson(res, 201, { ok: true, ...created }) || true;
  }

  if (method === 'GET' && (m = p.match(/^\/api\/commercial\/purchase-docs\/(\d+)$/))) {
    const id = Number(m[1]);
    const doc = database.prepare('SELECT * FROM commercial_purchase_docs WHERE id = ? AND tenant_id = ?').get(id, tenantId);
    if (!doc) throw createHttpError(404, 'Document achat introuvable');

    const lines = database.prepare('SELECT * FROM commercial_purchase_lines WHERE doc_id = ? ORDER BY line_order ASC').all(id);
    const payments = database.prepare('SELECT * FROM commercial_payments WHERE tenant_id = ? AND purchase_doc_id = ? ORDER BY id DESC').all(tenantId, id);
    const cheques = database.prepare('SELECT * FROM commercial_cheques_drafts WHERE tenant_id = ? AND purchase_doc_id = ? ORDER BY id DESC').all(tenantId, id);
    const supplier = doc.supplier_id ? database.prepare('SELECT * FROM commercial_suppliers WHERE id = ?').get(doc.supplier_id) : null;
    const sourceDoc = doc.source_doc_id ? database.prepare('SELECT * FROM commercial_purchase_docs WHERE id = ?').get(doc.source_doc_id) : null;

    return sendJson(res, 200, {
      ok: true,
      doc: serializePurchaseDoc(doc),
      lines: lines.map(serializePurchaseLine),
      payments: payments.map(serializePayment),
      cheques: cheques.map(serializeCheque),
      supplier: supplier ? serializeSupplier(supplier) : null,
      sourceDoc: sourceDoc ? serializePurchaseDoc(sourceDoc) : null,
    }) || true;
  }

  if (method === 'PATCH' && (m = p.match(/^\/api\/commercial\/purchase-docs\/(\d+)$/))) {
    const id = Number(m[1]);
    const b = await readJsonBody(req, standardLimit);

    const updated = withTransaction(database, () => {
      const cur = database.prepare('SELECT * FROM commercial_purchase_docs WHERE id = ? AND tenant_id = ?').get(id, tenantId);
      if (!cur) throw createHttpError(404, 'Document achat introuvable');
      if (cur.status !== 'BROUILLON') {
        throw createHttpError(400, 'Seuls les documents en brouillon peuvent être modifiés');
      }

      let supplierId = cur.supplier_id;
      let supplierName = cur.supplier_name;
      let supplierNif = cur.supplier_nif;
      const rawSupplierId = pick(b, 'supplierId', 'supplier_id');
      if (rawSupplierId !== undefined) {
        const sup = database.prepare('SELECT * FROM commercial_suppliers WHERE id = ? AND tenant_id = ?').get(Number(rawSupplierId), tenantId);
        if (!sup) throw createHttpError(404, 'Fournisseur introuvable');
        supplierId = sup.id;
        supplierName = sup.name;
        supplierNif = sup.nif;
      }

      const issueDate = pick(b, 'issueDate', 'issue_date') !== undefined ? String(pick(b, 'issueDate', 'issue_date')).trim() : cur.issue_date;
      if (!isValidIsoDate(issueDate)) throw createHttpError(400, 'issueDate invalide');
      const dueDate = pick(b, 'dueDate', 'due_date') !== undefined ? String(pick(b, 'dueDate', 'due_date')).trim() : cur.due_date;
      if (dueDate && !isValidIsoDate(dueDate)) throw createHttpError(400, 'dueDate invalide');

      if (Array.isArray(b.lines)) {
        const computed = computeDocLinesAndTotals(
          b.lines,
          pick(b, 'globalDiscountPct', 'global_discount_pct') ?? cur.global_discount_pct,
          database,
          tenantId,
          'purchase',
          pick,
          createHttpError,
        );
        database.prepare('DELETE FROM commercial_purchase_lines WHERE doc_id = ?').run(id);
        insertPurchaseLines(database, tenantId, id, computed.lines);

        database
          .prepare(`
            UPDATE commercial_purchase_docs SET
              supplier_id = ?, supplier_name = ?, supplier_nif = ?, supplier_ref = ?,
              issue_date = ?, due_date = ?,
              global_discount_pct = ?, subtotal_ht_mru = ?, discount_ht_mru = ?,
              total_ht_mru = ?, total_tva_mru = ?, total_ttc_mru = ?,
              deduct_stock_on_validate = ?, reason = ?, notes = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id = ? AND tenant_id = ?
          `)
          .run(
            supplierId,
            supplierName,
            supplierNif,
            pick(b, 'supplierRef', 'supplier_ref') !== undefined ? String(pick(b, 'supplierRef', 'supplier_ref')).trim() : cur.supplier_ref,
            issueDate,
            dueDate,
            computed.globalDiscountPct,
            computed.subtotalHt,
            computed.discountHt,
            computed.totalHt,
            computed.totalTva,
            computed.totalTtc,
            pick(b, 'deductStockOnValidate', 'deduct_stock_on_validate', 'restock') !== undefined
              ? (Boolean(pick(b, 'deductStockOnValidate', 'deduct_stock_on_validate', 'restock')) ? 1 : 0)
              : cur.deduct_stock_on_validate,
            pick(b, 'reason') !== undefined ? String(pick(b, 'reason')).trim() : cur.reason,
            pick(b, 'notes') !== undefined ? String(pick(b, 'notes')).trim() : cur.notes,
            id,
            tenantId,
          );
      } else {
        database
          .prepare(`
            UPDATE commercial_purchase_docs SET
              supplier_id = ?, supplier_name = ?, supplier_nif = ?, supplier_ref = ?,
              issue_date = ?, due_date = ?, reason = ?, notes = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id = ? AND tenant_id = ?
          `)
          .run(
            supplierId,
            supplierName,
            supplierNif,
            pick(b, 'supplierRef', 'supplier_ref') !== undefined ? String(pick(b, 'supplierRef', 'supplier_ref')).trim() : cur.supplier_ref,
            issueDate,
            dueDate,
            pick(b, 'reason') !== undefined ? String(pick(b, 'reason')).trim() : cur.reason,
            pick(b, 'notes') !== undefined ? String(pick(b, 'notes')).trim() : cur.notes,
            id,
            tenantId,
          );
      }

      const doc = database.prepare('SELECT * FROM commercial_purchase_docs WHERE id = ?').get(id);
      const lines = database.prepare('SELECT * FROM commercial_purchase_lines WHERE doc_id = ? ORDER BY line_order ASC').all(id);
      return { doc: serializePurchaseDoc(doc), lines: lines.map(serializePurchaseLine) };
    });

    return sendJson(res, 200, { ok: true, ...updated }) || true;
  }

  if (method === 'DELETE' && (m = p.match(/^\/api\/commercial\/purchase-docs\/(\d+)$/))) {
    const id = Number(m[1]);
    withTransaction(database, () => {
      const cur = database.prepare('SELECT * FROM commercial_purchase_docs WHERE id = ? AND tenant_id = ?').get(id, tenantId);
      if (!cur) throw createHttpError(404, 'Document achat introuvable');
      if (cur.status !== 'BROUILLON') {
        throw createHttpError(400, 'Seuls les documents en brouillon peuvent être supprimés');
      }
      if (cur.source_doc_id) {
        const src = database
          .prepare('SELECT * FROM commercial_purchase_docs WHERE id = ? AND tenant_id = ?')
          .get(cur.source_doc_id, tenantId);
        if (src && Number(src.converted_to_doc_id) === cur.id) {
          if (src.doc_type === 'FACTURE_FOURNISSEUR') {
            database
              .prepare("UPDATE commercial_purchase_docs SET converted_to_doc_id = NULL, converted_to_type = '', updated_at = CURRENT_TIMESTAMP WHERE id = ? AND tenant_id = ?")
              .run(src.id, tenantId);
          } else {
            const priorStatus =
              src.doc_type === 'COMMANDE_FOURNISSEUR'
                ? 'ENVOYEE'
                : src.doc_type === 'RECEPTION'
                ? src.validated_at || src.stock_applied
                  ? 'VALIDEE'
                  : 'BROUILLON'
                : src.status;
            database
              .prepare("UPDATE commercial_purchase_docs SET status = ?, converted_to_doc_id = NULL, converted_to_type = '', updated_at = CURRENT_TIMESTAMP WHERE id = ? AND tenant_id = ?")
              .run(priorStatus, src.id, tenantId);
          }
        }
      }
      database.prepare('DELETE FROM commercial_purchase_docs WHERE id = ? AND tenant_id = ?').run(id, tenantId);
    });
    return sendJson(res, 200, { ok: true, deleted: true, id }) || true;
  }

  if (method === 'POST' && (m = p.match(/^\/api\/commercial\/purchase-docs\/(\d+)\/validate$/))) {
    const id = Number(m[1]);
    const result = withTransaction(database, () =>
      validatePurchaseDocTx(database, tenantId, id, actor, nowHM, createHttpError),
    );
    return sendJson(res, 200, { ok: true, ...result }) || true;
  }

  if (method === 'POST' && (m = p.match(/^\/api\/commercial\/purchase-docs\/(\d+)\/convert$/))) {
    const id = Number(m[1]);
    const b = await readJsonBody(req, standardLimit);
    const targetType = String(pick(b, 'targetType', 'target_type') ?? '').trim().toUpperCase();
    const issueDate = String(pick(b, 'issueDate', 'issue_date') ?? todayIso()).trim();
    if (!isValidIsoDate(issueDate)) throw createHttpError(400, 'issueDate invalide');
    const rawDue = String(pick(b, 'dueDate', 'due_date') ?? '').trim();
    if (rawDue && !isValidIsoDate(rawDue)) throw createHttpError(400, 'dueDate invalide');
    const restock = Boolean(pick(b, 'restock', 'deductStockOnValidate', 'deduct_stock_on_validate'));
    const validateNow = Boolean(pick(b, 'validateNow', 'validate_now'));

    const allowedTargets = {
      COMMANDE_FOURNISSEUR: new Set(['RECEPTION', 'FACTURE_FOURNISSEUR']),
      RECEPTION: new Set(['FACTURE_FOURNISSEUR']),
      FACTURE_FOURNISSEUR: new Set(['AVOIR_FOURNISSEUR']),
    };

    const result = withTransaction(database, () => {
      const src = database.prepare('SELECT * FROM commercial_purchase_docs WHERE id = ? AND tenant_id = ?').get(id, tenantId);
      if (!src) throw createHttpError(404, 'Document achat source introuvable');
      if (!allowedTargets[src.doc_type] || !allowedTargets[src.doc_type].has(targetType)) {
        throw createHttpError(400, `Conversion achat impossible: ${src.doc_type} -> ${targetType}`);
      }
      if (['ANNULE', 'RECUE', 'RECEPTIONNEE', 'FACTUREE'].includes(src.status)) {
        throw createHttpError(400, `Document source déjà clôturé (${src.status})`);
      }
      if (src.doc_type === 'FACTURE_FOURNISSEUR' && !['VALIDEE', 'PARTIELLE', 'PAYEE'].includes(src.status)) {
        throw createHttpError(400, "La facture fournisseur doit être validée avant d'émettre un avoir");
      }

      const srcLines = database.prepare('SELECT * FROM commercial_purchase_lines WHERE doc_id = ? ORDER BY line_order ASC').all(id);
      if (srcLines.length === 0) throw createHttpError(400, 'Aucune ligne à convertir');

      let dueDate = rawDue;
      if (!dueDate && targetType === 'FACTURE_FOURNISSEUR' && src.supplier_id) {
        const sup = database.prepare('SELECT payment_terms_days FROM commercial_suppliers WHERE id = ?').get(src.supplier_id);
        if (sup && Number(sup.payment_terms_days) > 0) {
          dueDate = addDaysIso(issueDate, Number(sup.payment_terms_days));
        }
      }

      const newNumber = nextDocNumber(
        database,
        'commercial_purchase_docs',
        'doc_number',
        tenantId,
        PURCHASE_DOC_PREFIX[targetType],
        issueDate,
      );
      const inheritStockApplied = src.doc_type === 'RECEPTION' && targetType === 'FACTURE_FOURNISSEUR' ? Number(src.stock_applied) : 0;

      const info = database
        .prepare(`
          INSERT INTO commercial_purchase_docs (
            tenant_id, supplier_id, doc_type, doc_number, supplier_ref, status, issue_date, due_date,
            source_doc_id, source_doc_type, supplier_name, supplier_nif,
            global_discount_pct, subtotal_ht_mru, discount_ht_mru, total_ht_mru, total_tva_mru,
            total_ttc_mru, paid_mru, credited_mru, stock_applied, deduct_stock_on_validate, reason, notes
          ) VALUES (?, ?, ?, ?, ?, 'BROUILLON', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?, ?)
        `)
        .run(
          tenantId,
          src.supplier_id,
          targetType,
          newNumber,
          src.supplier_ref,
          issueDate,
          dueDate,
          src.id,
          src.doc_type,
          src.supplier_name,
          src.supplier_nif,
          src.global_discount_pct,
          src.subtotal_ht_mru,
          src.discount_ht_mru,
          src.total_ht_mru,
          src.total_tva_mru,
          src.total_ttc_mru,
          inheritStockApplied,
          targetType === 'AVOIR_FOURNISSEUR' && restock ? 1 : 0,
          String(pick(b, 'reason') ?? '').trim(),
          String(pick(b, 'notes') ?? src.notes ?? '').trim(),
        );
      const newDocId = Number(info.lastInsertRowid);

      const insLine = database.prepare(`
        INSERT INTO commercial_purchase_lines (
          tenant_id, doc_id, article_id, line_order, sku, designation, unit, qty,
          unit_cost_ht_mru, discount_pct, tva_rate, is_exempt, line_ht_mru, line_tva_mru, line_ttc_mru
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);
      for (const l of srcLines) {
        insLine.run(
          tenantId,
          newDocId,
          l.article_id,
          l.line_order,
          l.sku,
          l.designation,
          l.unit,
          l.qty,
          l.unit_cost_ht_mru,
          l.discount_pct,
          l.tva_rate,
          l.is_exempt,
          l.line_ht_mru,
          l.line_tva_mru,
          l.line_ttc_mru,
        );
      }

      if (src.doc_type !== 'FACTURE_FOURNISSEUR') {
        const nextSrcStatus =
          src.doc_type === 'COMMANDE_FOURNISSEUR'
            ? targetType === 'RECEPTION'
              ? 'RECEPTIONNEE'
              : 'FACTUREE'
            : 'FACTUREE';
        database
          .prepare('UPDATE commercial_purchase_docs SET status = ?, converted_to_doc_id = ?, converted_to_type = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
          .run(nextSrcStatus, newDocId, targetType, src.id);
      } else {
        database
          .prepare('UPDATE commercial_purchase_docs SET converted_to_doc_id = ?, converted_to_type = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
          .run(newDocId, targetType, src.id);
      }

      let out;
      if (validateNow) {
        out = validatePurchaseDocTx(database, tenantId, newDocId, actor, nowHM, createHttpError);
      } else {
        const newDoc = database.prepare('SELECT * FROM commercial_purchase_docs WHERE id = ?').get(newDocId);
        const newLines = database.prepare('SELECT * FROM commercial_purchase_lines WHERE doc_id = ? ORDER BY line_order ASC').all(newDocId);
        out = { doc: serializePurchaseDoc(newDoc), lines: newLines.map(serializePurchaseLine) };
      }
      const updatedSrc = database.prepare('SELECT * FROM commercial_purchase_docs WHERE id = ?').get(src.id);
      return { ...out, sourceDoc: serializePurchaseDoc(updatedSrc) };
    });

    return sendJson(res, 201, { ok: true, ...result }) || true;
  }

  if (method === 'POST' && (m = p.match(/^\/api\/commercial\/purchase-docs\/(\d+)\/payments$/))) {
    const id = Number(m[1]);
    const b = await readJsonBody(req, standardLimit);
    const rawAmount = pick(b, 'amountMru', 'amount_mru', 'amount');
    const amountNum = Number(rawAmount);
    if (rawAmount === undefined || rawAmount === null || rawAmount === '' || typeof rawAmount === 'boolean' || !Number.isFinite(amountNum)) {
      throw createHttpError(400, 'Montant de paiement invalide');
    }
    const amountMru = round2(amountNum);
    if (amountMru <= 0) {
      throw createHttpError(400, 'Montant de paiement invalide');
    }
    const payMethod = normalizeCommercialPayMethod(pick(b, 'payMethod', 'pay_method') ?? 'Virement', createHttpError);
    if (payMethod === 'Karni' || payMethod === 'Mixte') {
      throw createHttpError(400, `Mode de paiement fournisseur non supporté: ${payMethod}`);
    }
    const paymentDate = String(pick(b, 'paymentDate', 'payment_date') ?? todayIso()).trim();
    if (!isValidIsoDate(paymentDate)) throw createHttpError(400, 'paymentDate invalide');
    const ref = String(pick(b, 'ref', 'reference', 'chequeNumber', 'number') ?? '').trim();
    const notes = String(pick(b, 'notes') ?? '').trim();
    const reqAccountId = pick(b, 'treasuryAccountId', 'treasury_account_id');
    const dueDateRaw = String(pick(b, 'dueDate', 'due_date') ?? paymentDate).trim();
    if (!isValidIsoDate(dueDateRaw)) throw createHttpError(400, 'dueDate invalide');
    const bankName = String(pick(b, 'bankName', 'bank_name') ?? '').trim();

    const result = withTransaction(database, () => {
      const doc = database.prepare('SELECT * FROM commercial_purchase_docs WHERE id = ? AND tenant_id = ?').get(id, tenantId);
      if (!doc) throw createHttpError(404, 'Facture fournisseur introuvable');
      if (doc.doc_type !== 'FACTURE_FOURNISSEUR' || !['VALIDEE', 'PARTIELLE'].includes(doc.status)) {
        throw createHttpError(400, 'Les paiements sont autorisés uniquement sur une facture fournisseur validée non soldée');
      }

      const pendingChq = database
        .prepare(`
          SELECT COALESCE(SUM(amount_mru), 0) AS s FROM commercial_cheques_drafts
          WHERE tenant_id = ? AND purchase_doc_id = ? AND status = 'EMIS'
        `)
        .get(tenantId, id).s;
      const remaining = round2(doc.total_ttc_mru - doc.paid_mru - doc.credited_mru - pendingChq);
      if (amountMru > remaining + 0.01) {
        throw createHttpError(400, `Montant (${amountMru}) supérieur au solde à payer (${remaining})`);
      }

      const payNum = nextDocNumber(database, 'commercial_payments', 'payment_number', tenantId, 'PAY', paymentDate);

      if (payMethod === 'Chèque' || payMethod === 'Traite') {
        const chqNumber = ref || `CHQ-F-${Date.now().toString().slice(-6)}`;
        const instType = payMethod === 'Traite' ? 'TRAITE' : 'CHEQUE';
        const cInfo = database
          .prepare(`
            INSERT INTO commercial_cheques_drafts (
              tenant_id, direction, instrument_type, number, bank_name, supplier_id,
              purchase_doc_id, party_name, issue_date, due_date, amount_mru, status, notes
            ) VALUES (?, 'FOURNISSEUR', ?, ?, ?, ?, ?, ?, ?, ?, ?, 'EMIS', ?)
          `)
          .run(
            tenantId,
            instType,
            chqNumber,
            bankName,
            doc.supplier_id,
            id,
            doc.supplier_name,
            paymentDate,
            dueDateRaw,
            amountMru,
            notes,
          );
        const chequeId = Number(cInfo.lastInsertRowid);
        const pInfo = database
          .prepare(`
            INSERT INTO commercial_payments (
              tenant_id, payment_number, direction, supplier_id, purchase_doc_id, cheque_draft_id,
              payment_date, pay_method, amount_mru, ref, status, notes
            ) VALUES (?, ?, 'OUT', ?, ?, ?, ?, ?, ?, ?, 'PENDING', ?)
          `)
          .run(tenantId, payNum, doc.supplier_id, id, chequeId, paymentDate, payMethod, amountMru, chqNumber, notes);

        const updatedDoc = database.prepare('SELECT * FROM commercial_purchase_docs WHERE id = ?').get(id);
        const payment = database.prepare('SELECT * FROM commercial_payments WHERE id = ?').get(Number(pInfo.lastInsertRowid));
        const cheque = database.prepare('SELECT * FROM commercial_cheques_drafts WHERE id = ?').get(chequeId);
        return { doc: serializePurchaseDoc(updatedDoc), payment: serializePayment(payment), cheque: serializeCheque(cheque) };
      }

      const acc = reqAccountId
        ? database.prepare('SELECT * FROM commercial_treasury_accounts WHERE id = ? AND tenant_id = ?').get(Number(reqAccountId), tenantId)
        : resolveDefaultTreasuryAccount(database, tenantId, payMethod);
      if (!acc) throw createHttpError(404, 'Compte de trésorerie introuvable');

      const newBal = round2(Number(acc.current_balance_mru) - amountMru);
      database
        .prepare('UPDATE commercial_treasury_accounts SET current_balance_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
        .run(newBal, acc.id);

      const nextPaid = round2(Number(doc.paid_mru) + amountMru);
      const nextStatus = nextPaid + Number(doc.credited_mru) >= Number(doc.total_ttc_mru) - 0.01 ? 'PAYEE' : 'PARTIELLE';
      database
        .prepare('UPDATE commercial_purchase_docs SET paid_mru = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
        .run(nextPaid, nextStatus, id);

      if (doc.supplier_id) {
        syncSupplierBalanceDue(database, tenantId, doc.supplier_id);
      }

      const pInfo = database
        .prepare(`
          INSERT INTO commercial_payments (
            tenant_id, payment_number, direction, supplier_id, purchase_doc_id, treasury_account_id,
            payment_date, pay_method, amount_mru, ref, status, notes
          ) VALUES (?, ?, 'OUT', ?, ?, ?, ?, ?, ?, ?, 'POSTED', ?)
        `)
        .run(tenantId, payNum, doc.supplier_id, id, acc.id, paymentDate, payMethod, amountMru, ref, notes);

      database
        .prepare(`
          INSERT INTO commercial_treasury_movements (
            tenant_id, account_id, movement_date, direction, amount_mru, balance_after_mru,
            pay_method, category, label, ref, source_type, source_id
          ) VALUES (?, ?, ?, 'OUT', ?, ?, ?, 'PAIEMENT_FOURNISSEUR', ?, ?, 'PURCHASE_DOC', ?)
        `)
        .run(
          tenantId,
          acc.id,
          paymentDate,
          amountMru,
          newBal,
          payMethod,
          `Règlement ${doc.doc_number} · ${doc.supplier_name}`,
          ref || payNum,
          id,
        );

      const updatedDoc = database.prepare('SELECT * FROM commercial_purchase_docs WHERE id = ?').get(id);
      const payment = database.prepare('SELECT * FROM commercial_payments WHERE id = ?').get(Number(pInfo.lastInsertRowid));
      return { doc: serializePurchaseDoc(updatedDoc), payment: serializePayment(payment), cheque: null };
    });

    return sendJson(res, 201, { ok: true, ...result }) || true;
  }

  // --------------------------------------------------------------------------
  // 8. POS SESSIONS, Z-REPORTS & TICKETS
  // --------------------------------------------------------------------------
  if (method === 'GET' && p === '/api/commercial/pos/sessions') {
    const status = String(url.searchParams.get('status') || '').trim().toUpperCase();
    let sql = 'SELECT * FROM commercial_pos_sessions WHERE tenant_id = ?';
    const params = [tenantId];
    if (status) {
      sql += ' AND status = ?';
      params.push(status);
    }
    sql += ' ORDER BY id DESC LIMIT 100';
    const sessions = database.prepare(sql).all(...params).map(serializePosSession);
    return sendJson(res, 200, { ok: true, sessions }) || true;
  }

  if (method === 'POST' && p === '/api/commercial/pos/sessions/open') {
    const b = await readJsonBody(req, standardLimit);
    const registerCode = String(pick(b, 'registerCode', 'register_code') ?? 'C1').trim() || 'C1';
    const cashierName = String(pick(b, 'cashierName', 'cashier_name') ?? actor).trim();
    const openingFloatMru = Number(pick(b, 'openingFloatMru', 'opening_float_mru') ?? 0);
    if (!Number.isFinite(openingFloatMru) || openingFloatMru < 0) {
      throw createHttpError(400, "Fond de caisse initial invalide");
    }
    const notes = String(pick(b, 'notes') ?? '').trim();

    const session = withTransaction(database, () => {
      const existingOpen = database
        .prepare("SELECT id FROM commercial_pos_sessions WHERE tenant_id = ? AND register_code = ? AND status = 'OPEN' LIMIT 1")
        .get(tenantId, registerCode);
      if (existingOpen) {
        throw createHttpError(409, `Une session est déjà ouverte pour la caisse ${registerCode}`);
      }
      const nowIso = new Date().toISOString();
      const sesNum = nextDocNumber(database, 'commercial_pos_sessions', 'session_number', tenantId, 'SES', nowIso);
      const info = database
        .prepare(`
          INSERT INTO commercial_pos_sessions (
            tenant_id, session_number, register_code, cashier_name, status,
            opening_float_mru, expected_cash_mru, notes, opened_at
          ) VALUES (?, ?, ?, ?, 'OPEN', ?, ?, ?, ?)
        `)
        .run(tenantId, sesNum, registerCode, cashierName, round2(openingFloatMru), round2(openingFloatMru), notes, nowIso);
      return database.prepare('SELECT * FROM commercial_pos_sessions WHERE id = ?').get(Number(info.lastInsertRowid));
    });

    return sendJson(res, 201, { ok: true, session: serializePosSession(session) }) || true;
  }

  if (method === 'POST' && (m = p.match(/^\/api\/commercial\/pos\/sessions\/(\d+)\/close$/))) {
    const id = Number(m[1]);
    const b = await readJsonBody(req, standardLimit);
    const rawCounted = pick(b, 'countedCashMru', 'counted_cash_mru');
    if (rawCounted === undefined || rawCounted === '') {
      throw createHttpError(400, 'countedCashMru est requis pour clôturer la session');
    }
    const countedCashMru = Number(rawCounted);
    if (!Number.isFinite(countedCashMru) || countedCashMru < 0) {
      throw createHttpError(400, 'Montant compté invalide');
    }
    const notes = String(pick(b, 'notes') ?? '').trim();

    const result = withTransaction(database, () => {
      const ses = database.prepare('SELECT * FROM commercial_pos_sessions WHERE id = ? AND tenant_id = ?').get(id, tenantId);
      if (!ses) throw createHttpError(404, 'Session de caisse introuvable');
      if (ses.status !== 'OPEN') throw createHttpError(400, 'Session déjà clôturée');

      const expectedCashMru = round2(Number(ses.opening_float_mru) + Number(ses.cash_sales_mru) - Number(ses.refund_cash_mru));
      const varianceMru = round2(countedCashMru - expectedCashMru);
      const closedAt = new Date().toISOString();

      database
        .prepare(`
          UPDATE commercial_pos_sessions SET
            status = 'CLOSED', expected_cash_mru = ?, counted_cash_mru = ?, variance_mru = ?,
            notes = ?, closed_at = ?, updated_at = CURRENT_TIMESTAMP
          WHERE id = ? AND tenant_id = ?
        `)
        .run(
          expectedCashMru,
          round2(countedCashMru),
          varianceMru,
          notes || ses.notes,
          closedAt,
          id,
          tenantId,
        );

      const updated = database.prepare('SELECT * FROM commercial_pos_sessions WHERE id = ?').get(id);
      const tickets = database.prepare('SELECT * FROM commercial_pos_tickets WHERE session_id = ? AND tenant_id = ?').all(id, tenantId);
      return {
        session: serializePosSession(updated),
        zReport: buildZReport(updated, tickets),
      };
    });

    return sendJson(res, 200, { ok: true, ...result }) || true;
  }

  if (method === 'GET' && (m = p.match(/^\/api\/commercial\/pos\/sessions\/(\d+)\/z-report$/))) {
    const id = Number(m[1]);
    const ses = database.prepare('SELECT * FROM commercial_pos_sessions WHERE id = ? AND tenant_id = ?').get(id, tenantId);
    if (!ses) throw createHttpError(404, 'Session de caisse introuvable');
    const tickets = database.prepare('SELECT * FROM commercial_pos_tickets WHERE session_id = ? AND tenant_id = ?').all(id, tenantId);
    return sendJson(res, 200, { ok: true, session: serializePosSession(ses), zReport: buildZReport(ses, tickets) }) || true;
  }

  if (method === 'GET' && p === '/api/commercial/pos/tickets') {
    const sessionId = url.searchParams.get('sessionId');
    const status = String(url.searchParams.get('status') || '').trim().toUpperCase();
    const payMethod = String(url.searchParams.get('payMethod') || '').trim();
    const q = String(url.searchParams.get('q') || '').trim().toLowerCase();
    const from = String(url.searchParams.get('from') || '').trim();
    const to = String(url.searchParams.get('to') || '').trim();
    if (from && !isValidIsoDate(from)) throw createHttpError(400, 'Date from invalide');
    if (to && !isValidIsoDate(to)) throw createHttpError(400, 'Date to invalide');

    let sql = 'SELECT * FROM commercial_pos_tickets WHERE tenant_id = ?';
    const params = [tenantId];
    if (sessionId) {
      sql += ' AND session_id = ?';
      params.push(Number(sessionId));
    }
    if (status) {
      sql += ' AND status = ?';
      params.push(status);
    }
    if (payMethod) {
      sql += ' AND pay_method = ?';
      params.push(payMethod);
    }
    if (from) {
      sql += ' AND substr(created_at, 1, 10) >= ?';
      params.push(from);
    }
    if (to) {
      sql += ' AND substr(created_at, 1, 10) <= ?';
      params.push(to);
    }
    if (q) {
      sql += ' AND (LOWER(ticket_number) LIKE ? OR LOWER(customer_name) LIKE ?)';
      params.push(`%${q}%`, `%${q}%`);
    }
    sql += ' ORDER BY id DESC LIMIT 300';

    const rows = database.prepare(sql).all(...params);
    const getLines = database.prepare('SELECT * FROM commercial_pos_ticket_lines WHERE ticket_id = ? ORDER BY id ASC');
    const tickets = rows.map((r) => serializePosTicket(r, getLines.all(r.id).map(serializePosTicketLine), parseJson));
    return sendJson(res, 200, { ok: true, tickets }) || true;
  }

  if (method === 'POST' && p === '/api/commercial/pos/tickets') {
    const b = await readJsonBody(req, standardLimit);
    if (!Array.isArray(b.lines) || b.lines.length === 0) {
      throw createHttpError(400, 'Au moins un article est requis sur le ticket');
    }

    const rawTier = String(pick(b, 'priceTier', 'price_tier') ?? 'retail').trim().toLowerCase();
    const priceTier = rawTier === 'whole' || rawTier === 'gros' ? 'whole' : 'retail';
    const discountMru = Number(pick(b, 'discountMru', 'discount_mru') ?? 0);
    if (!Number.isFinite(discountMru) || discountMru < 0) {
      throw createHttpError(400, 'Remise ticket invalide');
    }
    const rawClientId = pick(b, 'clientId', 'client_id');
    const sessionIdRaw = pick(b, 'sessionId', 'session_id');
    const registerCode = String(pick(b, 'registerCode', 'register_code') ?? 'C1').trim() || 'C1';

    const result = withTransaction(database, () => {
      const ses = sessionIdRaw
        ? database.prepare("SELECT * FROM commercial_pos_sessions WHERE id = ? AND tenant_id = ? AND status = 'OPEN'").get(Number(sessionIdRaw), tenantId)
        : database.prepare("SELECT * FROM commercial_pos_sessions WHERE tenant_id = ? AND register_code = ? AND status = 'OPEN' ORDER BY id DESC LIMIT 1").get(tenantId, registerCode);
      if (!ses) {
        throw createHttpError(400, 'Aucune session de caisse ouverte');
      }

      let client = null;
      if (rawClientId !== undefined && rawClientId !== null && rawClientId !== '') {
        client = database.prepare('SELECT * FROM commercial_clients WHERE id = ? AND tenant_id = ?').get(Number(rawClientId), tenantId);
        if (!client) throw createHttpError(404, 'Client introuvable');
      }

      const getArt = database.prepare('SELECT * FROM commercial_articles WHERE id = ? AND tenant_id = ? LIMIT 1');
      let subtotalHt = 0;
      let sumLineTva = 0;
      let subtotalTtc = 0;
      let totalCostMru = 0;
      const lines = [];

      for (let i = 0; i < b.lines.length; i++) {
        const l = b.lines[i];
        const rawArtId = pick(l, 'articleId', 'article_id');
        let art = null;
        if (rawArtId !== undefined && rawArtId !== null && rawArtId !== '') {
          art = getArt.get(Number(rawArtId), tenantId);
          if (!art) throw createHttpError(404, `Article introuvable (#${rawArtId})`);
        }
        const qty = Number(pick(l, 'qty', 'quantity') ?? 1);
        if (!Number.isFinite(qty) || qty <= 0) throw createHttpError(400, `Quantité invalide ligne ${i + 1}`);

        const rawPriceHt = pick(l, 'unitPriceHtMru', 'unit_price_ht_mru', 'unitPriceHt');
        const defaultHt = art ? Number(priceTier === 'whole' ? art.price_whole_ht : art.price_retail_ht) : 0;
        const unitPriceHt = rawPriceHt !== undefined ? Number(rawPriceHt) : defaultHt;
        if (!Number.isFinite(unitPriceHt) || unitPriceHt < 0) throw createHttpError(400, `Prix invalide ligne ${i + 1}`);

        const discPct = Number(pick(l, 'discountPct', 'discount_pct') ?? 0);
        if (!Number.isFinite(discPct) || discPct < 0 || discPct > 100) throw createHttpError(400, `Remise invalide ligne ${i + 1}`);

        const { isExempt, tvaRate } = resolveLineTva(
          pick(l, 'isExempt', 'is_exempt'),
          pick(l, 'tvaRate', 'tva_rate'),
          art,
          createHttpError,
        );

        const lineHt = round2(qty * unitPriceHt * (1 - discPct / 100));
        const lineTva = isExempt || tvaRate === 0 ? 0 : round2(lineHt * (tvaRate / 100));
        const lineTtc = round2(lineHt + lineTva);
        const unitPriceTtc = isExempt || tvaRate === 0 ? round2(unitPriceHt) : round2(unitPriceHt * (1 + tvaRate / 100));
        const costPmp = art ? round2(art.pmp_cost_mru) : 0;
        const lineCost = round2(qty * costPmp);

        subtotalHt = round2(subtotalHt + lineHt);
        sumLineTva = round2(sumLineTva + lineTva);
        subtotalTtc = round2(subtotalTtc + lineTtc);
        totalCostMru = round2(totalCostMru + lineCost);

        lines.push({
          article: art,
          articleId: art ? art.id : null,
          sku: String(pick(l, 'sku') ?? (art ? art.sku : '')).trim(),
          designation: String(pick(l, 'designation', 'name') ?? (art ? art.name : '')).trim() || 'Article',
          unit: String(pick(l, 'unit') ?? (art ? art.unit : 'unité')).trim() || 'unité',
          qty: round3(qty),
          unitPriceHt: round2(unitPriceHt),
          unitPriceTtc,
          discountPct: round2(discPct),
          tvaRate,
          isExempt: isExempt ? 1 : 0,
          costPmp,
          lineHt,
          lineTva,
          lineTtc,
          lineCost,
        });
      }

      if (discountMru > subtotalTtc + 0.01) {
        throw createHttpError(400, 'La remise ne peut pas dépasser le total TTC');
      }
      const factor = subtotalTtc > 0 ? Math.max(0, (subtotalTtc - discountMru) / subtotalTtc) : 1;
      const totalHt = round2(subtotalHt * factor);
      const totalTva = round2(sumLineTva * factor);
      const totalTtc = round2(subtotalTtc - discountMru);

      // Parse payment tenders
      const rawPayments = Array.isArray(b.payments) && b.payments.length > 0 ? b.payments : null;
      const hasTopPayMethod = pick(b, 'payMethod', 'pay_method') !== undefined;
      const rawMethod = normalizeCommercialPayMethod(pick(b, 'payMethod', 'pay_method') ?? 'Cash', createHttpError);
      const rawTendered = pick(b, 'amountTenderedMru', 'amount_tendered_mru');

      const tenders = [];
      if (rawPayments) {
        if (hasTopPayMethod && rawMethod !== 'Mixte' && !POS_PAY_METHODS.has(rawMethod)) {
          throw createHttpError(400, `Mode de paiement POS non autorisé: ${rawMethod}`);
        }
        for (const pe of rawPayments) {
          const rawPeMethod = pick(pe, 'method', 'payMethod', 'pay_method');
          const mtd = normalizeCommercialPayMethod(rawPeMethod, createHttpError);
          if (!POS_PAY_METHODS.has(mtd)) {
            throw createHttpError(400, `Mode de paiement POS non autorisé dans payments[]: ${mtd}`);
          }
          const rawPeAmt = pick(pe, 'amountMru', 'amount_mru', 'amount');
          const peAmtNum = Number(rawPeAmt);
          if (rawPeAmt === undefined || rawPeAmt === null || rawPeAmt === '' || typeof rawPeAmt === 'boolean' || !Number.isFinite(peAmtNum)) {
            throw createHttpError(400, 'Montant de paiement invalide');
          }
          const amt = round2(peAmtNum);
          if (amt <= 0) throw createHttpError(400, 'Montant de paiement invalide');
          tenders.push({ method: mtd, amountMru: amt, ref: String(pick(pe, 'ref', 'reference') ?? '').trim() });
        }
      } else {
        if (!POS_PAY_METHODS.has(rawMethod)) {
          throw createHttpError(400, `Mode de paiement POS non autorisé: ${rawMethod}`);
        }
        let amt = totalTtc;
        if (rawTendered !== undefined && rawTendered !== null && rawTendered !== '') {
          if (rawMethod === 'Cash') {
            const tenderedNum = Number(rawTendered);
            if (typeof rawTendered === 'boolean' || !Number.isFinite(tenderedNum) || tenderedNum < 0) {
              throw createHttpError(400, 'Montant remis invalide');
            }
            amt = round2(tenderedNum);
          }
        }
        tenders.push({ method: rawMethod, amountMru: amt, ref: '' });
      }

      const sumTendered = round2(tenders.reduce((s, t) => s + t.amountMru, 0));
      if (sumTendered < totalTtc - 0.01) {
        throw createHttpError(400, `Montant encaissé (${sumTendered}) inférieur au total TTC (${totalTtc})`);
      }
      const excess = round2(Math.max(0, sumTendered - totalTtc));
      let cashInTenders = round2(tenders.filter((t) => t.method === 'Cash').reduce((s, t) => s + t.amountMru, 0));
      if (excess > cashInTenders + 0.01) {
        throw createHttpError(400, 'Le rendu monnaie ne peut dépasser le montant espèces');
      }
      const changeMru = excess;

      // Compute net applied per payment method (subtracting change from Cash)
      const byMethod = { Cash: 0, Bankily: 0, Masrivi: 0, Sedad: 0, Bimbank: 0, Click: 0, Karni: 0 };
      let changeToDeduct = changeMru;
      const netTenders = [];
      for (const t of tenders) {
        let netAmt = t.amountMru;
        if (t.method === 'Cash' && changeToDeduct > 0) {
          const take = Math.min(netAmt, changeToDeduct);
          netAmt = round2(netAmt - take);
          changeToDeduct = round2(changeToDeduct - take);
        }
        if (byMethod[t.method] !== undefined) {
          byMethod[t.method] = round2(byMethod[t.method] + netAmt);
        }
        netTenders.push({ method: t.method, tenderedMru: t.amountMru, amountMru: netAmt, ref: t.ref });
      }

      if (byMethod.Karni > 0) {
        if (!client) throw createHttpError(400, 'Un client est requis pour un paiement Karni');
        const invoiceEncoursMru = getClientInvoiceEncours(database, tenantId, client.id);
        const projectedEncours = round2(invoiceEncoursMru + Number(client.current_debt_mru) + byMethod.Karni);
        if (
          Number(client.credit_limit_mru) > 0 &&
          projectedEncours > Number(client.credit_limit_mru) + 0.01
        ) {
          throw createHttpError(400, 'Plafond crédit Karni dépassé');
        }
        database
          .prepare('UPDATE commercial_clients SET current_debt_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
          .run(round2(Number(client.current_debt_mru) + byMethod.Karni), client.id);
      }

      const distinctMethods = netTenders.filter((t) => t.amountMru > 0).map((t) => t.method);
      const effectivePayMethod =
        distinctMethods.length > 1 ? 'Mixte' : distinctMethods[0] || rawMethod;

      const dateStr = todayIso();
      const ticketNumber = nextDocNumber(database, 'commercial_pos_tickets', 'ticket_number', tenantId, 'TKT', dateStr);

      const tInfo = database
        .prepare(`
          INSERT INTO commercial_pos_tickets (
            tenant_id, session_id, client_id, ticket_number, price_tier, status,
            pay_method, payments_json, subtotal_ht_mru, discount_mru, total_ht_mru,
            total_tva_mru, total_ttc_mru, total_cost_mru, amount_tendered_mru, change_mru,
            customer_name, created_at
          ) VALUES (?, ?, ?, ?, ?, 'PAID', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `)
        .run(
          tenantId,
          ses.id,
          client ? client.id : null,
          ticketNumber,
          priceTier,
          effectivePayMethod,
          JSON.stringify(netTenders),
          subtotalHt,
          round2(discountMru),
          totalHt,
          totalTva,
          totalTtc,
          totalCostMru,
          sumTendered,
          changeMru,
          String(pick(b, 'customerName', 'customer_name') ?? (client ? client.name : '')).trim(),
          new Date().toISOString(),
        );
      const ticketId = Number(tInfo.lastInsertRowid);

      const insLine = database.prepare(`
        INSERT INTO commercial_pos_ticket_lines (
          tenant_id, ticket_id, article_id, sku, designation, unit, qty,
          unit_price_ht_mru, unit_price_ttc_mru, discount_pct, tva_rate, is_exempt,
          cost_pmp_mru, line_ht_mru, line_tva_mru, line_ttc_mru, line_cost_mru
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);
      for (const l of lines) {
        insLine.run(
          tenantId,
          ticketId,
          l.articleId,
          l.sku,
          l.designation,
          l.unit,
          l.qty,
          l.unitPriceHt,
          l.unitPriceTtc,
          l.discountPct,
          l.tvaRate,
          l.isExempt,
          l.costPmp,
          l.lineHt,
          l.lineTva,
          l.lineTtc,
          l.lineCost,
        );
        if (l.article && l.article.track_stock) {
          const freshArt = database.prepare('SELECT stock_qty, pmp_cost_mru FROM commercial_articles WHERE id = ?').get(l.article.id);
          const stockBefore = round3(freshArt.stock_qty);
          const stockAfter = round3(stockBefore - l.qty);
          database
            .prepare('UPDATE commercial_articles SET stock_qty = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
            .run(stockAfter, l.article.id);
          database
            .prepare(`
              INSERT INTO commercial_stock_movements (
                tenant_id, article_id, movement_type, qty_delta, unit_cost_mru,
                pmp_before_mru, pmp_after_mru, stock_before, stock_after,
                source_type, source_id, source_number, reason
              ) VALUES (?, ?, 'OUT_POS', ?, ?, ?, ?, ?, ?, 'POS_TICKET', ?, ?, ?)
            `)
            .run(
              tenantId,
              l.article.id,
              -l.qty,
              l.costPmp,
              round2(freshArt.pmp_cost_mru),
              round2(freshArt.pmp_cost_mru),
              stockBefore,
              stockAfter,
              ticketId,
              ticketNumber,
              `Vente caisse ${ticketNumber}`,
            );
        }
      }

      // Post treasury inflows for non-Karni tenders
      for (const mName of ['Cash', 'Bankily', 'Masrivi', 'Sedad', 'Bimbank', 'Click']) {
        const amt = byMethod[mName];
        if (amt > 0) {
          const acc = resolveDefaultTreasuryAccount(database, tenantId, mName);
          if (acc) {
            const newBal = round2(Number(acc.current_balance_mru) + amt);
            database
              .prepare('UPDATE commercial_treasury_accounts SET current_balance_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
              .run(newBal, acc.id);
            database
              .prepare(`
                INSERT INTO commercial_treasury_movements (
                  tenant_id, account_id, movement_date, direction, amount_mru, balance_after_mru,
                  pay_method, category, label, ref, source_type, source_id
                ) VALUES (?, ?, ?, 'IN', ?, ?, ?, 'VENTE_POS', ?, ?, 'POS_TICKET', ?)
              `)
              .run(tenantId, acc.id, dateStr, amt, newBal, mName, `Ticket ${ticketNumber}`, ticketNumber, ticketId);
          }
        }
      }

      // Update POS session totals
      const newCashSales = round2(Number(ses.cash_sales_mru) + byMethod.Cash);
      const newExpectedCash = round2(Number(ses.opening_float_mru) + newCashSales - Number(ses.refund_cash_mru));
      database
        .prepare(`
          UPDATE commercial_pos_sessions SET
            cash_sales_mru = ?, bankily_mru = ?, masrivi_mru = ?, sedad_mru = ?,
            bimbank_mru = ?, click_mru = ?, karni_mru = ?,
            total_sales_ht_mru = ?, total_sales_tva_mru = ?, total_sales_ttc_mru = ?,
            tickets_count = tickets_count + 1, expected_cash_mru = ?, updated_at = CURRENT_TIMESTAMP
          WHERE id = ?
        `)
        .run(
          newCashSales,
          round2(Number(ses.bankily_mru) + byMethod.Bankily),
          round2(Number(ses.masrivi_mru) + byMethod.Masrivi),
          round2(Number(ses.sedad_mru) + byMethod.Sedad),
          round2(Number(ses.bimbank_mru) + byMethod.Bimbank),
          round2(Number(ses.click_mru) + byMethod.Click),
          round2(Number(ses.karni_mru) + byMethod.Karni),
          round2(Number(ses.total_sales_ht_mru) + totalHt),
          round2(Number(ses.total_sales_tva_mru) + totalTva),
          round2(Number(ses.total_sales_ttc_mru) + totalTtc),
          newExpectedCash,
          ses.id,
        );

      const ticketRow = database.prepare('SELECT * FROM commercial_pos_tickets WHERE id = ?').get(ticketId);
      const lineRows = database.prepare('SELECT * FROM commercial_pos_ticket_lines WHERE ticket_id = ? ORDER BY id ASC').all(ticketId);
      const updatedSes = database.prepare('SELECT * FROM commercial_pos_sessions WHERE id = ?').get(ses.id);
      return {
        ticket: serializePosTicket(ticketRow, lineRows.map(serializePosTicketLine), parseJson),
        lines: lineRows.map(serializePosTicketLine),
        session: serializePosSession(updatedSes),
      };
    });

    return sendJson(res, 201, { ok: true, ...result }) || true;
  }

  if (method === 'POST' && (m = p.match(/^\/api\/commercial\/pos\/tickets\/(\d+)\/void$/))) {
    const id = Number(m[1]);
    const b = await readJsonBody(req, standardLimit);
    const reason = String(pick(b, 'reason', 'voidReason', 'void_reason') ?? '').trim() || 'Annulation ticket';

    const result = withTransaction(database, () => {
      const tkt = database.prepare('SELECT * FROM commercial_pos_tickets WHERE id = ? AND tenant_id = ?').get(id, tenantId);
      if (!tkt) throw createHttpError(404, 'Ticket introuvable');
      if (tkt.status === 'VOID') throw createHttpError(400, 'Ticket déjà annulé');

      const ses = database
        .prepare('SELECT * FROM commercial_pos_sessions WHERE id = ? AND tenant_id = ?')
        .get(tkt.session_id, tenantId);
      if (!ses || ses.status !== 'OPEN') {
        throw createHttpError(400, "Impossible d'annuler un ticket d'une session clôturée");
      }

      const lines = database.prepare('SELECT * FROM commercial_pos_ticket_lines WHERE ticket_id = ?').all(id);
      for (const l of lines) {
        if (l.article_id) {
          const art = database.prepare('SELECT * FROM commercial_articles WHERE id = ? AND tenant_id = ?').get(l.article_id, tenantId);
          if (art && art.track_stock) {
            const stockBefore = round3(art.stock_qty);
            const stockAfter = round3(stockBefore + Number(l.qty));
            database
              .prepare('UPDATE commercial_articles SET stock_qty = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
              .run(stockAfter, art.id);
            database
              .prepare(`
                INSERT INTO commercial_stock_movements (
                  tenant_id, article_id, movement_type, qty_delta, unit_cost_mru,
                  pmp_before_mru, pmp_after_mru, stock_before, stock_after,
                  source_type, source_id, source_number, reason
                ) VALUES (?, ?, 'IN_POS_VOID', ?, ?, ?, ?, ?, ?, 'POS_TICKET_VOID', ?, ?, ?)
              `)
              .run(
                tenantId,
                art.id,
                round3(l.qty),
                round2(l.cost_pmp_mru),
                round2(art.pmp_cost_mru),
                round2(art.pmp_cost_mru),
                stockBefore,
                stockAfter,
                id,
                tkt.ticket_number,
                reason,
              );
          }
        }
      }

      const tenders = parseJson(tkt.payments_json, []);
      const byMethod = { Cash: 0, Bankily: 0, Masrivi: 0, Sedad: 0, Bimbank: 0, Click: 0, Karni: 0 };
      if (tenders.length > 0) {
        for (const t of tenders) {
          const mName = t.method;
          if (byMethod[mName] !== undefined) {
            byMethod[mName] = round2(byMethod[mName] + Number(t.amountMru || 0));
          }
        }
      } else if (byMethod[tkt.pay_method] !== undefined) {
        byMethod[tkt.pay_method] = round2(tkt.total_ttc_mru);
      }

      if (byMethod.Karni > 0 && tkt.client_id) {
        const client = database.prepare('SELECT current_debt_mru FROM commercial_clients WHERE id = ?').get(tkt.client_id);
        if (client) {
          database
            .prepare('UPDATE commercial_clients SET current_debt_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
            .run(round2(Math.max(0, Number(client.current_debt_mru) - byMethod.Karni)), tkt.client_id);
        }
      }

      const dateStr = todayIso();
      for (const mName of ['Cash', 'Bankily', 'Masrivi', 'Sedad', 'Bimbank', 'Click']) {
        const amt = byMethod[mName];
        if (amt > 0) {
          const acc = resolveDefaultTreasuryAccount(database, tenantId, mName);
          if (acc) {
            const newBal = round2(Number(acc.current_balance_mru) - amt);
            database
              .prepare('UPDATE commercial_treasury_accounts SET current_balance_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
              .run(newBal, acc.id);
            database
              .prepare(`
                INSERT INTO commercial_treasury_movements (
                  tenant_id, account_id, movement_date, direction, amount_mru, balance_after_mru,
                  pay_method, category, label, ref, source_type, source_id
                ) VALUES (?, ?, ?, 'OUT', ?, ?, ?, 'POS_VOID_REFUND', ?, ?, 'POS_TICKET_VOID', ?)
              `)
              .run(
                tenantId,
                acc.id,
                dateStr,
                amt,
                newBal,
                mName,
                `Annulation ${tkt.ticket_number}`,
                tkt.ticket_number,
                id,
              );
          }
        }
      }

      if (ses) {
        const newRefundCash = round2(Number(ses.refund_cash_mru) + byMethod.Cash);
        const newExpectedCash = round2(Number(ses.opening_float_mru) + Number(ses.cash_sales_mru) - newRefundCash);
        database
          .prepare(`
            UPDATE commercial_pos_sessions SET
              bankily_mru = ?, masrivi_mru = ?, sedad_mru = ?,
              bimbank_mru = ?, click_mru = ?, karni_mru = ?,
              refund_cash_mru = ?,
              total_sales_ht_mru = ?, total_sales_tva_mru = ?, total_sales_ttc_mru = ?,
              expected_cash_mru = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
          `)
          .run(
            round2(Math.max(0, Number(ses.bankily_mru) - byMethod.Bankily)),
            round2(Math.max(0, Number(ses.masrivi_mru) - byMethod.Masrivi)),
            round2(Math.max(0, Number(ses.sedad_mru) - byMethod.Sedad)),
            round2(Math.max(0, Number(ses.bimbank_mru) - byMethod.Bimbank)),
            round2(Math.max(0, Number(ses.click_mru) - byMethod.Click)),
            round2(Math.max(0, Number(ses.karni_mru) - byMethod.Karni)),
            newRefundCash,
            round2(Math.max(0, Number(ses.total_sales_ht_mru) - Number(tkt.total_ht_mru))),
            round2(Math.max(0, Number(ses.total_sales_tva_mru) - Number(tkt.total_tva_mru))),
            round2(Math.max(0, Number(ses.total_sales_ttc_mru) - Number(tkt.total_ttc_mru))),
            newExpectedCash,
            ses.id,
          );
      }

      const voidedAt = new Date().toISOString();
      database
        .prepare("UPDATE commercial_pos_tickets SET status = 'VOID', void_reason = ?, voided_at = ? WHERE id = ?")
        .run(reason, voidedAt, id);

      const updated = database.prepare('SELECT * FROM commercial_pos_tickets WHERE id = ?').get(id);
      return {
        ticket: serializePosTicket(updated, lines.map(serializePosTicketLine), parseJson),
      };
    });

    return sendJson(res, 200, { ok: true, ...result }) || true;
  }

  // --------------------------------------------------------------------------
  // 9. TREASURY ACCOUNTS, MOVEMENTS & ATOMIC TRANSFERS
  // --------------------------------------------------------------------------
  if (method === 'GET' && p === '/api/commercial/treasury/accounts') {
    ensureCommercialDefaults(database, tenantId);
    const accounts = database
      .prepare('SELECT * FROM commercial_treasury_accounts WHERE tenant_id = ? AND active = 1 ORDER BY is_default DESC, id ASC')
      .all(tenantId)
      .map(serializeTreasuryAccount);
    const totalBalanceMru = round2(accounts.reduce((s, a) => s + a.currentBalanceMru, 0));
    return sendJson(res, 200, { ok: true, accounts, totalBalanceMru }) || true;
  }

  if (method === 'POST' && p === '/api/commercial/treasury/accounts') {
    const b = await readJsonBody(req, standardLimit);
    const name = String(pick(b, 'name') ?? '').trim();
    if (!name) throw createHttpError(400, 'Le nom du compte est requis');

    const accountType = String(pick(b, 'accountType', 'account_type') ?? 'CAISSE').trim().toUpperCase();
    if (!ACCOUNT_TYPES.has(accountType)) {
      throw createHttpError(400, `Type de compte invalide: ${accountType}`);
    }
    const rawInitial = pick(b, 'initialBalanceMru', 'initial_balance_mru');
    const initialNum =
      rawInitial !== undefined && rawInitial !== null && rawInitial !== '' ? Number(rawInitial) : 0;
    if (typeof rawInitial === 'boolean' || !Number.isFinite(initialNum)) {
      throw createHttpError(400, 'Solde initial invalide');
    }
    const initialBalanceMru = round2(initialNum);
    const rawCode = String(pick(b, 'code') ?? '').trim();
    const code =
      rawCode ||
      nextSequenceCode(
        database,
        'commercial_treasury_accounts',
        'code',
        tenantId,
        accountType === 'CAISSE' ? 'CAISSE' : accountType === 'BANQUE' ? 'BANQUE' : 'MOB',
        2,
      );
    const isDefault = Boolean(pick(b, 'isDefault', 'is_default')) ? 1 : 0;

    const info = database
      .prepare(`
        INSERT INTO commercial_treasury_accounts (
          tenant_id, code, name, account_type, bank_name, account_number,
          initial_balance_mru, current_balance_mru, is_default, active
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
      `)
      .run(
        tenantId,
        code,
        name,
        accountType,
        String(pick(b, 'bankName', 'bank_name') ?? '').trim(),
        String(pick(b, 'accountNumber', 'account_number') ?? '').trim(),
        initialBalanceMru,
        initialBalanceMru,
        isDefault,
      );
    const acc = database.prepare('SELECT * FROM commercial_treasury_accounts WHERE id = ?').get(Number(info.lastInsertRowid));
    return sendJson(res, 201, { ok: true, account: serializeTreasuryAccount(acc) }) || true;
  }

  if (method === 'GET' && p === '/api/commercial/treasury/movements') {
    const accountId = url.searchParams.get('accountId');
    const direction = String(url.searchParams.get('direction') || '').trim().toUpperCase();
    const category = String(url.searchParams.get('category') || '').trim();
    const from = String(url.searchParams.get('from') || '').trim();
    const to = String(url.searchParams.get('to') || '').trim();
    if (from && !isValidIsoDate(from)) throw createHttpError(400, 'Date from invalide');
    if (to && !isValidIsoDate(to)) throw createHttpError(400, 'Date to invalide');

    let sql = `
      SELECT m.*, a.name AS account_name
      FROM commercial_treasury_movements m
      LEFT JOIN commercial_treasury_accounts a ON a.id = m.account_id
      WHERE m.tenant_id = ?
    `;
    const params = [tenantId];
    if (accountId) {
      sql += ' AND m.account_id = ?';
      params.push(Number(accountId));
    }
    if (direction) {
      sql += ' AND m.direction = ?';
      params.push(direction);
    }
    if (category) {
      sql += ' AND m.category = ?';
      params.push(category);
    }
    if (from) {
      sql += ' AND m.movement_date >= ?';
      params.push(from);
    }
    if (to) {
      sql += ' AND m.movement_date <= ?';
      params.push(to);
    }
    sql += ' ORDER BY m.movement_date DESC, m.id DESC LIMIT 400';

    const rows = database.prepare(sql).all(...params);
    return sendJson(res, 200, { ok: true, movements: rows.map(serializeTreasuryMovement) }) || true;
  }

  if (method === 'POST' && p === '/api/commercial/treasury/movements') {
    const b = await readJsonBody(req, standardLimit);
    const accountId = Number(pick(b, 'accountId', 'account_id'));
    if (!Number.isInteger(accountId) || accountId <= 0) throw createHttpError(400, 'accountId requis');
    const direction = String(pick(b, 'direction') ?? '').trim().toUpperCase();
    if (direction !== 'IN' && direction !== 'OUT') {
      throw createHttpError(400, 'direction doit être IN ou OUT');
    }
    const rawAmount = pick(b, 'amountMru', 'amount_mru', 'amount');
    const amountNum = Number(rawAmount);
    if (rawAmount === undefined || rawAmount === null || rawAmount === '' || typeof rawAmount === 'boolean' || !Number.isFinite(amountNum)) {
      throw createHttpError(400, 'amountMru doit être strictement positif');
    }
    const amountMru = round2(amountNum);
    if (amountMru <= 0) {
      throw createHttpError(400, 'amountMru doit être strictement positif');
    }
    const movementDate = String(pick(b, 'movementDate', 'movement_date') ?? todayIso()).trim();
    if (!isValidIsoDate(movementDate)) throw createHttpError(400, 'movementDate invalide');
    const payMethod = normalizeCommercialPayMethod(pick(b, 'payMethod', 'pay_method') ?? 'Cash', createHttpError);
    const category = String(pick(b, 'category') ?? 'AUTRE').trim().toUpperCase() || 'AUTRE';
    const label = String(pick(b, 'label', 'notes') ?? '').trim();
    const ref = String(pick(b, 'ref', 'reference') ?? '').trim();

    const result = withTransaction(database, () => {
      const acc = database.prepare('SELECT * FROM commercial_treasury_accounts WHERE id = ? AND tenant_id = ?').get(accountId, tenantId);
      if (!acc) throw createHttpError(404, 'Compte de trésorerie introuvable');
      const delta = direction === 'IN' ? amountMru : -amountMru;
      const newBal = round2(Number(acc.current_balance_mru) + delta);
      database
        .prepare('UPDATE commercial_treasury_accounts SET current_balance_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
        .run(newBal, acc.id);
      const info = database
        .prepare(`
          INSERT INTO commercial_treasury_movements (
            tenant_id, account_id, movement_date, direction, amount_mru, balance_after_mru,
            pay_method, category, label, ref, source_type
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'MANUAL')
        `)
        .run(tenantId, acc.id, movementDate, direction, amountMru, newBal, payMethod, category, label, ref);

      const movement = database
        .prepare('SELECT m.*, a.name AS account_name FROM commercial_treasury_movements m LEFT JOIN commercial_treasury_accounts a ON a.id = m.account_id WHERE m.id = ?')
        .get(Number(info.lastInsertRowid));
      const updatedAcc = database.prepare('SELECT * FROM commercial_treasury_accounts WHERE id = ?').get(acc.id);
      return {
        movement: serializeTreasuryMovement(movement),
        account: serializeTreasuryAccount(updatedAcc),
      };
    });

    return sendJson(res, 201, { ok: true, ...result }) || true;
  }

  if (method === 'POST' && p === '/api/commercial/treasury/transfer') {
    const b = await readJsonBody(req, standardLimit);
    const fromAccountId = Number(pick(b, 'fromAccountId', 'from_account_id'));
    const toAccountId = Number(pick(b, 'toAccountId', 'to_account_id'));
    if (!Number.isInteger(fromAccountId) || !Number.isInteger(toAccountId)) {
      throw createHttpError(400, 'fromAccountId et toAccountId sont requis');
    }
    if (fromAccountId === toAccountId) {
      throw createHttpError(400, 'Les comptes source et destination doivent être différents');
    }
    const rawAmount = pick(b, 'amountMru', 'amount_mru', 'amount');
    const amountNum = Number(rawAmount);
    if (rawAmount === undefined || rawAmount === null || rawAmount === '' || typeof rawAmount === 'boolean' || !Number.isFinite(amountNum)) {
      throw createHttpError(400, 'amountMru doit être strictement positif');
    }
    const amountMru = round2(amountNum);
    if (amountMru <= 0) {
      throw createHttpError(400, 'amountMru doit être strictement positif');
    }
    const movementDate = String(pick(b, 'movementDate', 'movement_date') ?? todayIso()).trim();
    if (!isValidIsoDate(movementDate)) throw createHttpError(400, 'movementDate invalide');
    const label = String(pick(b, 'label', 'notes') ?? 'Virement interne').trim();
    const ref = String(pick(b, 'ref', 'reference') ?? '').trim();

    const result = withTransaction(database, () => {
      const fromAcc = database.prepare('SELECT * FROM commercial_treasury_accounts WHERE id = ? AND tenant_id = ?').get(fromAccountId, tenantId);
      const toAcc = database.prepare('SELECT * FROM commercial_treasury_accounts WHERE id = ? AND tenant_id = ?').get(toAccountId, tenantId);
      if (!fromAcc || !toAcc) throw createHttpError(404, 'Compte de trésorerie introuvable');

      const transferGroupId = `TRF-${crypto.randomUUID().slice(0, 8).toUpperCase()}`;
      const newFromBal = round2(Number(fromAcc.current_balance_mru) - amountMru);
      const newToBal = round2(Number(toAcc.current_balance_mru) + amountMru);

      database
        .prepare('UPDATE commercial_treasury_accounts SET current_balance_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
        .run(newFromBal, fromAcc.id);
      database
        .prepare('UPDATE commercial_treasury_accounts SET current_balance_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
        .run(newToBal, toAcc.id);

      const outInfo = database
        .prepare(`
          INSERT INTO commercial_treasury_movements (
            tenant_id, account_id, transfer_account_id, transfer_group_id,
            movement_date, direction, amount_mru, balance_after_mru,
            pay_method, category, label, ref, source_type
          ) VALUES (?, ?, ?, ?, ?, 'OUT', ?, ?, 'Virement', 'INTERNAL_TRANSFER', ?, ?, 'TRANSFER')
        `)
        .run(tenantId, fromAcc.id, toAcc.id, transferGroupId, movementDate, amountMru, newFromBal, `${label} -> ${toAcc.name}`, ref);

      const inInfo = database
        .prepare(`
          INSERT INTO commercial_treasury_movements (
            tenant_id, account_id, transfer_account_id, transfer_group_id,
            movement_date, direction, amount_mru, balance_after_mru,
            pay_method, category, label, ref, source_type
          ) VALUES (?, ?, ?, ?, ?, 'IN', ?, ?, 'Virement', 'INTERNAL_TRANSFER', ?, ?, 'TRANSFER')
        `)
        .run(tenantId, toAcc.id, fromAcc.id, transferGroupId, movementDate, amountMru, newToBal, `${label} <- ${fromAcc.name}`, ref);

      const getMvt = database.prepare('SELECT m.*, a.name AS account_name FROM commercial_treasury_movements m LEFT JOIN commercial_treasury_accounts a ON a.id = m.account_id WHERE m.id = ?');
      return {
        transferGroupId,
        outMovement: serializeTreasuryMovement(getMvt.get(Number(outInfo.lastInsertRowid))),
        inMovement: serializeTreasuryMovement(getMvt.get(Number(inInfo.lastInsertRowid))),
        fromAccount: serializeTreasuryAccount(database.prepare('SELECT * FROM commercial_treasury_accounts WHERE id = ?').get(fromAcc.id)),
        toAccount: serializeTreasuryAccount(database.prepare('SELECT * FROM commercial_treasury_accounts WHERE id = ?').get(toAcc.id)),
      };
    });

    return sendJson(res, 201, { ok: true, ...result }) || true;
  }

  // --------------------------------------------------------------------------
  // 10. CHEQUES & TRAITES A ECHEANCE
  // --------------------------------------------------------------------------
  if (method === 'GET' && p === '/api/commercial/cheques') {
    const direction = String(url.searchParams.get('direction') || '').trim().toUpperCase();
    const status = String(url.searchParams.get('status') || '').trim().toUpperCase();
    const dueSoon = url.searchParams.get('dueSoon') === '1';
    const from = String(url.searchParams.get('from') || '').trim();
    const to = String(url.searchParams.get('to') || '').trim();
    if (from && !isValidIsoDate(from)) throw createHttpError(400, 'Date from invalide');
    if (to && !isValidIsoDate(to)) throw createHttpError(400, 'Date to invalide');

    let sql = 'SELECT * FROM commercial_cheques_drafts WHERE tenant_id = ?';
    const params = [tenantId];
    if (direction) {
      sql += ' AND direction = ?';
      params.push(direction);
    }
    if (status) {
      sql += ' AND status = ?';
      params.push(status);
    }
    if (dueSoon) {
      sql += " AND status IN ('EN_PORTEFEUILLE','DEPOSE','EMIS') AND due_date <= ?";
      params.push(addDaysIso(todayIso(), 7));
    }
    if (from) {
      sql += ' AND due_date >= ?';
      params.push(from);
    }
    if (to) {
      sql += ' AND due_date <= ?';
      params.push(to);
    }
    sql += ' ORDER BY due_date ASC, id DESC LIMIT 300';

    const cheques = database.prepare(sql).all(...params).map(serializeCheque);
    return sendJson(res, 200, { ok: true, cheques }) || true;
  }

  if (method === 'POST' && p === '/api/commercial/cheques') {
    const b = await readJsonBody(req, standardLimit);
    const direction = String(pick(b, 'direction') ?? 'CLIENT').trim().toUpperCase();
    if (direction !== 'CLIENT' && direction !== 'FOURNISSEUR') {
      throw createHttpError(400, 'direction doit être CLIENT ou FOURNISSEUR');
    }
    const instrumentType = String(pick(b, 'instrumentType', 'instrument_type') ?? 'CHEQUE').trim().toUpperCase();
    if (instrumentType !== 'CHEQUE' && instrumentType !== 'TRAITE') {
      throw createHttpError(400, 'instrumentType doit être CHEQUE ou TRAITE');
    }
    const number = String(pick(b, 'number', 'ref') ?? '').trim();
    if (!number) throw createHttpError(400, 'Numéro de chèque/traite requis');

    const issueDate = String(pick(b, 'issueDate', 'issue_date') ?? todayIso()).trim();
    const dueDate = String(pick(b, 'dueDate', 'due_date') ?? '').trim();
    if (!isValidIsoDate(issueDate) || !isValidIsoDate(dueDate)) {
      throw createHttpError(400, 'issueDate et dueDate valides (YYYY-MM-DD) requis');
    }
    const rawAmount = pick(b, 'amountMru', 'amount_mru', 'amount');
    const amountNum = Number(rawAmount);
    if (rawAmount === undefined || rawAmount === null || rawAmount === '' || typeof rawAmount === 'boolean' || !Number.isFinite(amountNum)) {
      throw createHttpError(400, 'amountMru doit être strictement positif');
    }
    const amountMru = round2(amountNum);
    if (amountMru <= 0) {
      throw createHttpError(400, 'amountMru doit être strictement positif');
    }

    const rawClientId = pick(b, 'clientId', 'client_id');
    const rawSupplierId = pick(b, 'supplierId', 'supplier_id');
    const rawSalesDocId = pick(b, 'salesDocId', 'sales_doc_id');
    const rawPurchaseDocId = pick(b, 'purchaseDocId', 'purchase_doc_id');

    let partyName = String(pick(b, 'partyName', 'party_name') ?? '').trim();
    let clientId = null;
    let supplierId = null;
    let salesDocId = null;
    let purchaseDocId = null;

    if (rawClientId) {
      const c = database.prepare('SELECT id, name FROM commercial_clients WHERE id = ? AND tenant_id = ?').get(Number(rawClientId), tenantId);
      if (!c) throw createHttpError(404, 'Client introuvable');
      clientId = c.id;
      if (!partyName) partyName = c.name;
    }
    if (rawSupplierId) {
      const s = database.prepare('SELECT id, name FROM commercial_suppliers WHERE id = ? AND tenant_id = ?').get(Number(rawSupplierId), tenantId);
      if (!s) throw createHttpError(404, 'Fournisseur introuvable');
      supplierId = s.id;
      if (!partyName) partyName = s.name;
    }
    if (rawSalesDocId) {
      if (direction !== 'CLIENT') {
        throw createHttpError(400, 'Un effet FOURNISSEUR ne peut pas être lié à un document vente');
      }
      const d = database.prepare('SELECT id, client_id, client_name, doc_type, status FROM commercial_sales_docs WHERE id = ? AND tenant_id = ?').get(Number(rawSalesDocId), tenantId);
      if (!d) throw createHttpError(404, 'Document vente introuvable');
      if (d.doc_type !== 'FACTURE' || !['VALIDEE', 'PARTIELLE'].includes(d.status)) {
        throw createHttpError(400, 'Un chèque client doit être lié à une facture validée non soldée');
      }
      salesDocId = d.id;
      if (!clientId) clientId = d.client_id;
      if (!partyName) partyName = d.client_name;
    }
    if (rawPurchaseDocId) {
      if (direction !== 'FOURNISSEUR') {
        throw createHttpError(400, 'Un effet CLIENT ne peut pas être lié à un document achat');
      }
      const d = database.prepare('SELECT id, supplier_id, supplier_name, doc_type, status FROM commercial_purchase_docs WHERE id = ? AND tenant_id = ?').get(Number(rawPurchaseDocId), tenantId);
      if (!d) throw createHttpError(404, 'Document achat introuvable');
      if (d.doc_type !== 'FACTURE_FOURNISSEUR' || !['VALIDEE', 'PARTIELLE'].includes(d.status)) {
        throw createHttpError(400, 'Un chèque fournisseur doit être lié à une facture fournisseur validée non soldée');
      }
      purchaseDocId = d.id;
      if (!supplierId) supplierId = d.supplier_id;
      if (!partyName) partyName = d.supplier_name;
    }

    const initialStatus = direction === 'CLIENT' ? 'EN_PORTEFEUILLE' : 'EMIS';
    const info = database
      .prepare(`
        INSERT INTO commercial_cheques_drafts (
          tenant_id, direction, instrument_type, number, bank_name,
          client_id, supplier_id, sales_doc_id, purchase_doc_id,
          party_name, issue_date, due_date, amount_mru, status, notes
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `)
      .run(
        tenantId,
        direction,
        instrumentType,
        number,
        String(pick(b, 'bankName', 'bank_name') ?? '').trim(),
        clientId,
        supplierId,
        salesDocId,
        purchaseDocId,
        partyName,
        issueDate,
        dueDate,
        amountMru,
        initialStatus,
        String(pick(b, 'notes') ?? '').trim(),
      );

    const chq = database.prepare('SELECT * FROM commercial_cheques_drafts WHERE id = ?').get(Number(info.lastInsertRowid));
    return sendJson(res, 201, { ok: true, cheque: serializeCheque(chq) }) || true;
  }

  if (method === 'PATCH' && (m = p.match(/^\/api\/commercial\/cheques\/(\d+)\/status$/))) {
    const id = Number(m[1]);
    const b = await readJsonBody(req, standardLimit);
    const nextStatus = String(pick(b, 'status') ?? '').trim().toUpperCase();
    const reqAccId = pick(b, 'treasuryAccountId', 'treasury_account_id');
    const collectedAt = String(pick(b, 'collectedAt', 'collected_at') ?? todayIso()).trim();
    if (!isValidIsoDate(collectedAt)) throw createHttpError(400, 'Date invalide');

    const result = withTransaction(database, () => {
      const chq = database.prepare('SELECT * FROM commercial_cheques_drafts WHERE id = ? AND tenant_id = ?').get(id, tenantId);
      if (!chq) throw createHttpError(404, 'Chèque/traite introuvable');

      const validStatuses =
        chq.direction === 'CLIENT'
          ? new Set(['EN_PORTEFEUILLE', 'DEPOSE', 'ENCAISSE', 'IMPAYE', 'ANNULE'])
          : new Set(['EMIS', 'DECAISSE', 'IMPAYE', 'ANNULE']);
      if (!validStatuses.has(nextStatus)) {
        throw createHttpError(400, `Statut invalide pour ${chq.direction}: ${nextStatus}`);
      }
      if (chq.status === nextStatus) {
        return { cheque: serializeCheque(chq) };
      }

      const allowedTransitions =
        chq.direction === 'CLIENT'
          ? {
              EN_PORTEFEUILLE: new Set(['DEPOSE', 'ENCAISSE', 'IMPAYE', 'ANNULE']),
              DEPOSE: new Set(['ENCAISSE', 'IMPAYE', 'ANNULE']),
              ENCAISSE: new Set(['IMPAYE']),
              IMPAYE: new Set(),
              ANNULE: new Set(),
            }
          : {
              EMIS: new Set(['DECAISSE', 'IMPAYE', 'ANNULE']),
              DECAISSE: new Set(['IMPAYE']),
              IMPAYE: new Set(),
              ANNULE: new Set(),
            };
      const allowedNext = allowedTransitions[chq.status] || new Set();
      if (!allowedNext.has(nextStatus)) {
        throw createHttpError(400, `Transition de statut interdite: ${chq.status} -> ${nextStatus}`);
      }

      let treasuryAccountId = chq.treasury_account_id;
      let finalCollectedAt = chq.collected_at;
      const amt = round2(chq.amount_mru);

      if (nextStatus === 'ENCAISSE') {
        if (chq.direction !== 'CLIENT') throw createHttpError(400, 'Seuls les effets CLIENT peuvent être encaissés');
        if (!reqAccId) throw createHttpError(400, 'treasuryAccountId est requis pour encaisser un chèque');
        const acc = database.prepare('SELECT * FROM commercial_treasury_accounts WHERE id = ? AND tenant_id = ?').get(Number(reqAccId), tenantId);
        if (!acc) throw createHttpError(404, 'Compte de trésorerie introuvable');
        treasuryAccountId = acc.id;
        finalCollectedAt = collectedAt;

        const newBal = round2(Number(acc.current_balance_mru) + amt);
        database
          .prepare('UPDATE commercial_treasury_accounts SET current_balance_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
          .run(newBal, acc.id);
        database
          .prepare(`
            INSERT INTO commercial_treasury_movements (
              tenant_id, account_id, movement_date, direction, amount_mru, balance_after_mru,
              pay_method, category, label, ref, source_type, source_id
            ) VALUES (?, ?, ?, 'IN', ?, ?, ?, 'ENCAISSEMENT_CHEQUE', ?, ?, 'CHEQUE', ?)
          `)
          .run(
            tenantId,
            acc.id,
            collectedAt,
            amt,
            newBal,
            chq.instrument_type === 'TRAITE' ? 'Traite' : 'Chèque',
            `Encaissement ${chq.instrument_type} ${chq.number} · ${chq.party_name}`,
            chq.number,
            chq.id,
          );

        if (chq.sales_doc_id) {
          const doc = database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ? AND tenant_id = ?').get(chq.sales_doc_id, tenantId);
          if (doc) {
            const nextPaid = round2(Number(doc.paid_mru) + amt);
            const nextDocStatus = nextPaid + Number(doc.credited_mru) >= Number(doc.total_ttc_mru) - 0.01 ? 'PAYEE' : 'PARTIELLE';
            database
              .prepare('UPDATE commercial_sales_docs SET paid_mru = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
              .run(nextPaid, nextDocStatus, doc.id);
          }
          database
            .prepare("UPDATE commercial_payments SET status = 'POSTED', treasury_account_id = ? WHERE tenant_id = ? AND cheque_draft_id = ?")
            .run(acc.id, tenantId, chq.id);
        }
      } else if (nextStatus === 'DECAISSE') {
        if (chq.direction !== 'FOURNISSEUR') throw createHttpError(400, 'Seuls les effets FOURNISSEUR peuvent être décaissés');
        if (!reqAccId) throw createHttpError(400, 'treasuryAccountId est requis pour décaisser un chèque');
        const acc = database.prepare('SELECT * FROM commercial_treasury_accounts WHERE id = ? AND tenant_id = ?').get(Number(reqAccId), tenantId);
        if (!acc) throw createHttpError(404, 'Compte de trésorerie introuvable');
        treasuryAccountId = acc.id;
        finalCollectedAt = collectedAt;

        const newBal = round2(Number(acc.current_balance_mru) - amt);
        database
          .prepare('UPDATE commercial_treasury_accounts SET current_balance_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
          .run(newBal, acc.id);
        database
          .prepare(`
            INSERT INTO commercial_treasury_movements (
              tenant_id, account_id, movement_date, direction, amount_mru, balance_after_mru,
              pay_method, category, label, ref, source_type, source_id
            ) VALUES (?, ?, ?, 'OUT', ?, ?, ?, 'PAIEMENT_CHEQUE_FOURNISSEUR', ?, ?, 'CHEQUE', ?)
          `)
          .run(
            tenantId,
            acc.id,
            collectedAt,
            amt,
            newBal,
            chq.instrument_type === 'TRAITE' ? 'Traite' : 'Chèque',
            `Décaissement ${chq.instrument_type} ${chq.number} · ${chq.party_name}`,
            chq.number,
            chq.id,
          );

        if (chq.purchase_doc_id) {
          const doc = database.prepare('SELECT * FROM commercial_purchase_docs WHERE id = ? AND tenant_id = ?').get(chq.purchase_doc_id, tenantId);
          if (doc) {
            const nextPaid = round2(Number(doc.paid_mru) + amt);
            const nextDocStatus = nextPaid + Number(doc.credited_mru) >= Number(doc.total_ttc_mru) - 0.01 ? 'PAYEE' : 'PARTIELLE';
            database
              .prepare('UPDATE commercial_purchase_docs SET paid_mru = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
              .run(nextPaid, nextDocStatus, doc.id);
          }
          if (chq.supplier_id) syncSupplierBalanceDue(database, tenantId, chq.supplier_id);
          database
            .prepare("UPDATE commercial_payments SET status = 'POSTED', treasury_account_id = ? WHERE tenant_id = ? AND cheque_draft_id = ?")
            .run(acc.id, tenantId, chq.id);
        }
      } else if (nextStatus === 'IMPAYE') {
        if (chq.status === 'ENCAISSE') {
          const accId = Number(reqAccId || chq.treasury_account_id);
          if (accId) {
            const acc = database.prepare('SELECT * FROM commercial_treasury_accounts WHERE id = ? AND tenant_id = ?').get(accId, tenantId);
            if (acc) {
              const newBal = round2(Number(acc.current_balance_mru) - amt);
              database
                .prepare('UPDATE commercial_treasury_accounts SET current_balance_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
                .run(newBal, acc.id);
              database
                .prepare(`
                  INSERT INTO commercial_treasury_movements (
                    tenant_id, account_id, movement_date, direction, amount_mru, balance_after_mru,
                    pay_method, category, label, ref, source_type, source_id
                  ) VALUES (?, ?, ?, 'OUT', ?, ?, ?, 'IMPAYE_CHEQUE', ?, ?, 'CHEQUE_IMPAYE', ?)
                `)
                .run(
                  tenantId,
                  acc.id,
                  collectedAt,
                  amt,
                  newBal,
                  chq.instrument_type === 'TRAITE' ? 'Traite' : 'Chèque',
                  `Rejet impayé ${chq.number} · ${chq.party_name}`,
                  chq.number,
                  chq.id,
                );
            }
          }
          if (chq.sales_doc_id) {
            const doc = database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ? AND tenant_id = ?').get(chq.sales_doc_id, tenantId);
            if (doc) {
              const nextPaid = round2(Math.max(0, Number(doc.paid_mru) - amt));
              const nextDocStatus =
                nextPaid + Number(doc.credited_mru) > 0.01 ? 'PARTIELLE' : 'VALIDEE';
              database
                .prepare('UPDATE commercial_sales_docs SET paid_mru = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
                .run(nextPaid, nextDocStatus, doc.id);
            }
          }
        } else if (chq.status === 'DECAISSE') {
          const accId = Number(reqAccId || chq.treasury_account_id);
          if (accId) {
            const acc = database.prepare('SELECT * FROM commercial_treasury_accounts WHERE id = ? AND tenant_id = ?').get(accId, tenantId);
            if (acc) {
              const newBal = round2(Number(acc.current_balance_mru) + amt);
              database
                .prepare('UPDATE commercial_treasury_accounts SET current_balance_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
                .run(newBal, acc.id);
              database
                .prepare(`
                  INSERT INTO commercial_treasury_movements (
                    tenant_id, account_id, movement_date, direction, amount_mru, balance_after_mru,
                    pay_method, category, label, ref, source_type, source_id
                  ) VALUES (?, ?, ?, 'IN', ?, ?, ?, 'IMPAYE_CHEQUE_FOURNISSEUR', ?, ?, 'CHEQUE_IMPAYE', ?)
                `)
                .run(
                  tenantId,
                  acc.id,
                  collectedAt,
                  amt,
                  newBal,
                  chq.instrument_type === 'TRAITE' ? 'Traite' : 'Chèque',
                  `Annulation décaissement impayé ${chq.number}`,
                  chq.number,
                  chq.id,
                );
            }
          }
          if (chq.purchase_doc_id) {
            const doc = database.prepare('SELECT * FROM commercial_purchase_docs WHERE id = ? AND tenant_id = ?').get(chq.purchase_doc_id, tenantId);
            if (doc) {
              const nextPaid = round2(Math.max(0, Number(doc.paid_mru) - amt));
              const nextDocStatus =
                nextPaid + Number(doc.credited_mru) > 0.01 ? 'PARTIELLE' : 'VALIDEE';
              database
                .prepare('UPDATE commercial_purchase_docs SET paid_mru = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
                .run(nextPaid, nextDocStatus, doc.id);
            }
            if (chq.supplier_id) syncSupplierBalanceDue(database, tenantId, chq.supplier_id);
          }
        }
        database
          .prepare("UPDATE commercial_payments SET status = 'REVERSED' WHERE tenant_id = ? AND cheque_draft_id = ?")
          .run(tenantId, chq.id);
      } else if (nextStatus === 'ANNULE') {
        database
          .prepare("UPDATE commercial_payments SET status = 'REVERSED' WHERE tenant_id = ? AND cheque_draft_id = ? AND status = 'PENDING'")
          .run(tenantId, chq.id);
      }

      database
        .prepare(`
          UPDATE commercial_cheques_drafts SET
            status = ?, treasury_account_id = ?, collected_at = ?,
            notes = CASE WHEN ? != '' THEN ? ELSE notes END,
            updated_at = CURRENT_TIMESTAMP
          WHERE id = ? AND tenant_id = ?
        `)
        .run(
          nextStatus,
          treasuryAccountId,
          finalCollectedAt,
          String(pick(b, 'notes') ?? '').trim(),
          String(pick(b, 'notes') ?? '').trim(),
          id,
          tenantId,
        );

      const updated = database.prepare('SELECT * FROM commercial_cheques_drafts WHERE id = ?').get(id);
      return { cheque: serializeCheque(updated) };
    });

    return sendJson(res, 200, { ok: true, ...result }) || true;
  }

  // --------------------------------------------------------------------------
  // 11. OBJECTIVES (OBJECTIFS MENSUELS)
  // --------------------------------------------------------------------------
  if (method === 'GET' && p === '/api/commercial/objectives') {
    const rawYear = url.searchParams.get('year');
    const year = rawYear ? Number(rawYear) : new Date().getUTCFullYear();
    if (!Number.isInteger(year) || year < 2000 || year > 2100) {
      throw createHttpError(400, 'Année invalide (2000-2100)');
    }
    const payload = buildObjectivesPayload(database, tenantId, year);
    return sendJson(res, 200, payload) || true;
  }

  if (method === 'PUT' && p === '/api/commercial/objectives') {
    const b = await readJsonBody(req, standardLimit);
    const items = Array.isArray(b.items) ? b.items : [b];
    if (items.length === 0) throw createHttpError(400, 'Aucun objectif fourni');

    const baseYear = b.year !== undefined ? Number(b.year) : undefined;
    let effectiveYear = baseYear;

    withTransaction(database, () => {
      const upsert = database.prepare(`
        INSERT INTO commercial_objectives (tenant_id, year, month, target_ca_ht_mru, target_margin_pct, notes)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(tenant_id, year, month) DO UPDATE SET
          target_ca_ht_mru = excluded.target_ca_ht_mru,
          target_margin_pct = excluded.target_margin_pct,
          notes = excluded.notes,
          updated_at = CURRENT_TIMESTAMP
      `);

      for (const item of items) {
        const y = Number(item.year !== undefined ? item.year : baseYear);
        const month = Number(item.month);
        if (!Number.isInteger(y) || y < 2000 || y > 2100) {
          throw createHttpError(400, `Année invalide: ${item.year ?? baseYear}`);
        }
        if (!Number.isInteger(month) || month < 1 || month > 12) {
          throw createHttpError(400, `Mois invalide (1-12): ${item.month}`);
        }
        effectiveYear = y;
        const rawTargetCa = pick(item, 'targetCaHtMru', 'target_ca_ht_mru');
        const targetCaNum =
          rawTargetCa !== undefined && rawTargetCa !== null && rawTargetCa !== '' ? Number(rawTargetCa) : 0;
        if (typeof rawTargetCa === 'boolean' || !Number.isFinite(targetCaNum) || targetCaNum < 0) {
          throw createHttpError(400, 'Objectif CA HT invalide');
        }
        const targetCaHtMru = round2(targetCaNum);
        const rawMargin = pick(item, 'targetMarginPct', 'target_margin_pct');
        let targetMarginPct = null;
        if (rawMargin !== undefined && rawMargin !== null && rawMargin !== '') {
          const marginNum = Number(rawMargin);
          if (typeof rawMargin === 'boolean' || !Number.isFinite(marginNum) || marginNum < 0 || marginNum > 100) {
            throw createHttpError(400, 'Objectif taux de marge invalide');
          }
          targetMarginPct = round1(marginNum);
        }
        const notes = String(pick(item, 'notes') ?? '').trim();
        upsert.run(tenantId, y, month, targetCaHtMru, targetMarginPct, notes);
      }
    });

    const payload = buildObjectivesPayload(database, tenantId, effectiveYear || new Date().getUTCFullYear());
    return sendJson(res, 200, payload) || true;
  }

  return false;
}

// ============================================================================
// INTERNAL TRANSACTION HELPERS
// ============================================================================

function insertSalesLines(database, tenantId, docId, lines) {
  const ins = database.prepare(`
    INSERT INTO commercial_sales_lines (
      tenant_id, doc_id, article_id, line_order, sku, designation, unit, qty,
      unit_price_ht_mru, discount_pct, tva_rate, is_exempt, cost_pmp_mru,
      line_ht_mru, line_tva_mru, line_ttc_mru, line_cost_mru
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  for (const l of lines) {
    ins.run(
      tenantId,
      docId,
      l.articleId,
      l.lineOrder,
      l.sku,
      l.designation,
      l.unit,
      l.qty,
      l.unitPrice,
      l.discountPct,
      l.tvaRate,
      l.isExempt,
      l.costPmpMru,
      l.lineHt,
      l.lineTva,
      l.lineTtc,
      l.lineCostMru,
    );
  }
}

function insertPurchaseLines(database, tenantId, docId, lines) {
  const ins = database.prepare(`
    INSERT INTO commercial_purchase_lines (
      tenant_id, doc_id, article_id, line_order, sku, designation, unit, qty,
      unit_cost_ht_mru, discount_pct, tva_rate, is_exempt,
      line_ht_mru, line_tva_mru, line_ttc_mru
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  for (const l of lines) {
    ins.run(
      tenantId,
      docId,
      l.articleId,
      l.lineOrder,
      l.sku,
      l.designation,
      l.unit,
      l.qty,
      l.unitPrice,
      l.discountPct,
      l.tvaRate,
      l.isExempt,
      l.lineHt,
      l.lineTva,
      l.lineTtc,
    );
  }
}

function validateSalesDocTx(database, tenantId, docId, actor, nowHM, createHttpError) {
  const doc = database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ? AND tenant_id = ?').get(docId, tenantId);
  if (!doc) throw createHttpError(404, 'Document vente introuvable');
  if (doc.status !== 'BROUILLON') {
    throw createHttpError(400, `Document déjà validé ou clôturé (${doc.status})`);
  }

  const lines = database.prepare('SELECT * FROM commercial_sales_lines WHERE doc_id = ? ORDER BY line_order ASC').all(docId);
  const nowIso = new Date().toISOString();

  // Snapshot cost_pmp_mru (unless already deducted via BL -> Facture conversion)
  let totalCostMru = 0;
  for (const l of lines) {
    let costPmp = round2(l.cost_pmp_mru);
    if (l.article_id && !doc.stock_deducted) {
      const art = database.prepare('SELECT pmp_cost_mru FROM commercial_articles WHERE id = ? AND tenant_id = ?').get(l.article_id, tenantId);
      if (art) costPmp = round2(art.pmp_cost_mru);
    }
    const lineCost = round2(Number(l.qty) * costPmp);
    totalCostMru = round2(totalCostMru + lineCost);
    database
      .prepare('UPDATE commercial_sales_lines SET cost_pmp_mru = ?, line_cost_mru = ? WHERE id = ?')
      .run(costPmp, lineCost, l.id);
  }

  let nextStatus = 'VALIDEE';
  let stockDeducted = Number(doc.stock_deducted);

  if (doc.doc_type === 'DEVIS') {
    nextStatus = 'ENVOYE';
  } else if (doc.doc_type === 'COMMANDE') {
    nextStatus = 'CONFIRMEE';
  } else if (doc.doc_type === 'BL' || doc.doc_type === 'FACTURE') {
    nextStatus = doc.doc_type === 'BL' ? 'VALIDE' : 'VALIDEE';
    if (!stockDeducted) {
      const mvtType = doc.doc_type === 'BL' ? 'OUT_BL' : 'OUT_FACTURE';
      for (const l of lines) {
        if (!l.article_id) continue;
        const art = database.prepare('SELECT * FROM commercial_articles WHERE id = ? AND tenant_id = ?').get(l.article_id, tenantId);
        if (art && art.track_stock) {
          const stockBefore = round3(art.stock_qty);
          const stockAfter = round3(stockBefore - Number(l.qty));
          database
            .prepare('UPDATE commercial_articles SET stock_qty = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
            .run(stockAfter, art.id);
          database
            .prepare(`
              INSERT INTO commercial_stock_movements (
                tenant_id, article_id, movement_type, qty_delta, unit_cost_mru,
                pmp_before_mru, pmp_after_mru, stock_before, stock_after,
                source_type, source_id, source_number, reason
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `)
            .run(
              tenantId,
              art.id,
              mvtType,
              -round3(l.qty),
              round2(art.pmp_cost_mru),
              round2(art.pmp_cost_mru),
              round2(art.pmp_cost_mru),
              stockBefore,
              stockAfter,
              doc.doc_type,
              doc.id,
              doc.doc_number,
              `Validation ${doc.doc_number}`,
            );
        }
      }
      stockDeducted = 1;
    }
  } else if (doc.doc_type === 'AVOIR') {
    nextStatus = 'VALIDEE';
    if (doc.source_doc_id) {
      const srcInv = database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ? AND tenant_id = ?').get(doc.source_doc_id, tenantId);
      if (!srcInv || srcInv.doc_type !== 'FACTURE') {
        throw createHttpError(400, 'Facture source introuvable pour cet avoir');
      }
      const maxCredit = round2(Number(srcInv.total_ttc_mru) - Number(srcInv.credited_mru));
      if (Number(doc.total_ttc_mru) > maxCredit + 0.01) {
        throw createHttpError(400, `Montant de l'avoir (${doc.total_ttc_mru}) supérieur au solde créditable (${maxCredit})`);
      }
      const nextCredited = round2(Number(srcInv.credited_mru) + Number(doc.total_ttc_mru));
      let nextPaid = round2(Number(srcInv.paid_mru));
      const excessCredit = round2(nextPaid + nextCredited - Number(srcInv.total_ttc_mru));
      if (excessCredit > 0.01 && srcInv.client_id) {
        const karniRow = database
          .prepare(`
            SELECT COALESCE(SUM(amount_mru), 0) AS s
            FROM commercial_payments
            WHERE tenant_id = ? AND sales_doc_id = ? AND pay_method = 'Karni' AND status = 'POSTED'
          `)
          .get(tenantId, srcInv.id);
        const karniPaidOnInv = round2(karniRow ? karniRow.s : 0);
        if (karniPaidOnInv > 0) {
          const cli = database
            .prepare('SELECT id, current_debt_mru FROM commercial_clients WHERE id = ? AND tenant_id = ?')
            .get(srcInv.client_id, tenantId);
          if (cli && Number(cli.current_debt_mru) > 0) {
            const karniReduction = round2(
              Math.min(Number(cli.current_debt_mru), karniPaidOnInv, nextPaid, excessCredit),
            );
            if (karniReduction > 0) {
              nextPaid = round2(Math.max(0, nextPaid - karniReduction));
              database
                .prepare('UPDATE commercial_clients SET current_debt_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND tenant_id = ?')
                .run(round2(Math.max(0, Number(cli.current_debt_mru) - karniReduction)), cli.id, tenantId);
            }
          }
        }
      }
      const nextInvStatus =
        nextPaid + nextCredited >= Number(srcInv.total_ttc_mru) - 0.01
          ? 'PAYEE'
          : nextPaid + nextCredited > 0.01
          ? 'PARTIELLE'
          : srcInv.status;
      database
        .prepare('UPDATE commercial_sales_docs SET paid_mru = ?, credited_mru = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
        .run(nextPaid, nextCredited, nextInvStatus, srcInv.id);
    }
    if (doc.restock_on_validate) {
      for (const l of lines) {
        if (!l.article_id) continue;
        const art = database.prepare('SELECT * FROM commercial_articles WHERE id = ? AND tenant_id = ?').get(l.article_id, tenantId);
        if (art && art.track_stock) {
          const stockBefore = round3(art.stock_qty);
          const stockAfter = round3(stockBefore + Number(l.qty));
          database
            .prepare('UPDATE commercial_articles SET stock_qty = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
            .run(stockAfter, art.id);
          database
            .prepare(`
              INSERT INTO commercial_stock_movements (
                tenant_id, article_id, movement_type, qty_delta, unit_cost_mru,
                pmp_before_mru, pmp_after_mru, stock_before, stock_after,
                source_type, source_id, source_number, reason
              ) VALUES (?, ?, 'IN_AVOIR', ?, ?, ?, ?, ?, ?, 'AVOIR', ?, ?, ?)
            `)
            .run(
              tenantId,
              art.id,
              round3(l.qty),
              round2(art.pmp_cost_mru),
              round2(art.pmp_cost_mru),
              round2(art.pmp_cost_mru),
              stockBefore,
              stockAfter,
              doc.id,
              doc.doc_number,
              `Retour avoir ${doc.doc_number}`,
            );
        }
      }
    }
  }

  database
    .prepare(`
      UPDATE commercial_sales_docs SET
        status = ?, total_cost_mru = ?, stock_deducted = ?, validated_at = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND tenant_id = ?
    `)
    .run(nextStatus, totalCostMru, stockDeducted, nowIso, docId, tenantId);

  insertAudit(
    database,
    tenantId,
    actor,
    'COMM_SALES_VALIDATE',
    `Validation ${doc.doc_number}`,
    `${doc.doc_type} · ${doc.client_name} · ${round2(doc.total_ttc_mru)} MRU`,
    'commercial_sales_doc',
    doc.id,
    { status: doc.status },
    { status: nextStatus, stockDeducted: Boolean(stockDeducted) },
    nowHM,
  );

  const updatedDoc = database.prepare('SELECT * FROM commercial_sales_docs WHERE id = ?').get(docId);
  const updatedLines = database.prepare('SELECT * FROM commercial_sales_lines WHERE doc_id = ? ORDER BY line_order ASC').all(docId);
  return {
    doc: serializeSalesDoc(updatedDoc),
    lines: updatedLines.map(serializeSalesLine),
  };
}

function validatePurchaseDocTx(database, tenantId, docId, actor, nowHM, createHttpError) {
  const doc = database.prepare('SELECT * FROM commercial_purchase_docs WHERE id = ? AND tenant_id = ?').get(docId, tenantId);
  if (!doc) throw createHttpError(404, 'Document achat introuvable');
  if (doc.status !== 'BROUILLON') {
    throw createHttpError(400, `Document achat déjà validé ou clôturé (${doc.status})`);
  }

  const lines = database.prepare('SELECT * FROM commercial_purchase_lines WHERE doc_id = ? ORDER BY line_order ASC').all(docId);
  const nowIso = new Date().toISOString();
  let nextStatus = 'VALIDEE';
  let stockApplied = Number(doc.stock_applied);

  if (doc.doc_type === 'COMMANDE_FOURNISSEUR') {
    nextStatus = 'ENVOYEE';
  } else if (doc.doc_type === 'RECEPTION') {
    nextStatus = 'VALIDEE';
    if (!stockApplied) {
      for (const l of lines) {
        if (!l.article_id) continue;
        const art = database.prepare('SELECT * FROM commercial_articles WHERE id = ? AND tenant_id = ?').get(l.article_id, tenantId);
        if (art && art.track_stock) {
          const q = Number(l.qty);
          const stockBefore = round3(art.stock_qty);
          const s0 = Math.max(0, stockBefore);
          const p0 = round2(art.pmp_cost_mru);
          const effectiveUnitCost =
            q > 0
              ? round2((Number(l.line_ht_mru) * (1 - Number(doc.global_discount_pct) / 100)) / q)
              : round2(l.unit_cost_ht_mru);
          const newPmp = s0 + q > 0 ? round2((s0 * p0 + q * effectiveUnitCost) / (s0 + q)) : effectiveUnitCost;
          const stockAfter = round3(stockBefore + q);

          database
            .prepare(`
              UPDATE commercial_articles SET
                stock_qty = ?, pmp_cost_mru = ?, price_cost_mru = ?, updated_at = CURRENT_TIMESTAMP
              WHERE id = ?
            `)
            .run(stockAfter, newPmp, effectiveUnitCost, art.id);

          database
            .prepare(`
              INSERT INTO commercial_stock_movements (
                tenant_id, article_id, movement_type, qty_delta, unit_cost_mru,
                pmp_before_mru, pmp_after_mru, stock_before, stock_after,
                source_type, source_id, source_number, reason
              ) VALUES (?, ?, 'IN_RECEPTION', ?, ?, ?, ?, ?, ?, 'RECEPTION', ?, ?, ?)
            `)
            .run(
              tenantId,
              art.id,
              round3(q),
              effectiveUnitCost,
              p0,
              newPmp,
              stockBefore,
              stockAfter,
              doc.id,
              doc.doc_number,
              `Réception ${doc.doc_number}`,
            );
        }
      }
      stockApplied = 1;
    }
  } else if (doc.doc_type === 'FACTURE_FOURNISSEUR') {
    nextStatus = 'VALIDEE';
  } else if (doc.doc_type === 'AVOIR_FOURNISSEUR') {
    nextStatus = 'VALIDEE';
    if (doc.source_doc_id) {
      const srcInv = database.prepare('SELECT * FROM commercial_purchase_docs WHERE id = ? AND tenant_id = ?').get(doc.source_doc_id, tenantId);
      if (!srcInv || srcInv.doc_type !== 'FACTURE_FOURNISSEUR') {
        throw createHttpError(400, 'Facture fournisseur source introuvable pour cet avoir');
      }
      const maxCredit = round2(Number(srcInv.total_ttc_mru) - Number(srcInv.credited_mru));
      if (Number(doc.total_ttc_mru) > maxCredit + 0.01) {
        throw createHttpError(400, `Montant de l'avoir (${doc.total_ttc_mru}) supérieur au solde créditable (${maxCredit})`);
      }
      const nextCredited = round2(Number(srcInv.credited_mru) + Number(doc.total_ttc_mru));
      const nextInvStatus =
        Number(srcInv.paid_mru) + nextCredited >= Number(srcInv.total_ttc_mru) - 0.01
          ? 'PAYEE'
          : Number(srcInv.paid_mru) + nextCredited > 0.01
          ? 'PARTIELLE'
          : srcInv.status;
      database
        .prepare('UPDATE commercial_purchase_docs SET credited_mru = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
        .run(nextCredited, nextInvStatus, srcInv.id);
    }
    if (doc.deduct_stock_on_validate) {
      for (const l of lines) {
        if (!l.article_id) continue;
        const art = database.prepare('SELECT * FROM commercial_articles WHERE id = ? AND tenant_id = ?').get(l.article_id, tenantId);
        if (art && art.track_stock) {
          const stockBefore = round3(art.stock_qty);
          const stockAfter = round3(stockBefore - Number(l.qty));
          database
            .prepare('UPDATE commercial_articles SET stock_qty = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
            .run(stockAfter, art.id);
          database
            .prepare(`
              INSERT INTO commercial_stock_movements (
                tenant_id, article_id, movement_type, qty_delta, unit_cost_mru,
                pmp_before_mru, pmp_after_mru, stock_before, stock_after,
                source_type, source_id, source_number, reason
              ) VALUES (?, ?, 'OUT_AVOIR_FOURNISSEUR', ?, ?, ?, ?, ?, ?, 'AVOIR_FOURNISSEUR', ?, ?, ?)
            `)
            .run(
              tenantId,
              art.id,
              -round3(l.qty),
              round2(art.pmp_cost_mru),
              round2(art.pmp_cost_mru),
              round2(art.pmp_cost_mru),
              stockBefore,
              stockAfter,
              doc.id,
              doc.doc_number,
              `Retour fournisseur ${doc.doc_number}`,
            );
        }
      }
    }
  }

  database
    .prepare(`
      UPDATE commercial_purchase_docs SET
        status = ?, stock_applied = ?, validated_at = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND tenant_id = ?
    `)
    .run(nextStatus, stockApplied, nowIso, docId, tenantId);

  if (doc.supplier_id && (doc.doc_type === 'FACTURE_FOURNISSEUR' || doc.doc_type === 'AVOIR_FOURNISSEUR')) {
    syncSupplierBalanceDue(database, tenantId, doc.supplier_id);
  }

  insertAudit(
    database,
    tenantId,
    actor,
    'COMM_PURCHASE_VALIDATE',
    `Validation ${doc.doc_number}`,
    `${doc.doc_type} · ${doc.supplier_name} · ${round2(doc.total_ttc_mru)} MRU`,
    'commercial_purchase_doc',
    doc.id,
    { status: doc.status },
    { status: nextStatus, stockApplied: Boolean(stockApplied) },
    nowHM,
  );

  const updatedDoc = database.prepare('SELECT * FROM commercial_purchase_docs WHERE id = ?').get(docId);
  const updatedLines = database.prepare('SELECT * FROM commercial_purchase_lines WHERE doc_id = ? ORDER BY line_order ASC').all(docId);
  return {
    doc: serializePurchaseDoc(updatedDoc),
    lines: updatedLines.map(serializePurchaseLine),
  };
}

function syncSupplierBalanceDue(database, tenantId, supplierId) {
  const row = database
    .prepare(`
      SELECT COALESCE(SUM(MAX(0, total_ttc_mru - paid_mru - credited_mru)), 0) AS s
      FROM commercial_purchase_docs
      WHERE tenant_id = ? AND supplier_id = ? AND doc_type = 'FACTURE_FOURNISSEUR' AND status IN ('VALIDEE', 'PARTIELLE')
    `)
    .get(tenantId, supplierId);
  database
    .prepare('UPDATE commercial_suppliers SET balance_due_mru = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND tenant_id = ?')
    .run(round2(row.s), supplierId, tenantId);
}

function buildObjectivesPayload(database, tenantId, year) {
  const rows = database
    .prepare('SELECT * FROM commercial_objectives WHERE tenant_id = ? AND year = ? ORDER BY month ASC')
    .all(tenantId, year);
  const byMonth = new Map(rows.map((r) => [r.month, r]));

  const curFrom = `${year}-01-01`;
  const curTo = `${year}-12-31`;
  const prevFrom = `${year - 1}-01-01`;
  const prevTo = `${year - 1}-12-31`;
  const curCaMap = queryMonthlyCaMap(database, tenantId, curFrom, curTo);
  const prevCaMap = queryMonthlyCaMap(database, tenantId, prevFrom, prevTo);

  let totalTargetMru = 0;
  let totalRealizedMru = 0;
  let totalPrevMru = 0;
  const months = [];

  for (let m = 1; m <= 12; m++) {
    const obj = byMonth.get(m);
    const ym = `${year}-${pad2(m)}`;
    const prevYm = `${year - 1}-${pad2(m)}`;
    const targetCaHtMru = round2(obj ? obj.target_ca_ht_mru : 0);
    const targetMarginPct = obj && obj.target_margin_pct !== null ? round1(obj.target_margin_pct) : null;
    const realizedCaHtMru = round2(curCaMap.get(ym) || 0);
    const prevCaHtMru = round2(prevCaMap.get(prevYm) || 0);
    const attainmentPct = targetCaHtMru > 0 ? round1((realizedCaHtMru / targetCaHtMru) * 100) : null;
    const vsN1Pct = pctDelta(realizedCaHtMru, prevCaHtMru);

    let status = 'NON_DEFINI';
    if (targetCaHtMru > 0) {
      status = realizedCaHtMru >= targetCaHtMru ? 'ATTEINT' : realizedCaHtMru >= targetCaHtMru * 0.8 ? 'EN_COURS' : 'EN_RETARD';
    }

    totalTargetMru = round2(totalTargetMru + targetCaHtMru);
    totalRealizedMru = round2(totalRealizedMru + realizedCaHtMru);
    totalPrevMru = round2(totalPrevMru + prevCaHtMru);

    months.push({
      year,
      month: m,
      monthKey: ym,
      label: `${FRENCH_MONTHS_SHORT[m - 1]} ${String(year).slice(-2)}`,
      targetCaHtMru,
      targetMarginPct,
      notes: obj ? obj.notes : '',
      realizedCaHtMru,
      prevCaHtMru,
      attainmentPct,
      vsN1Pct,
      status,
    });
  }

  return {
    ok: true,
    year,
    summary: {
      totalTargetMru,
      totalRealizedMru,
      totalPrevMru,
      attainmentPct: totalTargetMru > 0 ? round1((totalRealizedMru / totalTargetMru) * 100) : null,
    },
    objectives: months,
    months,
  };
}

module.exports = {
  ensureCommercialDefaults,
  handleCommercialRoute,
};
