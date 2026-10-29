import { BackupDocument } from '../../common/contracts/Persistence';
import { BehaviorRecord, RecordStatus } from '../../common/contracts/Records';
import { PointLedgerEntry, PointReason, Redemption, TaskRewardState } from '../../common/contracts/Engagement';
import { BusinessSetting, SuggestionFeedbackEntry } from '../../common/contracts/Content';
import { IdempotencyOperation, OperationType } from '../../common/contracts/Persistence';
import { AppError, ErrorCode } from '../../common/errors/AppError';
import { SCHEMA_VERSION } from '../../data/persistence/RdbSchema';
import { validateRecord, validateLedger, validateTaskState, validateRedemption, validateOperation,
  validateSetting, validateFeedback } from '../../data/persistence/Validation';

function invalid(): never { throw new AppError(ErrorCode.BACKUP_INVALID, '备份数据不完整或格式无效。'); }
function unique(values: string[]): void {
  const seen: Set<string> = new Set<string>();
  for (const value of values) { if (seen.has(value)) { invalid(); } seen.add(value); }
}

function validateBackupRecord(item: BehaviorRecord): void {
  validateRecord(item);
  const rule = item.factorSnapshot.rule;
  if (item.category !== rule.category || item.unit !== rule.inputUnit || item.quantity < rule.minQuantity ||
    item.quantity > rule.maxQuantity) { invalid(); }
}

// Validation is read-only; file digest and restore must use the same bytes separately.
export function validateBackupDocument(document: BackupDocument): void {
  if (document === null || document === undefined || !Number.isSafeInteger(document.schemaVersion)) { invalid(); }
  if (document.schemaVersion !== SCHEMA_VERSION) {
    throw new AppError(ErrorCode.BACKUP_VERSION_UNSUPPORTED, '备份版本不兼容。');
  }
  if (typeof document.appVersion !== 'string' || document.appVersion.length === 0 ||
    !Number.isSafeInteger(document.exportedAt) || document.exportedAt < 0 ||
    !Array.isArray(document.records) || !Array.isArray(document.ledgerEntries) ||
    !Array.isArray(document.taskRewardStates) || !Array.isArray(document.redemptions) ||
    !Array.isArray(document.operations) || !Array.isArray(document.settings) || !Array.isArray(document.feedback)) { invalid(); }
  try {
    document.records.forEach((item: BehaviorRecord) => validateBackupRecord(item));
    document.ledgerEntries.forEach((item: PointLedgerEntry) => validateLedger(item));
    document.taskRewardStates.forEach((item: TaskRewardState) => validateTaskState(item));
    document.redemptions.forEach((item: Redemption) => validateRedemption(item));
    document.operations.forEach((item: IdempotencyOperation) => validateOperation(item));
    document.settings.forEach((item: BusinessSetting) => validateSetting(item));
    document.feedback.forEach((item: SuggestionFeedbackEntry) => validateFeedback(item));
    unique(document.records.map((item: BehaviorRecord): string => item.id));
    unique(document.records.map((item: BehaviorRecord): string => item.createdByRequestId));
    unique(document.ledgerEntries.map((item: PointLedgerEntry): string => item.id));
    unique(document.ledgerEntries.map((item: PointLedgerEntry): string => item.sourceKey));
    unique(document.taskRewardStates.map((item: TaskRewardState): string => JSON.stringify([item.taskId, item.periodKey])));
    unique(document.redemptions.map((item: Redemption): string => item.id));
    unique(document.redemptions.map((item: Redemption): string => item.rewardId));
    unique(document.redemptions.map((item: Redemption): string => item.requestId));
    unique(document.operations.map((item: IdempotencyOperation): string => item.requestId));
    unique(document.settings.map((item: BusinessSetting): string => item.key));
    unique(document.feedback.map((item: SuggestionFeedbackEntry): string => item.suggestionId));
    let balance = 0;
    for (const entry of document.ledgerEntries) {
      balance += entry.delta;
      if (!Number.isSafeInteger(balance)) { invalid(); }
      if (entry.relatedRecordId !== null && !document.records.some((record: BehaviorRecord): boolean => record.id === entry.relatedRecordId)) { invalid(); }
      if (entry.relatedTaskId !== null && !document.taskRewardStates.some((state: TaskRewardState): boolean =>
        state.taskId === entry.relatedTaskId && state.periodKey === entry.periodKey)) { invalid(); }
    }
    for (const state of document.taskRewardStates) {
      let total = 0;
      for (const entry of document.ledgerEntries) {
        if (entry.relatedTaskId === state.taskId && entry.periodKey === state.periodKey) {
          if (entry.reason !== PointReason.TASK_REWARD && entry.reason !== PointReason.REVOCATION_ADJUSTMENT) { invalid(); }
          total += entry.delta;
          if (!Number.isSafeInteger(total)) { invalid(); }
        }
      }
      if (total !== state.netGrantedPoints || (!state.everClaimed && total !== 0)) { invalid(); }
    }
    for (const redemption of document.redemptions) {
      const matching = document.ledgerEntries.filter((entry: PointLedgerEntry): boolean =>
        entry.sourceKey === `redeem:${redemption.rewardId}` && entry.reason === PointReason.REDEMPTION &&
          entry.delta === -redemption.costPoints);
      const operation = document.operations.find((item: IdempotencyOperation): boolean => item.requestId === redemption.requestId);
      if (matching.length !== 1 || operation === undefined || operation.result.redemption === null ||
        operation.result.redemption.id !== redemption.id || operation.result.redemption.rewardId !== redemption.rewardId) { invalid(); }
    }
    for (const entry of document.ledgerEntries) {
      if (entry.reason === PointReason.REDEMPTION && !document.redemptions.some((item: Redemption): boolean =>
        entry.sourceKey === `redeem:${item.rewardId}` && entry.delta === -item.costPoints)) { invalid(); }
    }
    for (const operation of document.operations) {
      if (operation.operationType === OperationType.CREATE_RECORD || operation.operationType === OperationType.UPDATE_RECORD) {
        const historical = operation.result.record;
        if (historical === null || !document.records.some((record: BehaviorRecord): boolean =>
          record.id === historical.id && record.createdByRequestId === historical.createdByRequestId && record.createdAt === historical.createdAt)) { invalid(); }
        validateBackupRecord(historical);
        if (operation.operationType === OperationType.CREATE_RECORD && operation.requestId !== historical.createdByRequestId) { invalid(); }
      }
      if (operation.operationType === OperationType.VOID_RECORD) {
        const input = JSON.parse(operation.inputFingerprint) as string[];
        if (!Array.isArray(input) || input.length !== 1 || typeof input[0] !== 'string' ||
          !document.records.some((record: BehaviorRecord): boolean => record.id === input[0] && record.status === RecordStatus.VOIDED)) { invalid(); }
      }
      if (operation.operationType === OperationType.CLAIM_TASK) {
        const progress = operation.result.taskProgress;
        if (progress === null || progress.definition === null || progress.definition === undefined ||
          !document.taskRewardStates.some((state: TaskRewardState): boolean => state.taskId === progress.definition.id &&
            state.periodKey === progress.periodKey && state.everClaimed)) { invalid(); }
      }
      if (operation.operationType === OperationType.REDEEM_REWARD) {
        const saved = operation.result.redemption;
        if (saved === null || !document.redemptions.some((item: Redemption): boolean =>
          item.id === saved.id && item.requestId === operation.requestId && item.rewardId === saved.rewardId)) { invalid(); }
      }
    }
  } catch (_) { invalid(); }
}
