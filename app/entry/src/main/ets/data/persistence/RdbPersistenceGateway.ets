import relationalStore from '@ohos.data.relationalStore';
import common from '@ohos.app.ability.common';
import {
  DatabaseSnapshot, IdempotencyOperation, PersistenceGateway, ReadRepository,
  RecordReadRepository, RecordWriteRepository, TaskStateReadRepository, TaskStateWriteRepository,
  PointsReadRepository, PointsWriteRepository, RedemptionReadRepository, RedemptionWriteRepository,
  OperationReadRepository, OperationWriteRepository, MetadataReadRepository, MetadataWriteRepository,
  TransactionContext
} from '../../common/contracts/Persistence';
import { BehaviorRecord, RecordFilter, RecordPage, RecordQuery, RecordStatus } from '../../common/contracts/Records';
import { Id, RequestId, TimestampMs } from '../../common/contracts/Common';
import { PointLedgerEntry, Redemption, TaskRewardState } from '../../common/contracts/Engagement';
import { BusinessSetting, SuggestionFeedbackEntry } from '../../common/contracts/Content';
import { AppError, ErrorCode, toAppError } from '../../common/errors/AppError';
import { DATABASE_NAME, initializeSchema, SCHEMA_VERSION } from './RdbSchema';
import { isValidLocalDate } from '../../common/utils/Dates';
import { validateRecord, validateLedger, validateTaskState, validateRedemption, validateOperation, validateSetting, validateFeedback } from './Validation';

class M03RepositoryAdapter1 implements RecordReadRepository {
  getById: (recordId: Id) => Promise<BehaviorRecord | null>;
  list: (query: RecordQuery) => Promise<RecordPage>;
  getActiveSnapshot: (filter: RecordFilter) => Promise<BehaviorRecord[]>;
  constructor(getById: (recordId: Id) => Promise<BehaviorRecord | null>, list: (query: RecordQuery) => Promise<RecordPage>, getActiveSnapshot: (filter: RecordFilter) => Promise<BehaviorRecord[]>) {
    this.getById = getById;
    this.list = list;
    this.getActiveSnapshot = getActiveSnapshot;
  }
}

class M03RepositoryAdapter2 implements RecordWriteRepository {
  getById: (recordId: Id) => Promise<BehaviorRecord | null>;
  list: (query: RecordQuery) => Promise<RecordPage>;
  getActiveSnapshot: (filter: RecordFilter) => Promise<BehaviorRecord[]>;
  insert: (record: BehaviorRecord) => Promise<void>;
  update: (record: BehaviorRecord) => Promise<void>;
  voidRecord: (recordId: Id, updatedAt: TimestampMs) => Promise<void>;
  constructor(getById: (recordId: Id) => Promise<BehaviorRecord | null>, list: (query: RecordQuery) => Promise<RecordPage>, getActiveSnapshot: (filter: RecordFilter) => Promise<BehaviorRecord[]>, insert: (record: BehaviorRecord) => Promise<void>, update: (record: BehaviorRecord) => Promise<void>, voidRecord: (recordId: Id, updatedAt: TimestampMs) => Promise<void>) {
    this.getById = getById;
    this.list = list;
    this.getActiveSnapshot = getActiveSnapshot;
    this.insert = insert;
    this.update = update;
    this.voidRecord = voidRecord;
  }
}

class M03RepositoryAdapter3 implements TaskStateWriteRepository {
  get: (taskId: Id, periodKey: string) => Promise<TaskRewardState | null>;
  listForPeriod: (periodKey: string) => Promise<TaskRewardState[]>;
  insert: (state: TaskRewardState) => Promise<void>;
  update: (state: TaskRewardState) => Promise<void>;
  constructor(get: (taskId: Id, periodKey: string) => Promise<TaskRewardState | null>, listForPeriod: (periodKey: string) => Promise<TaskRewardState[]>, insert: (state: TaskRewardState) => Promise<void>, update: (state: TaskRewardState) => Promise<void>) {
    this.get = get;
    this.listForPeriod = listForPeriod;
    this.insert = insert;
    this.update = update;
  }
}

class M03RepositoryAdapter4 implements PointsWriteRepository {
  getBalance: () => Promise<number>;
  listLedger: (offset: number, limit: number) => Promise<PointLedgerEntry[]>;
  getBySourceKey: (sourceKey: string) => Promise<PointLedgerEntry | null>;
  insert: (entry: PointLedgerEntry) => Promise<void>;
  constructor(getBalance: () => Promise<number>, listLedger: (offset: number, limit: number) => Promise<PointLedgerEntry[]>, getBySourceKey: (sourceKey: string) => Promise<PointLedgerEntry | null>, insert: (entry: PointLedgerEntry) => Promise<void>) {
    this.getBalance = getBalance;
    this.listLedger = listLedger;
    this.getBySourceKey = getBySourceKey;
    this.insert = insert;
  }
}

class M03RepositoryAdapter5 implements RedemptionWriteRepository {
  getByRewardId: (rewardId: Id) => Promise<Redemption | null>;
  list: () => Promise<Redemption[]>;
  insert: (redemption: Redemption) => Promise<void>;
  constructor(getByRewardId: (rewardId: Id) => Promise<Redemption | null>, list: () => Promise<Redemption[]>, insert: (redemption: Redemption) => Promise<void>) {
    this.getByRewardId = getByRewardId;
    this.list = list;
    this.insert = insert;
  }
}

class M03RepositoryAdapter6 implements OperationWriteRepository {
  getByRequestId: (requestId: RequestId) => Promise<IdempotencyOperation | null>;
  insert: (operation: IdempotencyOperation) => Promise<void>;
  constructor(getByRequestId: (requestId: RequestId) => Promise<IdempotencyOperation | null>, insert: (operation: IdempotencyOperation) => Promise<void>) {
    this.getByRequestId = getByRequestId;
    this.insert = insert;
  }
}

class M03RepositoryAdapter7 implements MetadataWriteRepository {
  getSetting: (key: string) => Promise<BusinessSetting | null>;
  listSettings: () => Promise<BusinessSetting[]>;
  getFeedback: (suggestionId: Id) => Promise<SuggestionFeedbackEntry | null>;
  listFeedback: () => Promise<SuggestionFeedbackEntry[]>;
  putSetting: (setting: BusinessSetting) => Promise<void>;
  putFeedback: (feedback: SuggestionFeedbackEntry) => Promise<void>;
  constructor(getSetting: (key: string) => Promise<BusinessSetting | null>, listSettings: () => Promise<BusinessSetting[]>, getFeedback: (suggestionId: Id) => Promise<SuggestionFeedbackEntry | null>, listFeedback: () => Promise<SuggestionFeedbackEntry[]>, putSetting: (setting: BusinessSetting) => Promise<void>, putFeedback: (feedback: SuggestionFeedbackEntry) => Promise<void>) {
    this.getSetting = getSetting;
    this.listSettings = listSettings;
    this.getFeedback = getFeedback;
    this.listFeedback = listFeedback;
    this.putSetting = putSetting;
    this.putFeedback = putFeedback;
  }
}

class M03RepositoryAdapter8 implements RecordReadRepository {
  getById: (recordId: Id) => Promise<BehaviorRecord | null>;
  list: (query: RecordQuery) => Promise<RecordPage>;
  getActiveSnapshot: (filter: RecordFilter) => Promise<BehaviorRecord[]>;
  constructor(getById: (recordId: Id) => Promise<BehaviorRecord | null>, list: (query: RecordQuery) => Promise<RecordPage>, getActiveSnapshot: (filter: RecordFilter) => Promise<BehaviorRecord[]>) {
    this.getById = getById;
    this.list = list;
    this.getActiveSnapshot = getActiveSnapshot;
  }
}

class M03RepositoryAdapter9 implements TaskStateReadRepository {
  get: (taskId: Id, periodKey: string) => Promise<TaskRewardState | null>;
  listForPeriod: (periodKey: string) => Promise<TaskRewardState[]>;
  constructor(get: (taskId: Id, periodKey: string) => Promise<TaskRewardState | null>, listForPeriod: (periodKey: string) => Promise<TaskRewardState[]>) {
    this.get = get;
    this.listForPeriod = listForPeriod;
  }
}

class M03RepositoryAdapter10 implements PointsReadRepository {
  getBalance: () => Promise<number>;
  listLedger: (offset: number, limit: number) => Promise<PointLedgerEntry[]>;
  getBySourceKey: (sourceKey: string) => Promise<PointLedgerEntry | null>;
  constructor(getBalance: () => Promise<number>, listLedger: (offset: number, limit: number) => Promise<PointLedgerEntry[]>, getBySourceKey: (sourceKey: string) => Promise<PointLedgerEntry | null>) {
    this.getBalance = getBalance;
    this.listLedger = listLedger;
    this.getBySourceKey = getBySourceKey;
  }
}

class M03RepositoryAdapter11 implements RedemptionReadRepository {
  getByRewardId: (rewardId: Id) => Promise<Redemption | null>;
  list: () => Promise<Redemption[]>;
  constructor(getByRewardId: (rewardId: Id) => Promise<Redemption | null>, list: () => Promise<Redemption[]>) {
    this.getByRewardId = getByRewardId;
    this.list = list;
  }
}

class M03RepositoryAdapter12 implements OperationReadRepository {
  getByRequestId: (requestId: RequestId) => Promise<IdempotencyOperation | null>;
  constructor(getByRequestId: (requestId: RequestId) => Promise<IdempotencyOperation | null>) {
    this.getByRequestId = getByRequestId;
  }
}

class M03RepositoryAdapter13 implements MetadataReadRepository {
  getSetting: (key: string) => Promise<BusinessSetting | null>;
  listSettings: () => Promise<BusinessSetting[]>;
  getFeedback: (suggestionId: Id) => Promise<SuggestionFeedbackEntry | null>;
  listFeedback: () => Promise<SuggestionFeedbackEntry[]>;
  constructor(getSetting: (key: string) => Promise<BusinessSetting | null>, listSettings: () => Promise<BusinessSetting[]>, getFeedback: (suggestionId: Id) => Promise<SuggestionFeedbackEntry | null>, listFeedback: () => Promise<SuggestionFeedbackEntry[]>) {
    this.getSetting = getSetting;
    this.listSettings = listSettings;
    this.getFeedback = getFeedback;
    this.listFeedback = listFeedback;
  }
}

class M03RepositoryAdapter14 implements ReadRepository {
  records: RecordReadRepository;
  taskStates: TaskStateReadRepository;
  points: PointsReadRepository;
  redemptions: RedemptionReadRepository;
  operations: OperationReadRepository;
  metadata: MetadataReadRepository;
  getFullSnapshot: () => Promise<DatabaseSnapshot>;
  constructor(records: RecordReadRepository, taskStates: TaskStateReadRepository, points: PointsReadRepository, redemptions: RedemptionReadRepository, operations: OperationReadRepository, metadata: MetadataReadRepository, getFullSnapshot: () => Promise<DatabaseSnapshot>) {
    this.records = records;
    this.taskStates = taskStates;
    this.points = points;
    this.redemptions = redemptions;
    this.operations = operations;
    this.metadata = metadata;
    this.getFullSnapshot = getFullSnapshot;
  }
}

interface SqlFilter {
  clause: string;
  args: Array<relationalStore.ValueType>;
}

const T_RECORDS: string = 'behavior_records';
const T_LEDGER: string = 'point_ledger';
const T_TASKS: string = 'task_reward_states';
const T_REDEMPTIONS: string = 'redemptions';
const T_OPERATIONS: string = 'idempotency_operations';
const T_SETTINGS: string = 'business_settings';
const T_FEEDBACK: string = 'suggestion_feedback';
const CATEGORY_VALUES: string[] = ['travel', 'energy_water', 'recycling', 'food'];

function containsValue(values: string[], candidate: string): boolean {
  for (let i: number = 0; i < values.length; i++) {
    if (values[i] === candidate) {
      return true;
    }
  }
  return false;
}

function fail(code: ErrorCode, message: string): AppError {
  return new AppError(code, message);
}

function mapStorageError(error: Object): AppError {
  if (error instanceof AppError) {
    return error;
  }
  const detail: string = `${String(error)} ${JSON.stringify(error)}`;
  if (detail.includes('14800032') || detail.toLowerCase().includes('constraint')) {
    return new AppError(ErrorCode.IDEMPOTENCY_CONFLICT, '请求与已保存数据冲突。');
  }
  return toAppError(error);
}

function validatePage(offset: number, limit: number): void {
  if (!Number.isSafeInteger(offset) || offset < 0 || !Number.isSafeInteger(limit) || limit <= 0) {
    throw fail(ErrorCode.INVALID_INPUT, '分页参数无效。');
  }
}

function jsonColumn<T>(row: relationalStore.ResultSet, name: string): T {
  return JSON.parse(row.getString(row.getColumnIndex(name))) as T;
}

async function readRows<T>(store: relationalStore.RdbStore, sql: string,
  args: Array<relationalStore.ValueType> = []): Promise<T[]> {
  let result: relationalStore.ResultSet | undefined = undefined;
  try {
    result = await store.querySql(sql, args);
    const rows: T[] = [];
    if (result.goToFirstRow()) {
      do {
        rows.push(jsonColumn<T>(result, 'payload'));
      } while (result.goToNextRow());
    }
    return rows;
  } finally {
    if (result !== undefined) {
      result.close();
    }
  }
}

async function readOne<T>(store: relationalStore.RdbStore, sql: string,
  args: Array<relationalStore.ValueType> = []): Promise<T | null> {
  let result: relationalStore.ResultSet | undefined = undefined;
  try {
    result = await store.querySql(sql, args);
    if (!result.goToFirstRow()) {
      return null;
    }
    return jsonColumn<T>(result, 'payload');
  } finally {
    if (result !== undefined) {
      result.close();
    }
  }
}

async function sumLedger(store: relationalStore.RdbStore): Promise<number> {
  let result: relationalStore.ResultSet | undefined = undefined;
  try {
    result = await store.querySql(`SELECT COALESCE(SUM(delta), 0) AS point_balance FROM ${T_LEDGER}`);
    if (!result.goToFirstRow()) {
      return 0;
    }
    const total: number = result.getLong(result.getColumnIndex('point_balance'));
    if (!Number.isSafeInteger(total)) {
      throw fail(ErrorCode.STORAGE_FAILED, '积分余额超出安全整数范围。');
    }
    return total;
  } finally {
    if (result !== undefined) {
      result.close();
    }
  }
}

async function countRows(store: relationalStore.RdbStore, sql: string,
  args: Array<relationalStore.ValueType>): Promise<number> {
  let result: relationalStore.ResultSet | undefined = undefined;
  try {
    result = await store.querySql(sql, args);
    if (!result.goToFirstRow()) {
      return 0;
    }
    return result.getLong(result.getColumnIndex('row_count'));
  } finally {
    if (result !== undefined) {
      result.close();
    }
  }
}

function recordFilterSql(filter: RecordFilter): SqlFilter {
  const parts: string[] = ['status = ?'];
  const args: Array<relationalStore.ValueType> = [RecordStatus.ACTIVE];
  if (filter.startDateInclusive !== null) {
    parts.push('business_date >= ?');
    args.push(filter.startDateInclusive);
  }
  if (filter.endDateExclusive !== null) {
    parts.push('business_date < ?');
    args.push(filter.endDateExclusive);
  }
  if (filter.category !== null) {
    parts.push('category = ?');
    args.push(filter.category);
  }
  if (filter.keyword !== null && filter.keyword.length > 0) {
    // instr performs literal matching: user '%' and '_' are not SQL wildcards.
    parts.push('(instr(note, ?) > 0 OR instr(rule_name, ?) > 0)');
    args.push(filter.keyword);
    args.push(filter.keyword);
  }
  return { clause: parts.join(' AND '), args };
}

function filterValid(filter: RecordFilter): void {
  if ((filter.category !== null && !containsValue(CATEGORY_VALUES, filter.category)) ||
    (filter.keyword !== null && typeof filter.keyword !== 'string') ||
    (filter.startDateInclusive !== null && !isValidLocalDate(filter.startDateInclusive)) ||
    (filter.endDateExclusive !== null && !isValidLocalDate(filter.endDateExclusive)) ||
    (filter.startDateInclusive !== null && filter.endDateExclusive !== null &&
      filter.startDateInclusive >= filter.endDateExclusive)) {
    throw fail(ErrorCode.INVALID_INPUT, '查询日期范围无效。');
  }
}

function recordValues(record: BehaviorRecord): Array<relationalStore.ValueType> {
  return [record.id, record.createdByRequestId, record.businessDate, record.category,
    record.createdAt, record.status, record.reductionGrams, record.note, record.factorSnapshot.rule.name, JSON.stringify(record)];
}

async function insertPayload(store: relationalStore.RdbStore, table: string, columns: string[],
  values: Array<relationalStore.ValueType>): Promise<void> {
  const marks: string[] = [];
  for (let i: number = 0; i < columns.length; i++) {
    marks.push('?');
  }
  await store.executeSql(`INSERT INTO ${table} (${columns.join(',')}) VALUES (${marks.join(',')})`, values);
}

function buildRecordRepository(store: relationalStore.RdbStore): RecordReadRepository {
  const repository: RecordReadRepository = new M03RepositoryAdapter1(
    async (recordId: Id): Promise<BehaviorRecord | null> => {
      try {
        return await readOne<BehaviorRecord>(store,
          `SELECT payload FROM ${T_RECORDS} WHERE id = ?`, [recordId]);
      } catch (error) {
        throw mapStorageError(error as Object);
      }
    },
    async (query: RecordQuery): Promise<RecordPage> => {
      validatePage(query.offset, query.limit);
      filterValid(query);
      const filter: SqlFilter = recordFilterSql(query);
      try {
        const total: number = await countRows(store,
          `SELECT COUNT(*) AS row_count FROM ${T_RECORDS} WHERE ${filter.clause}`, filter.args);
        const pageArgs: Array<relationalStore.ValueType> = filter.args.slice();
        pageArgs.push(query.limit);
        pageArgs.push(query.offset);
        const items: BehaviorRecord[] = await readRows<BehaviorRecord>(store,
          `SELECT payload FROM ${T_RECORDS} WHERE ${filter.clause} ORDER BY business_date DESC, created_at DESC, id ASC LIMIT ? OFFSET ?`,
          pageArgs);
        return { items, total, offset: query.offset, limit: query.limit };
      } catch (error) {
        throw mapStorageError(error as Object);
      }
    },
    async (filter: RecordFilter): Promise<BehaviorRecord[]> => {
      filterValid(filter);
      const where: SqlFilter = recordFilterSql(filter);
      try {
        return await readRows<BehaviorRecord>(store,
          `SELECT payload FROM ${T_RECORDS} WHERE ${where.clause} ORDER BY business_date DESC, created_at DESC, id ASC`, where.args);
      } catch (error) {
        throw mapStorageError(error as Object);
      }
    }
  );
  return repository;
}

function copyValue<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function compareText(a: string, b: string): number {
  return a < b ? -1 : (a > b ? 1 : 0);
}

class RdbTransactionContext implements TransactionContext {
  readonly records: RecordWriteRepository;
  readonly taskStates: TaskStateWriteRepository;
  readonly points: PointsWriteRepository;
  readonly redemptions: RedemptionWriteRepository;
  readonly operations: OperationWriteRepository;
  readonly metadata: MetadataWriteRepository;
  private readonly store: relationalStore.RdbStore;
  private active: boolean = true;
  private view: DatabaseSnapshot | null;

  constructor(store: relationalStore.RdbStore, view: DatabaseSnapshot | null = null) {
    this.store = store;
    this.view = view;
    this.records = this.createRecordWriter();
    this.taskStates = this.createTaskWriter();
    this.points = this.createPointWriter();
    this.redemptions = this.createRedemptionWriter();
    this.operations = this.createOperationWriter();
    this.metadata = this.createMetadataWriter();
  }

  deactivate(): void {
    this.active = false;
  }

  private ensureActive(): void {
    if (!this.active) {
      throw fail(ErrorCode.STORAGE_FAILED, '事务上下文已结束。');
    }
  }

  async getFullSnapshot(): Promise<DatabaseSnapshot> {
    this.ensureActive();
    return this.snapshot();
  }

  async replaceAll(snapshot: DatabaseSnapshot): Promise<void> {
    this.ensureActive();
    // Validate input shape before destructive statements; SQL constraints remain authoritative.
    ensureSnapshot(snapshot);
    if (snapshot.schemaVersion !== SCHEMA_VERSION) {
      throw fail(ErrorCode.BACKUP_VERSION_UNSUPPORTED, '数据库快照版本不兼容。');
    }
    ensureUnique(snapshot.records.map((item: BehaviorRecord) => item.id), 'record id');
    ensureUnique(snapshot.records.map((item: BehaviorRecord) => item.createdByRequestId), 'record request id');
    ensureUnique(snapshot.ledgerEntries.map((item: PointLedgerEntry) => item.id), 'ledger id');
    ensureUnique(snapshot.ledgerEntries.map((item: PointLedgerEntry) => item.sourceKey), 'ledger source key');
    ensureUnique(snapshot.redemptions.map((item: Redemption) => item.id), 'redemption id');
    ensureUnique(snapshot.redemptions.map((item: Redemption) => item.rewardId), 'reward id');
    ensureUnique(snapshot.redemptions.map((item: Redemption) => item.requestId), 'redemption request id');
    ensureUnique(snapshot.operations.map((item: IdempotencyOperation) => item.requestId), 'operation request id');
    ensureUnique(snapshot.taskRewardStates.map((item: TaskRewardState) => JSON.stringify([item.taskId, item.periodKey])), 'task period key');
    ensureUnique(snapshot.settings.map((item: BusinessSetting) => item.key), 'setting key');
    ensureUnique(snapshot.feedback.map((item: SuggestionFeedbackEntry) => item.suggestionId), 'feedback suggestion id');

    if (this.view !== null) {
      this.view = { schemaVersion: SCHEMA_VERSION, records: [], ledgerEntries: [], taskRewardStates: [],
        redemptions: [], operations: [], settings: [], feedback: [] };
    }
    const tables: string[] = [T_RECORDS, T_LEDGER, T_TASKS, T_REDEMPTIONS, T_OPERATIONS, T_SETTINGS, T_FEEDBACK];
    for (let i: number = 0; i < tables.length; i++) {
      await this.store.executeSql(`DELETE FROM ${tables[i]}`);
    }
    for (let i: number = 0; i < snapshot.records.length; i++) {
      await this.records.insert(snapshot.records[i]);
    }
    for (let i: number = 0; i < snapshot.ledgerEntries.length; i++) {
      await this.points.insert(snapshot.ledgerEntries[i]);
    }
    for (let i: number = 0; i < snapshot.taskRewardStates.length; i++) {
      await this.taskStates.insert(snapshot.taskRewardStates[i]);
    }
    for (let i: number = 0; i < snapshot.redemptions.length; i++) {
      await this.redemptions.insert(snapshot.redemptions[i]);
    }
    for (let i: number = 0; i < snapshot.operations.length; i++) {
      await this.operations.insert(snapshot.operations[i]);
    }
    for (let i: number = 0; i < snapshot.settings.length; i++) {
      await this.metadata.putSetting(snapshot.settings[i]);
    }
    for (let i: number = 0; i < snapshot.feedback.length; i++) {
      await this.metadata.putFeedback(snapshot.feedback[i]);
    }
  }

  private async snapshot(): Promise<DatabaseSnapshot> {
    if (this.view !== null) {
      const result: DatabaseSnapshot = copyValue(this.view);
      result.records.sort((a: BehaviorRecord, b: BehaviorRecord): number => compareText(a.id, b.id));
      result.ledgerEntries.sort((a: PointLedgerEntry, b: PointLedgerEntry): number => compareText(a.id, b.id));
      result.taskRewardStates.sort((a: TaskRewardState, b: TaskRewardState): number => compareText(a.taskId, b.taskId) || compareText(a.periodKey, b.periodKey));
      result.redemptions.sort((a: Redemption, b: Redemption): number => compareText(a.id, b.id));
      result.operations.sort((a: IdempotencyOperation, b: IdempotencyOperation): number => compareText(a.requestId, b.requestId));
      result.settings.sort((a: BusinessSetting, b: BusinessSetting): number => compareText(a.key, b.key));
      result.feedback.sort((a: SuggestionFeedbackEntry, b: SuggestionFeedbackEntry): number => compareText(a.suggestionId, b.suggestionId));
      return result;
    }
    const records: BehaviorRecord[] = await readRows<BehaviorRecord>(this.store, `SELECT payload FROM ${T_RECORDS} ORDER BY id ASC`);
    const ledgerEntries: PointLedgerEntry[] = await readRows<PointLedgerEntry>(this.store, `SELECT payload FROM ${T_LEDGER} ORDER BY id ASC`);
    const taskRewardStates: TaskRewardState[] = await readRows<TaskRewardState>(this.store, `SELECT payload FROM ${T_TASKS} ORDER BY task_id ASC, period_key ASC`);
    const redemptions: Redemption[] = await readRows<Redemption>(this.store, `SELECT payload FROM ${T_REDEMPTIONS} ORDER BY id ASC`);
    const operations: IdempotencyOperation[] = await readRows<IdempotencyOperation>(this.store, `SELECT payload FROM ${T_OPERATIONS} ORDER BY request_id ASC`);
    const settings: BusinessSetting[] = await readRows<BusinessSetting>(this.store, `SELECT payload FROM ${T_SETTINGS} ORDER BY setting_key ASC`);
    const feedback: SuggestionFeedbackEntry[] = await readRows<SuggestionFeedbackEntry>(this.store, `SELECT payload FROM ${T_FEEDBACK} ORDER BY suggestion_id ASC`);
    return { schemaVersion: SCHEMA_VERSION, records, ledgerEntries, taskRewardStates, redemptions, operations, settings, feedback };
  }

  private filteredRecords(filter: RecordFilter): BehaviorRecord[] {
    filterValid(filter);
    const matches: BehaviorRecord[] = this.view!.records.filter((item: BehaviorRecord): boolean =>
      item.status === RecordStatus.ACTIVE &&
      (filter.startDateInclusive === null || item.businessDate >= filter.startDateInclusive) &&
      (filter.endDateExclusive === null || item.businessDate < filter.endDateExclusive) &&
      (filter.category === null || item.category === filter.category) &&
      (filter.keyword === null || filter.keyword.length === 0 || item.note.includes(filter.keyword) || item.factorSnapshot.rule.name.includes(filter.keyword)));
    matches.sort((a: BehaviorRecord, b: BehaviorRecord): number => compareText(b.businessDate, a.businessDate) ||
      (b.createdAt - a.createdAt) || compareText(a.id, b.id));
    return copyValue(matches);
  }

  private createRecordWriter(): RecordWriteRepository {
    const reader: RecordReadRepository = this.view === null ? buildRecordRepository(this.store) : new M03RepositoryAdapter1(
      async (id: Id): Promise<BehaviorRecord | null> => {
        const found: BehaviorRecord | undefined = this.view!.records.find((item: BehaviorRecord): boolean => item.id === id);
        return found === undefined ? null : copyValue(found);
      },
      async (query: RecordQuery): Promise<RecordPage> => {
        validatePage(query.offset, query.limit);
        const items: BehaviorRecord[] = this.filteredRecords(query);
        return { items: items.slice(query.offset, query.offset + query.limit), total: items.length, offset: query.offset, limit: query.limit };
      },
      async (filter: RecordFilter): Promise<BehaviorRecord[]> => this.filteredRecords(filter)
    );
    const repository: RecordWriteRepository = new M03RepositoryAdapter2(
      async (recordId: Id): Promise<BehaviorRecord | null> => {
        this.ensureActive();
        return await reader.getById(recordId);
      },
      async (query: RecordQuery): Promise<RecordPage> => {
        this.ensureActive();
        return await reader.list(query);
      },
      async (filter: RecordFilter): Promise<BehaviorRecord[]> => {
        this.ensureActive();
        return await reader.getActiveSnapshot(filter);
      },
      async (record: BehaviorRecord): Promise<void> => {
        this.ensureActive();
        validateRecord(record);
        if (await reader.getById(record.id) !== null) {
          throw fail(ErrorCode.IDEMPOTENCY_CONFLICT, '记录标识已被使用。');
        }
        const existingRequest: BehaviorRecord | null = this.view === null ? await readOne<BehaviorRecord>(this.store,
          `SELECT payload FROM ${T_RECORDS} WHERE created_request_id=?`, [record.createdByRequestId]) :
          (this.view.records.find((item: BehaviorRecord): boolean => item.createdByRequestId === record.createdByRequestId) ?? null);
        if (existingRequest !== null) {
          throw fail(ErrorCode.IDEMPOTENCY_CONFLICT, '请求标识已被使用。');
        }
        try {
          await insertPayload(this.store, T_RECORDS,
            ['id','created_request_id','business_date','category','created_at','status','reduction_grams','note','rule_name','payload'], recordValues(record));
          if (this.view !== null) { this.view.records.push(copyValue(record)); }
        } catch (error) {
          throw mapStorageError(error as Object);
        }
      },
      async (record: BehaviorRecord): Promise<void> => {
        this.ensureActive();
        validateRecord(record);
        const current: BehaviorRecord | null = await reader.getById(record.id);
        if (current === null) {
          throw fail(ErrorCode.RECORD_NOT_FOUND, '记录不存在。');
        }
        if (current.createdByRequestId !== record.createdByRequestId || current.createdAt !== record.createdAt) {
          throw fail(ErrorCode.INVALID_INPUT, '记录更新不得更改创建来源。');
        }
        try {
          const values: Array<relationalStore.ValueType> = [record.businessDate, record.category, record.createdAt,
            record.status, record.reductionGrams, record.note, record.factorSnapshot.rule.name, JSON.stringify(record), record.id];
          await this.store.executeSql(`UPDATE ${T_RECORDS} SET business_date=?,category=?,created_at=?,status=?,reduction_grams=?,note=?,rule_name=?,payload=? WHERE id=?`, values);
          if (this.view !== null) { this.view.records = this.view.records.map((item: BehaviorRecord): BehaviorRecord => item.id === record.id ? copyValue(record) : item); }
        } catch (error) {
          throw mapStorageError(error as Object);
        }
      },
      async (recordId: Id, updatedAt: TimestampMs): Promise<void> => {
        this.ensureActive();
        if (updatedAt % 1 !== 0 || updatedAt < 0 || recordId.length === 0) {
          throw fail(ErrorCode.INVALID_INPUT, '撤销时间或记录标识无效。');
        }
        const current: BehaviorRecord | null = await reader.getById(recordId);
        if (current === null) {
          throw fail(ErrorCode.RECORD_NOT_FOUND, '记录不存在。');
        }
        if (current.status === RecordStatus.VOIDED) {
          return;
        }
        current.status = RecordStatus.VOIDED;
        current.updatedAt = updatedAt;
        try {
          await this.store.executeSql(`UPDATE ${T_RECORDS} SET status=?,payload=? WHERE id=?`,
            [RecordStatus.VOIDED, JSON.stringify(current), recordId]);
          if (this.view !== null) { this.view.records = this.view.records.map((item: BehaviorRecord): BehaviorRecord => item.id === recordId ? copyValue(current) : item); }
        } catch (error) {
          throw mapStorageError(error as Object);
        }
      }
    );
    return repository;
  }

  private createTaskWriter(): TaskStateWriteRepository {
    const repository: TaskStateWriteRepository = new M03RepositoryAdapter3(
      async (taskId: Id, periodKey: string): Promise<TaskRewardState | null> => {
        this.ensureActive();
        if (this.view !== null) { return copyValue(this.view.taskRewardStates.find((item: TaskRewardState): boolean => item.taskId === taskId && item.periodKey === periodKey) ?? null); }
        return await readOne<TaskRewardState>(this.store, `SELECT payload FROM ${T_TASKS} WHERE task_id=? AND period_key=?`, [taskId, periodKey]);
      },
      async (periodKey: string): Promise<TaskRewardState[]> => {
        this.ensureActive();
        if (this.view !== null) { return copyValue(this.view.taskRewardStates.filter((item: TaskRewardState): boolean => item.periodKey === periodKey).sort((a: TaskRewardState, b: TaskRewardState): number => compareText(a.taskId, b.taskId))); }
        return await readRows<TaskRewardState>(this.store, `SELECT payload FROM ${T_TASKS} WHERE period_key=? ORDER BY task_id ASC`, [periodKey]);
      },
      async (state: TaskRewardState): Promise<void> => {
        this.ensureActive();
        validateTaskState(state);
        if (await this.taskStates.get(state.taskId, state.periodKey) !== null) {
          throw fail(ErrorCode.IDEMPOTENCY_CONFLICT, '任务周期状态已存在。');
        }
        await insertPayload(this.store, T_TASKS, ['task_id','period_key','payload'], [state.taskId, state.periodKey, JSON.stringify(state)]);
        if (this.view !== null) { this.view.taskRewardStates.push(copyValue(state)); }
      },
      async (state: TaskRewardState): Promise<void> => {
        this.ensureActive();
        validateTaskState(state);
        const current: TaskRewardState | null = await this.taskStates.get(state.taskId, state.periodKey);
        if (current === null) {
          throw fail(ErrorCode.INVALID_INPUT, '任务状态不存在。');
        }
        await this.store.executeSql(`UPDATE ${T_TASKS} SET payload=? WHERE task_id=? AND period_key=?`,
          [JSON.stringify(state), state.taskId, state.periodKey]);
        if (this.view !== null) { this.view.taskRewardStates = this.view.taskRewardStates.map((item: TaskRewardState): TaskRewardState => item.taskId === state.taskId && item.periodKey === state.periodKey ? copyValue(state) : item); }
      }
    );
    return repository;
  }

  private createPointWriter(): PointsWriteRepository {
    const repository: PointsWriteRepository = new M03RepositoryAdapter4(
      async (): Promise<number> => {
        this.ensureActive();
        if (this.view !== null) {
          const total: number = this.view.ledgerEntries.reduce((sum: number, item: PointLedgerEntry): number => sum + item.delta, 0);
          if (!Number.isSafeInteger(total)) { throw fail(ErrorCode.STORAGE_FAILED, '积分余额超出安全整数范围。'); }
          return total;
        }
        return await sumLedger(this.store);
      },
      async (offset: number, limit: number): Promise<PointLedgerEntry[]> => {
        this.ensureActive();
        validatePage(offset, limit);
        if (this.view !== null) { return copyValue(this.view.ledgerEntries.slice().sort((a: PointLedgerEntry, b: PointLedgerEntry): number => (b.createdAt - a.createdAt) || compareText(a.id, b.id)).slice(offset, offset + limit)); }
        return await readRows<PointLedgerEntry>(this.store,
          `SELECT payload FROM ${T_LEDGER} ORDER BY created_at DESC, id ASC LIMIT ? OFFSET ?`, [limit, offset]);
      },
      async (sourceKey: string): Promise<PointLedgerEntry | null> => {
        this.ensureActive();
        if (this.view !== null) { return copyValue(this.view.ledgerEntries.find((item: PointLedgerEntry): boolean => item.sourceKey === sourceKey) ?? null); }
        return await readOne<PointLedgerEntry>(this.store, `SELECT payload FROM ${T_LEDGER} WHERE source_key=?`, [sourceKey]);
      },
      async (entry: PointLedgerEntry): Promise<void> => {
        this.ensureActive();
        validateLedger(entry);
        if (entry.delta % 1 !== 0 || entry.createdAt % 1 !== 0 ||
          entry.id.length === 0 || entry.sourceKey.length === 0) {
          throw fail(ErrorCode.INVALID_INPUT, '积分流水无效。');
        }
        const existing: PointLedgerEntry | null = this.view === null ? await readOne<PointLedgerEntry>(this.store,
          `SELECT payload FROM ${T_LEDGER} WHERE id=? OR source_key=?`, [entry.id, entry.sourceKey]) :
          (this.view.ledgerEntries.find((item: PointLedgerEntry): boolean => item.id === entry.id || item.sourceKey === entry.sourceKey) ?? null);
        if (existing !== null) {
          throw fail(ErrorCode.IDEMPOTENCY_CONFLICT, '积分流水标识已被使用。');
        }
        await insertPayload(this.store, T_LEDGER, ['id','source_key','delta','created_at','payload'],
          [entry.id, entry.sourceKey, entry.delta, entry.createdAt, JSON.stringify(entry)]);
        if (this.view !== null) { this.view.ledgerEntries.push(copyValue(entry)); }
      }
    );
    return repository;
  }

  private createRedemptionWriter(): RedemptionWriteRepository {
    const repository: RedemptionWriteRepository = new M03RepositoryAdapter5(
      async (rewardId: Id): Promise<Redemption | null> => {
        this.ensureActive();
        if (this.view !== null) { return copyValue(this.view.redemptions.find((item: Redemption): boolean => item.rewardId === rewardId) ?? null); }
        return await readOne<Redemption>(this.store, `SELECT payload FROM ${T_REDEMPTIONS} WHERE reward_id=?`, [rewardId]);
      },
      async (): Promise<Redemption[]> => {
        this.ensureActive();
        if (this.view !== null) { return copyValue(this.view.redemptions.slice().sort((a: Redemption, b: Redemption): number => (b.createdAt - a.createdAt) || compareText(a.id, b.id))); }
        return await readRows<Redemption>(this.store, `SELECT payload FROM ${T_REDEMPTIONS} ORDER BY created_at DESC, id ASC`);
      },
      async (redemption: Redemption): Promise<void> => {
        this.ensureActive();
        validateRedemption(redemption);
        const existing: Redemption | null = this.view === null ? await readOne<Redemption>(this.store,
          `SELECT payload FROM ${T_REDEMPTIONS} WHERE reward_id=? OR id=? OR request_id=?`,
          [redemption.rewardId, redemption.id, redemption.requestId]) :
          (this.view.redemptions.find((item: Redemption): boolean => item.rewardId === redemption.rewardId || item.id === redemption.id || item.requestId === redemption.requestId) ?? null);
        if (existing !== null) {
          if (existing.rewardId === redemption.rewardId) {
            throw fail(ErrorCode.ALREADY_REDEEMED, '该奖励已经兑换。');
          }
          throw fail(ErrorCode.IDEMPOTENCY_CONFLICT, '兑换标识已被使用。');
        }
        await insertPayload(this.store, T_REDEMPTIONS, ['id','reward_id','request_id','created_at','payload'],
          [redemption.id, redemption.rewardId, redemption.requestId, redemption.createdAt, JSON.stringify(redemption)]);
        if (this.view !== null) { this.view.redemptions.push(copyValue(redemption)); }
      }
    );
    return repository;
  }

  private createOperationWriter(): OperationWriteRepository {
    const repository: OperationWriteRepository = new M03RepositoryAdapter6(
      async (requestId: RequestId): Promise<IdempotencyOperation | null> => {
        this.ensureActive();
        if (this.view !== null) { return copyValue(this.view.operations.find((item: IdempotencyOperation): boolean => item.requestId === requestId) ?? null); }
        return await readOne<IdempotencyOperation>(this.store,
          `SELECT payload FROM ${T_OPERATIONS} WHERE request_id=?`, [requestId]);
      },
      async (operation: IdempotencyOperation): Promise<void> => {
        this.ensureActive();
        validateOperation(operation);
        if (await this.operations.getByRequestId(operation.requestId) !== null) {
          throw fail(ErrorCode.IDEMPOTENCY_CONFLICT, '请求已存在幂等结果。');
        }
        await insertPayload(this.store, T_OPERATIONS,
          ['request_id','operation_type','input_fingerprint','status','committed_at','payload'],
          [operation.requestId, operation.operationType, operation.inputFingerprint, operation.status,
            operation.committedAt, JSON.stringify(operation)]);
        if (this.view !== null) { this.view.operations.push(copyValue(operation)); }
      }
    );
    return repository;
  }

  private createMetadataWriter(): MetadataWriteRepository {
    const repository: MetadataWriteRepository = new M03RepositoryAdapter7(
      async (key: string): Promise<BusinessSetting | null> => {
        this.ensureActive();
        if (this.view !== null) { return copyValue(this.view.settings.find((item: BusinessSetting): boolean => item.key === key) ?? null); }
        return await readOne<BusinessSetting>(this.store, `SELECT payload FROM ${T_SETTINGS} WHERE setting_key=?`, [key]);
      },
      async (): Promise<BusinessSetting[]> => {
        this.ensureActive();
        if (this.view !== null) { return copyValue(this.view.settings.slice().sort((a: BusinessSetting, b: BusinessSetting): number => compareText(a.key, b.key))); }
        return await readRows<BusinessSetting>(this.store, `SELECT payload FROM ${T_SETTINGS} ORDER BY setting_key ASC`);
      },
      async (suggestionId: Id): Promise<SuggestionFeedbackEntry | null> => {
        this.ensureActive();
        if (this.view !== null) { return copyValue(this.view.feedback.find((item: SuggestionFeedbackEntry): boolean => item.suggestionId === suggestionId) ?? null); }
        return await readOne<SuggestionFeedbackEntry>(this.store, `SELECT payload FROM ${T_FEEDBACK} WHERE suggestion_id=?`, [suggestionId]);
      },
      async (): Promise<SuggestionFeedbackEntry[]> => {
        this.ensureActive();
        if (this.view !== null) { return copyValue(this.view.feedback.slice().sort((a: SuggestionFeedbackEntry, b: SuggestionFeedbackEntry): number => compareText(a.suggestionId, b.suggestionId))); }
        return await readRows<SuggestionFeedbackEntry>(this.store, `SELECT payload FROM ${T_FEEDBACK} ORDER BY suggestion_id ASC`);
      },
      async (setting: BusinessSetting): Promise<void> => {
        this.ensureActive();
        validateSetting(setting);
        validateJson(setting.valueJson);
        const current: BusinessSetting | null = await this.metadata.getSetting(setting.key);
        if (current === null) {
          await insertPayload(this.store, T_SETTINGS, ['setting_key','updated_at','payload'],
            [setting.key, setting.updatedAt, JSON.stringify(setting)]);
        } else {
          await this.store.executeSql(`UPDATE ${T_SETTINGS} SET updated_at=?,payload=? WHERE setting_key=?`,
            [setting.updatedAt, JSON.stringify(setting), setting.key]);
        }
        if (this.view !== null) { this.view.settings = this.view.settings.filter((item: BusinessSetting): boolean => item.key !== setting.key); this.view.settings.push(copyValue(setting)); }
      },
      async (feedback: SuggestionFeedbackEntry): Promise<void> => {
        this.ensureActive();
        validateFeedback(feedback);
        const current: SuggestionFeedbackEntry | null = await this.metadata.getFeedback(feedback.suggestionId);
        if (current === null) {
          await insertPayload(this.store, T_FEEDBACK, ['suggestion_id','updated_at','payload'],
            [feedback.suggestionId, feedback.updatedAt, JSON.stringify(feedback)]);
        } else {
          await this.store.executeSql(`UPDATE ${T_FEEDBACK} SET updated_at=?,payload=? WHERE suggestion_id=?`,
            [feedback.updatedAt, JSON.stringify(feedback), feedback.suggestionId]);
        }
        if (this.view !== null) { this.view.feedback = this.view.feedback.filter((item: SuggestionFeedbackEntry): boolean => item.suggestionId !== feedback.suggestionId); this.view.feedback.push(copyValue(feedback)); }
      }
    );
    return repository;
  }
}

function ensureSnapshot(snapshot: DatabaseSnapshot): void {
  if (snapshot === null || !Array.isArray(snapshot.records) || !Array.isArray(snapshot.ledgerEntries) ||
    !Array.isArray(snapshot.taskRewardStates) || !Array.isArray(snapshot.redemptions) ||
    !Array.isArray(snapshot.operations) || !Array.isArray(snapshot.settings) || !Array.isArray(snapshot.feedback)) {
    throw fail(ErrorCode.BACKUP_INVALID, '数据库快照结构无效。');
  }
  for (let i: number = 0; i < snapshot.records.length; i++) {
    const record: BehaviorRecord = snapshot.records[i];
    if (record === null || typeof record.id !== 'string' || record.id.length === 0 ||
      typeof record.createdByRequestId !== 'string' || record.createdByRequestId.length === 0 ||
      !isValidLocalDate(record.businessDate) || !Number.isSafeInteger(record.createdAt) ||
      !Number.isSafeInteger(record.updatedAt) || !Number.isSafeInteger(record.reductionGrams) ||
      (record.status !== RecordStatus.ACTIVE && record.status !== RecordStatus.VOIDED)) {
      throw fail(ErrorCode.BACKUP_INVALID, '快照中的行为记录无效。');
    }
  }
  for (let i: number = 0; i < snapshot.ledgerEntries.length; i++) {
    const entry: PointLedgerEntry = snapshot.ledgerEntries[i];
    if (entry === null || typeof entry.id !== 'string' || entry.id.length === 0 ||
      typeof entry.sourceKey !== 'string' || entry.sourceKey.length === 0 ||
      !Number.isSafeInteger(entry.delta) || !Number.isSafeInteger(entry.createdAt)) {
      throw fail(ErrorCode.BACKUP_INVALID, '快照中的积分流水无效。');
    }
  }
  for (let i: number = 0; i < snapshot.settings.length; i++) {
    const setting: BusinessSetting = snapshot.settings[i];
    if (setting === null || typeof setting.key !== 'string' || setting.key.length === 0 ||
      !Number.isSafeInteger(setting.updatedAt)) {
      throw fail(ErrorCode.BACKUP_INVALID, '快照中的业务设置无效。');
    }
    try {
      JSON.parse(setting.valueJson);
    } catch (_) {
      throw fail(ErrorCode.BACKUP_INVALID, '快照中的业务设置JSON无效。');
    }
  }
}

function ensureUnique(values: string[], name: string): void {
  const seen: Set<string> = new Set<string>();
  for (let i: number = 0; i < values.length; i++) {
    if (seen.has(values[i])) {
      throw fail(ErrorCode.BACKUP_INVALID, `快照存在重复${name}。`);
    }
    seen.add(values[i]);
  }
}

function validateJson(value: string): void {
  try {
    JSON.parse(value);
  } catch (_) {
    throw fail(ErrorCode.INVALID_INPUT, '业务设置必须是合法JSON。');
  }
}

class SerialQueue {
  private tail: Promise<void> = Promise.resolve();

  async run<T>(work: () => Promise<T>): Promise<T> {
    const result: Promise<T> = this.tail.then(async (): Promise<T> => await work());
    this.tail = result.then((): void => {}, (): void => {});
    return await result;
  }
}

export class RdbPersistenceGateway implements PersistenceGateway {
  readonly read: ReadRepository;
  private readonly store: relationalStore.RdbStore;
  private readonly queue: SerialQueue = new SerialQueue();
  private static readonly openPaths: Set<string> = new Set<string>();
  private readonly pathKey: string;
  private closed: boolean = false;
  private poisoned: boolean = false;

  private constructor(store: relationalStore.RdbStore, pathKey: string) {
    this.store = store;
    this.pathKey = pathKey;
    this.read = this.createReadRepository();
  }

  private ensureOpen(): void {
    if (this.closed || this.poisoned) {
      throw fail(ErrorCode.STORAGE_FAILED, '数据库已关闭或需要重新打开。');
    }
  }

  static async open(context: common.Context, databaseName: string = DATABASE_NAME): Promise<RdbPersistenceGateway> {
    if (!/^[A-Za-z0-9_.-]+$/.test(databaseName) || !databaseName.endsWith('.db')) {
      throw fail(ErrorCode.INVALID_INPUT, '数据库名称无效。');
    }
    const pathKey: string = `${context.databaseDir}/${databaseName}`;
    if (RdbPersistenceGateway.openPaths.has(pathKey)) {
      throw fail(ErrorCode.STORAGE_FAILED, '同一数据库已有打开或初始化中的网关。');
    }
    RdbPersistenceGateway.openPaths.add(pathKey);
    let store: relationalStore.RdbStore | undefined = undefined;
    try {
      store = await relationalStore.getRdbStore(context, {
        name: databaseName,
        securityLevel: relationalStore.SecurityLevel.S1,
        allowRebuild: false
      });
      await initializeSchema(store);
      return new RdbPersistenceGateway(store, pathKey);
    } catch (error) {
      RdbPersistenceGateway.openPaths.delete(pathKey);
      if (store !== undefined) {
        try {
          await store.close();
        } catch (_) {
          // Preserve the open/migration failure.
        }
      }
      throw mapStorageError(error as Object);
    }
  }

  async close(): Promise<void> {
    await this.queue.run(async (): Promise<void> => {
      if (this.closed) {
        return;
      }
      try {
        await this.store.close();
        this.closed = true;
        RdbPersistenceGateway.openPaths.delete(this.pathKey);
      } catch (error) {
        this.poisoned = true;
        throw mapStorageError(error as Object);
      }
    });
  }

  async runInTransaction<T>(work: (tx: TransactionContext) => Promise<T>): Promise<T> {
    return await this.queue.run(async (): Promise<T> => {
      this.ensureOpen();
      let tx: RdbTransactionContext | undefined = undefined;
      let committed: boolean = false;
      let began: boolean = false;
      try {
        // API 12 querySql can observe a different connection from executeSql. Keep a
        // transaction-local view so reads see successful writes until commit/rollback.
        const initial: DatabaseSnapshot = await new RdbTransactionContext(this.store).getFullSnapshot();
        this.store.beginTransaction();
        began = true;
        tx = new RdbTransactionContext(this.store, initial);
        const result: T = await work(tx);
        this.store.commit();
        committed = true;
        tx.deactivate();
        return result;
      } catch (error) {
        if (tx !== undefined) {
          tx.deactivate();
        }
        if (began && !committed) {
          try {
            this.store.rollBack();
          } catch (_) {
            this.poisoned = true;
            throw fail(ErrorCode.STORAGE_FAILED, '事务回滚失败，数据库已暂停使用。');
          }
        }
        throw mapStorageError(error as Object);
      }
    });
  }

  private createReadRepository(): ReadRepository {
    const guard = async <T>(work: () => Promise<T>): Promise<T> => {
      return await this.queue.run(async (): Promise<T> => {
        this.ensureOpen();
        let began: boolean = false;
        let committed: boolean = false;
        try {
          this.store.beginTransaction();
          began = true;
          const result: T = await work();
          this.store.commit();
          committed = true;
          return result;
        } catch (error) {
          throw mapStorageError(error as Object);
        } finally {
          if (began && !committed) {
            try {
              this.store.rollBack();
            } catch (_) {
              this.poisoned = true;
              throw fail(ErrorCode.STORAGE_FAILED, '读取事务回滚失败，数据库已暂停使用。');
            }
          }
        }
      });
    };
    const records: RecordReadRepository = new M03RepositoryAdapter8(
      async (id: Id): Promise<BehaviorRecord | null> => await guard(async () => await buildRecordRepository(this.store).getById(id)),
      async (query: RecordQuery): Promise<RecordPage> => await guard(async () => await buildRecordRepository(this.store).list(query)),
      async (filter: RecordFilter): Promise<BehaviorRecord[]> => await guard(async () => await buildRecordRepository(this.store).getActiveSnapshot(filter))
    );

    const taskStates: TaskStateReadRepository = new M03RepositoryAdapter9(
      async (taskId: Id, periodKey: string): Promise<TaskRewardState | null> => await guard(async () => await readOne<TaskRewardState>(this.store,
        `SELECT payload FROM ${T_TASKS} WHERE task_id=? AND period_key=?`, [taskId, periodKey])),
      async (periodKey: string): Promise<TaskRewardState[]> => await guard(async () => await readRows<TaskRewardState>(this.store,
        `SELECT payload FROM ${T_TASKS} WHERE period_key=? ORDER BY task_id ASC`, [periodKey]))
    );

    const points: PointsReadRepository = new M03RepositoryAdapter10(
      async (): Promise<number> => await guard(async () => {
        return await sumLedger(this.store);
      }),
      async (offset: number, limit: number): Promise<PointLedgerEntry[]> => await guard(async () => {
        validatePage(offset, limit);
        return await readRows<PointLedgerEntry>(this.store,
          `SELECT payload FROM ${T_LEDGER} ORDER BY created_at DESC, id ASC LIMIT ? OFFSET ?`, [limit, offset]);
      }),
      async (sourceKey: string): Promise<PointLedgerEntry | null> => await guard(async () => await readOne<PointLedgerEntry>(this.store,
        `SELECT payload FROM ${T_LEDGER} WHERE source_key=?`, [sourceKey]))
    );

    const redemptions: RedemptionReadRepository = new M03RepositoryAdapter11(
      async (rewardId: Id): Promise<Redemption | null> => await guard(async () => await readOne<Redemption>(this.store,
        `SELECT payload FROM ${T_REDEMPTIONS} WHERE reward_id=?`, [rewardId])),
      async (): Promise<Redemption[]> => await guard(async () => await readRows<Redemption>(this.store,
        `SELECT payload FROM ${T_REDEMPTIONS} ORDER BY created_at DESC, id ASC`))
    );

    const operations: OperationReadRepository = new M03RepositoryAdapter12(
      async (requestId: RequestId): Promise<IdempotencyOperation | null> => await guard(async () => await readOne<IdempotencyOperation>(this.store,
        `SELECT payload FROM ${T_OPERATIONS} WHERE request_id=?`, [requestId]))
    );

    const metadata: MetadataReadRepository = new M03RepositoryAdapter13(
      async (key: string): Promise<BusinessSetting | null> => await guard(async () => await readOne<BusinessSetting>(this.store,
        `SELECT payload FROM ${T_SETTINGS} WHERE setting_key=?`, [key])),
      async (): Promise<BusinessSetting[]> => await guard(async () => await readRows<BusinessSetting>(this.store,
        `SELECT payload FROM ${T_SETTINGS} ORDER BY setting_key ASC`)),
      async (id: Id): Promise<SuggestionFeedbackEntry | null> => await guard(async () => await readOne<SuggestionFeedbackEntry>(this.store,
        `SELECT payload FROM ${T_FEEDBACK} WHERE suggestion_id=?`, [id])),
      async (): Promise<SuggestionFeedbackEntry[]> => await guard(async () => await readRows<SuggestionFeedbackEntry>(this.store,
        `SELECT payload FROM ${T_FEEDBACK} ORDER BY suggestion_id ASC`))
    );

    const repository: ReadRepository = new M03RepositoryAdapter14(
      records,
      taskStates,
      points,
      redemptions,
      operations,
      metadata,
      async (): Promise<DatabaseSnapshot> => await guard(async (): Promise<DatabaseSnapshot> => {
        const tx: RdbTransactionContext = new RdbTransactionContext(this.store);
        try {
          return await tx.getFullSnapshot();
        } finally {
          tx.deactivate();
        }
      })
    );
    return repository;
  }
}
