import { describe, it, expect } from '@ohos/hypium';
import { validateBackupDocument } from '../../../../main/ets/features/dataTransfer/BackupValidation';
import { BackupDocument } from '../../../../main/ets/common/contracts/Persistence';
import relationalStore from '@ohos.data.relationalStore';
import fs from '@ohos.file.fs';
import { readBackupFile } from '../../../../main/ets/features/dataTransfer/BackupFileReader';
import common from '@ohos.app.ability.common';
import { Category, QuantityUnit } from '../../../../main/ets/common/contracts/Common';
import { CalculationMode, EvidenceStatus, FactorSnapshot } from '../../../../main/ets/common/contracts/Calculation';
import { BehaviorRecord, RecordStatus, RecordQuery } from '../../../../main/ets/common/contracts/Records';
import { PointLedgerEntry, PointReason, TaskRewardState, TaskPeriodType, TaskRuleType, Redemption, RewardType } from '../../../../main/ets/common/contracts/Engagement';
import { SuggestionFeedback } from '../../../../main/ets/common/contracts/Content';
import { DatabaseSnapshot, IdempotencyOperation, OperationStatus, OperationType } from '../../../../main/ets/common/contracts/Persistence';
import { RdbPersistenceGateway } from '../../../../main/ets/data/persistence/RdbPersistenceGateway';
import { migrateSchema, SCHEMA_VERSION } from '../../../../main/ets/data/persistence/RdbSchema';
import { AppError, ErrorCode } from '../../../../main/ets/common/errors/AppError';

const TEST_DATABASE: string = 'm03_rdb_integration_test.db';
const MIGRATION_FAILURE_DATABASE: string = 'm03_migration_failure_test.db';

let testAbilityContext: common.UIAbilityContext | undefined = undefined;

export function setRdbTestContext(context: common.UIAbilityContext): void {
  testAbilityContext = context;
}

function getRdbTestContext(): common.UIAbilityContext {
  if (testAbilityContext === undefined) {
    throw new Error('M03 test ability context is not initialized');
  }
  return testAbilityContext;
}

function emptySnapshot(): DatabaseSnapshot {
  return { schemaVersion: SCHEMA_VERSION, records: [], ledgerEntries: [], taskRewardStates: [],
    redemptions: [], operations: [], settings: [], feedback: [] };
}

function sampleRecord(id: string, requestId: string, businessDate: string, note: string): BehaviorRecord {
  const snapshot: FactorSnapshot = {
    rule: { id: 'fixture-rule', version: '1', category: Category.TRAVEL, name: '测试出行规则',
      inputUnit: QuantityUnit.KM, minQuantity: 0.1, maxQuantity: 100, mode: CalculationMode.DIRECT_REDUCTION,
      reductionFactorId: 'fixture-factor', baselineFactorId: null, actualFactorId: null,
      baselineLabel: '', actualLabel: '', assumptions: ['仅测试'], confirmationText: '' },
    factors: [{ id: 'fixture-factor', version: '1', name: '测试因子', unit: QuantityUnit.KM,
      gramsCo2ePerUnit: 10, originalValue: 10, originalUnit: 'g/km',
      source: { title: '测试', url: 'https://example.invalid', publisher: '测试', publishedDate: null,
        retrievedDate: '2026-10-28', region: '测试', boundary: '仅测试', notes: '' },
      assumptions: ['仅测试'], evidenceStatus: EvidenceStatus.DEVELOPMENT_FIXTURE }]
  };
  return { id, createdByRequestId: requestId, businessDate, category: Category.TRAVEL,
    ruleId: 'fixture-rule', ruleVersion: '1', quantity: 1, unit: QuantityUnit.KM, note,
    baselineConfirmed: true, reductionGrams: 10, formulaText: '测试', factorSnapshot: snapshot,
    createdAt: 1000, updatedAt: 1000, status: RecordStatus.ACTIVE };
}

function ledger(id: string, sourceKey: string, delta: number, createdAt: number): PointLedgerEntry {
  return { id, delta, reason: PointReason.TASK_REWARD, sourceKey, relatedRecordId: null,
    relatedTaskId: 'fixture-task', periodKey: '2026-10-28', createdAt };
}

async function openClean(): Promise<RdbPersistenceGateway> {
  const context = getRdbTestContext();
  const gateway = await RdbPersistenceGateway.open(context, TEST_DATABASE);
  await gateway.runInTransaction(async (tx): Promise<void> => {
    await tx.replaceAll(emptySnapshot());
  });
  return gateway;
}

export default function rdbPersistenceTest(): void {
  describe('M03NativeRdbPersistence', () => {
    it('readsValidBackupAndDetectsChangedContent', 0, async () => {
      const path = `${getRdbTestContext().filesDir}/backup-reader-test.json`;
      const file = await fs.open(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      const json = JSON.stringify({ schemaVersion: SCHEMA_VERSION, appVersion: '0.1.0', exportedAt: 10,
        records: [], ledgerEntries: [], taskRewardStates: [], redemptions: [], operations: [], settings: [], feedback: [] });
      try { await fs.write(file.fd, json); } finally { await fs.close(file); }
      try {
        const first = await readBackupFile(path);
        expect(first.digest).assertEqual('af88939cd3176284a663c899de2bcc92134b3563c04a5377dd2716b3b15ff4e2');
        expect(first.document.records.length).assertEqual(0);
        const changed = await fs.open(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        try { await fs.write(changed.fd, json.replace('0.1.0', '0.1.1')); } finally { await fs.close(changed); }
        const second = await readBackupFile(path);
        expect(first.digest !== second.digest).assertTrue();
        let changedCode = '';
        try { await readBackupFile(path, first.digest); } catch (error) { changedCode = (error as AppError).code; }
        expect(changedCode).assertEqual(ErrorCode.BACKUP_CHANGED);
        const broken = await fs.open(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        try { await fs.write(broken.fd, '{'); } finally { await fs.close(broken); }
        let invalid = false;
        try { await readBackupFile(path); } catch (error) { invalid = (error as AppError).code === ErrorCode.BACKUP_INVALID; }
        expect(invalid).assertTrue();
      } finally { await fs.unlink(path); }
    });

    it('validatesAnActualEmptySnapshotAsABackup', 0, async () => {
      const gateway = await openClean();
      try {
        const snapshot = await gateway.read.getFullSnapshot();
        const backup: BackupDocument = { schemaVersion: snapshot.schemaVersion, appVersion: '0.1.0', exportedAt: 1000,
          records: snapshot.records, ledgerEntries: snapshot.ledgerEntries, taskRewardStates: snapshot.taskRewardStates,
          redemptions: snapshot.redemptions, operations: snapshot.operations, settings: snapshot.settings, feedback: snapshot.feedback };
        validateBackupDocument(backup);
        expect(backup.records.length).assertEqual(0);
      } finally { await gateway.close(); }
    });

    it('persistsAcrossCloseAndReopenAndReturnsIsolatedSnapshots', 0, async () => {
      let gateway = await openClean();
      try {
        const saved = sampleRecord('record-reopen', 'request-reopen', '2024-12-31', 'persisted literal %_ token');
        await gateway.runInTransaction(async (tx): Promise<void> => {
          await tx.records.insert(saved);
          await tx.points.insert(ledger('ledger-reopen', 'source-reopen', 7, 10));
        });
        await gateway.close();
        gateway = await RdbPersistenceGateway.open(getRdbTestContext(), TEST_DATABASE);
        const loaded = await gateway.read.records.getById(saved.id);
        expect(loaded !== null).assertTrue();
        expect(JSON.stringify(loaded)).assertEqual(JSON.stringify(saved));
        expect(await gateway.read.points.getBalance()).assertEqual(7);
        if (loaded !== null) {
          loaded.note = 'mutated caller copy';
        }
        const unmodified = await gateway.read.records.getById(saved.id);
        expect(unmodified !== null).assertTrue();
        if (unmodified !== null) {
          expect(unmodified.note).assertEqual('persisted literal %_ token');
        }
      } finally {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(emptySnapshot()); });
        await gateway.close();
      }
    });

    it('commitsMultipleRepositoriesAndRollsBackEveryTableOnFailure', 0, async () => {
      const gateway = await openClean();
      try {
        const saved = sampleRecord('record-atomic', 'request-atomic', '2024-01-01', 'atomic');
        await gateway.runInTransaction(async (tx): Promise<void> => {
          await tx.records.insert(saved);
          await tx.points.insert(ledger('ledger-atomic', 'source-atomic', 9, 20));
          await tx.metadata.putSetting({ key: 'test.setting', valueJson: '{"a":1}', updatedAt: 30 });
        });
        expect((await gateway.read.records.getById(saved.id)) !== null).assertTrue();
        expect(await gateway.read.points.getBalance()).assertEqual(9);
        expect((await gateway.read.metadata.getSetting('test.setting')) !== null).assertTrue();

        let injected: boolean = false;
        try {
          await gateway.runInTransaction(async (tx): Promise<void> => {
            await tx.records.insert(sampleRecord('record-rollback', 'request-rollback', '2024-02-01', 'rollback'));
            await tx.points.insert(ledger('ledger-rollback', 'source-rollback', 99, 40));
            throw new Error('injected after both writes');
          });
        } catch (_) {
          injected = true;
        }
        expect(injected).assertTrue();
        expect(await gateway.read.records.getById('record-rollback')).assertEqual(null);
        expect(await gateway.read.points.getBySourceKey('source-rollback')).assertEqual(null);
        expect((await gateway.read.records.getById(saved.id)) !== null).assertTrue();
        expect(await gateway.read.points.getBalance()).assertEqual(9);
      } finally {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(emptySnapshot()); });
        await gateway.close();
      }
    });

    it('enforcesUniqueKeysAndSerializesConcurrentWrites', 0, async () => {
      const gateway = await openClean();
      try {
        const first = sampleRecord('record-unique', 'request-unique', '2026-10-28', 'first');
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.records.insert(first); });
        let duplicateRejected: boolean = false;
        try {
          await gateway.runInTransaction(async (tx): Promise<void> => {
            await tx.records.insert(sampleRecord('record-unique-2', 'request-unique', '2026-10-28', 'duplicate request'));
          });
        } catch (_) {
          duplicateRejected = true;
        }
        expect(duplicateRejected).assertTrue();

        await Promise.all([
          gateway.runInTransaction(async (tx): Promise<void> => { await tx.points.insert(ledger('concurrent-1', 'source-concurrent-1', 1, 50)); }),
          gateway.runInTransaction(async (tx): Promise<void> => { await tx.points.insert(ledger('concurrent-2', 'source-concurrent-2', 1, 50)); }),
          gateway.runInTransaction(async (tx): Promise<void> => { await tx.points.insert(ledger('concurrent-3', 'source-concurrent-3', 1, 50)); })
        ]);
        expect(await gateway.read.points.getBalance()).assertEqual(3);
        let duplicateSourceRejected: boolean = false;
        try {
          await gateway.runInTransaction(async (tx): Promise<void> => {
            await tx.points.insert(ledger('ledger-duplicate-source', 'source-concurrent-1', 50, 51));
          });
        } catch (_) {
          duplicateSourceRejected = true;
        }
        expect(duplicateSourceRejected).assertTrue();
        expect(await gateway.read.points.getBalance()).assertEqual(3);
        expect((await gateway.read.getFullSnapshot()).records.length).assertEqual(1);
      } finally {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(emptySnapshot()); });
        await gateway.close();
      }
    });

    it('usesLiteralKeywordAndHalfOpenDateAndStablePagination', 0, async () => {
      const gateway = await openClean();
      try {
        await gateway.runInTransaction(async (tx): Promise<void> => {
          await tx.records.insert(sampleRecord('r1', 'q1', '2023-12-31', '100%_literal'));
          await tx.records.insert(sampleRecord('r2', 'q2', '2024-01-01', '100xxliteral'));
          await tx.records.insert(sampleRecord('r3', 'q3', '2024-01-02', '100%_literal'));
          await tx.records.insert(sampleRecord('r5', 'q5', '2024-01-01', '100%_literal'));
          await tx.records.insert(sampleRecord('r4', 'q4', '2024-01-03', 'void me'));
          await tx.records.voidRecord('r4', 5000);
        });
        const query: RecordQuery = { startDateInclusive: '2024-01-01', endDateExclusive: '2024-01-03',
          category: null, keyword: '100%_literal', offset: 0, limit: 1 };
        const page = await gateway.read.records.list(query);
        expect(page.total).assertEqual(2);
        expect(page.items.length).assertEqual(1);
        expect(page.items[0].id).assertEqual('r3');
        const secondPage = await gateway.read.records.list({ startDateInclusive: query.startDateInclusive,
          endDateExclusive: query.endDateExclusive, category: query.category, keyword: query.keyword,
          offset: 1, limit: 1 });
        expect(secondPage.items[0].id).assertEqual('r5');
        const audit = await gateway.read.records.getById('r4');
        expect(audit !== null).assertTrue();
        if (audit !== null) {
          expect(audit.status).assertEqual(RecordStatus.VOIDED);
        }
        expect((await gateway.read.getFullSnapshot()).records.length).assertEqual(5);
      } finally {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(emptySnapshot()); });
        await gateway.close();
      }
    });

    it('storesAndReusesTheExactIdempotencyResultSlot', 0, async () => {
      const gateway = await openClean();
      try {
        const operation: IdempotencyOperation = { requestId: 'restore-request', operationType: OperationType.RESTORE_BACKUP,
          inputFingerprint: 'sha256:input', status: OperationStatus.COMMITTED, committedAt: 123,
          result: { record: null, taskProgress: null, redemption: null,
            restoreSummary: { recordCount: 2, ledgerEntryCount: 3, taskStateCount: 1, redemptionCount: 0,
              settingCount: 1, feedbackCount: 0, operationCount: 4, finalPointsBalance: 17 } } };
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.operations.insert(operation); });
        const original = await gateway.read.operations.getByRequestId(operation.requestId);
        expect(JSON.stringify(original)).assertEqual(JSON.stringify(operation));
        let conflict: boolean = false;
        try {
          await gateway.runInTransaction(async (tx): Promise<void> => {
            const changed: IdempotencyOperation = { requestId: operation.requestId, operationType: operation.operationType,
              inputFingerprint: 'different-input', status: OperationStatus.COMMITTED, committedAt: 456,
              result: { record: null, taskProgress: null, redemption: null, restoreSummary: null } };
            await tx.operations.insert(changed);
          });
        } catch (_) {
          conflict = true;
        }
        expect(conflict).assertTrue();
        expect(JSON.stringify(await gateway.read.operations.getByRequestId(operation.requestId)))
          .assertEqual(JSON.stringify(operation));
      } finally {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(emptySnapshot()); });
        await gateway.close();
      }
    });

    it('rollsBackActualDdlUpgradeFailureAndCanRetryWithoutLosingRows', 0, async () => {
      const context = getRdbTestContext();
      const store = await relationalStore.getRdbStore(context, {
        name: 'm03_upgrade_failure_test.db', securityLevel: relationalStore.SecurityLevel.S1, allowRebuild: false
      });
      try {
        await store.executeSql('CREATE TABLE IF NOT EXISTS preserved_rows (id TEXT PRIMARY KEY NOT NULL)');
        await store.executeSql('DELETE FROM preserved_rows');
        await store.executeSql('INSERT INTO preserved_rows(id) VALUES (?)', ['preserved']);
        store.version = 1;
        let rejected: boolean = false;
        try {
          await migrateSchema(store, { fromVersion: 1, toVersion: 2, statements: [
            'CREATE TABLE upgrade_temp (id TEXT PRIMARY KEY)',
            'INSERT INTO preserved_rows(id) VALUES (\'preserved\')'
          ] });
        } catch (_) {
          rejected = true;
        }
        expect(rejected).assertTrue();
        expect(store.version).assertEqual(1);
        const tables = await store.querySql('SELECT name FROM sqlite_master WHERE type=? AND name=?', ['table', 'upgrade_temp']);
        try {
          expect(tables.rowCount).assertEqual(0);
        } finally {
          tables.close();
        }
        await migrateSchema(store, { fromVersion: 1, toVersion: 2, statements: [
          'CREATE TABLE upgrade_temp (id TEXT PRIMARY KEY)'
        ] });
        expect(store.version).assertEqual(2);
        const kept = await store.querySql('SELECT id FROM preserved_rows');
        try {
          expect(kept.rowCount).assertEqual(1);
          expect(kept.goToFirstRow()).assertTrue();
          expect(kept.getString(0)).assertEqual('preserved');
        } finally {
          kept.close();
        }
      } finally {
        await store.close();
        await relationalStore.deleteRdbStore(context, 'm03_upgrade_failure_test.db');
      }
    });

    it('rejectsNewerSchemaWithoutRebuildingOrDeletingExistingData', 0, async () => {
      const context = getRdbTestContext();
      try {
        try {
          await relationalStore.deleteRdbStore(context, MIGRATION_FAILURE_DATABASE);
        } catch (_) {
          // The isolated test database may not exist yet.
        }
        const futureStore = await relationalStore.getRdbStore(context, {
          name: MIGRATION_FAILURE_DATABASE, securityLevel: relationalStore.SecurityLevel.S1, allowRebuild: false
        });
        await futureStore.executeSql('CREATE TABLE preserved_rows (id TEXT PRIMARY KEY NOT NULL)');
        await futureStore.executeSql("INSERT INTO preserved_rows (id) VALUES ('keep-me')");
        futureStore.version = SCHEMA_VERSION + 10;
        await futureStore.close();

        let rejected: boolean = false;
        try {
          await RdbPersistenceGateway.open(context, MIGRATION_FAILURE_DATABASE);
        } catch (_) {
          rejected = true;
        }
        expect(rejected).assertTrue();
        const afterFailure = await relationalStore.getRdbStore(context, {
          name: MIGRATION_FAILURE_DATABASE, securityLevel: relationalStore.SecurityLevel.S1, allowRebuild: false
        });
        try {
          const result = await afterFailure.querySql("SELECT id FROM preserved_rows WHERE id=?", ['keep-me']);
          try {
            expect(result.goToFirstRow()).assertTrue();
            expect(result.getString(result.getColumnIndex('id'))).assertEqual('keep-me');
          } finally {
            result.close();
          }
          expect(afterFailure.version).assertEqual(SCHEMA_VERSION + 10);
        } finally {
          await afterFailure.close();
        }
      } finally {
        await relationalStore.deleteRdbStore(context, MIGRATION_FAILURE_DATABASE);
      }
    });

    it('rollsBackSnapshotReplacementWhenImportedRowsViolateConstraints', 0, async () => {
      const gateway = await openClean();
      try {
        const original = sampleRecord('preserved-record', 'preserved-request', '2026-01-01', 'keep original');
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.records.insert(original); });
        const malformed = emptySnapshot();
        malformed.records = [sampleRecord('replacement-record', 'replacement-request', '2026-01-02', 'replacement')];
        malformed.settings = [{ key: 'invalid.setting', valueJson: '{not valid json', updatedAt: 2 }];
        let failed: boolean = false;
        try {
          await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(malformed); });
        } catch (_) {
          failed = true;
        }
        expect(failed).assertTrue();
        const afterFailure = await gateway.read.records.getById(original.id);
        expect(afterFailure !== null).assertTrue();
        if (afterFailure !== null) {
          expect(afterFailure.note).assertEqual('keep original');
        }
        expect(await gateway.read.metadata.getSetting('invalid.setting')).assertEqual(null);
        expect(await gateway.read.records.getById('replacement-record')).assertEqual(null);
      } finally {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(emptySnapshot()); });
        await gateway.close();
      }
    });

    it('rollsBackAnAlreadyAppliedReplacementWhenLaterWorkThrows', 0, async () => {
      const gateway = await openClean();
      try {
        await gateway.runInTransaction(async (tx): Promise<void> => {
          await tx.records.insert(sampleRecord('original-before-replace', 'before-request', '2026-01-01', 'original'));
        });
        const before = await gateway.read.getFullSnapshot();
        const replacement = emptySnapshot();
        replacement.records.push(sampleRecord('replacement', 'replacement-request', '2026-02-01', 'new'));
        let failed: boolean = false;
        try {
          await gateway.runInTransaction(async (tx): Promise<void> => {
            await tx.replaceAll(replacement);
            expect(await tx.records.getById('replacement') !== null).assertTrue();
            throw new Error('injected after full replacement');
          });
        } catch (_) {
          failed = true;
        }
        expect(failed).assertTrue();
        expect(await gateway.read.getFullSnapshot()).assertDeepEquals(before);
      } finally {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(emptySnapshot()); });
        await gateway.close();
      }
    });

    it('neverMixesAConcurrentAtomicWriteAcrossFullSnapshotTables', 0, async () => {
      const gateway = await openClean();
      try {
        const work = gateway.runInTransaction(async (tx): Promise<void> => {
          await tx.records.insert(sampleRecord('consistent', 'consistent-request', '2026-01-01', 'consistent'));
          await tx.points.insert(ledger('consistent-ledger', 'consistent-source', 5, 5));
          expect((await tx.getFullSnapshot()).records.length).assertEqual(1);
          expect(await tx.points.getBalance()).assertEqual(5);
        });
        const reading = gateway.read.getFullSnapshot();
        await work;
        const snapshot = await reading;
        expect(snapshot.records.length).assertEqual(1);
        expect(snapshot.ledgerEntries.length).assertEqual(1);
        const empty = emptySnapshot();
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(empty); });
        expect(await gateway.read.getFullSnapshot()).assertDeepEquals(empty);
      } finally {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(emptySnapshot()); });
        await gateway.close();
      }
    });

    it('roundTripsAllSevenRepositoriesWithTheirOriginalSnapshotsAndSorting', 0, async () => {
      const gateway = await openClean();
      try {
        const state: TaskRewardState = { taskId: 'z-task', periodKey: '2026-10-28', everClaimed: true,
          netGrantedPoints: 10, transitionSequence: 1, definitionSnapshot: { id: 'z-task', version: 'fixture-1',
            title: '测试任务', description: '仅测试', periodType: TaskPeriodType.DAILY,
            ruleType: TaskRuleType.POSITIVE_RECORD_COUNT, target: 1, points: 10, enabled: true } };
        const redemption: Redemption = { id: 'redeem-id', rewardId: 'fixture-reward', requestId: 'redeem-request',
          costPoints: 10, createdAt: 10, rewardSnapshot: { id: 'fixture-reward', version: 'old-version',
            type: RewardType.BADGE, title: '测试徽章', description: '仅测试', costPoints: 10 } };
        await gateway.runInTransaction(async (tx): Promise<void> => {
          await tx.records.insert(sampleRecord('all-record', 'all-create', '2026-10-28', 'all tables'));
          await tx.taskStates.insert(state);
          await tx.points.insert(ledger('all-point', 'all-source', 10, 10));
          await tx.redemptions.insert(redemption);
          await tx.metadata.putSetting({ key: 'z-setting', valueJson: '{"nested":[1,2]}', updatedAt: 10 });
          await tx.metadata.putSetting({ key: 'a-setting', valueJson: 'false', updatedAt: 10 });
          await tx.metadata.putFeedback({ suggestionId: 'z-feedback', feedback: SuggestionFeedback.ACCEPTED, updatedAt: 10 });
          await tx.metadata.putFeedback({ suggestionId: 'a-feedback', feedback: SuggestionFeedback.DISMISSED, updatedAt: 11 });
          await tx.operations.insert({ requestId: 'all-operation', operationType: OperationType.REDEEM_REWARD,
            inputFingerprint: 'original-input', status: OperationStatus.COMMITTED, committedAt: 10,
            result: { record: null, taskProgress: null, redemption: redemption, restoreSummary: null } });
          state.netGrantedPoints = 0;
          state.transitionSequence = 2;
          await tx.taskStates.update(state);
        });
        const before = await gateway.read.getFullSnapshot();
        expect(before.records.length).assertEqual(1);
        expect(before.ledgerEntries.length).assertEqual(1);
        expect(before.taskRewardStates[0].transitionSequence).assertEqual(2);
        expect(before.redemptions[0].rewardSnapshot.version).assertEqual('old-version');
        expect(before.operations[0].result.redemption !== null).assertTrue();
        expect((await gateway.read.metadata.listSettings())[0].key).assertEqual('a-setting');
        expect((await gateway.read.metadata.listFeedback())[0].suggestionId).assertEqual('a-feedback');
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(emptySnapshot()); });
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(before); });
        expect(await gateway.read.getFullSnapshot()).assertDeepEquals(before);
        let rewardCode: string = '';
        try {
          await gateway.runInTransaction(async (tx): Promise<void> => { await tx.redemptions.insert(redemption); });
        } catch (error) {
          rewardCode = (error as AppError).code;
        }
        expect(rewardCode).assertEqual(ErrorCode.ALREADY_REDEEMED);
      } finally {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(emptySnapshot()); });
        await gateway.close();
      }
    });

    it('preservesRestoreResultInReplacementAndNeverOverwritesLaterWritesOnRetry', 0, async () => {
      const gateway = await openClean();
      try {
        const imported = emptySnapshot();
        imported.records.push(sampleRecord('imported', 'imported-request', '2026-01-01', 'backup content'));
        const restore: IdempotencyOperation = { requestId: 'current-restore', operationType: OperationType.RESTORE_BACKUP,
          inputFingerprint: 'verified-digest', status: OperationStatus.COMMITTED, committedAt: 99,
          result: { record: null, taskProgress: null, redemption: null,
            restoreSummary: { recordCount: 1, ledgerEntryCount: 0, taskStateCount: 0, redemptionCount: 0,
              settingCount: 0, feedbackCount: 0, operationCount: 1, finalPointsBalance: 0 } } };
        await gateway.runInTransaction(async (tx): Promise<void> => {
          await tx.replaceAll(imported);
          await tx.operations.insert(restore);
        });
        await gateway.runInTransaction(async (tx): Promise<void> => {
          await tx.records.insert(sampleRecord('later', 'later-request', '2026-02-01', 'after restore'));
        });
        const originalResult = await gateway.runInTransaction(async (tx): Promise<IdempotencyOperation | null> => {
          const existing = await tx.operations.getByRequestId(restore.requestId);
          if (existing !== null) {
            return existing;
          }
          await tx.replaceAll(imported);
          await tx.operations.insert(restore);
          return restore;
        });
        expect(originalResult).assertDeepEquals(restore);
        expect(await gateway.read.records.getById('later') !== null).assertTrue();
        const conflictedImport = emptySnapshot();
        conflictedImport.operations.push(restore);
        let code: string = '';
        try {
          await gateway.runInTransaction(async (tx): Promise<void> => {
            await tx.replaceAll(conflictedImport);
            await tx.operations.insert(restore);
          });
        } catch (error) {
          code = (error as AppError).code;
        }
        expect(code).assertEqual(ErrorCode.IDEMPOTENCY_CONFLICT);
        expect(await gateway.read.records.getById('later') !== null).assertTrue();
        expect((await gateway.read.getFullSnapshot()).records.length).assertEqual(2);
      } finally {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(emptySnapshot()); });
        await gateway.close();
      }
    });

    it('readsOwnWritesAndReplacesExistingIdsWithoutLeakingCopies', 0, async () => {
      const gateway = await openClean();
      try {
        const original = sampleRecord('same-id', 'same-request', '2026-10-28', 'before');
        await gateway.runInTransaction(async (tx): Promise<void> => {
          await tx.records.insert(original);
          const retrieved = await tx.records.getById(original.id);
          expect(retrieved !== null).assertTrue();
          if (retrieved !== null) { retrieved.note = 'mutated copy'; }
          expect((await tx.records.getById(original.id))!.note).assertEqual('before');
          await tx.points.insert(ledger('same-point', 'same-source', 7, 10));
          expect(await tx.points.getBalance()).assertEqual(7);
          await tx.metadata.putSetting({ key: 'same-setting', valueJson: '1', updatedAt: 1 });
          await tx.metadata.putSetting({ key: 'same-setting', valueJson: '2', updatedAt: 2 });
          expect((await tx.metadata.getSetting('same-setting'))!.valueJson).assertEqual('2');
        });
        const replacement = await gateway.read.getFullSnapshot();
        replacement.records[0].note = 'replacement';
        replacement.ledgerEntries[0].delta = 12;
        await gateway.runInTransaction(async (tx): Promise<void> => {
          await tx.replaceAll(replacement);
          expect((await tx.records.getById('same-id'))!.note).assertEqual('replacement');
          expect(await tx.points.getBalance()).assertEqual(12);
          const snapshot = await tx.getFullSnapshot();
          snapshot.records[0].note = 'external mutation';
          expect((await tx.records.getById('same-id'))!.note).assertEqual('replacement');
        });
        expect((await gateway.read.records.getById('same-id'))!.note).assertEqual('replacement');
        expect(await gateway.read.points.getBalance()).assertEqual(12);
      } finally {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(emptySnapshot()); });
        await gateway.close();
      }
    });

    it('supportsFullSnapshotReplacementAndKeepsSchemaVersion', 0, async () => {
      const gateway = await openClean();
      try {
        const record = sampleRecord('snapshot-record', 'snapshot-request', '2025-02-28', 'snapshot');
        await gateway.runInTransaction(async (tx): Promise<void> => {
          await tx.records.insert(record);
          await tx.points.insert(ledger('snapshot-ledger', 'snapshot-source', -2, 60));
        });
        const snapshot = await gateway.read.getFullSnapshot();
        expect(snapshot.schemaVersion).assertEqual(SCHEMA_VERSION);
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(emptySnapshot()); });
        expect((await gateway.read.getFullSnapshot()).records.length).assertEqual(0);
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(snapshot); });
        expect((await gateway.read.getFullSnapshot()).records.length).assertEqual(1);
        expect(await gateway.read.points.getBalance()).assertEqual(-2);
      } finally {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(emptySnapshot()); });
        await gateway.close();
      }
    });
  });
}
