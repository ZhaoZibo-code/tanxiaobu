import { CalculationInput } from '../../common/contracts/Calculation';
import { AppServices, RecordService } from '../../common/contracts/Services';
import { BehaviorRecord, RecordPage, RecordQuery, RecordStatus } from '../../common/contracts/Records';
import { IdempotencyOperation, OperationStatus, OperationType, PersistenceGateway } from '../../common/contracts/Persistence';
import { AppError, ErrorCode } from '../../common/errors/AppError';
import { applyTaskAdjustments, planTaskAdjustments } from './TaskReconciliation';

export class RecordServiceImpl implements RecordService {
  private readonly gateway: PersistenceGateway;
  private readonly services: AppServices;

  constructor(gateway: PersistenceGateway, services: AppServices) {
    this.gateway = gateway;
    this.services = services;
  }

  async create(input: CalculationInput, requestId: string): Promise<BehaviorRecord> {
    if (typeof requestId !== 'string' || requestId.length === 0) {
      throw new AppError(ErrorCode.INVALID_INPUT, '请求标识不能为空。');
    }
    const fingerprint = JSON.stringify([input.ruleId, input.quantity, input.unit, input.businessDate,
      input.note.trim(), input.baselineConfirmed]);
    const existing = await this.gateway.read.operations.getByRequestId(requestId);
    if (existing !== null) {
      return this.recordFromOperation(existing, fingerprint, OperationType.CREATE_RECORD);
    }
    const preview = await this.services.calculation.preview(input);
    const now = this.services.clock.nowMs();
    const record: BehaviorRecord = {
      id: this.services.ids.newId(), createdByRequestId: requestId,
      businessDate: preview.input.businessDate, category: preview.category,
      ruleId: preview.factorSnapshot.rule.id, ruleVersion: preview.factorSnapshot.rule.version,
      quantity: preview.input.quantity, unit: preview.input.unit, note: preview.input.note,
      baselineConfirmed: preview.input.baselineConfirmed, reductionGrams: preview.reductionGrams,
      formulaText: preview.formulaText, factorSnapshot: preview.factorSnapshot,
      createdAt: now, updatedAt: now, status: RecordStatus.ACTIVE
    };
    let inserted = false;
    const result = await this.gateway.runInTransaction(async (tx): Promise<BehaviorRecord> => {
      const prior = await tx.operations.getByRequestId(requestId);
      if (prior !== null) {
        return this.recordFromOperation(prior, fingerprint, OperationType.CREATE_RECORD);
      }
      const adjustments = await planTaskAdjustments(tx, null, record, this.services, now);
      await tx.records.insert(record);
      await applyTaskAdjustments(tx, adjustments);
      await tx.operations.insert({ requestId: requestId, operationType: OperationType.CREATE_RECORD,
        inputFingerprint: fingerprint, status: OperationStatus.COMMITTED,
        result: { record: record, taskProgress: null, redemption: null, restoreSummary: null }, committedAt: now });
      inserted = true;
      return record;
    });
    if (inserted) {
      this.services.changes.notifyDataChanged();
    }
    return result;
  }

  private recordFromOperation(operation: IdempotencyOperation, fingerprint: string, type: OperationType): BehaviorRecord {
    if (operation.operationType !== type || operation.inputFingerprint !== fingerprint ||
      operation.result.record === null) {
      throw new AppError(ErrorCode.IDEMPOTENCY_CONFLICT, '请求标识已用于其他操作。');
    }
    return operation.result.record;
  }

  async getById(recordId: string): Promise<BehaviorRecord> {
    const record = await this.gateway.read.records.getById(recordId);
    if (record === null) {
      throw new AppError(ErrorCode.RECORD_NOT_FOUND, '记录不存在。');
    }
    return record;
  }

  async list(query: RecordQuery): Promise<RecordPage> {
    return await this.gateway.read.records.list(query);
  }

  async update(recordId: string, input: CalculationInput, requestId: string): Promise<BehaviorRecord> {
    if (typeof requestId !== 'string' || requestId.length === 0 || recordId.length === 0) {
      throw new AppError(ErrorCode.INVALID_INPUT, '记录或请求标识不能为空。');
    }
    const fingerprint = JSON.stringify([recordId, input.ruleId, input.quantity, input.unit, input.businessDate,
      input.note.trim(), input.baselineConfirmed]);
    const existing = await this.gateway.read.operations.getByRequestId(requestId);
    if (existing !== null) { return this.recordFromOperation(existing, fingerprint, OperationType.UPDATE_RECORD); }
    const preview = await this.services.calculation.preview(input);
    const now = this.services.clock.nowMs();
    let changed = false;
    const result = await this.gateway.runInTransaction(async (tx): Promise<BehaviorRecord> => {
      const prior = await tx.operations.getByRequestId(requestId);
      if (prior !== null) { return this.recordFromOperation(prior, fingerprint, OperationType.UPDATE_RECORD); }
      const current = await tx.records.getById(recordId);
      if (current === null || current.status !== RecordStatus.ACTIVE) {
        throw new AppError(ErrorCode.RECORD_NOT_FOUND, '记录不存在或已撤销。');
      }
      const updated: BehaviorRecord = { id: current.id, createdByRequestId: current.createdByRequestId,
        businessDate: preview.input.businessDate, category: preview.category, ruleId: preview.factorSnapshot.rule.id,
        ruleVersion: preview.factorSnapshot.rule.version, quantity: preview.input.quantity, unit: preview.input.unit,
        note: preview.input.note, baselineConfirmed: preview.input.baselineConfirmed, reductionGrams: preview.reductionGrams,
        formulaText: preview.formulaText, factorSnapshot: preview.factorSnapshot, createdAt: current.createdAt,
        updatedAt: now, status: RecordStatus.ACTIVE };
      const adjustments = await planTaskAdjustments(tx, current, updated, this.services, now);
      await tx.records.update(updated);
      await applyTaskAdjustments(tx, adjustments);
      await tx.operations.insert({ requestId: requestId, operationType: OperationType.UPDATE_RECORD,
        inputFingerprint: fingerprint, status: OperationStatus.COMMITTED,
        result: { record: updated, taskProgress: null, redemption: null, restoreSummary: null }, committedAt: now });
      changed = true;
      return updated;
    });
    if (changed) { this.services.changes.notifyDataChanged(); }
    return result;
  }

  async voidRecord(recordId: string, requestId: string): Promise<void> {
    if (typeof requestId !== 'string' || requestId.length === 0 || recordId.length === 0) {
      throw new AppError(ErrorCode.INVALID_INPUT, '记录或请求标识不能为空。');
    }
    const fingerprint = JSON.stringify([recordId]);
    const check = (operation: IdempotencyOperation): void => {
      if (operation.operationType !== OperationType.VOID_RECORD || operation.inputFingerprint !== fingerprint) {
        throw new AppError(ErrorCode.IDEMPOTENCY_CONFLICT, '请求标识已用于其他操作。');
      }
    };
    const existing = await this.gateway.read.operations.getByRequestId(requestId);
    if (existing !== null) { check(existing); return; }
    const now = this.services.clock.nowMs();
    let changed = false;
    await this.gateway.runInTransaction(async (tx): Promise<void> => {
      const prior = await tx.operations.getByRequestId(requestId);
      if (prior !== null) { check(prior); return; }
      const current = await tx.records.getById(recordId);
      if (current === null || current.status !== RecordStatus.ACTIVE) {
        throw new AppError(ErrorCode.RECORD_NOT_FOUND, '记录不存在或已撤销。');
      }
      const adjustments = await planTaskAdjustments(tx, current, null, this.services, now);
      await tx.records.voidRecord(recordId, now);
      await applyTaskAdjustments(tx, adjustments);
      await tx.operations.insert({ requestId: requestId, operationType: OperationType.VOID_RECORD,
        inputFingerprint: fingerprint, status: OperationStatus.COMMITTED,
        result: { record: null, taskProgress: null, redemption: null, restoreSummary: null }, committedAt: now });
      changed = true;
    });
    if (changed) { this.services.changes.notifyDataChanged(); }
  }
}
