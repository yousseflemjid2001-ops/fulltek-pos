const crypto = require('node:crypto');

const MS_PER_DAY = 86_400_000;
const BASE64URL_RE = /^[A-Za-z0-9_-]+$/;

function createHttpError(statusCode, message) {
  const err = new Error(message);
  err.statusCode = statusCode;
  return err;
}

function withTransaction(db, fn) {
  if (db.isTransaction) {
    return fn();
  }
  db.exec('BEGIN IMMEDIATE;');
  try {
    const result = fn();
    db.exec('COMMIT;');
    return result;
  } catch (err) {
    try {
      db.exec('ROLLBACK;');
    } catch {
      // ignore rollback error
    }
    throw err;
  }
}

function generateEd25519Keypair() {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519', {
    publicKeyEncoding: { type: 'spki', format: 'pem' },
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  });
  const keyId = `ed25519-${crypto.createHash('sha256').update(publicKey, 'utf8').digest('hex').slice(0, 12)}`;
  return { keyId, algorithm: 'Ed25519', publicKey, privateKey };
}

function getOrCreateSigningKey(db) {
  return withTransaction(db, () => {
    const existing = db.prepare(`
      SELECT id, key_id, algorithm, public_key_pem, private_key_pem, is_active, created_at
      FROM signing_keys
      WHERE is_active = 1
      ORDER BY id DESC
      LIMIT 1
    `).get();

    if (existing) {
      return {
        keyId: existing.key_id,
        algorithm: existing.algorithm || 'Ed25519',
        publicKey: existing.public_key_pem,
        privateKey: existing.private_key_pem,
        createdAt: existing.created_at,
      };
    }

    const kp = generateEd25519Keypair();
    const createdAt = new Date().toISOString();
    db.prepare(`
      INSERT INTO signing_keys (key_id, algorithm, public_key_pem, private_key_pem, is_active, created_at)
      VALUES (?, ?, ?, ?, 1, ?)
    `).run(kp.keyId, kp.algorithm, kp.publicKey, kp.privateKey, createdAt);

    return {
      keyId: kp.keyId,
      algorithm: kp.algorithm,
      publicKey: kp.publicKey,
      privateKey: kp.privateKey,
      createdAt,
    };
  });
}

function rotateSigningKey(db) {
  return withTransaction(db, () => {
    const nowIso = new Date().toISOString();
    db.prepare(`
      UPDATE signing_keys
      SET is_active = 0, revoked_at = ?
      WHERE is_active = 1
    `).run(nowIso);

    const kp = generateEd25519Keypair();
    db.prepare(`
      INSERT INTO signing_keys (key_id, algorithm, public_key_pem, private_key_pem, is_active, created_at)
      VALUES (?, ?, ?, ?, 1, ?)
    `).run(kp.keyId, kp.algorithm, kp.publicKey, kp.privateKey, nowIso);

    return {
      keyId: kp.keyId,
      algorithm: kp.algorithm,
      publicKey: kp.publicKey,
      privateKey: kp.privateKey,
      createdAt: nowIso,
    };
  });
}

function getPublicKey(db, keyId = null) {
  if (keyId && String(keyId).trim() !== '') {
    const row = db.prepare(`
      SELECT key_id, algorithm, public_key_pem
      FROM signing_keys
      WHERE key_id = ?
      LIMIT 1
    `).get(String(keyId).trim());

    return row
      ? {
          keyId: row.key_id,
          algorithm: row.algorithm || 'Ed25519',
          publicKey: row.public_key_pem,
        }
      : null;
  }

  const active = getOrCreateSigningKey(db);
  return {
    keyId: active.keyId,
    algorithm: active.algorithm,
    publicKey: active.publicKey,
  };
}

function generateUnlockCode(db) {
  const checkLease = db.prepare('SELECT 1 FROM offline_lease_tokens WHERE unlock_code = ? LIMIT 1');
  const checkLegacy = db.prepare('SELECT 1 FROM offline_codes WHERE code = ? LIMIT 1');

  for (let attempt = 0; attempt < 16; attempt++) {
    const g1 = crypto.randomInt(0, 10000).toString().padStart(4, '0');
    const g2 = crypto.randomInt(0, 10000).toString().padStart(4, '0');
    const g3 = crypto.randomInt(0, 10000).toString().padStart(4, '0');
    const code = `${g1}-${g2}-${g3}`;

    if (!checkLease.get(code) && !checkLegacy.get(code)) {
      return code;
    }
  }
  throw new Error('Failed to generate unique 12-digit unlock code after maximum attempts');
}

function parseStrictInteger(value) {
  if (typeof value === 'number') {
    return Number.isInteger(value) ? value : NaN;
  }
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!/^-?\d+$/.test(trimmed)) return NaN;
    const parsed = Number(trimmed);
    return Number.isSafeInteger(parsed) ? parsed : NaN;
  }
  return NaN;
}

function parseTimestampMs(value) {
  if (value instanceof Date) return value.getTime();
  if (typeof value === 'number') return value;
  if (typeof value === 'string' && value.trim() !== '') {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? NaN : parsed;
  }
  return NaN;
}

function issueOfflineLicense(db, tenantId, options = {}) {
  const tid = parseStrictInteger(tenantId);
  if (!Number.isInteger(tid) || tid <= 0) {
    throw createHttpError(400, 'Invalid tenantId');
  }

  const tenant = db.prepare(`
    SELECT id, tenant_code, name, plan, tills
    FROM tenants
    WHERE id = ?
  `).get(tid);
  if (!tenant) {
    throw createHttpError(404, 'Tenant not found');
  }

  const days = options.days === undefined ? 30 : parseStrictInteger(options.days);
  if (!Number.isInteger(days) || days < 1 || days > 3650) {
    throw createHttpError(400, 'days must be an integer between 1 and 3650');
  }

  const graceDays = options.graceDays === undefined ? 7 : parseStrictInteger(options.graceDays);
  if (!Number.isInteger(graceDays) || graceDays < 0 || graceDays > 365) {
    throw createHttpError(400, 'graceDays must be an integer between 0 and 365');
  }

  let explicitBranchId = null;
  if (options.branchId !== undefined && options.branchId !== null) {
    const parsedBranchId = parseStrictInteger(options.branchId);
    if (!Number.isInteger(parsedBranchId) || parsedBranchId <= 0) {
      throw createHttpError(400, 'Invalid branchId');
    }
    const branch = db.prepare('SELECT id, tenant_id FROM branches WHERE id = ?').get(parsedBranchId);
    if (!branch) {
      throw createHttpError(404, 'Branch not found');
    }
    if (branch.tenant_id !== tenant.id) {
      throw createHttpError(400, 'Branch does not belong to tenant');
    }
    explicitBranchId = branch.id;
  }

  const registerCode = options.registerCode && String(options.registerCode).trim() !== ''
    ? String(options.registerCode).trim()
    : null;
  const hardwareFingerprint = options.hardwareFingerprint && String(options.hardwareFingerprint).trim() !== ''
    ? String(options.hardwareFingerprint).trim()
    : null;

  const issuedAtDate = options.now instanceof Date
    ? options.now
    : (options.now !== undefined && options.now !== null ? new Date(options.now) : new Date());
  if (Number.isNaN(issuedAtDate.getTime())) {
    throw createHttpError(400, 'Invalid issuedAt date');
  }
  const expiresAtDate = new Date(issuedAtDate.getTime() + days * MS_PER_DAY);

  return withTransaction(db, () => {
    const signingKey = getOrCreateSigningKey(db);
    const code = generateUnlockCode(db);
    const nonce = crypto.randomBytes(16).toString('hex');

    let registerId = null;
    let branchId = explicitBranchId;

    if (registerCode) {
      const reg = db.prepare(`
        SELECT id, branch_id
        FROM pos_registers
        WHERE tenant_id = ? AND register_code = ?
        LIMIT 1
      `).get(tenant.id, registerCode);
      if (reg) {
        registerId = reg.id;
        if (!branchId && reg.branch_id) branchId = reg.branch_id;
      }
    }
    if (!branchId) {
      const mainBr = db.prepare(`
        SELECT id FROM branches WHERE tenant_id = ? AND is_main = 1 ORDER BY id ASC LIMIT 1
      `).get(tenant.id);
      if (mainBr) branchId = mainBr.id;
    }

    const payload = {
      version: 1,
      keyId: signingKey.keyId,
      tenantId: tenant.id,
      tenantCode: tenant.tenant_code,
      storeName: tenant.name,
      plan: tenant.plan || 'Pro',
      tillsQuota: Number(tenant.tills || 1),
      registerCode,
      hardwareFingerprint,
      code,
      days,
      graceDays,
      issuedAt: issuedAtDate.toISOString(),
      expiresAt: expiresAtDate.toISOString(),
      nonce,
    };

    const payloadJson = JSON.stringify(payload);
    const payloadB64 = Buffer.from(payloadJson, 'utf8').toString('base64url');
    const signature = crypto
      .sign(null, Buffer.from(payloadB64, 'utf8'), signingKey.privateKey)
      .toString('base64url');
    const leaseToken = `${payloadB64}.${signature}`;

    const codeInfo = db.prepare(`
      INSERT INTO offline_codes (
        tenant_id, branch_id, register_id, code, days, grace_days,
        key_id, register_code, hardware_fingerprint, payload_json,
        lease_token, signature, expires_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      tenant.id,
      branchId,
      registerId,
      code,
      days,
      graceDays,
      signingKey.keyId,
      registerCode || '',
      hardwareFingerprint || '',
      payloadJson,
      leaseToken,
      signature,
      payload.expiresAt,
    );

    const unlockCodeId = Number(codeInfo.lastInsertRowid);

    db.prepare(`
      INSERT INTO offline_lease_tokens (
        tenant_id, branch_id, register_id, unlock_code_id, key_id,
        unlock_code, register_code, hardware_fingerprint, days, grace_days,
        nonce, payload_json, payload_b64, signature, lease_token,
        issued_at, expires_at, status, revoked
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'ACTIVE', 0)
    `).run(
      tenant.id,
      branchId,
      registerId,
      unlockCodeId,
      signingKey.keyId,
      code,
      registerCode || '',
      hardwareFingerprint || '',
      days,
      graceDays,
      nonce,
      payloadJson,
      payloadB64,
      signature,
      leaseToken,
      payload.issuedAt,
      payload.expiresAt,
    );

    return {
      ok: true,
      code,
      days,
      graceDays,
      storeName: tenant.name,
      keyId: signingKey.keyId,
      issuedAt: payload.issuedAt,
      expiresAt: payload.expiresAt,
      payload,
      signature,
      leaseToken,
      publicKey: signingKey.publicKey,
    };
  });
}

function verifyOfflineLicense(leaseToken, publicKeyPem, options = {}) {
  if (typeof leaseToken !== 'string' || leaseToken.trim() === '') {
    return { valid: false, reason: 'malformed_token' };
  }

  const parts = leaseToken.trim().split('.');
  if (parts.length !== 2) {
    return { valid: false, reason: 'malformed_token' };
  }
  const [payloadB64, signature] = parts;
  if (!BASE64URL_RE.test(payloadB64) || !BASE64URL_RE.test(signature)) {
    return { valid: false, reason: 'malformed_token' };
  }

  let publicKeyObj;
  try {
    if (publicKeyPem instanceof crypto.KeyObject) {
      publicKeyObj = publicKeyPem;
    } else if (typeof publicKeyPem === 'string' && publicKeyPem.includes('BEGIN PUBLIC KEY')) {
      publicKeyObj = crypto.createPublicKey(publicKeyPem);
    } else {
      return { valid: false, reason: 'invalid_public_key' };
    }
  } catch {
    return { valid: false, reason: 'invalid_public_key' };
  }
  if (!publicKeyObj || publicKeyObj.type !== 'public' || publicKeyObj.asymmetricKeyType !== 'ed25519') {
    return { valid: false, reason: 'invalid_public_key' };
  }

  // 1. Cryptographic signature verification BEFORE trusting/parsing payload
  let sigBuf;
  try {
    sigBuf = Buffer.from(signature, 'base64url');
  } catch {
    return { valid: false, reason: 'invalid_signature' };
  }
  if (sigBuf.length !== 64) {
    return { valid: false, reason: 'invalid_signature' };
  }

  let sigOk = false;
  try {
    sigOk = crypto.verify(null, Buffer.from(payloadB64, 'utf8'), publicKeyObj, sigBuf);
  } catch {
    return { valid: false, reason: 'invalid_public_key' };
  }
  if (!sigOk) {
    return { valid: false, reason: 'invalid_signature' };
  }

  // 2. Payload decode & structural validation
  let payload;
  try {
    payload = JSON.parse(Buffer.from(payloadB64, 'base64url').toString('utf8'));
  } catch {
    return { valid: false, reason: 'invalid_payload' };
  }
  if (
    !payload ||
    typeof payload !== 'object' ||
    !Number.isInteger(payload.tenantId) ||
    typeof payload.code !== 'string' ||
    typeof payload.issuedAt !== 'string' ||
    typeof payload.expiresAt !== 'string'
  ) {
    return { valid: false, reason: 'invalid_payload' };
  }

  const expiresAtMs = Date.parse(payload.expiresAt);
  const issuedAtMs = Date.parse(payload.issuedAt);
  if (Number.isNaN(expiresAtMs) || Number.isNaN(issuedAtMs)) {
    return { valid: false, payload, reason: 'invalid_payload' };
  }

  // 3. Clock resolution & anti-clock-rollback check
  const nowMs = options.now !== undefined && options.now !== null
    ? parseTimestampMs(options.now)
    : Date.now();
  if (!Number.isFinite(nowMs)) {
    return { valid: false, payload, reason: 'invalid_clock' };
  }

  if (options.lastVerifiedAt !== undefined && options.lastVerifiedAt !== null) {
    const lastMs = parseTimestampMs(options.lastVerifiedAt);
    if (Number.isFinite(lastMs) && nowMs < lastMs) {
      return { valid: false, payload, reason: 'clock_rollback_detected' };
    }
  }

  // 4. Expiry & grace window
  let inGrace = false;
  const graceDays = Number.isFinite(Number(payload.graceDays)) ? Math.max(0, Number(payload.graceDays)) : 0;
  if (nowMs > expiresAtMs) {
    if (options.allowGrace === true && nowMs <= expiresAtMs + graceDays * MS_PER_DAY) {
      inGrace = true;
    } else {
      return { valid: false, payload, reason: 'expired' };
    }
  }

  // 5. Hardware fingerprint binding
  if (options.requireHardwareMatch === true) {
    if (!payload.hardwareFingerprint) {
      return { valid: false, payload, reason: 'hardware_unbound' };
    }
    if (
      !options.hardwareFingerprint ||
      String(options.hardwareFingerprint).trim() !== payload.hardwareFingerprint
    ) {
      return { valid: false, payload, reason: 'hardware_mismatch' };
    }
  } else if (
    payload.hardwareFingerprint &&
    options.hardwareFingerprint !== undefined &&
    options.hardwareFingerprint !== payload.hardwareFingerprint
  ) {
    return { valid: false, payload, reason: 'hardware_mismatch' };
  }

  // 6. Register code binding
  if (
    payload.registerCode &&
    options.registerCode !== undefined &&
    options.registerCode !== payload.registerCode
  ) {
    return { valid: false, payload, reason: 'register_mismatch' };
  }

  return inGrace ? { valid: true, payload, inGrace: true } : { valid: true, payload };
}

module.exports = {
  getOrCreateSigningKey,
  rotateSigningKey,
  getPublicKey,
  generateUnlockCode,
  issueOfflineLicense,
  verifyOfflineLicense,
};
