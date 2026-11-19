const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { DatabaseSync } = require('node:sqlite');

const DATA_DIR = path.join(__dirname, '..', 'data');
const DEFAULT_DB_PATH = path.join(DATA_DIR, 'fulltek.db');
const DB_PATH = process.env.DB_PATH || process.env.FULLTEK_DB_PATH || DEFAULT_DB_PATH;

const DEFAULT_DELIVERY_ZONES = [
  { id: 'zone-centre', nameFr: 'Centre / Ilot K', nameAr: 'المركز / إيلو ك', nameEn: 'Center / Ilot K', feeMru: 50 },
  { id: 'zone-tz', nameFr: 'Tevragh Zeina', nameAr: 'تفرغ زينة', nameEn: 'Tevragh Zeina', feeMru: 100 },
  { id: 'zone-ksar', nameFr: 'Ksar / Socogim', nameAr: 'لكصر / سوكوجيم', nameEn: 'Ksar / Socogim', feeMru: 150 },
  { id: 'zone-arafat', nameFr: 'Arafat / Dar Naim', nameAr: 'عرفات / دار النعيم', nameEn: 'Arafat / Dar Naim', feeMru: 150 },
];

const ROLES_SEED = [
  {
    code: 'SUPER_ADMIN',
    name_fr: 'Super-Admin SaaS',
    name_ar: 'مدير المنصة الأعلى',
    scope: 'PLATFORM',
    description: 'Toute la plateforme SaaS (tenants, licences, plans) sans accès direct aux ventes détaillées sans support tracé',
  },
  {
    code: 'OWNER',
    name_fr: 'Propriétaire',
    name_ar: 'المالك',
    scope: 'ALL_SITES',
    description: 'Accès complet à tous ses établissements, paramètres, finances et RBAC',
  },
  {
    code: 'MANAGER',
    name_fr: 'Gérant de Site',
    name_ar: 'مدير الفرع',
    scope: 'SINGLE_SITE',
    description: 'Gestion complète d’un site (prix, stock, remises, annulations, clôture Z)',
  },
  {
    code: 'CASHIER',
    name_fr: 'Caissier',
    name_ar: 'أمين الصندوق',
    scope: 'REGISTER',
    description: 'Vente et encaissement sur sa caisse ; remise/annulation sous PIN gérant',
  },
  {
    code: 'WAITER',
    name_fr: 'Serveur',
    name_ar: 'نادل',
    scope: 'TABLES',
    description: 'Prise de commande, envoi cuisine et addition sur ses tables',
  },
  {
    code: 'CHEF',
    name_fr: 'Cuisinier / Barman',
    name_ar: 'طباخ / بارمان',
    scope: 'KDS',
    description: 'Écran cuisine KDS uniquement (préparation des bons, sans prix)',
  },
  {
    code: 'STOCK',
    name_fr: 'Magasinier / Stock',
    name_ar: 'أمين المخزن',
    scope: 'INVENTORY',
    description: 'Réceptions, lots FEFO, péremptions, inventaire et prix d’achat',
  },
  {
    code: 'PHARMACIST',
    name_fr: 'Pharmacien Responsable',
    name_ar: 'الصيدلي المسؤول',
    scope: 'PHARMA',
    description: 'Dispensation médicaments contrôlés, registre ordonnances, substitutions et retraits de lots',
  },
  {
    code: 'ACCOUNTANT',
    name_fr: 'Comptable (lecture seule)',
    name_ar: 'محاسب',
    scope: 'READ_ONLY',
    description: 'Consultation des journaux, marges, clôtures Z et exports comptables',
  },
];

const PERMISSIONS_SEED = [
  {
    code: 'sale.collect',
    category: 'sales',
    name_fr: 'Encaisser une vente',
    name_ar: 'تحصيل مبيعات',
    description: 'Encaisser une commande en caisse (espèces, mobile money, crédit Karni)',
    is_sensitive: 1,
    requires_manager_pin: 0,
  },
  {
    code: 'sale.price_or_discount_override',
    category: 'sales',
    name_fr: 'Modifier un prix / remise > seuil',
    name_ar: 'تعديل السعر أو خصم يتجاوز الحد',
    description: 'Appliquer une remise exceptionnelle ou modifier un prix unitaire',
    is_sensitive: 1,
    requires_manager_pin: 1,
  },
  {
    code: 'sale.void_or_refund_paid',
    category: 'sales',
    name_fr: 'Annuler / rembourser un ticket payé',
    name_ar: 'إلغاء أو استرجاع فاتورة مدفوعة',
    description: 'Annulation ou remboursement d’une vente déjà encaissée',
    is_sensitive: 1,
    requires_manager_pin: 1,
  },
  {
    code: 'finance.view_margin_cost',
    category: 'finance',
    name_fr: 'Voir marges & prix d’achat',
    name_ar: 'عرض الهوامش وتكلفة الشراء',
    description: 'Accès aux coûts d’achat PMP et aux marges brutes',
    is_sensitive: 1,
    requires_manager_pin: 0,
  },
  {
    code: 'stock.receive_lots_expiry',
    category: 'stock',
    name_fr: 'Réception, lots & dates de péremption',
    name_ar: 'استلام البضاعة والدفعات وتواريخ الصلاحية',
    description: 'Enregistrer les réceptions fournisseurs, lots FEFO et péremptions',
    is_sensitive: 1,
    requires_manager_pin: 0,
  },
  {
    code: 'stock.adjust_waste_inventory',
    category: 'stock',
    name_fr: 'Ajustement / casse / inventaire',
    name_ar: 'تسوية المخزون والتالف والجرد',
    description: 'Ajuster les quantités en stock, déclarer casse/perte ou valider inventaire',
    is_sensitive: 1,
    requires_manager_pin: 0,
  },
  {
    code: 'cash.close_z_validate',
    category: 'finance',
    name_fr: 'Clôture Z & validation des écarts',
    name_ar: 'إغلاق الصندوق اليومي واعتماد الفروقات',
    description: 'Saisie de caisse Z et validation des écarts de trésorerie',
    is_sensitive: 1,
    requires_manager_pin: 0,
  },
  {
    code: 'users.manage_roles',
    category: 'security',
    name_fr: 'Créer utilisateurs & modifier droits',
    name_ar: 'إنشاء المستخدمين وتعديل الصلاحيات',
    description: 'Gestion des comptes personnel, codes PIN et permissions granulaires',
    is_sensitive: 1,
    requires_manager_pin: 0,
  },
  {
    code: 'reports.export',
    category: 'finance',
    name_fr: 'Exporter rapports / données',
    name_ar: 'تصدير التقارير والبيانات',
    description: 'Export CSV/Excel/PDF des ventes, TVA et journaux comptables',
    is_sensitive: 1,
    requires_manager_pin: 0,
  },
  {
    code: 'pharma.dispense_controlled',
    category: 'pharmacy',
    name_fr: 'Dispensation médicaments contrôlés',
    name_ar: 'صرف الأدوية الخاضعة للرقابة',
    description: 'Délivrance sous ordonnance, registre stupéfiants et rappels de lots',
    is_sensitive: 1,
    requires_manager_pin: 0,
  },
  {
    code: 'platform.admin_manage',
    category: 'platform',
    name_fr: 'Administration plateforme SaaS',
    name_ar: 'إدارة منصة SaaS',
    description: 'Provisioning tenants, approbation paiements et licences Ed25519',
    is_sensitive: 1,
    requires_manager_pin: 0,
  },
];

// Full CDC §7-A.2 access matrix: ALLOW | DENY | REQUIRE_MANAGER_PIN | BLIND_INPUT | READ_ONLY | LIMITED | ADDITION_ONLY | COST_ONLY
const ROLE_PERMISSION_MATRIX = {
  SUPER_ADMIN: {
    'platform.admin_manage': 'ALLOW',
    'users.manage_roles': 'ALLOW',
  },
  OWNER: {
    'sale.collect': 'ALLOW',
    'sale.price_or_discount_override': 'ALLOW',
    'sale.void_or_refund_paid': 'ALLOW',
    'finance.view_margin_cost': 'ALLOW',
    'stock.receive_lots_expiry': 'ALLOW',
    'stock.adjust_waste_inventory': 'ALLOW',
    'cash.close_z_validate': 'ALLOW',
    'users.manage_roles': 'ALLOW',
    'reports.export': 'ALLOW',
    'pharma.dispense_controlled': 'ALLOW',
  },
  MANAGER: {
    'sale.collect': 'ALLOW',
    'sale.price_or_discount_override': 'ALLOW',
    'sale.void_or_refund_paid': 'ALLOW',
    'finance.view_margin_cost': 'ALLOW',
    'stock.receive_lots_expiry': 'ALLOW',
    'stock.adjust_waste_inventory': 'ALLOW',
    'cash.close_z_validate': 'ALLOW',
    'users.manage_roles': 'LIMITED',
    'reports.export': 'ALLOW',
    'pharma.dispense_controlled': 'READ_ONLY',
  },
  CASHIER: {
    'sale.collect': 'ALLOW',
    'sale.price_or_discount_override': 'REQUIRE_MANAGER_PIN',
    'sale.void_or_refund_paid': 'REQUIRE_MANAGER_PIN',
    'cash.close_z_validate': 'BLIND_INPUT',
  },
  WAITER: {
    'sale.collect': 'ADDITION_ONLY',
  },
  CHEF: {},
  STOCK: {
    'finance.view_margin_cost': 'COST_ONLY',
    'stock.receive_lots_expiry': 'ALLOW',
    'stock.adjust_waste_inventory': 'ALLOW',
  },
  PHARMACIST: {
    'sale.collect': 'ALLOW',
    'stock.receive_lots_expiry': 'ALLOW',
    'stock.adjust_waste_inventory': 'ALLOW',
    'pharma.dispense_controlled': 'ALLOW',
  },
  ACCOUNTANT: {
    'finance.view_margin_cost': 'ALLOW',
    'stock.receive_lots_expiry': 'READ_ONLY',
    'stock.adjust_waste_inventory': 'READ_ONLY',
    'cash.close_z_validate': 'READ_ONLY',
    'reports.export': 'ALLOW',
  },
};

function hashPassword(plain) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(String(plain), salt, 64).toString('hex');
  return `${salt}:${hash}`;
}

function verifyPassword(plain, stored) {
  if (typeof plain !== 'string' || plain.length === 0) return false;
  const parts = String(stored || '').split(':');
  if (parts.length !== 2) return false;
  const [salt, keyHex] = parts;
  if (!salt || !keyHex) return false;
  const derived = crypto.scryptSync(String(plain), salt, 64);
  const expected = Buffer.from(keyHex, 'hex');
  if (derived.length !== expected.length) return false;
  return crypto.timingSafeEqual(derived, expected);
}

function ensureColumn(database, tableName, columnName, columnDef) {
  const cols = database.prepare(`PRAGMA table_info(${tableName})`).all();
  if (!cols.some((c) => c.name === columnName)) {
    database.exec(`ALTER TABLE ${tableName} ADD COLUMN ${columnName} ${columnDef};`);
  }
}

function initSchema(database) {
  database.exec(`
    -- 1. CORE SAAS, MULTI-SITE & HARDWARE REGISTERS
    CREATE TABLE IF NOT EXISTS tenants (
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
      enabled_themes TEXT DEFAULT '["01","04","06","07","11"]',
      features TEXT DEFAULT '[]',
      pay_methods TEXT DEFAULT '["Cash","Bankily","Masrivi","Sedad","Bimbank","Click","Karni"]',
      delivery_zones_json TEXT DEFAULT '[]',
      free_delivery_above_mru INTEGER DEFAULT 1500,
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

    CREATE TABLE IF NOT EXISTS branches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      code TEXT NOT NULL,
      name TEXT NOT NULL,
      city TEXT DEFAULT '',
      district TEXT DEFAULT '',
      address TEXT DEFAULT '',
      phone TEXT DEFAULT '',
      is_main INTEGER NOT NULL DEFAULT 0,
      is_central_kitchen INTEGER NOT NULL DEFAULT 0,
      active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(tenant_id, code)
    );

    CREATE TABLE IF NOT EXISTS pos_registers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
      register_code TEXT NOT NULL,
      name TEXT NOT NULL DEFAULT '',
      hardware_fingerprint TEXT DEFAULT '',
      ed25519_public_key TEXT DEFAULT '',
      is_master INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'active',
      last_seen_at TEXT DEFAULT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(tenant_id, register_code)
    );

    -- 2. SUPER-ADMIN & 9-ROLE RBAC + GRANULAR PERMISSIONS
    CREATE TABLE IF NOT EXISTS super_admins (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      email TEXT UNIQUE NOT NULL DEFAULT '',
      full_name TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'SUPER_ADMIN',
      active INTEGER NOT NULL DEFAULT 1,
      last_login_at TEXT DEFAULT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS roles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER REFERENCES tenants(id) ON DELETE CASCADE,
      code TEXT UNIQUE NOT NULL,
      name_fr TEXT NOT NULL,
      name_ar TEXT DEFAULT '',
      scope TEXT NOT NULL DEFAULT 'REGISTER',
      description TEXT DEFAULT '',
      is_system INTEGER NOT NULL DEFAULT 1,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS permissions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      code TEXT UNIQUE NOT NULL,
      category TEXT NOT NULL DEFAULT 'general',
      name_fr TEXT NOT NULL,
      name_ar TEXT DEFAULT '',
      description TEXT DEFAULT '',
      is_sensitive INTEGER NOT NULL DEFAULT 1,
      requires_manager_pin INTEGER NOT NULL DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS role_permissions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      role_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
      permission_id INTEGER NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
      access_mode TEXT NOT NULL DEFAULT 'ALLOW',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(role_id, permission_id)
    );

    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
      role_id INTEGER REFERENCES roles(id) ON DELETE SET NULL,
      full_name TEXT NOT NULL,
      username TEXT NOT NULL,
      pass_hash TEXT NOT NULL,
      pin_code TEXT NOT NULL,
      role TEXT NOT NULL,
      email TEXT DEFAULT '',
      phone TEXT DEFAULT '',
      active INTEGER DEFAULT 1,
      failed_pin_count INTEGER NOT NULL DEFAULT 0,
      locked_until TEXT DEFAULT '',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT '',
      UNIQUE(tenant_id, username)
    );

    CREATE TABLE IF NOT EXISTS user_permissions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      permission_id INTEGER NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
      granted INTEGER NOT NULL DEFAULT 1,
      access_mode TEXT NOT NULL DEFAULT 'ALLOW',
      granted_by TEXT DEFAULT '',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(user_id, permission_id)
    );

    -- 3. ED25519 OFFLINE LICENSING, SAAS PAYMENTS & AUDIT
    CREATE TABLE IF NOT EXISTS signing_keys (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      key_id TEXT UNIQUE NOT NULL,
      algorithm TEXT NOT NULL DEFAULT 'Ed25519',
      public_key_pem TEXT NOT NULL,
      private_key_pem TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      revoked_at TEXT DEFAULT NULL
    );

    CREATE TABLE IF NOT EXISTS offline_codes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
      register_id INTEGER REFERENCES pos_registers(id) ON DELETE SET NULL,
      code TEXT NOT NULL,
      days INTEGER NOT NULL,
      grace_days INTEGER DEFAULT 7,
      key_id TEXT DEFAULT '',
      register_code TEXT DEFAULT '',
      hardware_fingerprint TEXT DEFAULT '',
      payload_json TEXT DEFAULT '',
      lease_token TEXT DEFAULT '',
      signature TEXT DEFAULT '',
      expires_at TEXT DEFAULT NULL,
      redeemed_at TEXT DEFAULT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS offline_lease_tokens (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
      register_id INTEGER REFERENCES pos_registers(id) ON DELETE SET NULL,
      unlock_code_id INTEGER UNIQUE REFERENCES offline_codes(id) ON DELETE SET NULL,
      key_id TEXT NOT NULL REFERENCES signing_keys(key_id) ON DELETE RESTRICT,
      unlock_code TEXT UNIQUE NOT NULL,
      register_code TEXT DEFAULT '',
      hardware_fingerprint TEXT DEFAULT '',
      days INTEGER NOT NULL DEFAULT 30,
      grace_days INTEGER NOT NULL DEFAULT 7,
      nonce TEXT UNIQUE NOT NULL,
      payload_json TEXT NOT NULL,
      payload_b64 TEXT NOT NULL,
      signature TEXT NOT NULL,
      lease_token TEXT NOT NULL,
      issued_at TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      last_verified_at TEXT DEFAULT NULL,
      status TEXT NOT NULL DEFAULT 'ACTIVE',
      revoked INTEGER NOT NULL DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS saas_payments (
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

    CREATE TABLE IF NOT EXISTS audit_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER REFERENCES tenants(id) ON DELETE SET NULL,
      branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
      user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
      actor TEXT DEFAULT 'M. Taha Chouaib',
      action TEXT DEFAULT '',
      device_id TEXT DEFAULT '',
      title TEXT NOT NULL,
      subtitle TEXT NOT NULL,
      entity_type TEXT DEFAULT '',
      entity_id TEXT DEFAULT '',
      before_json TEXT DEFAULT '',
      after_json TEXT DEFAULT '',
      ip_address TEXT DEFAULT '',
      time_label TEXT NOT NULL,
      is_training INTEGER DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    -- 4. CATALOG, STOCK FEFO & FOOD COST BOM
    CREATE TABLE IF NOT EXISTS categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      name_fr TEXT NOT NULL,
      name_ar TEXT DEFAULT '',
      name_en TEXT DEFAULT '',
      icon TEXT DEFAULT '',
      sort_order INTEGER DEFAULT 0,
      active INTEGER DEFAULT 1,
      created_at TEXT DEFAULT ''
    );

    CREATE TABLE IF NOT EXISTS products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
      sku TEXT DEFAULT '',
      barcode TEXT DEFAULT '',
      name_fr TEXT NOT NULL,
      name_ar TEXT DEFAULT '',
      name_en TEXT DEFAULT '',
      icon TEXT DEFAULT '',
      unit TEXT DEFAULT 'unit',
      price_retail INTEGER NOT NULL,
      price_whole INTEGER DEFAULT 0,
      price_cost INTEGER DEFAULT 0,
      dci TEXT DEFAULT '',
      track_fefo INTEGER DEFAULT 0,
      requires_cnam INTEGER DEFAULT 0,
      kitchen_station TEXT DEFAULT 'KITCHEN',
      is_top INTEGER DEFAULT 0,
      is_out_of_stock INTEGER DEFAULT 0,
      modifiers_json TEXT DEFAULT '[]',
      active INTEGER DEFAULT 1,
      created_at TEXT DEFAULT '',
      updated_at TEXT DEFAULT ''
    );

    CREATE TABLE IF NOT EXISTS stock_batches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
      product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
      lot_number TEXT NOT NULL,
      qty INTEGER NOT NULL,
      purchase_price_mru INTEGER DEFAULT 0,
      supplier_name TEXT DEFAULT '',
      is_recalled INTEGER DEFAULT 0,
      cold_chain INTEGER DEFAULT 0,
      expires_at TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS ingredients (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
      sku TEXT DEFAULT '',
      name_fr TEXT NOT NULL,
      name_ar TEXT DEFAULT '',
      name_en TEXT DEFAULT '',
      unit TEXT NOT NULL DEFAULT 'kg',
      pmp_cost_mru REAL NOT NULL DEFAULT 0,
      current_stock REAL NOT NULL DEFAULT 0,
      min_stock REAL NOT NULL DEFAULT 0,
      is_sub_recipe INTEGER NOT NULL DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS recipes_bom (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
      ingredient_id INTEGER NOT NULL REFERENCES ingredients(id) ON DELETE RESTRICT,
      qty_per_unit REAL NOT NULL,
      unit TEXT NOT NULL DEFAULT 'g',
      condition_channel TEXT NOT NULL DEFAULT 'ALL',
      modifier_key TEXT NOT NULL DEFAULT '',
      is_sub_recipe INTEGER NOT NULL DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(product_id, ingredient_id, condition_channel, modifier_key)
    );

    -- 5. FLOOR PLAN, VIP RESERVATIONS, ORDERS, EXCEPTIONS, KARNI & CLOSINGS
    CREATE TABLE IF NOT EXISTS dining_zones (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
      name_fr TEXT NOT NULL,
      name_ar TEXT DEFAULT '',
      name_en TEXT DEFAULT '',
      zone_type TEXT NOT NULL DEFAULT 'SALLE',
      price_tier TEXT NOT NULL DEFAULT 'STANDARD',
      table_count INTEGER NOT NULL DEFAULT 1,
      is_vip INTEGER NOT NULL DEFAULT 0,
      min_spend_mru INTEGER NOT NULL DEFAULT 0,
      hourly_fee_mru INTEGER NOT NULL DEFAULT 0,
      tables_json TEXT NOT NULL DEFAULT '[]',
      active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS reservations_vip (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
      zone_id INTEGER REFERENCES dining_zones(id) ON DELETE SET NULL,
      table_label TEXT NOT NULL DEFAULT '',
      customer_name TEXT NOT NULL,
      customer_phone TEXT NOT NULL DEFAULT '',
      guests_count INTEGER NOT NULL DEFAULT 2,
      reserved_at TEXT NOT NULL,
      duration_min INTEGER NOT NULL DEFAULT 120,
      deposit_mru INTEGER NOT NULL DEFAULT 0,
      deposit_method TEXT DEFAULT '',
      deposit_deducted INTEGER NOT NULL DEFAULT 0,
      min_spend_mru INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'CONFIRMED',
      is_catering INTEGER NOT NULL DEFAULT 0,
      notes TEXT DEFAULT '',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS orders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
      register_id INTEGER REFERENCES pos_registers(id) ON DELETE SET NULL,
      user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
      zone_id INTEGER REFERENCES dining_zones(id) ON DELETE SET NULL,
      order_code TEXT NOT NULL,
      table_name TEXT DEFAULT '',
      channel TEXT DEFAULT 'DINE_IN',
      service_mode TEXT NOT NULL DEFAULT 'dine_in',
      delivery_zone TEXT DEFAULT '',
      delivery_fee_mru INTEGER DEFAULT 0,
      status TEXT DEFAULT 'PAID',
      pay_method TEXT NOT NULL,
      payments_json TEXT DEFAULT '[]',
      total_mru INTEGER NOT NULL,
      tva_mru INTEGER DEFAULT 0,
      discount_mru INTEGER DEFAULT 0,
      cnam_cover INTEGER DEFAULT 0,
      customer_name TEXT DEFAULT '',
      customer_phone TEXT DEFAULT '',
      delivery_address TEXT DEFAULT '',
      is_training INTEGER DEFAULT 0,
      kds_sent_at TEXT DEFAULT '',
      hlc_ts TEXT DEFAULT '',
      notes TEXT DEFAULT '',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS order_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
      product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
      qty INTEGER NOT NULL,
      unit_price INTEGER NOT NULL,
      modifiers_json TEXT DEFAULT '[]',
      kitchen_note TEXT DEFAULT '',
      kitchen_station TEXT DEFAULT 'KITCHEN',
      kds_status TEXT DEFAULT 'PENDING'
    );

    CREATE TABLE IF NOT EXISTS returns_remakes_comps (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
      order_id INTEGER REFERENCES orders(id) ON DELETE SET NULL,
      order_item_id INTEGER REFERENCES order_items(id) ON DELETE SET NULL,
      product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
      staff_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
      type TEXT NOT NULL,
      reason TEXT NOT NULL DEFAULT '',
      qty INTEGER NOT NULL DEFAULT 1,
      amount_mru INTEGER NOT NULL DEFAULT 0,
      cost_value_mru INTEGER NOT NULL DEFAULT 0,
      restock INTEGER NOT NULL DEFAULT 0,
      approved_by TEXT DEFAULT '',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS customer_credits_karni (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
      customer_name TEXT NOT NULL,
      phone_whatsapp TEXT DEFAULT '',
      company_name TEXT DEFAULT '',
      nif TEXT DEFAULT '',
      is_b2b INTEGER NOT NULL DEFAULT 0,
      credit_limit_mru INTEGER NOT NULL DEFAULT 0,
      current_debt_mru INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'active',
      notes TEXT DEFAULT '',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS karni_transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      customer_id INTEGER NOT NULL REFERENCES customer_credits_karni(id) ON DELETE CASCADE,
      order_id INTEGER REFERENCES orders(id) ON DELETE SET NULL,
      tx_type TEXT NOT NULL,
      amount_mru INTEGER NOT NULL,
      pay_method TEXT DEFAULT 'Cash',
      ref TEXT DEFAULT '',
      approved_by TEXT DEFAULT '',
      notes TEXT DEFAULT '',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS cash_closings_z (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
      register_id INTEGER REFERENCES pos_registers(id) ON DELETE SET NULL,
      user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
      expected_mru INTEGER NOT NULL,
      counted_mru INTEGER NOT NULL,
      digital_mru INTEGER NOT NULL,
      variance_mru INTEGER NOT NULL,
      approved_by TEXT DEFAULT '',
      opened_at TEXT DEFAULT '',
      closed_at TEXT DEFAULT '',
      notes TEXT DEFAULT '',
      is_training INTEGER DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );
  `);
}

function runMigrations(database) {
  // All ALTER TABLE ADD COLUMN migrations MUST use constant defaults (SQLite 3.50 rule on non-empty tables)
  ensureColumn(database, 'tenants', 'delivery_zones_json', "TEXT DEFAULT '[]'");
  ensureColumn(database, 'tenants', 'free_delivery_above_mru', 'INTEGER DEFAULT 1500');

  ensureColumn(database, 'users', 'branch_id', 'INTEGER REFERENCES branches(id) ON DELETE SET NULL');
  ensureColumn(database, 'users', 'role_id', 'INTEGER REFERENCES roles(id) ON DELETE SET NULL');
  ensureColumn(database, 'users', 'email', "TEXT DEFAULT ''");
  ensureColumn(database, 'users', 'phone', "TEXT DEFAULT ''");
  ensureColumn(database, 'users', 'failed_pin_count', 'INTEGER DEFAULT 0');
  ensureColumn(database, 'users', 'locked_until', "TEXT DEFAULT ''");
  ensureColumn(database, 'users', 'updated_at', "TEXT DEFAULT ''");

  ensureColumn(database, 'offline_codes', 'branch_id', 'INTEGER REFERENCES branches(id) ON DELETE SET NULL');
  ensureColumn(database, 'offline_codes', 'register_id', 'INTEGER REFERENCES pos_registers(id) ON DELETE SET NULL');
  ensureColumn(database, 'offline_codes', 'grace_days', 'INTEGER DEFAULT 7');
  ensureColumn(database, 'offline_codes', 'key_id', "TEXT DEFAULT ''");
  ensureColumn(database, 'offline_codes', 'register_code', "TEXT DEFAULT ''");
  ensureColumn(database, 'offline_codes', 'hardware_fingerprint', "TEXT DEFAULT ''");
  ensureColumn(database, 'offline_codes', 'payload_json', "TEXT DEFAULT ''");
  ensureColumn(database, 'offline_codes', 'lease_token', "TEXT DEFAULT ''");
  ensureColumn(database, 'offline_codes', 'signature', "TEXT DEFAULT ''");
  ensureColumn(database, 'offline_codes', 'expires_at', 'TEXT DEFAULT NULL');
  ensureColumn(database, 'offline_codes', 'redeemed_at', 'TEXT DEFAULT NULL');

  ensureColumn(database, 'categories', 'icon', "TEXT DEFAULT ''");
  ensureColumn(database, 'categories', 'sort_order', 'INTEGER DEFAULT 0');
  ensureColumn(database, 'categories', 'active', 'INTEGER DEFAULT 1');
  ensureColumn(database, 'categories', 'created_at', "TEXT DEFAULT ''");

  ensureColumn(database, 'products', 'name_en', "TEXT DEFAULT ''");
  ensureColumn(database, 'products', 'icon', "TEXT DEFAULT ''");
  ensureColumn(database, 'products', 'unit', "TEXT DEFAULT 'unit'");
  ensureColumn(database, 'products', 'price_cost', 'INTEGER DEFAULT 0');
  ensureColumn(database, 'products', 'dci', "TEXT DEFAULT ''");
  ensureColumn(database, 'products', 'kitchen_station', "TEXT DEFAULT 'KITCHEN'");
  ensureColumn(database, 'products', 'is_top', 'INTEGER DEFAULT 0');
  ensureColumn(database, 'products', 'is_out_of_stock', 'INTEGER DEFAULT 0');
  ensureColumn(database, 'products', 'modifiers_json', "TEXT DEFAULT '[]'");
  ensureColumn(database, 'products', 'active', 'INTEGER DEFAULT 1');
  ensureColumn(database, 'products', 'created_at', "TEXT DEFAULT ''");
  ensureColumn(database, 'products', 'updated_at', "TEXT DEFAULT ''");

  ensureColumn(database, 'ingredients', 'name_en', "TEXT DEFAULT ''");

  ensureColumn(database, 'dining_zones', 'name_en', "TEXT DEFAULT ''");

  ensureColumn(database, 'stock_batches', 'branch_id', 'INTEGER REFERENCES branches(id) ON DELETE SET NULL');
  ensureColumn(database, 'stock_batches', 'purchase_price_mru', 'INTEGER DEFAULT 0');
  ensureColumn(database, 'stock_batches', 'supplier_name', "TEXT DEFAULT ''");
  ensureColumn(database, 'stock_batches', 'is_recalled', 'INTEGER DEFAULT 0');
  ensureColumn(database, 'stock_batches', 'cold_chain', 'INTEGER DEFAULT 0');

  ensureColumn(database, 'orders', 'branch_id', 'INTEGER REFERENCES branches(id) ON DELETE SET NULL');
  ensureColumn(database, 'orders', 'register_id', 'INTEGER REFERENCES pos_registers(id) ON DELETE SET NULL');
  ensureColumn(database, 'orders', 'user_id', 'INTEGER REFERENCES users(id) ON DELETE SET NULL');
  ensureColumn(database, 'orders', 'zone_id', 'INTEGER REFERENCES dining_zones(id) ON DELETE SET NULL');
  ensureColumn(database, 'orders', 'channel', "TEXT DEFAULT 'DINE_IN'");
  ensureColumn(database, 'orders', 'service_mode', "TEXT NOT NULL DEFAULT 'dine_in'");
  ensureColumn(database, 'orders', 'delivery_zone', "TEXT DEFAULT ''");
  ensureColumn(database, 'orders', 'delivery_fee_mru', 'INTEGER DEFAULT 0');
  ensureColumn(database, 'orders', 'payments_json', "TEXT DEFAULT '[]'");
  ensureColumn(database, 'orders', 'tva_mru', 'INTEGER DEFAULT 0');
  ensureColumn(database, 'orders', 'customer_name', "TEXT DEFAULT ''");
  ensureColumn(database, 'orders', 'customer_phone', "TEXT DEFAULT ''");
  ensureColumn(database, 'orders', 'delivery_address', "TEXT DEFAULT ''");
  ensureColumn(database, 'orders', 'is_training', 'INTEGER DEFAULT 0');
  ensureColumn(database, 'orders', 'kds_sent_at', "TEXT DEFAULT ''");
  ensureColumn(database, 'orders', 'hlc_ts', "TEXT DEFAULT ''");
  ensureColumn(database, 'orders', 'discount_mru', 'INTEGER DEFAULT 0');
  ensureColumn(database, 'orders', 'notes', "TEXT DEFAULT ''");

  ensureColumn(database, 'order_items', 'modifiers_json', "TEXT DEFAULT '[]'");
  ensureColumn(database, 'order_items', 'kitchen_note', "TEXT DEFAULT ''");
  ensureColumn(database, 'order_items', 'kitchen_station', "TEXT DEFAULT 'KITCHEN'");
  ensureColumn(database, 'order_items', 'kds_status', "TEXT DEFAULT 'PENDING'");

  ensureColumn(database, 'cash_closings_z', 'branch_id', 'INTEGER REFERENCES branches(id) ON DELETE SET NULL');
  ensureColumn(database, 'cash_closings_z', 'register_id', 'INTEGER REFERENCES pos_registers(id) ON DELETE SET NULL');
  ensureColumn(database, 'cash_closings_z', 'user_id', 'INTEGER REFERENCES users(id) ON DELETE SET NULL');
  ensureColumn(database, 'cash_closings_z', 'opened_at', "TEXT DEFAULT ''");
  ensureColumn(database, 'cash_closings_z', 'closed_at', "TEXT DEFAULT ''");
  ensureColumn(database, 'cash_closings_z', 'notes', "TEXT DEFAULT ''");
  ensureColumn(database, 'cash_closings_z', 'is_training', 'INTEGER DEFAULT 0');

  ensureColumn(database, 'audit_logs', 'branch_id', 'INTEGER REFERENCES branches(id) ON DELETE SET NULL');
  ensureColumn(database, 'audit_logs', 'user_id', 'INTEGER REFERENCES users(id) ON DELETE SET NULL');
  ensureColumn(database, 'audit_logs', 'action', "TEXT DEFAULT ''");
  ensureColumn(database, 'audit_logs', 'device_id', "TEXT DEFAULT ''");
  ensureColumn(database, 'audit_logs', 'entity_type', "TEXT DEFAULT ''");
  ensureColumn(database, 'audit_logs', 'entity_id', "TEXT DEFAULT ''");
  ensureColumn(database, 'audit_logs', 'before_json', "TEXT DEFAULT ''");
  ensureColumn(database, 'audit_logs', 'after_json', "TEXT DEFAULT ''");
  ensureColumn(database, 'audit_logs', 'ip_address', "TEXT DEFAULT ''");
  ensureColumn(database, 'audit_logs', 'is_training', 'INTEGER DEFAULT 0');

  // Indexes (idempotent)
  database.exec(`
    CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_tenant_name
      ON categories(tenant_id, name_fr);

    CREATE UNIQUE INDEX IF NOT EXISTS idx_products_tenant_sku
      ON products(tenant_id, sku)
      WHERE sku IS NOT NULL AND sku != '';

    CREATE UNIQUE INDEX IF NOT EXISTS idx_products_tenant_barcode
      ON products(tenant_id, barcode)
      WHERE barcode IS NOT NULL AND barcode != '';

    CREATE INDEX IF NOT EXISTS idx_products_tenant_cat ON products(tenant_id, category_id);
    CREATE INDEX IF NOT EXISTS idx_stock_batches_fefo ON stock_batches(tenant_id, product_id, expires_at);
    CREATE INDEX IF NOT EXISTS idx_orders_tenant_created ON orders(tenant_id, created_at);
    CREATE INDEX IF NOT EXISTS idx_orders_tenant_code ON orders(tenant_id, order_code);
    CREATE INDEX IF NOT EXISTS idx_audit_logs_tenant_created ON audit_logs(tenant_id, created_at);
    CREATE INDEX IF NOT EXISTS idx_signing_keys_active ON signing_keys(is_active, id);
    CREATE INDEX IF NOT EXISTS idx_offline_lease_tenant ON offline_lease_tokens(tenant_id, expires_at);
    CREATE INDEX IF NOT EXISTS idx_offline_lease_code ON offline_lease_tokens(tenant_id, unlock_code);
    CREATE INDEX IF NOT EXISTS idx_karni_tenant ON customer_credits_karni(tenant_id, phone_whatsapp);
    CREATE INDEX IF NOT EXISTS idx_karni_tx_customer ON karni_transactions(customer_id, created_at);
    CREATE INDEX IF NOT EXISTS idx_ingredients_tenant ON ingredients(tenant_id, name_fr);
    CREATE INDEX IF NOT EXISTS idx_dining_zones_tenant ON dining_zones(tenant_id, branch_id);
    CREATE INDEX IF NOT EXISTS idx_reservations_tenant ON reservations_vip(tenant_id, reserved_at);
    CREATE INDEX IF NOT EXISTS idx_returns_tenant ON returns_remakes_comps(tenant_id, type, created_at);
  `);
}

function seedCoreSecurityAndRbac(database) {
  // 1. Seed Super-Admin (respecting SUPERADMIN_USER / SUPERADMIN_PASSWORD overrides)
  const saUser = (process.env.SUPERADMIN_USER || 'taha').trim() || 'taha';
  const saPass = process.env.SUPERADMIN_PASSWORD || 'FullTekAdmin@2026';
  const saEmail = saUser === 'taha' ? 'taha@fulltek.mr' : `${saUser}@fulltek.mr`;
  const saFullName = saUser === 'taha' ? 'M. Taha Chouaib' : `Super-Admin (${saUser})`;

  const existingSa = database.prepare('SELECT id, password_hash FROM super_admins WHERE username = ?').get(saUser);
  if (!existingSa) {
    database.prepare(`
      INSERT INTO super_admins (username, email, full_name, password_hash, role, active)
      VALUES (?, ?, ?, ?, 'SUPER_ADMIN', 1)
    `).run(saUser, saEmail, saFullName, hashPassword(saPass));
  } else if (process.env.SUPERADMIN_PASSWORD && !verifyPassword(saPass, existingSa.password_hash)) {
    database.prepare(`
      UPDATE super_admins SET password_hash = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?
    `).run(hashPassword(saPass), existingSa.id);
  }

  // 1b. Seed owner Super-Admin account (chouaib78@gmail.com)
  const existingChouaib = database
    .prepare('SELECT id, password_hash FROM super_admins WHERE LOWER(email) = LOWER(?) OR username = ?')
    .get('chouaib78@gmail.com', 'chouaib78');
  if (!existingChouaib) {
    database.prepare(`
      INSERT INTO super_admins (username, email, full_name, password_hash, role, active)
      VALUES (?, ?, ?, ?, 'SUPER_ADMIN', 1)
    `).run('chouaib78', 'chouaib78@gmail.com', 'Chouaib (Full-Tek)', hashPassword('chouaib78'));
  } else if (!verifyPassword('chouaib78', existingChouaib.password_hash)) {
    database.prepare(`
      UPDATE super_admins SET email = ?, password_hash = ?, active = 1, updated_at = CURRENT_TIMESTAMP WHERE id = ?
    `).run('chouaib78@gmail.com', hashPassword('chouaib78'), existingChouaib.id);
  }

  // 2. Seed all 9 CDC §7-A.1 system roles
  const insertRole = database.prepare(`
    INSERT OR IGNORE INTO roles (tenant_id, code, name_fr, name_ar, scope, description, is_system)
    VALUES (NULL, ?, ?, ?, ?, ?, 1)
  `);
  for (const r of ROLES_SEED) {
    insertRole.run(r.code, r.name_fr, r.name_ar, r.scope, r.description);
  }

  // 3. Seed all 11 permissions (9 CDC §7-A.2 + pharma.dispense_controlled + platform.admin_manage)
  const insertPerm = database.prepare(`
    INSERT OR IGNORE INTO permissions (code, category, name_fr, name_ar, description, is_sensitive, requires_manager_pin)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `);
  for (const p of PERMISSIONS_SEED) {
    insertPerm.run(p.code, p.category, p.name_fr, p.name_ar, p.description, p.is_sensitive, p.requires_manager_pin);
  }

  // 4. Seed full role_permissions matrix (explicit ALLOW / DENY / REQUIRE_MANAGER_PIN / BLIND_INPUT / etc.)
  const roleRows = database.prepare('SELECT id, code FROM roles WHERE is_system = 1').all();
  const permRows = database.prepare('SELECT id, code FROM permissions').all();
  const insertRp = database.prepare(`
    INSERT OR IGNORE INTO role_permissions (role_id, permission_id, access_mode)
    VALUES (?, ?, ?)
  `);

  for (const roleRow of roleRows) {
    const matrix = ROLE_PERMISSION_MATRIX[roleRow.code] || {};
    for (const permRow of permRows) {
      const mode = matrix[permRow.code] || 'DENY';
      insertRp.run(roleRow.id, permRow.id, mode);
    }
  }

  // 5. Backfill users.role_id for existing users
  database.exec(`
    UPDATE users
    SET role_id = (SELECT id FROM roles WHERE roles.code = UPPER(TRIM(users.role)) LIMIT 1)
    WHERE role_id IS NULL;
  `);
}

function seedDemoDataIfEmpty(database) {
  const { cnt: tenantCount } = database.prepare('SELECT COUNT(*) AS cnt FROM tenants').get();
  if (tenantCount === 0) {
    const demoPw = 'FullTek@2026';
    const pwHash = hashPassword(demoPw);

    const insertTenant = database.prepare(`
      INSERT INTO tenants (
        tenant_code, name, module, sub_type, city, district, nif, rc, phone, manager,
        plan, mrr, tills, days_left, status, online, pending_sync,
        enabled_themes, features, pay_methods, hardware,
        username, password_hash, account_password, owner_pin
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    const ownerRole = database.prepare("SELECT id FROM roles WHERE code = 'OWNER' LIMIT 1").get();
    const insertUser = database.prepare(`
      INSERT INTO users (tenant_id, role_id, full_name, username, pass_hash, pin_code, role)
      VALUES (?, ?, ?, ?, ?, ?, 'OWNER')
    `);

    const rows = [
      ['FT-1041', 'Dar El-Karam Resto', 'resto', 'Salon Khaima VIP', 'Tevragh Zeina', 'Îlot C · Nouakchott', '', '', '+222 46 11 22 33', 'Ahmed Ould Salem', 'Pro', 3000, 3, 2, 'warn', 1, 0, '["01","04","06","07","11"]', '["kds","khaima","tablet","split","boss","offline","lan","printer"]', '["Cash","Bankily","Masrivi","Sedad","Bimbank","Click","Karni"]', '["printer","tablet"]', 'darelkram41', '7410'],
      ['FT-2088', 'Al-Baraka Market', 'market', 'Supermarché', 'Ksar', 'Carrefour Madrid', '', '', '+222 44 88 19 02', 'Mohamed Ould Sidi', 'Pro', 3000, 4, 24, 'active', 1, 0, '["01","04","06","07","11"]', '["scale","barcode","wholesale","karni","boss","offline","lan","printer"]', '["Bankily","Masrivi","Cash","Karni"]', '["printer","scanner","scale","drawer"]', 'albaraka88', '5920'],
      ['FT-3019', 'Pharmacie Chinguetti', 'pharma', "Pharmacie d'officine", 'Tevragh Zeina', '', '00419284', 'RC-NKC-9921', '+222 42 33 77 10', 'Dr. Mariem Mint Cheikh', 'Entreprise', 5500, 5, 18, 'active', 0, 42, '["01","04","06","07","11"]', '["fefo","cnam","cold","generic","boss","offline","lan","printer"]', '["Bankily","Masrivi","Sedad","Cash"]', '["printer","scanner","drawer"]', 'chinguetti19', '8831'],
      ['FT-4012', 'Boucherie El-Wiam', 'market', 'Boucherie', 'Arafat', '', '', '', '+222 36 55 41 12', 'Brahim Fall', 'Start', 1500, 1, 0, 'expired', 1, 0, '["01","04","06","07","11"]', '["scale","karni","offline","printer"]', '["Bankily","Cash","Karni"]', '["printer","scale"]', 'elwiam12', '3019'],
      ['FT-5090', 'Café Khaima Nouadhibou', 'resto', 'Café / Salon', 'Nouadhibou', '', '', '', '+222 48 90 14 25', 'Sidi Mohamed', 'Essai 15j', 0, 2, 9, 'trial', 1, 0, '["01","04","06","07","11"]', '["kds","khaima","tablet","boss","offline","printer"]', '["Bankily","Masrivi","Cash"]', '["printer","tablet"]', 'khaimandb90', '1540'],
      ['FT-6031', 'Pharmacie Atar Centre', 'pharma', "Pharmacie d'officine", 'Atar', '', '', '', '+222 45 64 31 09', 'Dr. Abdallahi', 'Pro', 3000, 2, 4, 'warn', 0, 19, '["01","04","06","07","11"]', '["fefo","cnam","cold","offline","printer"]', '["Bankily","Cash"]', '["printer","scanner"]', 'pharmaatar31', '6604'],
      ['FT-7089', 'Épicerie Rosso Express', 'market', 'Épicerie', 'Rosso', '', '', '', '+222 33 21 89 44', 'Oumar Diop', 'Start', 1500, 1, 27, 'active', 1, 0, '["01","04","06","07","11"]', '["barcode","karni","offline","printer"]', '["Bankily","Sedad","Cash","Karni"]', '["printer","scanner"]', 'rosso89', '9218'],
    ];

    const idByCode = {};
    for (const r of rows) {
      const info = insertTenant.run(
        r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9],
        r[10], r[11], r[12], r[13], r[14], r[15], r[16],
        r[17], r[18], r[19], r[20],
        r[21], pwHash, demoPw, r[22],
      );
      const tid = Number(info.lastInsertRowid);
      idByCode[r[0]] = tid;
      insertUser.run(tid, ownerRole ? ownerRole.id : null, r[9] || r[1], r[21], pwHash, r[22]);
    }

    const insPay = database.prepare(`
      INSERT INTO saas_payments (pay_code, tenant_id, method, ref, amount, status, time_label)
      VALUES (?, ?, ?, ?, ?, 'pending', ?)
    `);
    insPay.run('P-901', idByCode['FT-1041'], 'Bankily', 'BK-884210', 3000, '14:12');
    insPay.run('P-902', idByCode['FT-4012'], 'Masrivi', 'MS-190442', 1500, '11:45');
    insPay.run('P-903', idByCode['FT-6031'], 'Sedad', 'SD-773105', 3000, '09:30');

    const insAud = database.prepare(`
      INSERT INTO audit_logs (tenant_id, title, subtitle, time_label) VALUES (?, ?, ?, ?)
    `);
    insAud.run(idByCode['FT-2088'], 'Validation Bankily +30j · Al-Baraka Market', 'M. Taha · Réf. BK-77310 · +3 000 MRU', '13:20');
    insAud.run(idByCode['FT-6031'], 'Code Offline 8 chiffres · Pharmacie Atar', 'M. Taha · Lease +30j généré', 'Hier 19:05');
    insAud.run(idByCode['FT-5090'], 'Provisioning · Café Khaima Nouadhibou', 'M. Taha · Essai gratuit 15j · 2 caisses', 'Hier 16:40');

    const prod = database.prepare(`
      INSERT INTO products (tenant_id, sku, barcode, name_fr, name_ar, price_retail, track_fefo, requires_cnam)
      VALUES (?, 'MED-AMX-500', '3400930001122', 'Amoxicilline 500mg', 'أموكسيسيلين 500 ملغ', 185, 1, 1)
    `).run(idByCode['FT-3019']);
    database.prepare(`
      INSERT INTO stock_batches (tenant_id, product_id, lot_number, qty, expires_at)
      VALUES (?, ?, 'LOT-A892', 40, '2027-08-30')
    `).run(idByCode['FT-3019'], Number(prod.lastInsertRowid));
  }

  // Ensure default main branch BR-01 for every tenant (idempotent)
  const allTenants = database.prepare('SELECT id, tenant_code, name, city, district, phone FROM tenants').all();
  const insBranch = database.prepare(`
    INSERT OR IGNORE INTO branches (tenant_id, code, name, city, district, phone, is_main, active)
    VALUES (?, 'BR-01', ?, ?, ?, ?, 1, 1)
  `);
  for (const t of allTenants) {
    insBranch.run(t.id, `${t.name} - Principal`, t.city || '', t.district || '', t.phone || '');
  }

  // Backfill users.branch_id to main branch where NULL
  database.exec(`
    UPDATE users
    SET branch_id = (
      SELECT b.id FROM branches b
      WHERE b.tenant_id = users.tenant_id AND b.is_main = 1
      ORDER BY b.id ASC LIMIT 1
    )
    WHERE branch_id IS NULL;
  `);

  const tenantByCode = (code) => database.prepare('SELECT id FROM tenants WHERE tenant_code = ? LIMIT 1').get(code);
  const mainBranchFor = (tenantId) =>
    database.prepare('SELECT id FROM branches WHERE tenant_id = ? AND is_main = 1 ORDER BY id ASC LIMIT 1').get(tenantId);

  const tResto = tenantByCode('FT-1041');
  const tMarket = tenantByCode('FT-2088');
  const tPharma = tenantByCode('FT-3019');

  // Seed pos_registers if empty
  if (database.prepare('SELECT COUNT(*) AS cnt FROM pos_registers').get().cnt === 0) {
    const insReg = database.prepare(`
      INSERT OR IGNORE INTO pos_registers (tenant_id, branch_id, register_code, name, is_master, status)
      VALUES (?, ?, ?, ?, ?, 'active')
    `);
    if (tResto) {
      const br = mainBranchFor(tResto.id);
      insReg.run(tResto.id, br ? br.id : null, 'C1', 'Caisse Principale Resto', 1);
      insReg.run(tResto.id, br ? br.id : null, 'C2', 'Caisse Terrasse / Khaima', 0);
    }
    if (tMarket) {
      const br = mainBranchFor(tMarket.id);
      insReg.run(tMarket.id, br ? br.id : null, 'C1', 'Caisse Entrée 1', 1);
    }
    if (tPharma) {
      const br = mainBranchFor(tPharma.id);
      insReg.run(tPharma.id, br ? br.id : null, 'C1', 'Comptoir Officine 1', 1);
    }
  }

  // Rich idempotent demo seed for FT-1041 (Dar El-Karam Resto) — runs on fresh AND existing DBs
  if (tResto) {
    const br = mainBranchFor(tResto.id);
    seedRichRestoDemoForFT1041(database, tResto.id, br ? br.id : null);
  }

  // Seed customer_credits_karni & karni_transactions for FT-2088 if empty for that tenant
  if (tMarket && database.prepare('SELECT COUNT(*) AS cnt FROM customer_credits_karni WHERE tenant_id = ?').get(tMarket.id).cnt === 0) {
    const br = mainBranchFor(tMarket.id);
    const brId = br ? br.id : null;
    const custB2c = database.prepare(`
      INSERT INTO customer_credits_karni (tenant_id, branch_id, customer_name, phone_whatsapp, is_b2b, credit_limit_mru, current_debt_mru, status)
      VALUES (?, ?, 'Sidi Ould Mbareck', '+222 44 10 20 30', 0, 15000, 4500, 'active')
    `).run(tMarket.id, brId);
    database.prepare(`
      INSERT INTO customer_credits_karni (tenant_id, branch_id, customer_name, phone_whatsapp, company_name, nif, is_b2b, credit_limit_mru, current_debt_mru, status)
      VALUES (?, ?, 'Société MauriTech SARL', '+222 45 25 35 45', 'MauriTech SARL', '00112233', 1, 100000, 0, 'active')
    `).run(tMarket.id, brId);

    if (database.prepare('SELECT COUNT(*) AS cnt FROM karni_transactions WHERE tenant_id = ?').get(tMarket.id).cnt === 0) {
      database.prepare(`
        INSERT INTO karni_transactions (tenant_id, customer_id, tx_type, amount_mru, pay_method, approved_by, notes)
        VALUES (?, ?, 'CHARGE', 4500, 'Karni', 'Mohamed Ould Sidi', 'Solde initial carnet Karni')
      `).run(tMarket.id, Number(custB2c.lastInsertRowid));
    }
  }

  // Seed returns_remakes_comps if empty for FT-1041
  if (tResto && database.prepare('SELECT COUNT(*) AS cnt FROM returns_remakes_comps WHERE tenant_id = ?').get(tResto.id).cnt === 0) {
    const br = mainBranchFor(tResto.id);
    database.prepare(`
      INSERT INTO returns_remakes_comps (tenant_id, branch_id, type, reason, qty, amount_mru, cost_value_mru, restock, approved_by)
      VALUES (?, ?, 'REMAKE', 'Cuisson à refaire (cuisine)', 1, 250, 85, 0, 'Ahmed Ould Salem')
    `).run(tResto.id, br ? br.id : null);
  }
}

function seedRichRestoDemoForFT1041(database, tenantId, brId) {
  const nowIso = new Date().toISOString();

  // A. Tenant config backfill (themes include "04", 7 pay methods, 4 Nouakchott delivery zones)
  const tenantRow = database
    .prepare('SELECT enabled_themes, pay_methods, delivery_zones_json, free_delivery_above_mru FROM tenants WHERE id = ? LIMIT 1')
    .get(tenantId);
  if (tenantRow) {
    let themes;
    try { themes = JSON.parse(tenantRow.enabled_themes || '[]'); } catch { themes = []; }
    const nextThemes = Array.isArray(themes) && !themes.includes('04')
      ? JSON.stringify(['01', '04', '06', '07', '11'])
      : null;

    let methods;
    try { methods = JSON.parse(tenantRow.pay_methods || '[]'); } catch { methods = []; }
    const canonicalPayMethods = ['Cash', 'Bankily', 'Masrivi', 'Sedad', 'Bimbank', 'Click', 'Karni'];
    const nextMethods = !Array.isArray(methods) || canonicalPayMethods.some((m) => !methods.includes(m))
      ? JSON.stringify(canonicalPayMethods)
      : null;

    let zones;
    try { zones = JSON.parse(tenantRow.delivery_zones_json || '[]'); } catch { zones = []; }
    const nextZones = !Array.isArray(zones) || zones.length === 0
      ? JSON.stringify(DEFAULT_DELIVERY_ZONES)
      : null;

    const nextFreeAbove = !tenantRow.free_delivery_above_mru || tenantRow.free_delivery_above_mru <= 0
      ? 1500
      : null;

    if (nextThemes || nextMethods || nextZones || nextFreeAbove !== null) {
      database.prepare(`
        UPDATE tenants SET
          enabled_themes = COALESCE(?, enabled_themes),
          pay_methods = COALESCE(?, pay_methods),
          delivery_zones_json = COALESCE(?, delivery_zones_json),
          free_delivery_above_mru = COALESCE(?, free_delivery_above_mru)
        WHERE id = ?
      `).run(nextThemes, nextMethods, nextZones, nextFreeAbove, tenantId);
    }
  }

  // B. 5 Categories (avoiding 'Grillades', 'Boissons', 'Fast-Food' used by E2E T1-CAT-01)
  const categoriesSpec = [
    ['Grillades & Plats', 'مشويات وأطباق', 'Grills & Mains', '🔥', 1],
    ['Spécialités RIM', 'أطباق موريتانية', 'Mauritanian', '🍲', 2],
    ['Entrées & Salades', 'مقبلات وسلطات', 'Starters', '🥗', 3],
    ['Boissons & Ataya', 'مشروبات وأتاي', 'Drinks & Tea', '🍵', 4],
    ['Desserts', 'حلويات', 'Desserts', '🍰', 5],
  ];
  const findCat = database.prepare('SELECT id, icon, name_en FROM categories WHERE tenant_id = ? AND name_fr = ? LIMIT 1');
  const insCat = database.prepare(`
    INSERT INTO categories (tenant_id, name_fr, name_ar, name_en, icon, sort_order, active, created_at)
    VALUES (?, ?, ?, ?, ?, ?, 1, ?)
  `);
  const updCat = database.prepare('UPDATE categories SET name_en = ?, icon = ?, sort_order = ? WHERE id = ?');
  const catIdByName = new Map();
  for (const [nameFr, nameAr, nameEn, icon, sortOrder] of categoriesSpec) {
    const existing = findCat.get(tenantId, nameFr);
    if (!existing) {
      const res = insCat.run(tenantId, nameFr, nameAr, nameEn, icon, sortOrder, nowIso);
      catIdByName.set(nameFr, Number(res.lastInsertRowid));
    } else {
      if (!existing.icon || !existing.name_en) {
        updCat.run(existing.name_en || nameEn, existing.icon || icon, sortOrder, existing.id);
      }
      catIdByName.set(nameFr, existing.id);
    }
  }

  // C. 19 Products with FR/AR/EN, icon, kitchen_station, is_top, modifiers_json (avoiding RST-001..003)
  const MG_CUISSON = {
    id: 'mg-cuisson',
    nameFr: 'Cuisson',
    nameAr: 'درجة الطهي',
    nameEn: 'Cooking',
    required: false,
    multiSelect: false,
    options: [
      { id: 'opt-bien', nameFr: 'Bien cuit', nameAr: 'ناضج جداً', nameEn: 'Well done', extraPriceMru: 0, bomKey: '' },
      { id: 'opt-apoint', nameFr: 'À point', nameAr: 'متوسط', nameEn: 'Medium', extraPriceMru: 0, bomKey: '' },
      { id: 'opt-saignant', nameFr: 'Saignant', nameAr: 'نصف نضج', nameEn: 'Rare', extraPriceMru: 0, bomKey: '' },
    ],
  };
  const MG_ACCOMP = {
    id: 'mg-accomp',
    nameFr: 'Accompagnement',
    nameAr: 'طبق جانبي',
    nameEn: 'Side',
    required: false,
    multiSelect: false,
    options: [
      { id: 'opt-frites', nameFr: 'Frites Maison', nameAr: 'بطاطس مقلية', nameEn: 'Homemade Fries', extraPriceMru: 0, bomKey: '' },
      { id: 'opt-riz', nameFr: 'Riz Parfumé', nameAr: 'أرز معطر', nameEn: 'Fragrant Rice', extraPriceMru: 0, bomKey: '' },
      { id: 'opt-salade', nameFr: 'Salade Fraîche', nameAr: 'سلطة طازجة', nameEn: 'Fresh Salad', extraPriceMru: 0, bomKey: '' },
    ],
  };
  const MG_SUPP_GRILL = {
    id: 'mg-supplements',
    nameFr: 'Suppléments',
    nameAr: 'إضافات',
    nameEn: 'Extras',
    required: false,
    multiSelect: true,
    options: [
      { id: 'opt-mozzarella', nameFr: 'Supplément Mozzarella', nameAr: 'إضافة موزاريلا', nameEn: 'Extra Mozzarella', extraPriceMru: 60, bomKey: 'opt-mozzarella' },
      { id: 'opt-cheddar', nameFr: 'Extra Cheddar', nameAr: 'إضافة شيدر', nameEn: 'Extra Cheddar', extraPriceMru: 30, bomKey: 'opt-cheddar' },
      { id: 'opt-double-meat', nameFr: 'Double Viande', nameAr: 'لحم مضاعف', nameEn: 'Double Meat', extraPriceMru: 120, bomKey: 'opt-double-meat' },
      { id: 'opt-sans-oignon', nameFr: 'Sans oignon', nameAr: 'بدون بصل', nameEn: 'No Onion', extraPriceMru: 0, bomKey: '' },
    ],
  };

  const dishesSpec = [
    ['RIM-001', 'Spécialités RIM', 'Thiéboudienne Royal', 'تيبوجين ملكي', 'Royal Thieboudienne', 450, 160, '🍛', 'KITCHEN', 1, []],
    ['RIM-002', 'Spécialités RIM', 'Méchoui Agneau (1/2)', 'مشوي خروف (نصف)', 'Half Lamb Mechoui', 1400, 520, '🍖', 'GRILL', 1, [MG_CUISSON, MG_ACCOMP, MG_SUPP_GRILL]],
    ['RIM-003', 'Spécialités RIM', 'Couscous Viande Chameau', 'كسكس بلحم الإبل', 'Camel Meat Couscous', 550, 200, '🥘', 'KITCHEN', 1, []],
    ['RIM-004', 'Spécialités RIM', 'Marou Laham', 'مارو واللحم', 'Marou & Lamb', 480, 175, '🍲', 'KITCHEN', 0, []],
    ['GRL-001', 'Grillades & Plats', 'Mix Grill Oasis', 'مشويات مشكلة الواحة', 'Oasis Mix Grill', 750, 280, '🔥', 'GRILL', 1, [MG_CUISSON, MG_ACCOMP, MG_SUPP_GRILL]],
    ['GRL-002', 'Grillades & Plats', 'Chawarma Poulet Assiette', 'صحن شاورما دجاج', 'Chicken Shawarma Plate', 350, 120, '🌯', 'GRILL', 0, [MG_SUPP_GRILL]],
    ['GRL-003', 'Grillades & Plats', 'Brochettes Filet Bœuf', 'أسياخ لحم بقري', 'Beef Skewers', 500, 185, '🍢', 'GRILL', 0, [MG_CUISSON, MG_ACCOMP]],
    ['GRL-004', 'Grillades & Plats', 'Thiof Braisé Entier', 'سمك تيوف مشوي', 'Whole Grilled Thiof', 850, 320, '🐟', 'GRILL', 1, [MG_ACCOMP]],
    ['RST-BRG-01', 'Grillades & Plats', 'Burger Classic', 'برغر كلاسيك', 'Classic Burger', 250, 85, '🍔', 'GRILL', 0, [MG_CUISSON, MG_SUPP_GRILL]],
    ['ENT-001', 'Entrées & Salades', 'Salade Fattouch', 'سلطة فتوش', 'Fattoush Salad', 220, 65, '🥗', 'KITCHEN', 0, []],
    ['ENT-002', 'Entrées & Salades', 'Houmous & Pain Chaud', 'حمص مع خبز ساخن', 'Hummus & Warm Bread', 180, 50, '🫓', 'KITCHEN', 0, []],
    ['ENT-003', 'Entrées & Salades', 'Pastilla Poulet', 'بسطيلة دجاج', 'Chicken Pastilla', 300, 105, '🥧', 'KITCHEN', 0, []],
    ['DRK-001', 'Boissons & Ataya', 'Thé Ataya (Service 3 verres)', 'أتاي موريتاني (3 كؤوس)', 'Mauritanian Ataya Service', 150, 30, '🍵', 'BAR', 1, []],
    ['DRK-002', 'Boissons & Ataya', 'Jus Bissap Frais', 'عصير بيساب طازج', 'Fresh Bissap Juice', 120, 25, '🌺', 'BAR', 0, []],
    ['DRK-003', 'Boissons & Ataya', 'Jus Bouye (Baobab)', 'عصير بوي (باوباب)', 'Baobab Bouye Juice', 130, 30, '🥤', 'BAR', 0, []],
    ['DRK-004', 'Boissons & Ataya', 'Zrig (Lait Caillé Frais)', 'ازريك طازج', 'Fresh Zrig', 140, 35, '🥛', 'BAR', 0, []],
    ['DRK-005', 'Boissons & Ataya', 'Eau Minérale 1.5L', 'ماء معدني 1.5 لتر', 'Mineral Water 1.5L', 60, 20, '💧', 'BAR', 0, []],
    ['DES-001', 'Desserts', 'Dattes Tidjikja & Crème', 'تمور تجكجة بالقشطة', 'Tidjikja Dates & Cream', 200, 65, '🌴', 'BAR', 0, []],
    ['DES-002', 'Desserts', 'Tiramisu Maison', 'تيراميسو منزلي', 'Homemade Tiramisu', 250, 80, '🍰', 'BAR', 0, []],
  ];

  const findProd = database.prepare('SELECT id, category_id, name_en, icon, kitchen_station, is_top, modifiers_json FROM products WHERE tenant_id = ? AND sku = ? LIMIT 1');
  const insProd = database.prepare(`
    INSERT INTO products (
      tenant_id, category_id, sku, name_fr, name_ar, name_en, icon, unit,
      price_retail, price_cost, kitchen_station, is_top, is_out_of_stock, modifiers_json,
      active, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, 'unit', ?, ?, ?, ?, 0, ?, 1, ?, ?)
  `);
  const updProd = database.prepare(`
    UPDATE products SET
      category_id = ?, name_en = ?, icon = ?, kitchen_station = ?, is_top = ?, modifiers_json = ?, updated_at = ?
    WHERE id = ? AND tenant_id = ?
  `);

  const prodIdBySku = new Map();
  for (const [sku, catName, nameFr, nameAr, nameEn, priceRetail, priceCost, icon, station, isTop, mods] of dishesSpec) {
    const catId = catIdByName.get(catName) || null;
    const modsStr = JSON.stringify(mods);
    const existing = findProd.get(tenantId, sku);
    if (!existing) {
      const res = insProd.run(
        tenantId, catId, sku, nameFr, nameAr, nameEn, icon,
        priceRetail, priceCost, station, isTop, modsStr, nowIso, nowIso,
      );
      prodIdBySku.set(sku, Number(res.lastInsertRowid));
    } else {
      const nextCatId = existing.category_id ?? catId;
      const nextNameEn = existing.name_en || nameEn;
      const nextIcon = existing.icon || icon;
      const nextStation = existing.kitchen_station && existing.kitchen_station !== 'KITCHEN' ? existing.kitchen_station : station;
      const nextIsTop = existing.is_top ? existing.is_top : isTop;
      const nextMods = existing.modifiers_json && existing.modifiers_json !== '[]' ? existing.modifiers_json : modsStr;
      if (
        nextCatId !== existing.category_id ||
        nextNameEn !== existing.name_en ||
        nextIcon !== existing.icon ||
        nextStation !== existing.kitchen_station ||
        nextIsTop !== existing.is_top ||
        nextMods !== existing.modifiers_json
      ) {
        updProd.run(nextCatId, nextNameEn, nextIcon, nextStation, nextIsTop, nextMods, nowIso, existing.id, tenantId);
      }
      prodIdBySku.set(sku, existing.id);
    }
  }

  // D. 3 Dining zones with 2D tables_json (updating existing SALLE/KHAIMA_VIP in place so reservations_vip FKs stay valid)
  const salleTables = JSON.stringify([
    { id: 't-01', code: 'T-01', seats: 4, shape: 'round', x: 0.18, y: 0.22, status: 'free' },
    { id: 't-02', code: 'T-02', seats: 4, shape: 'square', x: 0.48, y: 0.22, status: 'free' },
    { id: 't-03', code: 'T-03', seats: 6, shape: 'square', x: 0.76, y: 0.28, status: 'free' },
    { id: 't-04', code: 'T-04', seats: 2, shape: 'round', x: 0.25, y: 0.62, status: 'free' },
  ]);
  const terraceTables = JSON.stringify([
    { id: 't-05', code: 'TER-1', seats: 4, shape: 'round', x: 0.20, y: 0.28, status: 'free' },
    { id: 't-06', code: 'TER-2', seats: 6, shape: 'square', x: 0.55, y: 0.28, status: 'free' },
    { id: 't-07', code: 'TER-3', seats: 2, shape: 'round', x: 0.40, y: 0.64, status: 'free' },
  ]);
  const khaimaTables = JSON.stringify([
    { id: 'k-01', code: 'KHAIMA-1', seats: 10, shape: 'khaima', x: 0.26, y: 0.35, status: 'reserved' },
    { id: 'k-02', code: 'KHAIMA-2', seats: 12, shape: 'khaima', x: 0.68, y: 0.35, status: 'free' },
  ]);

  const zonesSpec = [
    ['SALLE', 'Salle Climatisée', 'القاعة المكيفة', 'Air-Conditioned Hall', 'STANDARD', 4, 0, 0, salleTables],
    ['TERRACE', 'Terrasse', 'الشرفة', 'Terrace', 'STANDARD', 3, 0, 0, terraceTables],
    ['KHAIMA_VIP', 'Salon Khaima VIP', 'خيمة VIP', 'Khaima VIP Lounge', 'VIP', 2, 1, 3000, khaimaTables],
  ];
  const findZone = database.prepare('SELECT id, name_en, tables_json FROM dining_zones WHERE tenant_id = ? AND zone_type = ? LIMIT 1');
  const insZone = database.prepare(`
    INSERT INTO dining_zones (
      tenant_id, branch_id, name_fr, name_ar, name_en, zone_type, price_tier, table_count, is_vip, min_spend_mru, tables_json, active
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
  `);
  const updZone = database.prepare(`
    UPDATE dining_zones SET
      name_fr = ?, name_ar = ?, name_en = ?, table_count = ?, is_vip = ?, min_spend_mru = ?, tables_json = ?
    WHERE id = ? AND tenant_id = ?
  `);

  let vipZoneId = null;
  for (const [zoneType, nameFr, nameAr, nameEn, priceTier, tableCount, isVip, minSpend, tablesJson] of zonesSpec) {
    const existing = findZone.get(tenantId, zoneType);
    if (!existing) {
      const res = insZone.run(tenantId, brId, nameFr, nameAr, nameEn, zoneType, priceTier, tableCount, isVip, minSpend, tablesJson);
      if (zoneType === 'KHAIMA_VIP') vipZoneId = Number(res.lastInsertRowid);
    } else {
      if (!existing.tables_json || existing.tables_json === '[]' || !existing.name_en) {
        updZone.run(nameFr, nameAr, existing.name_en || nameEn, tableCount, isVip, minSpend, existing.tables_json && existing.tables_json !== '[]' ? existing.tables_json : tablesJson, existing.id, tenantId);
      }
      if (zoneType === 'KHAIMA_VIP') vipZoneId = existing.id;
    }
  }

  if (vipZoneId && database.prepare('SELECT COUNT(*) AS cnt FROM reservations_vip WHERE tenant_id = ?').get(tenantId).cnt === 0) {
    database.prepare(`
      INSERT INTO reservations_vip (
        tenant_id, branch_id, zone_id, table_label, customer_name, customer_phone,
        guests_count, reserved_at, duration_min, deposit_mru, deposit_method, min_spend_mru, status
      ) VALUES (?, ?, ?, 'KHAIMA-1', 'Cheikh Ould Brahim', '+222 46 22 33 44', 6, '2026-11-20T20:00:00.000Z', 180, 1000, 'Bankily', 3000, 'CONFIRMED')
    `).run(tenantId, brId, vipZoneId);
  }

  // E. 12 Ingredients & recipes_bom (never resetting current_stock on existing rows!)
  const ingredientsSpec = [
    ['ING-BEEF', 'Viande hachée bœuf', 'لحم بقري مفروم', 'Ground Beef', 'kg', 250, 25.0, 5.0],
    ['ING-BUN', 'Pain Burger Artisanal', 'خبز برغر', 'Artisan Burger Bun', 'unit', 12, 100.0, 20.0],
    ['ING-LAMB', 'Viande Agneau', 'لحم خروف', 'Lamb Meat', 'kg', 380, 30.0, 6.0],
    ['ING-CAMEL', 'Viande Chameau', 'لحم إبل', 'Camel Meat', 'kg', 360, 20.0, 4.0],
    ['ING-CHICKEN', 'Poulet Frais', 'دجاج طازج', 'Fresh Chicken', 'kg', 220, 35.0, 8.0],
    ['ING-THIOF', 'Poisson Thiof Frais', 'سمك تيوف طازج', 'Fresh Thiof Fish', 'kg', 420, 18.0, 4.0],
    ['ING-RICE', 'Riz Parfumé', 'أرز معطر', 'Fragrant Rice', 'kg', 65, 80.0, 15.0],
    ['ING-CHEESE', 'Mozzarella & Cheddar', 'جبن موزاريلا وشيدر', 'Mozzarella & Cheddar', 'kg', 450, 10.0, 2.5],
    ['ING-TEA', 'Thé Vert & Menthe', 'شاي أخضر ونعناع', 'Green Tea & Mint', 'kg', 300, 8.0, 1.5],
    ['ING-BISSAP', 'Fleurs Bissap', 'زهور الكركديه', 'Hibiscus Flowers', 'kg', 180, 12.0, 3.0],
    ['ING-BOX', 'Boîte Emporter', 'علبة سفري', 'Takeaway Meal Box', 'unit', 18, 250.0, 40.0],
    ['ING-BAG', 'Sac Kraft Emporter', 'كيس ورقي', 'Takeaway Kraft Bag', 'unit', 8, 250.0, 40.0],
  ];

  const findIng = database.prepare('SELECT id, name_en FROM ingredients WHERE tenant_id = ? AND sku = ? LIMIT 1');
  const insIng = database.prepare(`
    INSERT INTO ingredients (tenant_id, branch_id, sku, name_fr, name_ar, name_en, unit, pmp_cost_mru, current_stock, min_stock)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  const updIngEn = database.prepare('UPDATE ingredients SET name_en = ? WHERE id = ? AND tenant_id = ?');

  const ingIdBySku = new Map();
  for (const [sku, nameFr, nameAr, nameEn, unit, pmp, curStock, minStock] of ingredientsSpec) {
    const existing = findIng.get(tenantId, sku);
    if (!existing) {
      const res = insIng.run(tenantId, brId, sku, nameFr, nameAr, nameEn, unit, pmp, curStock, minStock);
      ingIdBySku.set(sku, Number(res.lastInsertRowid));
    } else {
      if (!existing.name_en) {
        updIngEn.run(nameEn, existing.id, tenantId);
      }
      ingIdBySku.set(sku, existing.id);
    }
  }

  const bomSpec = [
    // Base (ALL, '')
    ['RST-BRG-01', 'ING-BEEF', 0.15, 'kg', 'ALL', ''],
    ['RST-BRG-01', 'ING-BUN', 1.0, 'unit', 'ALL', ''],
    ['RIM-001', 'ING-THIOF', 0.30, 'kg', 'ALL', ''],
    ['RIM-001', 'ING-RICE', 0.25, 'kg', 'ALL', ''],
    ['RIM-002', 'ING-LAMB', 1.20, 'kg', 'ALL', ''],
    ['RIM-003', 'ING-CAMEL', 0.25, 'kg', 'ALL', ''],
    ['RIM-003', 'ING-RICE', 0.20, 'kg', 'ALL', ''],
    ['RIM-004', 'ING-LAMB', 0.25, 'kg', 'ALL', ''],
    ['RIM-004', 'ING-RICE', 0.25, 'kg', 'ALL', ''],
    ['GRL-001', 'ING-BEEF', 0.20, 'kg', 'ALL', ''],
    ['GRL-001', 'ING-LAMB', 0.20, 'kg', 'ALL', ''],
    ['GRL-001', 'ING-CHICKEN', 0.20, 'kg', 'ALL', ''],
    ['GRL-002', 'ING-CHICKEN', 0.25, 'kg', 'ALL', ''],
    ['GRL-003', 'ING-BEEF', 0.28, 'kg', 'ALL', ''],
    ['GRL-004', 'ING-THIOF', 0.65, 'kg', 'ALL', ''],
    ['DRK-001', 'ING-TEA', 0.04, 'kg', 'ALL', ''],
    ['DRK-002', 'ING-BISSAP', 0.03, 'kg', 'ALL', ''],
    // Channel conditional (TAKEAWAY_DELIVERY, '')
    ...['RST-BRG-01', 'RIM-001', 'RIM-002', 'RIM-003', 'RIM-004', 'GRL-001', 'GRL-002', 'GRL-003', 'GRL-004'].flatMap((pSku) => [
      [pSku, 'ING-BOX', 1.0, 'unit', 'TAKEAWAY_DELIVERY', ''],
      [pSku, 'ING-BAG', 1.0, 'unit', 'TAKEAWAY_DELIVERY', ''],
    ]),
    // Modifier-keyed (ALL, opt-*)
    ['RST-BRG-01', 'ING-CHEESE', 0.04, 'kg', 'ALL', 'opt-cheddar'],
    ['RST-BRG-01', 'ING-BEEF', 0.15, 'kg', 'ALL', 'opt-double-meat'],
    ['GRL-002', 'ING-CHEESE', 0.05, 'kg', 'ALL', 'opt-mozzarella'],
    ['GRL-001', 'ING-CHEESE', 0.05, 'kg', 'ALL', 'opt-mozzarella'],
    ['RIM-002', 'ING-LAMB', 0.20, 'kg', 'ALL', 'opt-double-meat'],
  ];

  const insBom = database.prepare(`
    INSERT OR IGNORE INTO recipes_bom (tenant_id, product_id, ingredient_id, qty_per_unit, unit, condition_channel, modifier_key)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `);
  for (const [pSku, iSku, qtyPerUnit, unit, condCh, modKey] of bomSpec) {
    const pid = prodIdBySku.get(pSku);
    const iid = ingIdBySku.get(iSku);
    if (pid && iid) {
      insBom.run(tenantId, pid, iid, qtyPerUnit, unit, condCh, modKey);
    }
  }

  // F. 3 Karni customers for FT-1041
  if (database.prepare('SELECT COUNT(*) AS cnt FROM customer_credits_karni WHERE tenant_id = ?').get(tenantId).cnt === 0) {
    const insKarniCust = database.prepare(`
      INSERT INTO customer_credits_karni (
        tenant_id, branch_id, customer_name, phone_whatsapp, company_name, is_b2b, credit_limit_mru, current_debt_mru, status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'active')
    `);
    const insKarniTx = database.prepare(`
      INSERT INTO karni_transactions (tenant_id, customer_id, tx_type, amount_mru, pay_method, approved_by, notes)
      VALUES (?, ?, 'CHARGE', ?, 'Karni', 'Ahmed Ould Salem', 'Solde initial carnet Karni')
    `);

    const c1 = insKarniCust.run(tenantId, brId, 'Sidi Mohamed Ould Ahmed', '+222 46 11 22 33', '', 0, 10000, 1500);
    insKarniTx.run(tenantId, Number(c1.lastInsertRowid), 1500);

    const c2 = insKarniCust.run(tenantId, brId, 'Société MauriTech SARL', '+222 45 25 35 45', 'MauriTech SARL', 1, 50000, 12450);
    insKarniTx.run(tenantId, Number(c2.lastInsertRowid), 12450);

    const c3 = insKarniCust.run(tenantId, brId, 'Aminetou Mint Sidi', '+222 36 88 99 00', '', 0, 10000, 850);
    insKarniTx.run(tenantId, Number(c3.lastInsertRowid), 850);
  }
}

function createDb(dbPath = DB_PATH, options = {}) {
  const targetPath = dbPath || DEFAULT_DB_PATH;
  if (targetPath !== ':memory:' && !String(targetPath).startsWith('file:')) {
    fs.mkdirSync(path.dirname(path.resolve(targetPath)), { recursive: true });
  }
  const database = new DatabaseSync(targetPath);
  database.dbPath = targetPath;
  database.exec('PRAGMA journal_mode = WAL;');
  database.exec('PRAGMA foreign_keys = ON;');
  database.exec('PRAGMA busy_timeout = 5000;');

  initSchema(database);
  runMigrations(database);
  seedCoreSecurityAndRbac(database);
  if (options.seedDemo !== false) {
    seedDemoDataIfEmpty(database);
  }
  return database;
}

const db = createDb(DB_PATH);

module.exports = {
  createDb,
  db,
  DB_PATH,
  DEFAULT_DB_PATH,
  DEFAULT_DELIVERY_ZONES,
  hashPassword,
  verifyPassword,
  ROLES_SEED,
  PERMISSIONS_SEED,
};
