import { Id, RequestId, TimestampMs } from './Common';
import { BehaviorRecord, RecordFilter, RecordPage, RecordQuery } from './Records';
import { PointLedgerEntry, Redemption, TaskProgress, TaskRewardState } from './Engagement';
import { BusinessSetting, SuggestionFeedbackEntry } from './Content';
import { RestoreSummary } from './Backup';

export enum OperationType {
  CREATE_RECORD = 'create_record',
  UPDATE_RECORD = 'update_record',
  VOID_RECORD = 'void_record',
  CLAIM_TASK = 'claim_task',
  REDEEM_REWARD = 'redeem_reward',
  RESTORE_BACKUP = 'restore_backup'
}

export enum OperationStatus {
  COMMITTED = 'committed'
}

export interface OperationResult {
  record: BehaviorRecord | null;
  taskProgress: TaskProgress | null;
  redemption: Redemption | null;
  restoreSummary: RestoreSummary | null;
}

export interface IdempotencyOperation {
  requestId: RequestId;
  operationType: OperationType;
  inputFingerprint: string;
  status: OperationStatus;
  result: OperationResult;
  committedAt: TimestampMs;
}

export interface DatabaseSnapshot {
  schemaVersion: number;
  records: BehaviorRecord[];
  ledgerEntries: PointLedgerEntry[];
  taskRewardStates: TaskRewardState[];
  redemptions: Redemption[];
  operations: IdempotencyOperation[];
  settings: BusinessSetting[];
  feedback: SuggestionFeedbackEntry[];
}

export interface BackupDocument extends DatabaseSnapshot {
  appVersion: string;
  exportedAt: TimestampMs;
}

export interface RecordReadRepository {
  getById(recordId: Id): Promise<BehaviorRecord | null>;
  list(query: RecordQuery): Promise<RecordPage>;
  getActiveSnapshot(filter: RecordFilter): Promise<BehaviorRecord[]>;
}

export interface RecordWriteRepository extends RecordReadRepository {
  insert(record: BehaviorRecord): Promise<void>;
  update(record: BehaviorRecord): Promise<void>;
  voidRecord(recordId: Id, updatedAt: TimestampMs): Promise<void>;
}

export interface TaskStateReadRepository {
  get(taskId: Id, periodKey: string): Promise<TaskRewardState | null>;
  listForPeriod(periodKey: string): Promise<TaskRewardState[]>;
}

export interface TaskStateWriteRepository extends TaskStateReadRepository {
  insert(state: TaskRewardState): Promise<void>;
  update(state: TaskRewardState): Promise<void>;
}

export interface PointsReadRepository {
  getBalance(): Promise<number>;
  listLedger(offset: number, limit: number): Promise<PointLedgerEntry[]>;
  getBySourceKey(sourceKey: string): Promise<PointLedgerEntry | null>;
}

export interface PointsWriteRepository extends PointsReadRepository {
  insert(entry: PointLedgerEntry): Promise<void>;
}

export interface RedemptionReadRepository {
  getByRewardId(rewardId: Id): Promise<Redemption | null>;
  list(): Promise<Redemption[]>;
}

export interface RedemptionWriteRepository extends RedemptionReadRepository {
  insert(redemption: Redemption): Promise<void>;
}

export interface OperationReadRepository {
  getByRequestId(requestId: RequestId): Promise<IdempotencyOperation | null>;
}

export interface OperationWriteRepository extends OperationReadRepository {
  insert(operation: IdempotencyOperation): Promise<void>;
}

export interface MetadataReadRepository {
  getSetting(key: string): Promise<BusinessSetting | null>;
  listSettings(): Promise<BusinessSetting[]>;
  getFeedback(suggestionId: Id): Promise<SuggestionFeedbackEntry | null>;
  listFeedback(): Promise<SuggestionFeedbackEntry[]>;
}

export interface MetadataWriteRepository extends MetadataReadRepository {
  putSetting(setting: BusinessSetting): Promise<void>;
  putFeedback(feedback: SuggestionFeedbackEntry): Promise<void>;
}

export interface ReadRepository {
  records: RecordReadRepository;
  taskStates: TaskStateReadRepository;
  points: PointsReadRepository;
  redemptions: RedemptionReadRepository;
  operations: OperationReadRepository;
  metadata: MetadataReadRepository;
  getFullSnapshot(): Promise<DatabaseSnapshot>;
}

export interface TransactionContext {
  records: RecordWriteRepository;
  taskStates: TaskStateWriteRepository;
  points: PointsWriteRepository;
  redemptions: RedemptionWriteRepository;
  operations: OperationWriteRepository;
  metadata: MetadataWriteRepository;
  getFullSnapshot(): Promise<DatabaseSnapshot>;
  replaceAll(snapshot: DatabaseSnapshot): Promise<void>;
}

export interface PersistenceGateway {
  read: ReadRepository;
  runInTransaction<T>(work: (tx: TransactionContext) => Promise<T>): Promise<T>;
}
