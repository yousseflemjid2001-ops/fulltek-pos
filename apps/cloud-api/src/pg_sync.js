const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');
const { Pool } = require('pg');

/**
 * Persists the SQLite database file as a gzip-compressed binary snapshot
 * inside Aiven / PostgreSQL (`db_snapshots` table) so ephemeral container
 * restarts (e.g. Render Free) never lose data.
 */
function createPgBackupManager(rawUrl) {
  const trimmed = String(rawUrl || '').trim();
  if (!trimmed || !/^postgres(ql)?:\/\//i.test(trimmed)) {
    return null;
  }

  let connectionString = trimmed;
  try {
    const parsed = new URL(trimmed);
    parsed.searchParams.delete('sslmode');
    connectionString = parsed.toString();
  } catch {
    // Keep original connection string if URL parsing fails
  }

  const pool = new Pool({
    connectionString,
    ssl: { rejectUnauthorized: false },
    max: 3,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 15000,
  });

  let timer = null;
  let inFlight = null;
  let dirty = false;
  let lastPushAt = null;
  let lastError = null;

  async function ensureSchema() {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS db_snapshots (
        id INTEGER PRIMARY KEY,
        updated_at TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        payload BYTEA NOT NULL
      );
    `);
  }

  async function restoreIfNeeded(dbPath) {
    if (!dbPath || dbPath === ':memory:') {
      return { restored: false, hasRemoteSnapshot: false };
    }
    await ensureSchema();
    const res = await pool.query(
      'SELECT payload, updated_at, size_bytes FROM db_snapshots WHERE id = 1',
    );
    if (!res.rows.length || !res.rows[0].payload) {
      return { restored: false, hasRemoteSnapshot: false };
    }

    const row = res.rows[0];
    const localExists = fs.existsSync(dbPath) && fs.statSync(dbPath).size > 4096;
    if (localExists) {
      return { restored: false, hasRemoteSnapshot: true };
    }

    fs.mkdirSync(path.dirname(dbPath), { recursive: true });
    const rawBytes = zlib.gunzipSync(Buffer.from(row.payload));
    const tmpPath = `${dbPath}.restore.tmp`;
    fs.writeFileSync(tmpPath, rawBytes);
    for (const suffix of ['-wal', '-shm']) {
      if (fs.existsSync(`${dbPath}${suffix}`)) {
        fs.rmSync(`${dbPath}${suffix}`, { force: true });
      }
    }
    fs.renameSync(tmpPath, dbPath);
    lastPushAt = row.updated_at || null;
    console.log(
      `[PG-SYNC] Restored SQLite snapshot from PostgreSQL (${rawBytes.length} bytes, updated ${row.updated_at})`,
    );
    return { restored: true, hasRemoteSnapshot: true };
  }

  async function pushNow(database, dbPath) {
    if (!database || database.isOpen === false || !dbPath || dbPath === ':memory:') {
      return;
    }
    if (inFlight) {
      dirty = true;
      return inFlight;
    }

    inFlight = (async () => {
      do {
        dirty = false;
        const snapPath = `${dbPath}.snap.${process.pid}.tmp`;
        try {
          if (fs.existsSync(snapPath)) {
            fs.rmSync(snapPath, { force: true });
          }
          const escaped = snapPath.replace(/'/g, "''");
          database.exec(`VACUUM INTO '${escaped}'`);
          const rawBytes = fs.readFileSync(snapPath);
          const gz = zlib.gzipSync(rawBytes);
          const nowIso = new Date().toISOString();
          await ensureSchema();
          await pool.query(
            `
              INSERT INTO db_snapshots (id, updated_at, size_bytes, payload)
              VALUES (1, $1, $2, $3)
              ON CONFLICT (id) DO UPDATE SET
                updated_at = EXCLUDED.updated_at,
                size_bytes = EXCLUDED.size_bytes,
                payload = EXCLUDED.payload
            `,
            [nowIso, rawBytes.length, gz],
          );
          lastPushAt = nowIso;
          lastError = null;
        } catch (err) {
          lastError = err?.message || String(err);
          console.error('[PG-SYNC] Snapshot push failed:', lastError);
        } finally {
          if (fs.existsSync(snapPath)) {
            fs.rmSync(snapPath, { force: true });
          }
        }
      } while (dirty);
    })().finally(() => {
      inFlight = null;
    });

    return inFlight;
  }

  function schedulePush(database, dbPath, delayMs = 400) {
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => {
      timer = null;
      pushNow(database, dbPath);
    }, delayMs);
    if (typeof timer.unref === 'function') timer.unref();
  }

  async function flushAndClose(database, dbPath) {
    if (timer) {
      clearTimeout(timer);
      timer = null;
      await pushNow(database, dbPath);
    } else if (inFlight) {
      await inFlight;
    }
    await pool.end().catch(() => {});
  }

  return {
    restoreIfNeeded,
    pushNow,
    schedulePush,
    flushAndClose,
    getStatus: () => ({
      enabled: true,
      lastPushAt,
      lastError,
    }),
  };
}

module.exports = { createPgBackupManager };
