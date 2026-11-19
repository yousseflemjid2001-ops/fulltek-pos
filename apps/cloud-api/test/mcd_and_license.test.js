const { describe, it, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { DatabaseSync } = require('node:sqlite');

// Isolate module-load singleton DB away from apps/cloud-api/data/fulltek.db
const singletonTmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'fulltek-m1-singleton-'));
process.env.DB_PATH = path.join(singletonTmpDir, 'singleton.db');

const {
  createDb,
  db: singletonDb,
  hashPassword,
  verifyPassword,
} = require('../src/db');
const {
  getOrCreateSigningKey,
  rotateSigningKey,
  getPublicKey,
  generateUnlockCode,
  issueOfflineLicense,
  verifyOfflineLicense,
} = require('../src/license');

after(() => {
  try {
    singletonDb.close();
  } catch {
    // ignore
  }
  fs.rmSync(singletonTmpDir, { recursive: true, force: true });
});

function withTempDir(fn) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'fulltek-m1-'));
  try {
    return fn(dir);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

const EXPECTED_27_TABLES = [
  'tenants',
  'branches',
  'pos_registers',
  'super_admins',
  'roles',
  'permissions',
  'role_permissions',
  'users',
  'user_permissions',
  'signing_keys',
  'offline_codes',
  'offline_lease_tokens',
  'saas_payments',
  'audit_logs',
  'categories',
  'products',
  'stock_batches',
  'ingredients',
  'recipes_bom',
  'dining_zones',
  'reservations_vip',
  'orders',
  'order_items',
  'returns_remakes_comps',
  'customer_credits_karni',
  'karni_transactions',
  'cash_closings_z',
];

describe('1. Fresh createDb(tempPath) initialization', () => {
  it('enables WAL journal mode and foreign_keys ON', () => {
    withTempDir((dir) => {
      const dbPath = path.join(dir, 'fresh.db');
      const db = createDb(dbPath);
      try {
        const jm = db.prepare('PRAGMA journal_mode').get();
        const fk = db.prepare('PRAGMA foreign_keys').get();
        assert.equal(String(jm.journal_mode).toLowerCase(), 'wal');
        assert.equal(fk.foreign_keys, 1);

        assert.throws(() => {
          db.prepare("INSERT INTO branches (tenant_id, code, name) VALUES (999999, 'BR-X', 'Invalid')").run();
        }, /FOREIGN KEY/i);
      } finally {
        db.close();
      }
    });
  });

  it('creates all 27 MCD tables', () => {
    withTempDir((dir) => {
      const dbPath = path.join(dir, 'tables.db');
      const db = createDb(dbPath);
      try {
        const rows = db
          .prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'")
          .all();
        const tableNames = rows.map((r) => r.name);
        for (const expected of EXPECTED_27_TABLES) {
          assert.ok(tableNames.includes(expected), `Missing table: ${expected}`);
        }
        assert.equal(tableNames.length, 27);
      } finally {
        db.close();
      }
    });
  });

  it('verifies upgraded columns across existing and new tables via PRAGMA table_info', () => {
    withTempDir((dir) => {
      const dbPath = path.join(dir, 'cols.db');
      const db = createDb(dbPath);
      try {
        const colNames = (tbl) => db.prepare(`PRAGMA table_info(${tbl})`).all().map((c) => c.name);

        for (const col of ['branch_id', 'role_id', 'email', 'phone', 'failed_pin_count', 'locked_until', 'updated_at']) {
          assert.ok(colNames('users').includes(col), `users missing ${col}`);
        }
        for (const col of ['name_en', 'unit', 'price_cost', 'dci', 'active', 'created_at', 'updated_at']) {
          assert.ok(colNames('products').includes(col), `products missing ${col}`);
        }
        for (const col of [
          'branch_id', 'register_id', 'grace_days', 'key_id', 'register_code',
          'hardware_fingerprint', 'payload_json', 'lease_token', 'signature', 'expires_at', 'redeemed_at',
        ]) {
          assert.ok(colNames('offline_codes').includes(col), `offline_codes missing ${col}`);
        }
        for (const col of ['branch_id', 'purchase_price_mru', 'supplier_name', 'is_recalled', 'cold_chain']) {
          assert.ok(colNames('stock_batches').includes(col), `stock_batches missing ${col}`);
        }
        for (const col of [
          'unlock_code_id', 'key_id', 'unlock_code', 'nonce', 'payload_json',
          'payload_b64', 'signature', 'lease_token', 'issued_at', 'expires_at', 'last_verified_at', 'status', 'revoked',
        ]) {
          assert.ok(colNames('offline_lease_tokens').includes(col), `offline_lease_tokens missing ${col}`);
        }
      } finally {
        db.close();
      }
    });
  });

  it('enforces partial unique indexes on products(tenant_id, sku) and products(tenant_id, barcode)', () => {
    withTempDir((dir) => {
      const dbPath = path.join(dir, 'indexes.db');
      const db = createDb(dbPath);
      try {
        const idxs = db
          .prepare("SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'products'")
          .all()
          .map((r) => r.name);
        assert.ok(idxs.includes('idx_products_tenant_sku'));
        assert.ok(idxs.includes('idx_products_tenant_barcode'));

        const t1 = db.prepare('SELECT id FROM tenants ORDER BY id ASC LIMIT 1').get().id;
        const t2 = db.prepare('SELECT id FROM tenants ORDER BY id ASC LIMIT 1 OFFSET 1').get().id;

        // Multiple empty SKU/barcode products allowed in same tenant
        db.prepare("INSERT INTO products (tenant_id, sku, barcode, name_fr, price_retail) VALUES (?, '', '', 'Sans Code 1', 100)").run(t1);
        db.prepare("INSERT INTO products (tenant_id, sku, barcode, name_fr, price_retail) VALUES (?, '', '', 'Sans Code 2', 120)").run(t1);

        // Non-empty SKU unique per tenant
        db.prepare("INSERT INTO products (tenant_id, sku, barcode, name_fr, price_retail) VALUES (?, 'SKU-UNIQ-1', '', 'Prod A', 200)").run(t1);
        assert.throws(() => {
          db.prepare("INSERT INTO products (tenant_id, sku, barcode, name_fr, price_retail) VALUES (?, 'SKU-UNIQ-1', '', 'Prod B', 250)").run(t1);
        }, /UNIQUE/i);
        // Same SKU in another tenant succeeds
        db.prepare("INSERT INTO products (tenant_id, sku, barcode, name_fr, price_retail) VALUES (?, 'SKU-UNIQ-1', '', 'Prod T2', 250)").run(t2);

        // Non-empty barcode unique per tenant
        db.prepare("INSERT INTO products (tenant_id, sku, barcode, name_fr, price_retail) VALUES (?, '', '629000000001', 'Barcode A', 300)").run(t1);
        assert.throws(() => {
          db.prepare("INSERT INTO products (tenant_id, sku, barcode, name_fr, price_retail) VALUES (?, '', '629000000001', 'Barcode B', 350)").run(t1);
        }, /UNIQUE/i);
        db.prepare("INSERT INTO products (tenant_id, sku, barcode, name_fr, price_retail) VALUES (?, '', '629000000001', 'Barcode T2', 350)").run(t2);
      } finally {
        db.close();
      }
    });
  });
});

describe('2. Idempotent migration of legacy 11-table SQLite database', () => {
  it('migrates pre-upgrade 11-table DB without data loss and survives repeated createDb() calls', () => {
    withTempDir((dir) => {
      const legacyPath = path.join(dir, 'legacy.db');
      const raw = new DatabaseSync(legacyPath);
      try {
        raw.exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;');
        raw.exec(`
          CREATE TABLE tenants (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant_code TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            module TEXT NOT NULL,
            sub_type TEXT DEFAULT '',
            city TEXT NOT NULL,
            district TEXT DEFAULT '',
            address TEXT DEFAULT '',
            legal_name TEXT DEFAULT '',
            nif TEXT DEFAULT '',
            rc TEXT DEFAULT '',
            phone TEXT NOT NULL,
            email TEXT DEFAULT '',
            manager TEXT DEFAULT '',
            default_lang TEXT DEFAULT 'fr',
            plan TEXT DEFAULT 'Pro',
            billing TEXT DEFAULT 'monthly',
            mrr INTEGER DEFAULT 3000,
            tills INTEGER DEFAULT 1,
            days_left INTEGER DEFAULT 30,
            status TEXT DEFAULT 'active',
            online INTEGER DEFAULT 1,
            pending_sync INTEGER DEFAULT 0,
            enabled_themes TEXT DEFAULT '["01","06","07","11"]',
            features TEXT DEFAULT '[]',
            pay_methods TEXT DEFAULT '["Bankily","Masrivi","Sedad","Cash"]',
            hardware TEXT DEFAULT '[]',
            notes TEXT DEFAULT '',
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            account_password TEXT DEFAULT '',
            owner_pin TEXT DEFAULT '4242',
            initial_pay_method TEXT DEFAULT '',
            initial_pay_ref TEXT DEFAULT '',
            initial_offline_code TEXT DEFAULT '',
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
          );
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
            full_name TEXT NOT NULL,
            username TEXT NOT NULL,
            pass_hash TEXT NOT NULL,
            pin_code TEXT NOT NULL,
            role TEXT NOT NULL,
            active INTEGER DEFAULT 1,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(tenant_id, username)
          );
          CREATE TABLE saas_payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            pay_code TEXT UNIQUE NOT NULL,
            tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
            method TEXT NOT NULL,
            ref TEXT DEFAULT '',
            amount INTEGER NOT NULL,
            status TEXT DEFAULT 'pending',
            time_label TEXT DEFAULT '',
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          );
          CREATE TABLE offline_codes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
            code TEXT NOT NULL,
            days INTEGER NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          );
          CREATE TABLE audit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant_id INTEGER REFERENCES tenants(id) ON DELETE SET NULL,
            actor TEXT DEFAULT 'M. Taha Chouaib',
            title TEXT NOT NULL,
            subtitle TEXT NOT NULL,
            time_label TEXT NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          );
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
            name_fr TEXT NOT NULL,
            name_ar TEXT DEFAULT '',
            name_en TEXT DEFAULT ''
          );
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
            category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
            sku TEXT DEFAULT '',
            barcode TEXT DEFAULT '',
            name_fr TEXT NOT NULL,
            name_ar TEXT DEFAULT '',
            price_retail INTEGER NOT NULL,
            price_whole INTEGER DEFAULT 0,
            track_fefo INTEGER DEFAULT 0,
            requires_cnam INTEGER DEFAULT 0
          );
          CREATE TABLE stock_batches (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
            product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
            lot_number TEXT NOT NULL,
            qty INTEGER NOT NULL,
            expires_at TEXT NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          );
          CREATE TABLE orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
            order_code TEXT NOT NULL,
            table_name TEXT DEFAULT '',
            status TEXT DEFAULT 'PAID',
            pay_method TEXT NOT NULL,
            total_mru INTEGER NOT NULL,
            cnam_cover INTEGER DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          );
          CREATE TABLE order_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
            product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
            qty INTEGER NOT NULL,
            unit_price INTEGER NOT NULL
          );
          CREATE TABLE cash_closings_z (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
            expected_mru INTEGER NOT NULL,
            counted_mru INTEGER NOT NULL,
            digital_mru INTEGER NOT NULL,
            variance_mru INTEGER NOT NULL,
            approved_by TEXT DEFAULT '',
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          );
        `);

        const pwHash = hashPassword('LegacyPass1!');
        const tInfo = raw
          .prepare("INSERT INTO tenants (tenant_code, name, module, city, phone, username, password_hash) VALUES ('FT-LEG-1', 'Legacy Store', 'market', 'Nouakchott', '+222 40 00 00 00', 'legacy_owner', ?)")
          .run(pwHash);
        const tid = Number(tInfo.lastInsertRowid);
        raw.prepare("INSERT INTO users (tenant_id, full_name, username, pass_hash, pin_code, role) VALUES (?, 'Legacy Owner', 'legacy_owner', ?, '1234', 'OWNER')").run(tid, pwHash);
        const cInfo = raw.prepare("INSERT INTO categories (tenant_id, name_fr) VALUES (?, 'Boissons')").run(tid);
        const cid = Number(cInfo.lastInsertRowid);
        raw.prepare("INSERT INTO products (tenant_id, category_id, sku, barcode, name_fr, price_retail) VALUES (?, ?, '', '', 'Eau 1.5L', 30)").run(tid, cid);
        raw.prepare("INSERT INTO products (tenant_id, category_id, sku, barcode, name_fr, price_retail) VALUES (?, ?, '', '', 'Jus Local', 80)").run(tid, cid);
        raw.prepare("INSERT INTO offline_codes (tenant_id, code, days) VALUES (?, '1234-5678', 30)").run(tid);
        raw.prepare("INSERT INTO saas_payments (pay_code, tenant_id, method, amount) VALUES ('P-LEG-1', ?, 'Bankily', 3000)").run(tid);
      } finally {
        raw.close();
      }

      const db1 = createDb(legacyPath);
      db1.close();

      const db2 = createDb(legacyPath);
      try {
        const tables = db2
          .prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'")
          .all()
          .map((r) => r.name);
        for (const t of EXPECTED_27_TABLES) {
          assert.ok(tables.includes(t), `Migrated DB missing table ${t}`);
        }

        const prodCols = db2.prepare('PRAGMA table_info(products)').all().map((c) => c.name);
        const offCols = db2.prepare('PRAGMA table_info(offline_codes)').all().map((c) => c.name);
        const userCols = db2.prepare('PRAGMA table_info(users)').all().map((c) => c.name);
        assert.ok(prodCols.includes('name_en'));
        assert.ok(offCols.includes('lease_token'));
        assert.ok(userCols.includes('branch_id'));
        assert.ok(userCols.includes('role_id'));

        assert.equal(db2.prepare('SELECT COUNT(*) AS cnt FROM tenants').get().cnt, 1);
        assert.equal(db2.prepare('SELECT tenant_code FROM tenants').get().tenant_code, 'FT-LEG-1');
        assert.equal(db2.prepare('SELECT COUNT(*) AS cnt FROM users').get().cnt, 1);
        assert.equal(db2.prepare('SELECT COUNT(*) AS cnt FROM products').get().cnt, 2);
        assert.equal(db2.prepare('SELECT code FROM offline_codes').get().code, '1234-5678');

        // Core security & RBAC seeded even on populated legacy DB
        assert.equal(db2.prepare("SELECT username FROM super_admins WHERE username = 'taha'").get().username, 'taha');
        assert.equal(db2.prepare('SELECT COUNT(*) AS cnt FROM roles WHERE is_system = 1').get().cnt, 9);
        assert.ok(db2.prepare('SELECT COUNT(*) AS cnt FROM permissions').get().cnt >= 11);

        // Existing user backfilled with OWNER role_id and BR-01 branch_id
        const legUser = db2.prepare("SELECT role_id, branch_id FROM users WHERE username = 'legacy_owner'").get();
        assert.ok(legUser.role_id > 0);
        assert.ok(legUser.branch_id > 0);
      } finally {
        db2.close();
      }
    });
  });
});

describe('3. Seed verification (Super-Admin, 9 CDC roles, permissions & demo rows)', () => {
  it('seeds default Super-Admin taha / FullTekAdmin@2026 with scrypt hash', () => {
    withTempDir((dir) => {
      const prevUser = process.env.SUPERADMIN_USER;
      const prevPass = process.env.SUPERADMIN_PASSWORD;
      delete process.env.SUPERADMIN_USER;
      delete process.env.SUPERADMIN_PASSWORD;
      let db;
      try {
        db = createDb(path.join(dir, 'sa.db'));
        const row = db.prepare("SELECT * FROM super_admins WHERE username = 'taha'").get();
        assert.ok(row);
        assert.equal(row.role, 'SUPER_ADMIN');
        assert.equal(row.active, 1);
        assert.equal(row.email, 'taha@fulltek.mr');
        assert.equal(verifyPassword('FullTekAdmin@2026', row.password_hash), true);
        assert.equal(verifyPassword('WrongPass', row.password_hash), false);
      } finally {
        if (db) db.close();
        if (prevUser !== undefined) process.env.SUPERADMIN_USER = prevUser;
        if (prevPass !== undefined) process.env.SUPERADMIN_PASSWORD = prevPass;
      }
    });
  });

  it('respects SUPERADMIN_USER and SUPERADMIN_PASSWORD env overrides', () => {
    withTempDir((dir) => {
      const prevUser = process.env.SUPERADMIN_USER;
      const prevPass = process.env.SUPERADMIN_PASSWORD;
      process.env.SUPERADMIN_USER = 'admin_override';
      process.env.SUPERADMIN_PASSWORD = 'Secr3tOverride!';
      let db;
      try {
        db = createDb(path.join(dir, 'env_sa.db'));
        const row = db.prepare("SELECT * FROM super_admins WHERE username = 'admin_override'").get();
        assert.ok(row);
        assert.equal(row.role, 'SUPER_ADMIN');
        assert.equal(verifyPassword('Secr3tOverride!', row.password_hash), true);
        assert.equal(verifyPassword('FullTekAdmin@2026', row.password_hash), false);
      } finally {
        if (db) db.close();
        if (prevUser === undefined) delete process.env.SUPERADMIN_USER;
        else process.env.SUPERADMIN_USER = prevUser;
        if (prevPass === undefined) delete process.env.SUPERADMIN_PASSWORD;
        else process.env.SUPERADMIN_PASSWORD = prevPass;
      }
    });
  });

  it('seeds exact 9 CDC RBAC roles and 11 sensitive permissions with role_permissions matrix', () => {
    withTempDir((dir) => {
      const db = createDb(path.join(dir, 'rbac.db'));
      try {
        const roleCodes = db.prepare('SELECT code FROM roles WHERE is_system = 1 ORDER BY id').all().map((r) => r.code);
        assert.deepEqual(roleCodes.sort(), [
          'ACCOUNTANT',
          'CASHIER',
          'CHEF',
          'MANAGER',
          'OWNER',
          'PHARMACIST',
          'STOCK',
          'SUPER_ADMIN',
          'WAITER',
        ]);

        const permCodes = db.prepare('SELECT code FROM permissions').all().map((p) => p.code);
        for (const p of [
          'sale.collect',
          'sale.price_or_discount_override',
          'sale.void_or_refund_paid',
          'finance.view_margin_cost',
          'stock.receive_lots_expiry',
          'stock.adjust_waste_inventory',
          'cash.close_z_validate',
          'users.manage_roles',
          'reports.export',
          'pharma.dispense_controlled',
          'platform.admin_manage',
        ]) {
          assert.ok(permCodes.includes(p), `Missing permission ${p}`);
        }

        const getMode = (roleCode, permCode) =>
          db
            .prepare(`
              SELECT rp.access_mode
              FROM role_permissions rp
              JOIN roles r ON r.id = rp.role_id
              JOIN permissions p ON p.id = rp.permission_id
              WHERE r.code = ? AND p.code = ?
            `)
            .get(roleCode, permCode).access_mode;

        for (const cdcPerm of [
          'sale.collect',
          'sale.price_or_discount_override',
          'sale.void_or_refund_paid',
          'finance.view_margin_cost',
          'stock.receive_lots_expiry',
          'stock.adjust_waste_inventory',
          'cash.close_z_validate',
          'users.manage_roles',
          'reports.export',
        ]) {
          assert.equal(getMode('OWNER', cdcPerm), 'ALLOW');
        }
        assert.equal(getMode('CASHIER', 'sale.collect'), 'ALLOW');
        assert.equal(getMode('CASHIER', 'sale.price_or_discount_override'), 'REQUIRE_MANAGER_PIN');
        assert.equal(getMode('CASHIER', 'sale.void_or_refund_paid'), 'REQUIRE_MANAGER_PIN');
        assert.equal(getMode('CASHIER', 'cash.close_z_validate'), 'BLIND_INPUT');
        assert.equal(getMode('CASHIER', 'finance.view_margin_cost'), 'DENY');
        assert.equal(getMode('ACCOUNTANT', 'sale.collect'), 'DENY');
        assert.equal(getMode('ACCOUNTANT', 'reports.export'), 'ALLOW');
        assert.equal(getMode('PHARMACIST', 'pharma.dispense_controlled'), 'ALLOW');
        assert.equal(getMode('SUPER_ADMIN', 'platform.admin_manage'), 'ALLOW');
      } finally {
        db.close();
      }
    });
  });

  it('seeds baseline demo rows across existing and R3 tables', () => {
    withTempDir((dir) => {
      const db = createDb(path.join(dir, 'demo.db'));
      try {
        assert.equal(db.prepare('SELECT COUNT(*) AS cnt FROM tenants').get().cnt, 7);
        assert.equal(db.prepare('SELECT COUNT(*) AS cnt FROM saas_payments').get().cnt, 3);
        assert.equal(db.prepare('SELECT COUNT(*) AS cnt FROM audit_logs').get().cnt, 3);
        assert.ok(db.prepare('SELECT COUNT(*) AS cnt FROM products').get().cnt >= 1);
        assert.ok(db.prepare('SELECT COUNT(*) AS cnt FROM stock_batches').get().cnt >= 1);
        assert.ok(db.prepare('SELECT COUNT(*) AS cnt FROM branches').get().cnt >= 7);
        assert.ok(db.prepare('SELECT COUNT(*) AS cnt FROM pos_registers').get().cnt >= 3);
        assert.ok(db.prepare('SELECT COUNT(*) AS cnt FROM ingredients').get().cnt >= 2);
        assert.ok(db.prepare('SELECT COUNT(*) AS cnt FROM recipes_bom').get().cnt >= 2);
        assert.ok(db.prepare('SELECT COUNT(*) AS cnt FROM dining_zones').get().cnt >= 2);
        assert.ok(db.prepare('SELECT COUNT(*) AS cnt FROM reservations_vip').get().cnt >= 1);
        assert.ok(db.prepare('SELECT COUNT(*) AS cnt FROM customer_credits_karni').get().cnt >= 2);
        assert.ok(db.prepare('SELECT COUNT(*) AS cnt FROM karni_transactions').get().cnt >= 1);
        assert.ok(db.prepare('SELECT COUNT(*) AS cnt FROM returns_remakes_comps').get().cnt >= 1);
      } finally {
        db.close();
      }
    });
  });
});

describe('4. Ed25519 offline license engine (src/license.js)', () => {
  it('persists a single active Ed25519 keypair in signing_keys and exposes getPublicKey', () => {
    withTempDir((dir) => {
      const db = createDb(path.join(dir, 'keys.db'));
      try {
        const k1 = getOrCreateSigningKey(db);
        const k2 = getOrCreateSigningKey(db);
        assert.equal(k1.keyId, k2.keyId);
        assert.equal(k1.publicKey, k2.publicKey);
        assert.equal(k1.privateKey, k2.privateKey);
        assert.equal(k1.algorithm, 'Ed25519');
        assert.equal(db.prepare('SELECT COUNT(*) AS cnt FROM signing_keys').get().cnt, 1);

        const pub = getPublicKey(db);
        assert.equal(pub.keyId, k1.keyId);
        assert.equal(pub.algorithm, 'Ed25519');
        assert.ok(pub.publicKey.includes('-----BEGIN PUBLIC KEY-----'));
        assert.equal(pub.privateKey, undefined);
      } finally {
        db.close();
      }
    });
  });

  it('issueOfflineLicense produces 12-digit code, canonical payload, Ed25519 signature, and dual persistence', () => {
    withTempDir((dir) => {
      const db = createDb(path.join(dir, 'issue.db'));
      try {
        const tenant = db.prepare("SELECT * FROM tenants WHERE tenant_code = 'FT-1041'").get();
        const issued = issueOfflineLicense(db, tenant.id, {
          days: 30,
          graceDays: 7,
          registerCode: 'C1',
          hardwareFingerprint: 'HW-FP-001',
        });

        assert.equal(issued.ok, true);
        assert.match(issued.code, /^\d{4}-\d{4}-\d{4}$/);
        assert.equal(issued.days, 30);
        assert.equal(issued.graceDays, 7);
        assert.equal(issued.storeName, tenant.name);
        assert.ok(issued.keyId.startsWith('ed25519-'));

        const parts = issued.leaseToken.split('.');
        assert.equal(parts.length, 2);
        assert.ok(parts[0].length > 20);
        assert.equal(parts[1], issued.signature);

        assert.equal(issued.payload.version, 1);
        assert.equal(issued.payload.keyId, issued.keyId);
        assert.equal(issued.payload.tenantId, tenant.id);
        assert.equal(issued.payload.tenantCode, tenant.tenant_code);
        assert.equal(issued.payload.storeName, tenant.name);
        assert.equal(issued.payload.plan, tenant.plan);
        assert.equal(issued.payload.tillsQuota, tenant.tills);
        assert.equal(issued.payload.registerCode, 'C1');
        assert.equal(issued.payload.hardwareFingerprint, 'HW-FP-001');
        assert.equal(issued.payload.code, issued.code);
        assert.equal(issued.payload.days, 30);
        assert.equal(issued.payload.graceDays, 7);
        assert.ok(issued.payload.issuedAt);
        assert.ok(issued.payload.expiresAt);
        assert.ok(issued.payload.nonce);

        const codeRow = db.prepare('SELECT * FROM offline_codes WHERE code = ?').get(issued.code);
        assert.ok(codeRow);
        assert.equal(codeRow.days, 30);
        assert.equal(codeRow.lease_token, issued.leaseToken);
        assert.equal(codeRow.signature, issued.signature);
        assert.equal(codeRow.key_id, issued.keyId);

        const leaseRow = db.prepare('SELECT * FROM offline_lease_tokens WHERE unlock_code = ?').get(issued.code);
        assert.ok(leaseRow);
        assert.equal(leaseRow.unlock_code_id, codeRow.id);
        assert.equal(leaseRow.payload_b64, parts[0]);
        assert.equal(leaseRow.signature, issued.signature);
        assert.equal(leaseRow.lease_token, issued.leaseToken);
        assert.equal(leaseRow.nonce, issued.payload.nonce);

        // Validation errors on invalid inputs
        assert.throws(() => issueOfflineLicense(db, 999999), (e) => e.statusCode === 404);
        assert.throws(() => issueOfflineLicense(db, tenant.id, { days: 0 }), (e) => e.statusCode === 400);
        assert.throws(() => issueOfflineLicense(db, tenant.id, { graceDays: -1 }), (e) => e.statusCode === 400);
      } finally {
        db.close();
      }
    });
  });

  it('verifyOfflineLicense and raw node:crypto.verify pass on valid leaseToken', () => {
    withTempDir((dir) => {
      const db = createDb(path.join(dir, 'verify_ok.db'));
      try {
        const tenant = db.prepare('SELECT id FROM tenants ORDER BY id ASC LIMIT 1').get();
        const issued = issueOfflineLicense(db, tenant.id, {
          days: 30,
          graceDays: 7,
          registerCode: 'C1',
          hardwareFingerprint: 'HW-FP-001',
        });

        const res = verifyOfflineLicense(issued.leaseToken, issued.publicKey, {
          hardwareFingerprint: 'HW-FP-001',
          registerCode: 'C1',
        });
        assert.equal(res.valid, true);
        assert.equal(res.payload.code, issued.code);

        const [payloadB64, signature] = issued.leaseToken.split('.');
        const rawOk = crypto.verify(
          null,
          Buffer.from(payloadB64, 'utf8'),
          issued.publicKey,
          Buffer.from(signature, 'base64url'),
        );
        assert.equal(rawOk, true);
      } finally {
        db.close();
      }
    });
  });

  it('rejects tampered payload, tampered signature, and wrong public key', () => {
    withTempDir((dir) => {
      const db = createDb(path.join(dir, 'tamper.db'));
      try {
        const tenant = db.prepare('SELECT id FROM tenants ORDER BY id ASC LIMIT 1').get();
        const issued = issueOfflineLicense(db, tenant.id, { days: 30 });
        const [payloadB64, signature] = issued.leaseToken.split('.');

        // Tampered payload
        const mutated = JSON.parse(Buffer.from(payloadB64, 'base64url').toString('utf8'));
        mutated.days = 3650;
        const tamperedPayloadB64 = Buffer.from(JSON.stringify(mutated), 'utf8').toString('base64url');
        const tamperedPayloadToken = `${tamperedPayloadB64}.${signature}`;
        assert.equal(verifyOfflineLicense(tamperedPayloadToken, issued.publicKey).valid, false);
        assert.equal(verifyOfflineLicense(tamperedPayloadToken, issued.publicKey).reason, 'invalid_signature');
        assert.equal(
          crypto.verify(null, Buffer.from(tamperedPayloadB64, 'utf8'), issued.publicKey, Buffer.from(signature, 'base64url')),
          false,
        );

        // Tampered signature (flip byte safely in raw 64-byte buffer)
        const sigBytes = Buffer.from(signature, 'base64url');
        sigBytes[0] ^= 0xff;
        const tamperedSig = sigBytes.toString('base64url');
        const tamperedSigToken = `${payloadB64}.${tamperedSig}`;
        assert.equal(verifyOfflineLicense(tamperedSigToken, issued.publicKey).valid, false);
        assert.equal(verifyOfflineLicense(tamperedSigToken, issued.publicKey).reason, 'invalid_signature');
        assert.equal(
          crypto.verify(null, Buffer.from(payloadB64, 'utf8'), issued.publicKey, sigBytes),
          false,
        );

        // Wrong public key
        const { publicKey: wrongPubPem } = crypto.generateKeyPairSync('ed25519', {
          publicKeyEncoding: { type: 'spki', format: 'pem' },
          privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
        });
        assert.equal(verifyOfflineLicense(issued.leaseToken, wrongPubPem).valid, false);
        assert.equal(verifyOfflineLicense(issued.leaseToken, wrongPubPem).reason, 'invalid_signature');
        assert.equal(
          crypto.verify(null, Buffer.from(payloadB64, 'utf8'), wrongPubPem, Buffer.from(signature, 'base64url')),
          false,
        );
      } finally {
        db.close();
      }
    });
  });

  it('enforces expiry, grace window, anti-clock-rollback, hardwareFingerprint, and key rotation', () => {
    withTempDir((dir) => {
      const db = createDb(path.join(dir, 'policy.db'));
      try {
        const tenant = db.prepare('SELECT id FROM tenants ORDER BY id ASC LIMIT 1').get();
        const baseNow = new Date('2026-11-01T10:00:00.000Z');
        const issued = issueOfflineLicense(db, tenant.id, {
          days: 10,
          graceDays: 5,
          registerCode: 'C1',
          hardwareFingerprint: 'HW-NODE-A',
          now: baseNow,
        });

        // Within active period (+5d)
        assert.equal(
          verifyOfflineLicense(issued.leaseToken, issued.publicKey, {
            now: new Date(baseNow.getTime() + 5 * 86_400_000),
            hardwareFingerprint: 'HW-NODE-A',
            registerCode: 'C1',
          }).valid,
          true,
        );

        // Expired without allowGrace (+11d)
        const expNoGrace = verifyOfflineLicense(issued.leaseToken, issued.publicKey, {
          now: new Date(baseNow.getTime() + 11 * 86_400_000),
        });
        assert.equal(expNoGrace.valid, false);
        assert.equal(expNoGrace.reason, 'expired');

        // Within grace with allowGrace: true (+12d <= 10d + 5d)
        const inGrace = verifyOfflineLicense(issued.leaseToken, issued.publicKey, {
          now: new Date(baseNow.getTime() + 12 * 86_400_000),
          allowGrace: true,
        });
        assert.equal(inGrace.valid, true);
        assert.equal(inGrace.inGrace, true);

        // Past grace even with allowGrace (+16d > 15d)
        const pastGrace = verifyOfflineLicense(issued.leaseToken, issued.publicKey, {
          now: new Date(baseNow.getTime() + 16 * 86_400_000),
          allowGrace: true,
        });
        assert.equal(pastGrace.valid, false);
        assert.equal(pastGrace.reason, 'expired');

        // Anti-clock-rollback
        const rollback = verifyOfflineLicense(issued.leaseToken, issued.publicKey, {
          lastVerifiedAt: new Date(baseNow.getTime() + 4 * 86_400_000),
          now: new Date(baseNow.getTime() + 2 * 86_400_000),
        });
        assert.equal(rollback.valid, false);
        assert.equal(rollback.reason, 'clock_rollback_detected');

        // Hardware & register mismatch
        const hwMismatch = verifyOfflineLicense(issued.leaseToken, issued.publicKey, {
          now: new Date(baseNow.getTime() + 1 * 86_400_000),
          hardwareFingerprint: 'HW-NODE-B',
        });
        assert.equal(hwMismatch.valid, false);
        assert.equal(hwMismatch.reason, 'hardware_mismatch');

        const regMismatch = verifyOfflineLicense(issued.leaseToken, issued.publicKey, {
          now: new Date(baseNow.getTime() + 1 * 86_400_000),
          registerCode: 'C9',
        });
        assert.equal(regMismatch.valid, false);
        assert.equal(regMismatch.reason, 'register_mismatch');

        // Key rotation preserves verification of previously issued token via historical keyId
        const rotated = rotateSigningKey(db);
        assert.notEqual(rotated.keyId, issued.keyId);
        const oldPub = getPublicKey(db, issued.keyId);
        assert.equal(oldPub.publicKey, issued.publicKey);
        assert.equal(
          verifyOfflineLicense(issued.leaseToken, oldPub.publicKey, {
            now: new Date(baseNow.getTime() + 1 * 86_400_000),
          }).valid,
          true,
        );

        // Unlock code generator produces valid unique codes
        const c = generateUnlockCode(db);
        assert.match(c, /^\d{4}-\d{4}-\d{4}$/);
      } finally {
        db.close();
      }
    });
  });
});

describe('5. Branch isolation, strict integer parsing, hardware binding, key-type & DB hardening', () => {
  it('validates options.branchId existence and tenant ownership in issueOfflineLicense', () => {
    withTempDir((dir) => {
      const db = createDb(path.join(dir, 'branch_check.db'));
      try {
        const tenants = db.prepare('SELECT id FROM tenants ORDER BY id ASC LIMIT 2').all();
        const t1Id = tenants[0].id;
        const t2Id = tenants[1].id;

        const secBranchInfo = db.prepare(
          "INSERT INTO branches (tenant_id, code, name, is_main) VALUES (?, 'BR-02', 'Succursale 2', 0)"
        ).run(t1Id);
        const t1SecBranchId = Number(secBranchInfo.lastInsertRowid);
        const t2BranchId = db.prepare('SELECT id FROM branches WHERE tenant_id = ? LIMIT 1').get(t2Id).id;

        // Valid branch belonging to tenant
        const okIssued = issueOfflineLicense(db, t1Id, { branchId: t1SecBranchId });
        const codeRow = db.prepare('SELECT branch_id FROM offline_codes WHERE code = ?').get(okIssued.code);
        const leaseRow = db.prepare('SELECT branch_id FROM offline_lease_tokens WHERE unlock_code = ?').get(okIssued.code);
        assert.equal(codeRow.branch_id, t1SecBranchId);
        assert.equal(leaseRow.branch_id, t1SecBranchId);

        // Non-existent branch -> 404 (not raw SQLite FK error)
        assert.throws(
          () => issueOfflineLicense(db, t1Id, { branchId: 999999 }),
          (err) => err.statusCode === 404 && /Branch not found/i.test(err.message),
        );

        // Cross-tenant branch -> 400
        assert.throws(
          () => issueOfflineLicense(db, t1Id, { branchId: t2BranchId }),
          (err) => err.statusCode === 400 && /does not belong to tenant/i.test(err.message),
        );

        // Invalid branchId values -> 400
        for (const badBranch of [0, -1, 1.5, 'abc', '', '   ', true, false, [1], {}]) {
          assert.throws(
            () => issueOfflineLicense(db, t1Id, { branchId: badBranch }),
            (err) => err.statusCode === 400,
            `Expected 400 for branchId=${JSON.stringify(badBranch)}`,
          );
        }
      } finally {
        db.close();
      }
    });
  });

  it('rejects permissive JS coercion on tenantId, days, and graceDays in issueOfflineLicense', () => {
    withTempDir((dir) => {
      const db = createDb(path.join(dir, 'strict_int.db'));
      try {
        const t1Id = db.prepare('SELECT id FROM tenants ORDER BY id ASC LIMIT 1').get().id;

        for (const badTenant of [true, false, [1], {}, '', '   ', null, undefined, 1.5, '1.5', NaN, Infinity, 0, -1]) {
          assert.throws(
            () => issueOfflineLicense(db, badTenant),
            (err) => err.statusCode === 400,
            `Expected 400 for tenantId=${JSON.stringify(badTenant)}`,
          );
        }

        for (const badDays of [true, false, [1], {}, '', '   ', null, 1.5, '1.5', NaN, Infinity, 0, -1, 3651]) {
          assert.throws(
            () => issueOfflineLicense(db, t1Id, { days: badDays }),
            (err) => err.statusCode === 400,
            `Expected 400 for days=${JSON.stringify(badDays)}`,
          );
        }

        for (const badGrace of [true, false, [0], {}, '', '   ', null, 1.5, '1.5', NaN, Infinity, -1, 366]) {
          assert.throws(
            () => issueOfflineLicense(db, t1Id, { graceDays: badGrace }),
            (err) => err.statusCode === 400,
            `Expected 400 for graceDays=${JSON.stringify(badGrace)}`,
          );
        }

        // Trimmed base-10 integer strings & boundary 0 graceDays still succeed
        const valid = issueOfflineLicense(db, ` ${t1Id} `, { days: '15', graceDays: '0' });
        assert.equal(valid.days, 15);
        assert.equal(valid.graceDays, 0);
      } finally {
        db.close();
      }
    });
  });

  it('enforces requireHardwareMatch even when options.hardwareFingerprint is omitted or empty', () => {
    withTempDir((dir) => {
      const db = createDb(path.join(dir, 'hw_match.db'));
      try {
        const t1Id = db.prepare('SELECT id FROM tenants ORDER BY id ASC LIMIT 1').get().id;
        const unbound = issueOfflineLicense(db, t1Id, { days: 30 });
        const bound = issueOfflineLicense(db, t1Id, { days: 30, hardwareFingerprint: 'HW-STRICT-01' });

        // Unbound token must fail when requireHardwareMatch: true regardless of whether hardwareFingerprint is provided
        for (const opts of [
          { requireHardwareMatch: true },
          { requireHardwareMatch: true, hardwareFingerprint: '' },
          { requireHardwareMatch: true, hardwareFingerprint: 'HW-STRICT-01' },
        ]) {
          const res = verifyOfflineLicense(unbound.leaseToken, unbound.publicKey, opts);
          assert.equal(res.valid, false);
          assert.equal(res.reason, 'hardware_unbound');
        }

        // Bound token must fail when requireHardwareMatch: true and fingerprint is omitted/empty/wrong
        for (const opts of [
          { requireHardwareMatch: true },
          { requireHardwareMatch: true, hardwareFingerprint: '' },
          { requireHardwareMatch: true, hardwareFingerprint: '   ' },
          { requireHardwareMatch: true, hardwareFingerprint: null },
          { requireHardwareMatch: true, hardwareFingerprint: 'HW-OTHER' },
        ]) {
          const res = verifyOfflineLicense(bound.leaseToken, bound.publicKey, opts);
          assert.equal(res.valid, false);
          assert.equal(res.reason, 'hardware_mismatch');
        }

        // Bound token succeeds when matching fingerprint provided
        const okRes = verifyOfflineLicense(bound.leaseToken, bound.publicKey, {
          requireHardwareMatch: true,
          hardwareFingerprint: 'HW-STRICT-01',
        });
        assert.equal(okRes.valid, true);
      } finally {
        db.close();
      }
    });
  });

  it('rejects non-Ed25519 (RSA / private) public keys with reason invalid_public_key', () => {
    withTempDir((dir) => {
      const db = createDb(path.join(dir, 'key_type.db'));
      try {
        const t1Id = db.prepare('SELECT id FROM tenants ORDER BY id ASC LIMIT 1').get().id;
        const issued = issueOfflineLicense(db, t1Id, { days: 30 });

        const { publicKey: rsaPubPem } = crypto.generateKeyPairSync('rsa', {
          modulusLength: 2048,
          publicKeyEncoding: { type: 'spki', format: 'pem' },
          privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
        });
        const rsaPubObj = crypto.createPublicKey(rsaPubPem);

        const resPem = verifyOfflineLicense(issued.leaseToken, rsaPubPem);
        assert.equal(resPem.valid, false);
        assert.equal(resPem.reason, 'invalid_public_key');

        const resObj = verifyOfflineLicense(issued.leaseToken, rsaPubObj);
        assert.equal(resObj.valid, false);
        assert.equal(resObj.reason, 'invalid_public_key');

        const activeKey = getOrCreateSigningKey(db);
        const privKeyObj = crypto.createPrivateKey(activeKey.privateKey);
        const resPriv = verifyOfflineLicense(issued.leaseToken, privKeyObj);
        assert.equal(resPriv.valid, false);
        assert.equal(resPriv.reason, 'invalid_public_key');
      } finally {
        db.close();
      }
    });
  });

  it('hardens verifyPassword against non-string/empty inputs and backfills lowercase legacy user roles', () => {
    // verifyPassword non-string / empty guard
    const undefHash = hashPassword('undefined');
    const nullHash = hashPassword('null');
    const emptyHash = hashPassword('');
    assert.equal(verifyPassword(undefined, undefHash), false);
    assert.equal(verifyPassword(null, nullHash), false);
    assert.equal(verifyPassword('', emptyHash), false);
    assert.equal(verifyPassword(123, hashPassword('123')), false);
    assert.equal(verifyPassword('ActualPass1!', hashPassword('ActualPass1!')), true);

    // Case-insensitive & trimmed legacy role backfill in seedCoreSecurityAndRbac
    withTempDir((dir) => {
      const dbPath = path.join(dir, 'legacy_role_case.db');
      const db1 = createDb(dbPath);
      const t1Id = db1.prepare('SELECT id FROM tenants ORDER BY id ASC LIMIT 1').get().id;
      const pwHash = hashPassword('CashierPass1!');
      db1.prepare(`
        INSERT INTO users (tenant_id, role_id, full_name, username, pass_hash, pin_code, role)
        VALUES (?, NULL, 'Caissier Legacy', 'cashier_leg', ?, '1111', '  cashier  ')
      `).run(t1Id, pwHash);
      db1.close();

      const db2 = createDb(dbPath);
      try {
        const cashierRole = db2.prepare("SELECT id FROM roles WHERE code = 'CASHIER'").get();
        const user = db2.prepare("SELECT role_id FROM users WHERE username = 'cashier_leg'").get();
        assert.ok(cashierRole);
        assert.equal(user.role_id, cashierRole.id);
      } finally {
        db2.close();
      }
    });
  });
});
