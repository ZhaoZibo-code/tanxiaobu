import { BackupDocument, IdempotencyOperation, OperationStatus, OperationType, PersistenceGateway } from '../../common/contracts/Persistence';
import { RestoreSummary } from '../../common/contracts/Backup';
import { AppServices } from '../../common/contracts/Services';
import { AppError, ErrorCode } from '../../common/errors/AppError';
import { validateBackupDocument } from './BackupValidation';

export function priorResult(operation: IdempotencyOperation, digest: string): RestoreSummary {
  if (operation.operationType !== OperationType.RESTORE_BACKUP || operation.inputFingerprint !== digest || operation.result.restoreSummary === null) {
    throw new AppError(ErrorCode.IDEMPOTENCY_CONFLICT, '请求标识已用于其他操作。');
  }
  return operation.result.restoreSummary;
}

export async function restoreSnapshot(gateway: PersistenceGateway, services: AppServices,
  document: BackupDocument, digest: string, requestId: string): Promise<RestoreSummary> {
  if (!/^[0-9a-f]{64}$/.test(digest) || requestId.length === 0) {
    throw new AppError(ErrorCode.INVALID_INPUT, '恢复请求无效。');
  }
  const previous = await gateway.read.operations.getByRequestId(requestId);
  if (previous !== null) { return priorResult(previous, digest); }
  validateBackupDocument(document);
  if (document.operations.some((op: IdempotencyOperation): boolean => op.requestId === requestId)) {
    throw new AppError(ErrorCode.IDEMPOTENCY_CONFLICT, '备份中已包含相同的请求标识。');
  }
  const balance = document.ledgerEntries.reduce((total: number, entry): number => total + entry.delta, 0);
  const summary: RestoreSummary = { recordCount: document.records.length, ledgerEntryCount: document.ledgerEntries.length,
    taskStateCount: document.taskRewardStates.length, redemptionCount: document.redemptions.length,
    settingCount: document.settings.length, feedbackCount: document.feedback.length,
    operationCount: document.operations.length + 1, finalPointsBalance: balance };
  let changed = false;
  const result = await gateway.runInTransaction(async tx => {
    const prior = await tx.operations.getByRequestId(requestId);
    if (prior !== null) { return priorResult(prior, digest); }
    await tx.replaceAll(document);
    await tx.operations.insert({ requestId: requestId, operationType: OperationType.RESTORE_BACKUP,
      inputFingerprint: digest, status: OperationStatus.COMMITTED, committedAt: services.clock.nowMs(),
      result: { record: null, taskProgress: null, redemption: null, restoreSummary: summary } });
    changed = true;
    return summary;
  });
  if (changed) { services.changes.notifyDataChanged(); }
  return result;
}
