import { describe, it, expect } from '@ohos/hypium';
import { BackupDocument } from '../../main/ets/common/contracts/Persistence';
import { PointReason } from '../../main/ets/common/contracts/Engagement';
import { ErrorCode, AppError } from '../../main/ets/common/errors/AppError';
import { validateBackupDocument } from '../../main/ets/features/dataTransfer/BackupValidation';

function empty(): BackupDocument {
  return { schemaVersion: 1, appVersion: '0.1.0', exportedAt: 10, records: [], ledgerEntries: [],
    taskRewardStates: [], redemptions: [], operations: [], settings: [], feedback: [] };
}
function errorCode(document: BackupDocument): string {
  try { validateBackupDocument(document); return ''; } catch (error) { return (error as AppError).code; }
}
export default function backupValidationTest(): void {
  describe('BackupValidation', () => {
    it('acceptsEmptyAndRejectsUnsupportedVersion', 0, () => {
      const document = empty(); expect(errorCode(document)).assertEqual('');
      document.schemaVersion = 99; expect(errorCode(document)).assertEqual(ErrorCode.BACKUP_VERSION_UNSUPPORTED);
    });
    it('rejectsDuplicateSettingsAndMalformedJson', 0, () => {
      const document = empty();
      document.settings = [{key: 'a', valueJson: '1', updatedAt: 1}, {key: 'a', valueJson: '2', updatedAt: 2}];
      expect(errorCode(document)).assertEqual(ErrorCode.BACKUP_INVALID);
      document.settings = [{key: 'a', valueJson: '{', updatedAt: 1}];
      expect(errorCode(document)).assertEqual(ErrorCode.BACKUP_INVALID);
    });
    it('rejectsOrphanedLedgerReferencesAndOverflow', 0, () => {
      const document = empty();
      document.ledgerEntries = [{ id: 'a', delta: 1, reason: PointReason.REVOCATION_ADJUSTMENT,
        sourceKey: 'a', relatedRecordId: 'missing', relatedTaskId: null, periodKey: null, createdAt: 1 }];
      expect(errorCode(document)).assertEqual(ErrorCode.BACKUP_INVALID);
      document.ledgerEntries[0].relatedRecordId = null;
      document.ledgerEntries[0].delta = Number.MAX_SAFE_INTEGER;
      document.ledgerEntries.push({ id: 'b', delta: 1, reason: PointReason.REDEMPTION,
        sourceKey: 'b', relatedRecordId: null, relatedTaskId: null, periodKey: null, createdAt: 1 });
      expect(errorCode(document)).assertEqual(ErrorCode.BACKUP_INVALID);
    });
  });
}
