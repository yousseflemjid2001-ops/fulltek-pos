const zlib = require('node:zlib');

const MAX_ZIP_ENTRY_BYTES = 20 * 1024 * 1024;
const MAX_ZIP_TOTAL_BYTES = 50 * 1024 * 1024;

function createHttpError(statusCode, message, errors = null) {
  const err = new Error(message);
  err.statusCode = statusCode;
  if (Array.isArray(errors)) {
    err.errors = errors;
  }
  return err;
}

function nowHM() {
  const d = new Date();
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

function normalizeHeader(raw) {
  return String(raw ?? '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[\s\-./()]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

const HEADER_ALIASES = new Map([
  // Required: name_fr
  ['name_fr', 'name_fr'],
  ['name', 'name_fr'],
  ['nom', 'name_fr'],
  ['nom_fr', 'name_fr'],
  ['produit', 'name_fr'],
  ['product', 'name_fr'],
  ['product_name', 'name_fr'],
  ['designation', 'name_fr'],
  ['libelle', 'name_fr'],
  ['article', 'name_fr'],
  ['item', 'name_fr'],
  ['اسم_فرنسي', 'name_fr'],
  ['الاسم_الفرنسي', 'name_fr'],
  ['المنتج', 'name_fr'],
  ['اسم_المنتج', 'name_fr'],

  // Required: price_retail
  ['price_retail', 'price_retail'],
  ['prix_vente', 'price_retail'],
  ['prix_detail', 'price_retail'],
  ['prix', 'price_retail'],
  ['price', 'price_retail'],
  ['pu', 'price_retail'],
  ['prix_unitaire', 'price_retail'],
  ['unit_price', 'price_retail'],
  ['tarif', 'price_retail'],
  ['mru', 'price_retail'],
  ['سعر_البيع', 'price_retail'],
  ['سعر_التجزئة', 'price_retail'],
  ['السعر', 'price_retail'],

  // Optional fields
  ['sku', 'sku'],
  ['code', 'sku'],
  ['code_produit', 'sku'],
  ['ref', 'sku'],
  ['reference', 'sku'],
  ['الرمز', 'sku'],
  ['رمز_المنتج', 'sku'],

  ['barcode', 'barcode'],
  ['code_barre', 'barcode'],
  ['code_barres', 'barcode'],
  ['codebarre', 'barcode'],
  ['ean', 'barcode'],
  ['ean13', 'barcode'],
  ['upc', 'barcode'],
  ['gtin', 'barcode'],
  ['الباركود', 'barcode'],
  ['الرمز_الشريطي', 'barcode'],

  ['category', 'category'],
  ['categorie', 'category'],
  ['category_fr', 'category'],
  ['categorie_fr', 'category'],
  ['famille', 'category'],
  ['rayon', 'category'],
  ['groupe', 'category'],
  ['الفئة', 'category'],
  ['التصنيف', 'category'],
  ['القسم', 'category'],

  ['category_ar', 'category_ar'],
  ['categorie_ar', 'category_ar'],
  ['famille_ar', 'category_ar'],
  ['الفئة_عربي', 'category_ar'],
  ['التصنيف_بالعربية', 'category_ar'],

  ['name_ar', 'name_ar'],
  ['nom_ar', 'name_ar'],
  ['produit_ar', 'name_ar'],
  ['designation_ar', 'name_ar'],
  ['الاسم_العربي', 'name_ar'],
  ['الاسم_بالعربية', 'name_ar'],
  ['اسم_عربي', 'name_ar'],

  ['name_en', 'name_en'],
  ['nom_en', 'name_en'],
  ['english_name', 'name_en'],

  ['unit', 'unit'],
  ['unite', 'unit'],
  ['uom', 'unit'],
  ['الوحدة', 'unit'],

  ['price_whole', 'price_whole'],
  ['prix_gros', 'price_whole'],
  ['wholesale_price', 'price_whole'],
  ['gros', 'price_whole'],
  ['سعر_الجملة', 'price_whole'],

  ['price_cost', 'price_cost'],
  ['prix_achat', 'price_cost'],
  ['cost', 'price_cost'],
  ['cout', 'price_cost'],
  ['pmp', 'price_cost'],
  ['تكلفة_الشراء', 'price_cost'],
  ['سعر_الشراء', 'price_cost'],

  ['dci', 'dci'],
  ['inn', 'dci'],
  ['molecule', 'dci'],

  ['track_fefo', 'track_fefo'],
  ['fefo', 'track_fefo'],
  ['suivi_fefo', 'track_fefo'],
  ['peremption', 'track_fefo'],
  ['تتبع_الصلاحية', 'track_fefo'],

  ['requires_cnam', 'requires_cnam'],
  ['cnam', 'requires_cnam'],
  ['remboursable_cnam', 'requires_cnam'],
  ['تغطية_كنام', 'requires_cnam'],

  ['lot_number', 'lot_number'],
  ['lot', 'lot_number'],
  ['numero_lot', 'lot_number'],
  ['num_lot', 'lot_number'],
  ['batch', 'lot_number'],
  ['رقم_الدفعة', 'lot_number'],
  ['رقم_التشغيلة', 'lot_number'],

  ['qty', 'qty'],
  ['stock_qty', 'qty'],
  ['quantity', 'qty'],
  ['quantite', 'qty'],
  ['stock', 'qty'],
  ['الكمية', 'qty'],

  ['expires_at', 'expires_at'],
  ['expiry', 'expires_at'],
  ['expiry_date', 'expires_at'],
  ['expiration', 'expires_at'],
  ['date_expiration', 'expires_at'],
  ['date_peremption', 'expires_at'],
  ['dlc', 'expires_at'],
  ['تاريخ_الانتهاء', 'expires_at'],
  ['تاريخ_الصلاحية', 'expires_at'],

  // Resto POS extended fields
  ['icon', 'icon'],
  ['icone', 'icon'],
  ['emoji', 'icon'],
  ['picto', 'icon'],
  ['الايقونة', 'icon'],
  ['الأيقونة', 'icon'],

  ['kitchen_station', 'kitchen_station'],
  ['station', 'kitchen_station'],
  ['poste', 'kitchen_station'],
  ['poste_cuisine', 'kitchen_station'],
  ['kds_station', 'kitchen_station'],
  ['cuisine_poste', 'kitchen_station'],
  ['محطة_المطبخ', 'kitchen_station'],

  ['is_top', 'is_top'],
  ['top', 'is_top'],
  ['best_seller', 'is_top'],
  ['bestseller', 'is_top'],
  ['vedette', 'is_top'],
  ['الأكثر_مبيعا', 'is_top'],
  ['الاكثر_مبيعا', 'is_top'],

  ['is_out_of_stock', 'is_out_of_stock'],
  ['out_of_stock', 'is_out_of_stock'],
  ['epuise', 'is_out_of_stock'],
  ['rupture', 'is_out_of_stock'],
  ['rupture_stock', 'is_out_of_stock'],
  ['86', 'is_out_of_stock'],
  ['نفذت_الكمية', 'is_out_of_stock'],

  ['modifiers_json', 'modifiers_json'],
  ['modifiers', 'modifiers_json'],
  ['modificateurs', 'modifiers_json'],
  ['options', 'modifiers_json'],
  ['extras', 'modifiers_json'],
  ['الإضافات', 'modifiers_json'],
  ['الاضافات', 'modifiers_json'],
]);

function mapCanonicalField(headerText) {
  const norm = normalizeHeader(headerText);
  return HEADER_ALIASES.get(norm) || null;
}

function detectCsvDelimiter(text) {
  const counts = { ',': 0, ';': 0, '\t': 0 };
  let inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (ch === '"') {
      if (inQuotes && text[i + 1] === '"') {
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (!inQuotes) {
      if (ch === '\r' || ch === '\n') break;
      if (ch === ',' || ch === ';' || ch === '\t') {
        counts[ch]++;
      }
    }
  }
  if (counts[';'] > counts[','] && counts[';'] >= counts['\t']) return ';';
  if (counts['\t'] > counts[','] && counts['\t'] > counts[';']) return '\t';
  return ',';
}

function parseCsvText(rawText) {
  if (typeof rawText !== 'string') {
    throw createHttpError(400, 'CSV content must be a string');
  }
  const clean = rawText.replace(/^\uFEFF/, '').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  if (clean.trim() === '') {
    throw createHttpError(400, 'Empty catalog CSV');
  }

  const delimiter = detectCsvDelimiter(clean);
  const rows = [];
  let row = [];
  let field = '';
  let inQuotes = false;

  for (let i = 0; i < clean.length; i++) {
    const ch = clean[i];
    if (inQuotes) {
      if (ch === '"') {
        if (clean[i + 1] === '"') {
          field += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field += ch;
      }
      continue;
    }

    if (ch === '"') {
      inQuotes = true;
    } else if (ch === delimiter) {
      row.push(field.trim());
      field = '';
    } else if (ch === '\n') {
      row.push(field.trim());
      if (row.some((cell) => cell !== '')) {
        rows.push(row);
      }
      row = [];
      field = '';
    } else {
      field += ch;
    }
  }

  if (inQuotes) {
    throw createHttpError(400, 'Malformed CSV: unterminated quoted field');
  }

  row.push(field.trim());
  if (row.some((cell) => cell !== '')) {
    rows.push(row);
  }

  if (rows.length < 2) {
    throw createHttpError(400, 'Catalog must contain a header row and at least one data row');
  }

  return rows;
}

function unescapeXml(str) {
  return String(str)
    .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => String.fromCodePoint(parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_, dec) => String.fromCodePoint(parseInt(dec, 10)))
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&');
}

function parseXmlAttributes(attrStr) {
  const attrs = Object.create(null);
  const re = /([A-Za-z_][\w:.-]*)\s*=\s*(?:"([^"]*)"|'([^']*)')/g;
  let m;
  while ((m = re.exec(attrStr)) !== null) {
    attrs[m[1]] = unescapeXml(m[2] !== undefined ? m[2] : m[3]);
  }
  return attrs;
}

function colLettersToIndex(cellRef) {
  const match = /^([A-Za-z]+)\d+$/.exec(String(cellRef || '').trim());
  if (!match) return -1;
  const letters = match[1].toUpperCase();
  let idx = 0;
  for (let i = 0; i < letters.length; i++) {
    idx = idx * 26 + (letters.charCodeAt(i) - 64);
  }
  return idx - 1;
}

function unzipEntries(buf) {
  if (!Buffer.isBuffer(buf) || buf.length < 22) {
    throw createHttpError(400, 'Invalid XLSX file: buffer too small');
  }

  const minOffset = Math.max(0, buf.length - 65557);
  let eocdOffset = -1;
  for (let i = buf.length - 22; i >= minOffset; i--) {
    if (buf.readUInt32LE(i) === 0x06054b50) {
      const commentLen = buf.readUInt16LE(i + 20);
      if (i + 22 + commentLen <= buf.length) {
        eocdOffset = i;
        break;
      }
    }
  }
  if (eocdOffset === -1) {
    throw createHttpError(400, 'Invalid XLSX file: not a valid ZIP archive');
  }

  const cdEntries = buf.readUInt16LE(eocdOffset + 10);
  const cdSize = buf.readUInt32LE(eocdOffset + 12);
  const cdOffset = buf.readUInt32LE(eocdOffset + 16);
  if (cdOffset + cdSize > eocdOffset) {
    throw createHttpError(400, 'Invalid XLSX file: corrupt ZIP central directory');
  }

  const entries = new Map();
  let cursor = cdOffset;
  let totalUncompressed = 0;

  for (let idx = 0; idx < cdEntries; idx++) {
    if (cursor + 46 > cdOffset + cdSize || buf.readUInt32LE(cursor) !== 0x02014b50) {
      throw createHttpError(400, 'Invalid XLSX file: corrupt central directory entry');
    }

    const flags = buf.readUInt16LE(cursor + 8);
    const method = buf.readUInt16LE(cursor + 10);
    const crc32Expected = buf.readUInt32LE(cursor + 16);
    const compSize = buf.readUInt32LE(cursor + 20);
    const uncompSize = buf.readUInt32LE(cursor + 24);
    const nameLen = buf.readUInt16LE(cursor + 28);
    const extraLen = buf.readUInt16LE(cursor + 30);
    const commentLen = buf.readUInt16LE(cursor + 32);
    const localHeaderOffset = buf.readUInt32LE(cursor + 42);

    const headerEnd = cursor + 46 + nameLen + extraLen + commentLen;
    if (headerEnd > cdOffset + cdSize) {
      throw createHttpError(400, 'Invalid XLSX file: truncated central directory entry');
    }

    const entryName = buf.toString('utf8', cursor + 46, cursor + 46 + nameLen).replace(/^\/+/, '');
    cursor = headerEnd;

    if ((flags & 1) !== 0) {
      throw createHttpError(400, 'Invalid XLSX file: encrypted ZIP entries are not supported');
    }
    if (method !== 0 && method !== 8) {
      throw createHttpError(400, `Invalid XLSX file: unsupported compression method (${method})`);
    }
    if (uncompSize > MAX_ZIP_ENTRY_BYTES) {
      throw createHttpError(400, 'Invalid XLSX file: ZIP entry exceeds size limit');
    }
    totalUncompressed += uncompSize;
    if (totalUncompressed > MAX_ZIP_TOTAL_BYTES) {
      throw createHttpError(400, 'Invalid XLSX file: uncompressed ZIP payload exceeds limit');
    }

    if (localHeaderOffset + 30 > cdOffset) {
      throw createHttpError(400, 'Invalid XLSX file: invalid local file header offset');
    }
    if (buf.readUInt32LE(localHeaderOffset) !== 0x04034b50) {
      throw createHttpError(400, 'Invalid XLSX file: corrupt local file header magic');
    }

    const lNameLen = buf.readUInt16LE(localHeaderOffset + 26);
    const lExtraLen = buf.readUInt16LE(localHeaderOffset + 28);
    const dataStart = localHeaderOffset + 30 + lNameLen + lExtraLen;
    const dataEnd = dataStart + compSize;
    if (dataEnd > cdOffset) {
      throw createHttpError(400, 'Invalid XLSX file: truncated ZIP entry data');
    }

    const compressedSlice = buf.subarray(dataStart, dataEnd);
    let data;
    try {
      data = method === 0 ? Buffer.from(compressedSlice) : zlib.inflateRawSync(compressedSlice);
    } catch {
      throw createHttpError(400, 'Invalid XLSX file: corrupt deflate stream');
    }

    if (data.length !== uncompSize) {
      throw createHttpError(400, 'Invalid XLSX file: uncompressed entry size mismatch');
    }
    if ((zlib.crc32(data) >>> 0) !== crc32Expected) {
      throw createHttpError(400, 'Invalid XLSX file: CRC32 checksum mismatch');
    }

    entries.set(entryName, data);
  }

  return entries;
}

function parseSharedStrings(xmlText) {
  const strings = [];
  const siRe = /<(?:\w+:)?si\b[^>]*>([\s\S]*?)<\/(?:\w+:)?si>/g;
  let siMatch;
  while ((siMatch = siRe.exec(xmlText)) !== null) {
    const inner = siMatch[1].replace(/<(?:\w+:)?rPh\b[^>]*>[\s\S]*?<\/(?:\w+:)?rPh>/g, '');
    const tRe = /<(?:\w+:)?t\b[^>]*>([\s\S]*?)<\/(?:\w+:)?t>/g;
    let tMatch;
    let combined = '';
    while ((tMatch = tRe.exec(inner)) !== null) {
      combined += unescapeXml(tMatch[1]);
    }
    strings.push(combined);
  }
  return strings;
}

function resolveFirstWorksheetPath(entries) {
  const workbookBuf = entries.get('xl/workbook.xml');
  if (!workbookBuf) {
    throw createHttpError(400, 'Invalid XLSX file: missing xl/workbook.xml');
  }
  const workbookXml = workbookBuf.toString('utf8');
  const sheetMatch = /<(?:\w+:)?sheet\b([^>]*)\/?\s*>/i.exec(workbookXml);
  if (!sheetMatch) {
    throw createHttpError(400, 'Invalid XLSX file: no worksheets found in workbook.xml');
  }
  const sheetAttrs = parseXmlAttributes(sheetMatch[1]);
  const rId = sheetAttrs['r:id'] || sheetAttrs.id;

  const relsBuf = entries.get('xl/_rels/workbook.xml.rels');
  if (relsBuf) {
    const relsXml = relsBuf.toString('utf8');
    const relRe = /<(?:\w+:)?Relationship\b([^>]*)\/?\s*>/gi;
    let relMatch;
    while ((relMatch = relRe.exec(relsXml)) !== null) {
      const attrs = parseXmlAttributes(relMatch[1]);
      if (attrs.Id === rId && attrs.Target) {
        const cleanTarget = attrs.Target.replace(/\\/g, '/').replace(/^\/+/, '');
        const fullPath = cleanTarget.startsWith('xl/') ? cleanTarget : `xl/${cleanTarget}`;
        if (!entries.has(fullPath)) {
          throw createHttpError(400, `Invalid XLSX file: missing worksheet (${fullPath})`);
        }
        return fullPath;
      }
    }
    throw createHttpError(400, 'Invalid XLSX file: worksheet relationship not found');
  }

  if (entries.has('xl/worksheets/sheet1.xml')) {
    return 'xl/worksheets/sheet1.xml';
  }
  throw createHttpError(400, 'Invalid XLSX file: missing worksheet XML');
}

function parseWorksheetRows(sheetXml, sharedStrings) {
  const rows = [];
  const rowRe = /<(?:\w+:)?row\b[^>]*>([\s\S]*?)<\/(?:\w+:)?row>/g;
  let rowMatch;

  while ((rowMatch = rowRe.exec(sheetXml)) !== null) {
    const rowBody = rowMatch[1];
    const cellRe = /<(?:\w+:)?c\b([^>]*?)(?:\/>|>([\s\S]*?)<\/(?:\w+:)?c>)/g;
    const cellsByCol = new Map();
    let sequentialCol = 0;
    let maxCol = -1;
    let cellMatch;

    while ((cellMatch = cellRe.exec(rowBody)) !== null) {
      const attrs = parseXmlAttributes(cellMatch[1]);
      const cellBody = cellMatch[2] || '';
      const colFromRef = attrs.r ? colLettersToIndex(attrs.r) : -1;
      const colIdx = colFromRef >= 0 ? colFromRef : sequentialCol;
      sequentialCol = colIdx + 1;
      if (colIdx > maxCol) maxCol = colIdx;

      const cellType = attrs.t || 'n';
      let value = '';

      if (cellType === 'inlineStr') {
        const tRe = /<(?:\w+:)?t\b[^>]*>([\s\S]*?)<\/(?:\w+:)?t>/g;
        let tMatch;
        while ((tMatch = tRe.exec(cellBody)) !== null) {
          value += unescapeXml(tMatch[1]);
        }
      } else {
        const vMatch = /<(?:\w+:)?v\b[^>]*>([\s\S]*?)<\/(?:\w+:)?v>/.exec(cellBody);
        const rawV = vMatch ? unescapeXml(vMatch[1]) : '';
        if (cellType === 's') {
          const idx = Number.parseInt(rawV, 10);
          value = Number.isInteger(idx) && idx >= 0 && idx < sharedStrings.length ? sharedStrings[idx] : '';
        } else if (cellType === 'b') {
          value = rawV.trim() === '1' ? '1' : '0';
        } else if (cellType === 'e') {
          value = '';
        } else {
          value = rawV;
        }
      }

      cellsByCol.set(colIdx, String(value).trim());
    }

    if (maxCol < 0) continue;
    const denseRow = new Array(maxCol + 1).fill('');
    for (const [colIdx, val] of cellsByCol.entries()) {
      denseRow[colIdx] = val;
    }
    if (denseRow.some((cell) => cell !== '')) {
      rows.push(denseRow);
    }
  }

  if (rows.length < 2) {
    throw createHttpError(400, 'XLSX sheet must contain a header row and at least one data row');
  }
  return rows;
}

function parseXlsxBuffer(buf) {
  const entries = unzipEntries(buf);
  const sheetPath = resolveFirstWorksheetPath(entries);
  const sharedBuf = entries.get('xl/sharedStrings.xml');
  const sharedStrings = sharedBuf ? parseSharedStrings(sharedBuf.toString('utf8')) : [];
  const sheetXml = entries.get(sheetPath).toString('utf8');
  return parseWorksheetRows(sheetXml, sharedStrings);
}

function parseStrictNonNegativeInt(raw, fieldLabel) {
  if (typeof raw === 'boolean' || raw === null || raw === undefined) {
    return { ok: false, error: `${fieldLabel} must be a non-negative number` };
  }
  if (typeof raw === 'number') {
    if (!Number.isFinite(raw) || raw < 0) {
      return { ok: false, error: `${fieldLabel} must be a non-negative number` };
    }
    return { ok: true, value: Math.round(raw) };
  }
  const str = String(raw).trim().replace(/\s+/g, '');
  if (!/^\d+(?:[.,]\d+)?$/.test(str)) {
    return { ok: false, error: `${fieldLabel} must be a non-negative number` };
  }
  const num = Number(str.replace(',', '.'));
  if (!Number.isFinite(num) || num < 0) {
    return { ok: false, error: `${fieldLabel} must be a non-negative number` };
  }
  return { ok: true, value: Math.round(num) };
}

function parseBooleanFlag(raw, fieldLabel) {
  if (typeof raw === 'boolean') return { ok: true, value: raw ? 1 : 0 };
  if (typeof raw === 'number') {
    if (raw === 1) return { ok: true, value: 1 };
    if (raw === 0) return { ok: true, value: 0 };
    return { ok: false, error: `${fieldLabel} must be boolean or 0/1` };
  }
  const s = String(raw).trim().toLowerCase();
  if (s === '1' || s === 'true' || s === 'oui' || s === 'yes' || s === 'نعم') {
    return { ok: true, value: 1 };
  }
  if (s === '0' || s === 'false' || s === 'non' || s === 'no' || s === 'لا') {
    return { ok: true, value: 0 };
  }
  return { ok: false, error: `${fieldLabel} has invalid boolean value "${raw}"` };
}

function normalizeGridRows(grid) {
  const headers = grid[0];
  const colToField = new Map();
  const presentFields = new Set();

  for (let c = 0; c < headers.length; c++) {
    const field = mapCanonicalField(headers[c]);
    if (field && !colToField.has(c)) {
      colToField.set(c, field);
      presentFields.add(field);
    }
  }

  const missingReq = [];
  if (!presentFields.has('name_fr')) missingReq.push('name_fr');
  if (!presentFields.has('price_retail')) missingReq.push('price_retail');
  if (missingReq.length > 0) {
    throw createHttpError(400, `Missing required column(s): ${missingReq.join(', ')}`, [
      { row: 1, message: `Missing required column(s): ${missingReq.join(', ')}` },
    ]);
  }

  const normalized = [];
  for (let r = 1; r < grid.length; r++) {
    const rawRow = grid[r];
    const obj = Object.create(null);
    for (const [colIdx, field] of colToField.entries()) {
      const val = colIdx < rawRow.length ? String(rawRow[colIdx] ?? '').trim() : '';
      if (obj[field] === undefined || obj[field] === '') {
        obj[field] = val;
      }
    }
    normalized.push({ rowNum: r + 1, data: obj, presentFields });
  }
  return normalized;
}

function normalizeObjectRows(rows) {
  if (!Array.isArray(rows) || rows.length === 0) {
    throw createHttpError(400, 'Catalog rows array must be non-empty');
  }

  const normalized = [];
  for (let i = 0; i < rows.length; i++) {
    const rawObj = rows[i];
    if (!rawObj || typeof rawObj !== 'object' || Array.isArray(rawObj)) {
      throw createHttpError(400, 'Invalid row object in catalog rows', [
        { row: i + 1, message: 'Row must be a JSON object' },
      ]);
    }
    const obj = Object.create(null);
    const presentFields = new Set();
    for (const [key, val] of Object.entries(rawObj)) {
      const field = mapCanonicalField(key);
      if (!field) continue;
      presentFields.add(field);
      if (val === null || val === undefined) {
        if (obj[field] === undefined) obj[field] = '';
      } else if (typeof val === 'string') {
        obj[field] = val.trim();
      } else {
        obj[field] = val;
      }
    }
    normalized.push({ rowNum: i + 1, data: obj, presentFields });
  }
  return normalized;
}

function validateNormalizedRows(normalizedRows) {
  const errors = [];
  const validated = [];

  for (const entry of normalizedRows) {
    const { rowNum, data, presentFields } = entry;
    const rowErrors = [];

    const nameFr = typeof data.name_fr === 'string' ? data.name_fr.trim() : String(data.name_fr ?? '').trim();
    if (!nameFr) {
      rowErrors.push('name_fr is required');
    }

    const priceRetailParsed = parseStrictNonNegativeInt(data.price_retail, 'price_retail');
    if (!priceRetailParsed.ok) {
      rowErrors.push(priceRetailParsed.error);
    }

    let priceWhole = undefined;
    if (data.price_whole !== undefined && String(data.price_whole).trim() !== '') {
      const parsed = parseStrictNonNegativeInt(data.price_whole, 'price_whole');
      if (!parsed.ok) rowErrors.push(parsed.error);
      else priceWhole = parsed.value;
    }

    let priceCost = undefined;
    if (data.price_cost !== undefined && String(data.price_cost).trim() !== '') {
      const parsed = parseStrictNonNegativeInt(data.price_cost, 'price_cost');
      if (!parsed.ok) rowErrors.push(parsed.error);
      else priceCost = parsed.value;
    }

    let qty = undefined;
    if (data.qty !== undefined && String(data.qty).trim() !== '') {
      const parsed = parseStrictNonNegativeInt(data.qty, 'qty');
      if (!parsed.ok) rowErrors.push(parsed.error);
      else qty = parsed.value;
    }

    let trackFefo = undefined;
    if (data.track_fefo !== undefined && String(data.track_fefo).trim() !== '') {
      const parsed = parseBooleanFlag(data.track_fefo, 'track_fefo');
      if (!parsed.ok) rowErrors.push(parsed.error);
      else trackFefo = parsed.value;
    }

    let requiresCnam = undefined;
    if (data.requires_cnam !== undefined && String(data.requires_cnam).trim() !== '') {
      const parsed = parseBooleanFlag(data.requires_cnam, 'requires_cnam');
      if (!parsed.ok) rowErrors.push(parsed.error);
      else requiresCnam = parsed.value;
    }

    const lotNumber = data.lot_number !== undefined ? String(data.lot_number).trim() : '';
    const expiresAt = data.expires_at !== undefined ? String(data.expires_at).trim() : '';
    if ((lotNumber !== '' && expiresAt === '') || (lotNumber === '' && expiresAt !== '')) {
      rowErrors.push('lot_number and expires_at must be provided together');
    } else if (expiresAt !== '') {
      const ts = Date.parse(expiresAt);
      if (Number.isNaN(ts)) {
        rowErrors.push(`expires_at "${expiresAt}" is not a valid date`);
      }
    }

    const icon = data.icon !== undefined ? String(data.icon).trim() : '';

    let kitchenStation = '';
    if (data.kitchen_station !== undefined && String(data.kitchen_station).trim() !== '') {
      let st = String(data.kitchen_station).trim().toUpperCase();
      if (st === 'CUISINE') st = 'KITCHEN';
      if (st !== 'KITCHEN' && st !== 'GRILL' && st !== 'BAR') {
        rowErrors.push(`kitchen_station "${data.kitchen_station}" must be KITCHEN, GRILL, or BAR`);
      } else {
        kitchenStation = st;
      }
    }

    let isTop = undefined;
    if (data.is_top !== undefined && String(data.is_top).trim() !== '') {
      const parsed = parseBooleanFlag(data.is_top, 'is_top');
      if (!parsed.ok) rowErrors.push(parsed.error);
      else isTop = parsed.value;
    }

    let isOutOfStock = undefined;
    if (data.is_out_of_stock !== undefined && String(data.is_out_of_stock).trim() !== '') {
      const parsed = parseBooleanFlag(data.is_out_of_stock, 'is_out_of_stock');
      if (!parsed.ok) rowErrors.push(parsed.error);
      else isOutOfStock = parsed.value;
    }

    let modifiersJson = undefined;
    if (data.modifiers_json !== undefined) {
      if (Array.isArray(data.modifiers_json)) {
        modifiersJson = JSON.stringify(data.modifiers_json);
      } else {
        const rawMod = String(data.modifiers_json).trim();
        if (rawMod !== '') {
          try {
            const parsedMod = JSON.parse(rawMod);
            if (!Array.isArray(parsedMod)) {
              rowErrors.push('modifiers_json must be a valid JSON array');
            } else {
              modifiersJson = JSON.stringify(parsedMod);
            }
          } catch {
            rowErrors.push('modifiers_json must be a valid JSON array');
          }
        }
      }
    }

    if (rowErrors.length > 0) {
      errors.push({ row: rowNum, message: rowErrors.join('; ') });
      continue;
    }

    validated.push({
      rowNum,
      presentFields,
      sku: data.sku !== undefined ? String(data.sku).trim() : '',
      barcode: data.barcode !== undefined ? String(data.barcode).trim() : '',
      category: data.category !== undefined ? String(data.category).trim() : '',
      category_ar: data.category_ar !== undefined ? String(data.category_ar).trim() : '',
      name_fr: nameFr,
      name_ar: data.name_ar !== undefined ? String(data.name_ar).trim() : '',
      name_en: data.name_en !== undefined ? String(data.name_en).trim() : '',
      icon,
      unit: data.unit !== undefined ? String(data.unit).trim() : '',
      price_retail: priceRetailParsed.value,
      price_whole: priceWhole,
      price_cost: priceCost,
      dci: data.dci !== undefined ? String(data.dci).trim() : '',
      track_fefo: trackFefo,
      requires_cnam: requiresCnam,
      kitchen_station: kitchenStation,
      is_top: isTop,
      is_out_of_stock: isOutOfStock,
      modifiers_json: modifiersJson,
      lot_number: lotNumber,
      qty,
      expires_at: expiresAt,
    });
  }

  if (errors.length > 0) {
    throw createHttpError(400, 'Catalog validation failed', errors);
  }
  return validated;
}

function decodeImportInput(input) {
  const contentType = String(input.contentType || '').toLowerCase();
  const filename = String(input.filename || '').toLowerCase();
  const buf = Buffer.isBuffer(input.buffer) ? input.buffer : Buffer.from(input.buffer || '');

  // Explicit JSON or auto-detected JSON payload
  const looksLikeJson =
    contentType.includes('application/json') ||
    (!contentType &&
      buf.length > 0 &&
      (() => {
        const lead = buf.subarray(0, 64).toString('utf8').trimStart();
        return lead.startsWith('{') || lead.startsWith('[');
      })());

  if (looksLikeJson) {
    let body;
    try {
      const text = buf.toString('utf8').trim();
      body = text ? JSON.parse(text) : {};
    } catch {
      throw createHttpError(400, 'Invalid JSON');
    }
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      throw createHttpError(400, 'JSON import payload must be an object');
    }

    const bodyFormat = String(body.format || '').trim().toLowerCase();
    const bodyFilename = String(body.filename || filename || '').toLowerCase();

    if (Array.isArray(body.rows)) {
      return { format: 'json', rows: normalizeObjectRows(body.rows) };
    }

    if (body.contentBase64 !== undefined && body.contentBase64 !== null) {
      if (typeof body.contentBase64 !== 'string' || body.contentBase64.trim() === '') {
        throw createHttpError(400, 'contentBase64 must be a non-empty base64 string');
      }
      const decodedBuf = Buffer.from(body.contentBase64.trim(), 'base64');
      if (decodedBuf.length === 0) {
        throw createHttpError(400, 'Decoded base64 content is empty');
      }
      const isZipMagic =
        decodedBuf.length >= 4 &&
        decodedBuf[0] === 0x50 &&
        decodedBuf[1] === 0x4b &&
        decodedBuf[2] === 0x03 &&
        decodedBuf[3] === 0x04;
      const isCsvRequested = bodyFormat === 'csv' || (bodyFilename.endsWith('.csv') && !isZipMagic && bodyFormat !== 'xlsx');

      if (isCsvRequested) {
        return { format: 'csv', rows: normalizeGridRows(parseCsvText(decodedBuf.toString('utf8'))) };
      }
      return { format: 'xlsx', rows: normalizeGridRows(parseXlsxBuffer(decodedBuf)) };
    }

    const csvText = body.csvText !== undefined ? body.csvText : body.content;
    if (csvText !== undefined) {
      if (typeof csvText !== 'string') {
        throw createHttpError(400, 'csvText must be a string');
      }
      return { format: 'csv', rows: normalizeGridRows(parseCsvText(csvText)) };
    }

    throw createHttpError(400, 'Missing csvText, contentBase64, or rows in JSON import payload');
  }

  // Raw binary XLSX
  if (
    contentType.includes('spreadsheetml') ||
    contentType.includes('application/vnd.ms-excel') ||
    contentType.includes('application/octet-stream') ||
    (!contentType && buf.length >= 4 && buf[0] === 0x50 && buf[1] === 0x4b && buf[2] === 0x03 && buf[3] === 0x04)
  ) {
    return { format: 'xlsx', rows: normalizeGridRows(parseXlsxBuffer(buf)) };
  }

  // Raw CSV / text
  return { format: 'csv', rows: normalizeGridRows(parseCsvText(buf.toString('utf8'))) };
}

function importCatalog(db, tenantId, input) {
  const tid = Number(tenantId);
  if (!Number.isInteger(tid) || tid <= 0) {
    throw createHttpError(400, 'Invalid tenantId');
  }

  const tenant = db.prepare('SELECT id, name FROM tenants WHERE id = ?').get(tid);
  if (!tenant) {
    throw createHttpError(404, 'Tenant not found');
  }

  const decoded = decodeImportInput(input || {});
  const rows = validateNormalizedRows(decoded.rows);
  const nowIso = new Date().toISOString();

  let created = 0;
  let updated = 0;
  let categoriesCreated = 0;

  db.exec('BEGIN IMMEDIATE;');
  try {
    const findCategoryStmt = db.prepare('SELECT id, name_ar FROM categories WHERE tenant_id = ? AND name_fr = ? LIMIT 1');
    const insertCategoryStmt = db.prepare(`
      INSERT INTO categories (tenant_id, name_fr, name_ar, created_at)
      VALUES (?, ?, ?, ?)
    `);
    const updateCategoryArStmt = db.prepare('UPDATE categories SET name_ar = ? WHERE id = ?');

    const findBySkuStmt = db.prepare('SELECT * FROM products WHERE tenant_id = ? AND sku = ? LIMIT 1');
    const findByBarcodeStmt = db.prepare('SELECT * FROM products WHERE tenant_id = ? AND barcode = ? LIMIT 1');
    const findByNameStmt = db.prepare('SELECT * FROM products WHERE tenant_id = ? AND name_fr = ? LIMIT 1');

    const conflictSkuStmt = db.prepare('SELECT id FROM products WHERE tenant_id = ? AND sku = ? AND id != ? LIMIT 1');
    const conflictBarcodeStmt = db.prepare('SELECT id FROM products WHERE tenant_id = ? AND barcode = ? AND id != ? LIMIT 1');

    const insertProductStmt = db.prepare(`
      INSERT INTO products (
        tenant_id, category_id, sku, barcode, name_fr, name_ar, name_en, icon, unit,
        price_retail, price_whole, price_cost, dci, track_fefo, requires_cnam,
        kitchen_station, is_top, is_out_of_stock, modifiers_json,
        active, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
    `);

    const updateProductStmt = db.prepare(`
      UPDATE products SET
        category_id = ?,
        sku = ?,
        barcode = ?,
        name_fr = ?,
        name_ar = ?,
        name_en = ?,
        icon = ?,
        unit = ?,
        price_retail = ?,
        price_whole = ?,
        price_cost = ?,
        dci = ?,
        track_fefo = ?,
        requires_cnam = ?,
        kitchen_station = ?,
        is_top = ?,
        is_out_of_stock = ?,
        modifiers_json = ?,
        updated_at = ?
      WHERE id = ? AND tenant_id = ?
    `);

    const findBatchStmt = db.prepare(`
      SELECT id FROM stock_batches
      WHERE tenant_id = ? AND product_id = ? AND lot_number = ?
      LIMIT 1
    `);
    const insertBatchStmt = db.prepare(`
      INSERT INTO stock_batches (
        tenant_id, product_id, lot_number, qty, purchase_price_mru, expires_at
      ) VALUES (?, ?, ?, ?, ?, ?)
    `);
    const updateBatchStmt = db.prepare(`
      UPDATE stock_batches
      SET qty = ?, purchase_price_mru = ?, expires_at = ?
      WHERE id = ?
    `);

    for (const row of rows) {
      let categoryId = null;
      if (row.category !== '') {
        const cat = findCategoryStmt.get(tenant.id, row.category);
        if (cat) {
          categoryId = cat.id;
          if (row.category_ar !== '' && row.category_ar !== cat.name_ar) {
            updateCategoryArStmt.run(row.category_ar, cat.id);
          }
        } else {
          const catRes = insertCategoryStmt.run(tenant.id, row.category, row.category_ar, nowIso);
          categoryId = Number(catRes.lastInsertRowid);
          categoriesCreated++;
        }
      }

      let existing = null;
      if (row.sku !== '') {
        existing = findBySkuStmt.get(tenant.id, row.sku);
      }
      if (!existing && row.barcode !== '') {
        existing = findByBarcodeStmt.get(tenant.id, row.barcode);
      }
      if (!existing && row.sku === '' && row.barcode === '') {
        existing = findByNameStmt.get(tenant.id, row.name_fr);
      }

      let productId;
      if (existing) {
        const nextSku = row.sku !== '' ? row.sku : existing.sku;
        const nextBarcode = row.barcode !== '' ? row.barcode : existing.barcode;

        if (nextSku !== '' && conflictSkuStmt.get(tenant.id, nextSku, existing.id)) {
          throw createHttpError(400, 'Catalog validation failed', [
            { row: row.rowNum, message: `SKU "${nextSku}" conflicts with another product` },
          ]);
        }
        if (nextBarcode !== '' && conflictBarcodeStmt.get(tenant.id, nextBarcode, existing.id)) {
          throw createHttpError(400, 'Catalog validation failed', [
            { row: row.rowNum, message: `Barcode "${nextBarcode}" conflicts with another product` },
          ]);
        }

        const nextCategoryId = categoryId !== null ? categoryId : existing.category_id;
        const nextNameAr = row.name_ar !== '' ? row.name_ar : existing.name_ar;
        const nextNameEn = row.name_en !== '' ? row.name_en : existing.name_en;
        const nextIcon = row.icon !== '' ? row.icon : (existing.icon ?? '');
        const nextUnit = row.unit !== '' ? row.unit : existing.unit;
        const nextPriceWhole = row.price_whole !== undefined ? row.price_whole : existing.price_whole;
        const nextPriceCost = row.price_cost !== undefined ? row.price_cost : existing.price_cost;
        const nextDci = row.dci !== '' ? row.dci : existing.dci;
        const nextTrackFefo = row.track_fefo !== undefined ? row.track_fefo : existing.track_fefo;
        const nextRequiresCnam = row.requires_cnam !== undefined ? row.requires_cnam : existing.requires_cnam;
        const nextStation = row.kitchen_station !== '' ? row.kitchen_station : (existing.kitchen_station || 'KITCHEN');
        const nextIsTop = row.is_top !== undefined ? row.is_top : (existing.is_top ?? 0);
        const nextIsOutOfStock = row.is_out_of_stock !== undefined ? row.is_out_of_stock : (existing.is_out_of_stock ?? 0);
        const nextModifiersJson = row.modifiers_json !== undefined ? row.modifiers_json : (existing.modifiers_json || '[]');

        updateProductStmt.run(
          nextCategoryId,
          nextSku,
          nextBarcode,
          row.name_fr,
          nextNameAr,
          nextNameEn,
          nextIcon,
          nextUnit,
          row.price_retail,
          nextPriceWhole,
          nextPriceCost,
          nextDci,
          nextTrackFefo,
          nextRequiresCnam,
          nextStation,
          nextIsTop,
          nextIsOutOfStock,
          nextModifiersJson,
          nowIso,
          existing.id,
          tenant.id,
        );
        productId = existing.id;
        updated++;
      } else {
        const prodRes = insertProductStmt.run(
          tenant.id,
          categoryId,
          row.sku,
          row.barcode,
          row.name_fr,
          row.name_ar,
          row.name_en,
          row.icon ?? '',
          row.unit || 'unit',
          row.price_retail,
          row.price_whole ?? 0,
          row.price_cost ?? 0,
          row.dci,
          row.track_fefo ?? 0,
          row.requires_cnam ?? 0,
          row.kitchen_station || 'KITCHEN',
          row.is_top ?? 0,
          row.is_out_of_stock ?? 0,
          row.modifiers_json ?? '[]',
          nowIso,
          nowIso,
        );
        productId = Number(prodRes.lastInsertRowid);
        created++;
      }

      if (row.lot_number !== '' && row.expires_at !== '') {
        const batchQty = row.qty ?? 0;
        const batchCost = row.price_cost ?? 0;
        const existingBatch = findBatchStmt.get(tenant.id, productId, row.lot_number);
        if (existingBatch) {
          updateBatchStmt.run(batchQty, batchCost, row.expires_at, existingBatch.id);
        } else {
          insertBatchStmt.run(tenant.id, productId, row.lot_number, batchQty, batchCost, row.expires_at);
        }
      }
    }

    const summary = {
      format: decoded.format,
      totalRows: rows.length,
      created,
      updated,
      categoriesCreated,
    };

    db.prepare(`
      INSERT INTO audit_logs (
        tenant_id, actor, action, title, subtitle, entity_type, entity_id, after_json, time_label
      ) VALUES (?, ?, 'CATALOG_IMPORT', ?, ?, 'catalog', ?, ?, ?)
    `).run(
      tenant.id,
      String(input?.actor || 'M. Taha Chouaib'),
      `Import catalogue (${decoded.format.toUpperCase()}) · ${tenant.name}`,
      `${created} créés, ${updated} mis à jour, ${categoriesCreated} catégories`,
      String(tenant.id),
      JSON.stringify(summary),
      nowHM(),
    );

    db.exec('COMMIT;');
  } catch (err) {
    try {
      db.exec('ROLLBACK;');
    } catch {
      // ignore rollback error
    }
    throw err;
  }

  return {
    ok: true,
    tenantId: tenant.id,
    format: decoded.format,
    totalRows: rows.length,
    created,
    updated,
    categoriesCreated,
    errors: [],
  };
}

module.exports = {
  importCatalog,
  parseCsvText,
  parseXlsxBuffer,
  normalizeHeader,
};
