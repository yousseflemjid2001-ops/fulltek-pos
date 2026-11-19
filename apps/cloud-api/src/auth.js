const crypto = require('node:crypto');
const { verifyPassword } = require('./db');

const DEFAULT_JWT_SECRET = 'fulltek-mauritania-dev-secret';
const DEFAULT_EXPIRES_IN_SEC = 86400;
const BASE64URL_RE = /^[A-Za-z0-9_-]+$/;

function nowHM() {
  const d = new Date();
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

function getJwtSecret(overrideSecret) {
  if (overrideSecret !== undefined) {
    if ((typeof overrideSecret === 'string' || Buffer.isBuffer(overrideSecret)) && overrideSecret.length > 0) {
      return overrideSecret;
    }
    return null;
  }
  const envSecret = process.env.JWT_SECRET;
  if (typeof envSecret === 'string' && envSecret.length > 0) {
    return envSecret;
  }
  return DEFAULT_JWT_SECRET;
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function signJwt(payload, expiresInSec = DEFAULT_EXPIRES_IN_SEC, secret) {
  if (!isPlainObject(payload)) {
    throw new TypeError('JWT payload must be a plain object');
  }

  const resolvedExpiry = expiresInSec === undefined || expiresInSec === null
    ? DEFAULT_EXPIRES_IN_SEC
    : expiresInSec;
  if (typeof resolvedExpiry !== 'number' || !Number.isFinite(resolvedExpiry)) {
    throw new TypeError('expiresInSec must be a finite number');
  }

  const resolvedSecret = getJwtSecret(secret);
  if (!resolvedSecret) {
    throw new Error('JWT secret must be non-empty');
  }

  const nowSec = Math.floor(Date.now() / 1000);
  const iat = typeof payload.iat === 'number' && Number.isFinite(payload.iat)
    ? Math.floor(payload.iat)
    : nowSec;
  const exp = typeof payload.exp === 'number' && Number.isFinite(payload.exp)
    ? Math.floor(payload.exp)
    : Math.floor(nowSec + resolvedExpiry);

  const headerB64 = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' }), 'utf8').toString('base64url');
  const payloadB64 = Buffer.from(JSON.stringify({ ...payload, iat, exp }), 'utf8').toString('base64url');
  const signingInput = `${headerB64}.${payloadB64}`;
  const sigB64 = crypto
    .createHmac('sha256', resolvedSecret)
    .update(signingInput, 'utf8')
    .digest('base64url');

  return `${signingInput}.${sigB64}`;
}

function verifyJwt(token, secret) {
  const resolvedSecret = getJwtSecret(secret);
  if (!resolvedSecret) {
    return { valid: false, reason: 'missing_secret' };
  }

  if (typeof token !== 'string' || token.length === 0 || token.length > 16384) {
    return { valid: false, reason: 'malformed_token' };
  }

  const parts = token.split('.');
  if (parts.length !== 3) {
    return { valid: false, reason: 'malformed_token' };
  }

  const [headerB64, payloadB64, sigB64] = parts;
  if (!BASE64URL_RE.test(headerB64) || !BASE64URL_RE.test(payloadB64) || !BASE64URL_RE.test(sigB64)) {
    return { valid: false, reason: 'malformed_token' };
  }

  let header;
  try {
    header = JSON.parse(Buffer.from(headerB64, 'base64url').toString('utf8'));
  } catch {
    return { valid: false, reason: 'invalid_header' };
  }
  if (!isPlainObject(header)) {
    return { valid: false, reason: 'invalid_header' };
  }

  if (header.alg !== 'HS256') {
    return { valid: false, reason: 'unsupported_alg' };
  }
  if (header.typ !== undefined && (typeof header.typ !== 'string' || header.typ.toUpperCase() !== 'JWT')) {
    return { valid: false, reason: 'invalid_header' };
  }

  // Verify HMAC-SHA256 signature BEFORE decoding/trusting payload
  let actualSig;
  try {
    actualSig = Buffer.from(sigB64, 'base64url');
  } catch {
    return { valid: false, reason: 'invalid_signature' };
  }

  const expectedSig = crypto
    .createHmac('sha256', resolvedSecret)
    .update(`${headerB64}.${payloadB64}`, 'utf8')
    .digest();

  if (actualSig.length !== expectedSig.length || actualSig.toString('base64url') !== sigB64) {
    return { valid: false, reason: 'invalid_signature' };
  }
  if (!crypto.timingSafeEqual(actualSig, expectedSig)) {
    return { valid: false, reason: 'invalid_signature' };
  }

  let payload;
  try {
    payload = JSON.parse(Buffer.from(payloadB64, 'base64url').toString('utf8'));
  } catch {
    return { valid: false, reason: 'invalid_payload' };
  }
  if (!isPlainObject(payload)) {
    return { valid: false, reason: 'invalid_payload' };
  }

  const nowSec = Math.floor(Date.now() / 1000);
  if (typeof payload.exp !== 'number' || !Number.isFinite(payload.exp)) {
    return { valid: false, reason: 'invalid_payload' };
  }
  if (!(payload.exp > nowSec)) {
    return { valid: false, reason: 'expired' };
  }
  if (payload.nbf !== undefined) {
    if (typeof payload.nbf !== 'number' || !Number.isFinite(payload.nbf)) {
      return { valid: false, reason: 'invalid_payload' };
    }
    if (payload.nbf > nowSec) {
      return { valid: false, reason: 'not_yet_valid' };
    }
  }
  if (payload.iat !== undefined && (typeof payload.iat !== 'number' || !Number.isFinite(payload.iat))) {
    return { valid: false, reason: 'invalid_payload' };
  }

  return { valid: true, header, payload };
}

function extractBearerToken(req) {
  const raw = req && req.headers ? req.headers.authorization : null;
  if (typeof raw !== 'string') return null;
  const match = /^Bearer\s+([^\s]+)$/i.exec(raw.trim());
  return match ? match[1] : null;
}

function writeAuthAudit(db, entry) {
  try {
    db.prepare(`
      INSERT INTO audit_logs (
        actor, action, title, subtitle, entity_type, entity_id, ip_address, time_label
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      entry.actor,
      entry.action,
      entry.title,
      entry.subtitle,
      entry.entityType,
      entry.entityId,
      entry.ipAddress,
      nowHM(),
    );
  } catch {
    // Best-effort audit logging must not break auth flow
  }
}

function authenticateSuperAdmin(db, usernameOrEmail, password, options = {}) {
  if (
    typeof usernameOrEmail !== 'string' ||
    usernameOrEmail.trim() === '' ||
    typeof password !== 'string' ||
    password.length === 0
  ) {
    return { ok: false, status: 400, error: 'username and password are required' };
  }

  const identifier = usernameOrEmail.trim();
  const ipAddress = typeof options.ipAddress === 'string' ? options.ipAddress : '';

  const admin = db.prepare(`
    SELECT id, username, email, full_name, password_hash, role, active
    FROM super_admins
    WHERE username = ? OR (email != '' AND LOWER(email) = LOWER(?))
    LIMIT 1
  `).get(identifier, identifier);

  const valid = Boolean(
    admin &&
    Number(admin.active) === 1 &&
    admin.role === 'SUPER_ADMIN' &&
    verifyPassword(password, admin.password_hash),
  );

  if (!valid) {
    writeAuthAudit(db, {
      actor: identifier,
      action: 'SUPER_ADMIN_LOGIN_FAILED',
      title: 'Échec connexion Super-Admin',
      subtitle: `Tentative échouée (${identifier})`,
      entityType: 'super_admin',
      entityId: admin ? String(admin.id) : '',
      ipAddress,
    });
    return { ok: false, status: 401, error: 'Identifiant ou mot de passe Super-Admin incorrect' };
  }

  db.prepare(`
    UPDATE super_admins
    SET last_login_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
    WHERE id = ?
  `).run(admin.id);

  const expiresIn =
    typeof options.expiresInSec === 'number' && Number.isFinite(options.expiresInSec) && options.expiresInSec > 0
      ? Math.floor(options.expiresInSec)
      : DEFAULT_EXPIRES_IN_SEC;

  const token = signJwt(
    {
      sub: admin.id,
      id: admin.id,
      username: admin.username,
      email: admin.email,
      fullName: admin.full_name,
      role: 'SUPER_ADMIN',
    },
    expiresIn,
    options.jwtSecret,
  );

  writeAuthAudit(db, {
    actor: admin.full_name,
    action: 'SUPER_ADMIN_LOGIN',
    title: `Connexion Super-Admin · ${admin.username}`,
    subtitle: 'Authentification JWT réussie',
    entityType: 'super_admin',
    entityId: String(admin.id),
    ipAddress,
  });

  return {
    ok: true,
    status: 200,
    token,
    expiresIn,
    admin: {
      id: admin.id,
      username: admin.username,
      email: admin.email,
      fullName: admin.full_name,
      role: admin.role,
    },
  };
}

function defaultSendJson(res, status, data) {
  const body = JSON.stringify(data);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,PATCH,DELETE,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  });
  res.end(body);
}

function requireSuperAdmin(req, res, db, options = {}) {
  const respond = typeof options.sendJson === 'function' ? options.sendJson : defaultSendJson;
  const replyUnauthorized = (message) => {
    respond(res, 401, { error: message });
    return null;
  };

  const token = extractBearerToken(req);
  if (!token) {
    return replyUnauthorized('Authentification Super-Admin requise');
  }

  const verified = verifyJwt(token, options.jwtSecret);
  if (!verified.valid) {
    return replyUnauthorized(
      verified.reason === 'expired' ? 'Session Super-Admin expirée' : 'Jeton Super-Admin invalide',
    );
  }

  const { payload } = verified;
  if (payload.role !== 'SUPER_ADMIN') {
    return replyUnauthorized('Accès réservé au Super-Admin');
  }

  const adminId = Number.isInteger(payload.sub) ? payload.sub : payload.id;
  if (!Number.isInteger(adminId) || adminId <= 0) {
    return replyUnauthorized('Jeton Super-Admin invalide');
  }

  const admin = db.prepare(`
    SELECT id, username, email, full_name, role, active
    FROM super_admins
    WHERE id = ?
    LIMIT 1
  `).get(adminId);

  if (!admin || Number(admin.active) !== 1 || admin.role !== 'SUPER_ADMIN') {
    return replyUnauthorized('Compte Super-Admin inactif ou introuvable');
  }

  return {
    id: admin.id,
    username: admin.username,
    email: admin.email,
    fullName: admin.full_name,
    role: admin.role,
    payload,
  };
}

function requireTenantAuth(req, res, db, options = {}) {
  const respond = typeof options.sendJson === 'function' ? options.sendJson : defaultSendJson;
  const reply = (status, message) => {
    respond(res, status, { error: message });
    return null;
  };

  const token = extractBearerToken(req);
  if (!token) {
    return reply(401, 'Missing Bearer token');
  }

  const verified = verifyJwt(token, options.jwtSecret);
  if (!verified.valid) {
    return reply(401, verified.reason === 'expired' ? 'POS token expired' : 'Invalid or expired POS token');
  }

  const { payload } = verified;
  if (payload.role === 'SUPER_ADMIN') {
    return reply(401, 'Invalid or expired POS token');
  }

  const rawTid = payload.tenantId;
  const tenantId = typeof rawTid === 'number' ? rawTid : Number(rawTid);
  if (!Number.isInteger(tenantId) || tenantId <= 0) {
    return reply(401, 'Invalid or expired POS token');
  }

  const tenant = db.prepare('SELECT * FROM tenants WHERE id = ? LIMIT 1').get(tenantId);
  if (!tenant) {
    return reply(401, 'Tenant not found or inactive');
  }
  if (tenant.status === 'locked') {
    return reply(403, 'Tenant account is locked');
  }

  return tenant;
}

module.exports = {
  DEFAULT_JWT_SECRET,
  DEFAULT_EXPIRES_IN_SEC,
  getJwtSecret,
  signJwt,
  verifyJwt,
  extractBearerToken,
  authenticateSuperAdmin,
  requireSuperAdmin,
  requireTenantAuth,
};
