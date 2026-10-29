import relationalStore from '@ohos.data.relationalStore';

export const DATABASE_NAME: string = 'carbon_footprint_v1.db';
export const SCHEMA_VERSION: number = 1;

export const CREATE_SCHEMA_SQL: string[] = [
  `CREATE TABLE IF NOT EXISTS behavior_records (
    id TEXT PRIMARY KEY NOT NULL,
    created_request_id TEXT NOT NULL UNIQUE,
    business_date TEXT NOT NULL,
    category TEXT NOT NULL CHECK(category IN ('travel','energy_water','recycling','food')),
    created_at INTEGER NOT NULL CHECK(typeof(created_at) = 'integer' AND created_at >= 0),
    status TEXT NOT NULL CHECK(status IN ('active','voided')),
    reduction_grams INTEGER NOT NULL CHECK(typeof(reduction_grams) = 'integer'),
    note TEXT NOT NULL,
    rule_name TEXT NOT NULL,
    payload TEXT NOT NULL
  )`,
  'CREATE INDEX IF NOT EXISTS idx_records_date_status ON behavior_records(status, business_date DESC, created_at DESC, id ASC)',
  'CREATE INDEX IF NOT EXISTS idx_records_category ON behavior_records(category, status, business_date DESC)',
  `CREATE TABLE IF NOT EXISTS point_ledger (
    id TEXT PRIMARY KEY NOT NULL,
    source_key TEXT NOT NULL UNIQUE,
    delta INTEGER NOT NULL CHECK(typeof(delta) = 'integer'),
    created_at INTEGER NOT NULL,
    payload TEXT NOT NULL
  )`,
  'CREATE INDEX IF NOT EXISTS idx_ledger_created ON point_ledger(created_at DESC, id ASC)',
  `CREATE TABLE IF NOT EXISTS task_reward_states (
    task_id TEXT NOT NULL,
    period_key TEXT NOT NULL,
    payload TEXT NOT NULL,
    PRIMARY KEY(task_id, period_key)
  )`,
  `CREATE TABLE IF NOT EXISTS redemptions (
    id TEXT PRIMARY KEY NOT NULL,
    reward_id TEXT NOT NULL UNIQUE,
    request_id TEXT NOT NULL UNIQUE,
    created_at INTEGER NOT NULL,
    payload TEXT NOT NULL
  )`,
  'CREATE INDEX IF NOT EXISTS idx_redemptions_created ON redemptions(created_at DESC, id ASC)',
  `CREATE TABLE IF NOT EXISTS idempotency_operations (
    request_id TEXT PRIMARY KEY NOT NULL,
    operation_type TEXT NOT NULL,
    input_fingerprint TEXT NOT NULL,
    status TEXT NOT NULL,
    committed_at INTEGER NOT NULL,
    payload TEXT NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS business_settings (
    setting_key TEXT PRIMARY KEY NOT NULL,
    updated_at INTEGER NOT NULL,
    payload TEXT NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS suggestion_feedback (
    suggestion_id TEXT PRIMARY KEY NOT NULL,
    updated_at INTEGER NOT NULL,
    payload TEXT NOT NULL
  )`
];

export interface SchemaMigration {
  fromVersion: number;
  toVersion: number;
  statements: string[];
}

// The same migration runner is used by initialization and real-RDB failure/retry tests.
export async function migrateSchema(store: relationalStore.RdbStore, migration: SchemaMigration): Promise<void> {
  if (store.version !== migration.fromVersion || migration.toVersion <= migration.fromVersion) {
    throw new Error('Invalid database migration sequence');
  }
  store.beginTransaction();
  let committed: boolean = false;
  try {
    for (let i: number = 0; i < migration.statements.length; i++) {
      await store.executeSql(migration.statements[i]);
    }
    store.commit();
    committed = true;
    store.version = migration.toVersion;
  } catch (error) {
    if (!committed) {
      store.rollBack();
    }
    throw error as Error;
  }
}

export async function initializeSchema(store: relationalStore.RdbStore): Promise<void> {
  const currentVersion: number = store.version;
  if (currentVersion > SCHEMA_VERSION) {
    throw new Error(`Unsupported database schema version ${currentVersion}`);
  }
  if (currentVersion === SCHEMA_VERSION) {
    return;
  }
  await migrateSchema(store, { fromVersion: 0, toVersion: SCHEMA_VERSION, statements: CREATE_SCHEMA_SQL });
}
