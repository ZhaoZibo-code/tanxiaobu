import { describe, it, expect } from '@ohos/hypium';
import { restoreSnapshot } from '../../../../main/ets/features/dataTransfer/BackupRestoreCore';
import { validateBackupDocument } from '../../../../main/ets/features/dataTransfer/BackupValidation';
import { BackupDocument } from '../../../../main/ets/common/contracts/Persistence';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import { BackupExportService } from '../../../../main/ets/features/dataTransfer/BackupExportService';
import { readBackupFile } from '../../../../main/ets/features/dataTransfer/BackupFileReader';
import { AdviceServiceImpl } from '../../../../main/ets/application/core/AdviceServiceImpl';
import { SuggestionFeedback } from '../../../../main/ets/common/contracts/Content';
import { EngagementServiceImpl } from '../../../../main/ets/application/core/EngagementServiceImpl';
import { RecordServiceImpl } from '../../../../main/ets/application/core/RecordServiceImpl';
import { createAppServices } from '../../../../main/ets/common/composition/AppComposition';
import { Category, Clock, IdGenerator, QuantityUnit } from '../../../../main/ets/common/contracts/Common';
import { CalculationInput, CalculationMode, CalculationPreview, CalculationRule, EvidenceStatus, FactorSnapshot } from '../../../../main/ets/common/contracts/Calculation';
import { CalculationService } from '../../../../main/ets/common/contracts/Services';
import { BehaviorRecord, RecordStatus } from '../../../../main/ets/common/contracts/Records';
import { DatabaseSnapshot, IdempotencyOperation, MetadataWriteRepository, OperationWriteRepository, PersistenceGateway,
  PointsWriteRepository, ReadRepository, RecordWriteRepository, RedemptionWriteRepository, TaskStateWriteRepository,
  TransactionContext } from '../../../../main/ets/common/contracts/Persistence';
import { RdbPersistenceGateway } from '../../../../main/ets/data/persistence/RdbPersistenceGateway';
import { SCHEMA_VERSION } from '../../../../main/ets/data/persistence/RdbSchema';
import { AppError, ErrorCode } from '../../../../main/ets/common/errors/AppError';

let context: common.UIAbilityContext | undefined = undefined;
export function setEngagementTestContext(value: common.UIAbilityContext): void { context = value; }
class TestClock implements Clock { nowMs(): number { return 1000; } today(): string { return '2026-10-28'; } }
class TestIds implements IdGenerator {
  private next: number = 0;
  newId(): string { this.next += 1; return `engagement-test-${this.next}`; }
}

function empty(): DatabaseSnapshot {
  return { schemaVersion: SCHEMA_VERSION, records: [], ledgerEntries: [], taskRewardStates: [],
    redemptions: [], operations: [], settings: [], feedback: [] };
}
function sample(id: string, category: Category): BehaviorRecord {
  const factor: FactorSnapshot = {
    rule: { id: 'fixture', version: '1', category: category, name: '测试', inputUnit: QuantityUnit.KWH,
      minQuantity: 0.1, maxQuantity: 10, mode: CalculationMode.DIRECT_REDUCTION, reductionFactorId: 'factor',
      baselineFactorId: null, actualFactorId: null, baselineLabel: '', actualLabel: '', assumptions: [], confirmationText: '' },
    factors: [{ id: 'factor', version: '1', name: '测试', unit: QuantityUnit.KWH, gramsCo2ePerUnit: 10,
      originalValue: 10, originalUnit: 'g/kWh', source: { title: '测试', url: 'https://example.invalid',
        publisher: '测试', publishedDate: null, retrievedDate: '2026-10-28', region: '测试', boundary: '测试', notes: '' },
      assumptions: [], evidenceStatus: EvidenceStatus.DEVELOPMENT_FIXTURE }]
  };
  return { id: id, createdByRequestId: `request-${id}`, businessDate: '2026-10-28', category: category,
    ruleId: 'fixture', ruleVersion: '1', quantity: 1, unit: QuantityUnit.KWH, note: '', baselineConfirmed: true,
    reductionGrams: 10, formulaText: '测试', factorSnapshot: factor, createdAt: 1000, updatedAt: 1000, status: RecordStatus.ACTIVE };
}

class TestCalculation implements CalculationService {
  async listRules(): Promise<CalculationRule[]> { return []; }
  async preview(input: CalculationInput): Promise<CalculationPreview> {
    const category = input.ruleId === 'energy' ? Category.ENERGY_WATER : Category.TRAVEL;
    const snapshot = sample('calc', category).factorSnapshot;
    snapshot.rule.id = input.ruleId;
    return { input: input, category: category, ruleName: '测试', reductionGrams: 10,
      formulaText: '测试', steps: [], assumptions: [], warnings: [], factorSnapshot: snapshot, eligibleForPositiveTasks: true };
  }
}

class TestAdviceCalculation extends TestCalculation {
  async listRules(): Promise<CalculationRule[]> {
    const first = sample('a', Category.ENERGY_WATER).factorSnapshot.rule;
    const second = sample('b', Category.TRAVEL).factorSnapshot.rule;
    first.id = 'energy'; second.id = 'travel';
    return [first, second];
  }
}

function input(ruleId: string): CalculationInput {
  return { ruleId: ruleId, quantity: 1, unit: QuantityUnit.KWH, businessDate: '2026-10-28', note: '', baselineConfirmed: true };
}

class InjectedOperations implements OperationWriteRepository {
  private readonly inner: OperationWriteRepository;
  constructor(inner: OperationWriteRepository) { this.inner = inner; }
  async getByRequestId(id: string): Promise<IdempotencyOperation | null> { return await this.inner.getByRequestId(id); }
  async insert(_operation: IdempotencyOperation): Promise<void> { throw new Error('injected before operation write'); }
}

class InjectedTransaction implements TransactionContext {
  readonly records: RecordWriteRepository;
  readonly taskStates: TaskStateWriteRepository;
  readonly points: PointsWriteRepository;
  readonly redemptions: RedemptionWriteRepository;
  readonly operations: OperationWriteRepository;
  readonly metadata: MetadataWriteRepository;
  private readonly inner: TransactionContext;
  constructor(inner: TransactionContext) {
    this.inner = inner; this.records = inner.records; this.taskStates = inner.taskStates; this.points = inner.points;
    this.redemptions = inner.redemptions; this.metadata = inner.metadata; this.operations = new InjectedOperations(inner.operations);
  }
  async getFullSnapshot(): Promise<DatabaseSnapshot> { return await this.inner.getFullSnapshot(); }
  async replaceAll(snapshot: DatabaseSnapshot): Promise<void> { await this.inner.replaceAll(snapshot); }
}

class InjectedFailureGateway implements PersistenceGateway {
  readonly read: ReadRepository;
  private readonly inner: PersistenceGateway;
  constructor(inner: PersistenceGateway) { this.inner = inner; this.read = inner.read; }
  async runInTransaction<T>(work: (tx: TransactionContext) => Promise<T>): Promise<T> {
    return await this.inner.runInTransaction(async (tx): Promise<T> => {
      return await work(new InjectedTransaction(tx));
    });
  }
}

export default function engagementTest(): void {
  describe('M04EngagementIsolated', () => {
    it('restoresRecordsTasksAndRewardsWithNegativeBalance', 0, async () => {
      if (context === undefined) { throw new Error('test context missing'); }
      const gateway = await RdbPersistenceGateway.open(context, 'engagement_isolated_test.db');
      const services = createAppServices(); services.clock = new TestClock(); services.ids = new TestIds(); services.calculation = new TestCalculation();
      const path = `${context.filesDir}/backup-rich-restore-test.json`;
      try {
        await gateway.runInTransaction(async tx => { await tx.replaceAll(empty()); });
        const records = new RecordServiceImpl(gateway, services);
        const engagement = new EngagementServiceImpl(gateway, services);
        const first = await records.create(input('energy'), 'rich-create-1');
        const second = await records.create(input('travel'), 'rich-create-2');
        await engagement.claim('daily_record_once', '2026-10-28', 'rich-claim-1');
        await engagement.claim('daily_two_categories', '2026-10-28', 'rich-claim-2');
        await engagement.redeem('badge_first_step', 'rich-redeem');
        await records.voidRecord(first.id, 'rich-void-1');
        await records.voidRecord(second.id, 'rich-void-2');
        expect(await engagement.getBalance()).assertEqual(-10);
        const source = await gateway.read.getFullSnapshot();
        const backup: BackupDocument = { schemaVersion: source.schemaVersion, appVersion: '0.1.0', exportedAt: 1000,
          records: source.records, ledgerEntries: source.ledgerEntries, taskRewardStates: source.taskRewardStates,
          redemptions: source.redemptions, operations: source.operations, settings: source.settings, feedback: source.feedback };
        const file = await fs.open(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        try { await fs.write(file.fd, JSON.stringify(backup)); } finally { await fs.close(file); }
        const service = new BackupExportService(context, async (): Promise<PersistenceGateway> => gateway, services);
        const preview = await service.inspectBackup(path);
        await gateway.runInTransaction(async tx => { await tx.replaceAll(empty()); });
        const summary = await service.restoreBackup(path, preview.contentDigest, 'rich-restore');
        expect(summary.recordCount).assertEqual(2);
        expect(summary.finalPointsBalance).assertEqual(-10);
        const restored = await gateway.read.getFullSnapshot();
        expect(restored.records).assertDeepEquals(source.records);
        expect(restored.ledgerEntries).assertDeepEquals(source.ledgerEntries);
        expect(restored.taskRewardStates).assertDeepEquals(source.taskRewardStates);
        expect(restored.redemptions).assertDeepEquals(source.redemptions);
        expect(restored.operations.length).assertEqual(source.operations.length + 1);
        expect(await engagement.getBalance()).assertEqual(-10);
      } finally {
        try { await fs.unlink(path); } catch (_) {}
        await gateway.runInTransaction(async tx => { await tx.replaceAll(empty()); });
        await gateway.close();
      }
    });

    it('readsAndRestoresAValidatedBackupFileInAnIsolatedDatabase', 0, async () => {
      if (context === undefined) { throw new Error('test context missing'); }
      const gateway = await RdbPersistenceGateway.open(context, 'engagement_isolated_test.db');
      const services = createAppServices(); services.clock = new TestClock();
      const path = `${context.filesDir}/backup-restore-test.json`;
      try {
        await gateway.runInTransaction(async tx => { await tx.replaceAll(empty()); await tx.records.insert(sample('file-record', Category.ENERGY_WATER)); });
        const source = await gateway.read.getFullSnapshot();
        const backup: BackupDocument = { schemaVersion: source.schemaVersion, appVersion: '0.1.0', exportedAt: 1000,
          records: source.records, ledgerEntries: source.ledgerEntries, taskRewardStates: source.taskRewardStates,
          redemptions: source.redemptions, operations: source.operations, settings: source.settings, feedback: source.feedback };
        const file = await fs.open(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        try { await fs.write(file.fd, JSON.stringify(backup)); } finally { await fs.close(file); }
        const service = new BackupExportService(context, async (): Promise<PersistenceGateway> => gateway, services);
        const preview = await service.inspectBackup(path);
        expect(preview.recordCount).assertEqual(1);
        await gateway.runInTransaction(async tx => { await tx.replaceAll(empty()); });
        const result = await service.restoreBackup(path, preview.contentDigest, 'file-restore');
        expect(result.recordCount).assertEqual(1);
        expect(await gateway.read.records.getById('file-record') !== null).assertTrue();
        const changed = await fs.open(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        try { await fs.write(changed.fd, '{}'); } finally { await fs.close(changed); }
        const repeat = await service.restoreBackup(path, preview.contentDigest, 'file-restore');
        expect(repeat.recordCount).assertEqual(1);
        let code = '';
        try { await service.restoreBackup(path, preview.contentDigest, 'new-restore'); } catch (error) { code = (error as AppError).code; }
        expect(code).assertEqual(ErrorCode.BACKUP_CHANGED);
      } finally {
        await fs.unlink(path);
        await gateway.runInTransaction(async tx => { await tx.replaceAll(empty()); });
        await gateway.close();
      }
    });

    it('restoresAtomicallyAndDoesNotOverwriteLaterWritesOnRetry', 0, async () => {
      if (context === undefined) { throw new Error('test context missing'); }
      const gateway = await RdbPersistenceGateway.open(context, 'engagement_isolated_test.db');
      const services = createAppServices(); services.clock = new TestClock();
      const digest = 'a'.repeat(64);
      const backup: BackupDocument = { schemaVersion: SCHEMA_VERSION, appVersion: '0.1.0', exportedAt: 1000,
        records: [], ledgerEntries: [], taskRewardStates: [], redemptions: [], operations: [],
        settings: [{ key: 'imported', valueJson: '1', updatedAt: 1 }], feedback: [] };
      try {
        await gateway.runInTransaction(async tx => { await tx.replaceAll(empty()); await tx.metadata.putSetting({ key: 'original', valueJson: '1', updatedAt: 1 }); });
        let failed = false;
        try { await restoreSnapshot(new InjectedFailureGateway(gateway), services, backup, digest, 'restore-failure'); } catch (_) { failed = true; }
        expect(failed).assertTrue();
        expect(await gateway.read.metadata.getSetting('original') !== null).assertTrue();
        expect(await gateway.read.metadata.getSetting('imported')).assertEqual(null);
        const summary = await restoreSnapshot(gateway, services, backup, digest, 'restore-success');
        expect(summary.settingCount).assertEqual(1);
        expect(await gateway.read.metadata.getSetting('original')).assertEqual(null);
        await gateway.runInTransaction(async tx => { await tx.metadata.putSetting({ key: 'later', valueJson: '2', updatedAt: 2 }); });
        const retry = await restoreSnapshot(gateway, services, backup, digest, 'restore-success');
        expect(retry.settingCount).assertEqual(1);
        expect(await gateway.read.metadata.getSetting('later') !== null).assertTrue();
        let conflict = '';
        try { await restoreSnapshot(gateway, services, backup, 'b'.repeat(64), 'restore-success'); } catch (error) { conflict = (error as AppError).code; }
        expect(conflict).assertEqual(ErrorCode.IDEMPOTENCY_CONFLICT);
      } finally {
        await gateway.runInTransaction(async tx => { await tx.replaceAll(empty()); });
        await gateway.close();
      }
    });

    it('adviceUsesRecentRecordsAndPersistsFeedback', 0, async () => {
      if (context === undefined) { throw new Error('test context missing'); }
      let gateway = await RdbPersistenceGateway.open(context, 'engagement_isolated_test.db');
      const services = createAppServices(); services.clock = new TestClock(); services.calculation = new TestAdviceCalculation();
      try {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(empty()); await tx.records.insert(sample('advice-record', Category.ENERGY_WATER)); });
        let advice = new AdviceServiceImpl(async (): Promise<PersistenceGateway> => gateway, services);
        const suggestions = await advice.listSuggestions('2026-10-28');
        expect(suggestions.length).assertEqual(2);
        expect(suggestions[0].reason.includes('1 次')).assertTrue();
        expect(suggestions[1].reason.includes('还没有')).assertTrue();
        await advice.recordFeedback(suggestions[0].id, SuggestionFeedback.DISMISSED);
        expect((await advice.listSuggestions('2026-10-28')).length).assertEqual(1);
        await gateway.close();
        gateway = await RdbPersistenceGateway.open(context, 'engagement_isolated_test.db');
        advice = new AdviceServiceImpl(async (): Promise<PersistenceGateway> => gateway, services);
        expect((await advice.listSuggestions('2026-10-28')).length).assertEqual(1);
        expect((await advice.listSuggestions('2026-10-29')).length).assertEqual(2);
      } finally {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(empty()); });
        await gateway.close();
      }
    });

    it('claimsAndRedeemsExactlyOnceAndSurvivesReopen', 0, async () => {
      if (context === undefined) { throw new Error('test context missing'); }
      let gateway = await RdbPersistenceGateway.open(context, 'engagement_isolated_test.db');
      const services = createAppServices(); services.clock = new TestClock(); services.ids = new TestIds();
      try {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(empty()); });
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.records.insert(sample('one', Category.ENERGY_WATER)); });
        let service = new EngagementServiceImpl(gateway, services);
        expect((await service.listForDate('2026-10-28'))[0].eligible).assertTrue();
        expect((await service.claim('daily_record_once', '2026-10-28', 'claim-1')).earnedPoints).assertEqual(10);
        expect((await service.claim('daily_record_once', '2026-10-28', 'claim-1')).earnedPoints).assertEqual(10);
        expect(await service.getBalance()).assertEqual(10);
        let duplicate: string = '';
        try { await service.claim('daily_record_once', '2026-10-28', 'claim-2'); } catch (error) { duplicate = (error as AppError).code; }
        expect(duplicate).assertEqual(ErrorCode.TASK_NOT_ELIGIBLE);
        let insufficient: string = '';
        try { await service.redeem('certificate_virtual_tree', 'redeem-too-early'); } catch (error) { insufficient = (error as AppError).code; }
        expect(insufficient).assertEqual(ErrorCode.INSUFFICIENT_POINTS);
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.records.insert(sample('two', Category.TRAVEL)); });
        await service.claim('daily_two_categories', '2026-10-28', 'claim-3');
        expect(await service.getBalance()).assertEqual(30);
        const reward = await service.redeem('certificate_virtual_tree', 'redeem-1');
        expect((await service.redeem('certificate_virtual_tree', 'redeem-1')).id).assertEqual(reward.id);
        expect(await service.getBalance()).assertEqual(0);
        const snapshot = await gateway.read.getFullSnapshot();
        const backup: BackupDocument = { schemaVersion: snapshot.schemaVersion, appVersion: '0.1.0', exportedAt: 1000,
          records: snapshot.records, ledgerEntries: snapshot.ledgerEntries, taskRewardStates: snapshot.taskRewardStates,
          redemptions: snapshot.redemptions, operations: snapshot.operations, settings: snapshot.settings, feedback: snapshot.feedback };
        validateBackupDocument(backup);
        backup.taskRewardStates[0].netGrantedPoints += 1;
        let invalidState = false;
        try { validateBackupDocument(backup); } catch (_) { invalidState = true; }
        expect(invalidState).assertTrue();
        backup.taskRewardStates[0].netGrantedPoints -= 1;
        backup.ledgerEntries = backup.ledgerEntries.filter((entry): boolean => entry.reason !== 'redemption');
        let missingRedemption = false;
        try { validateBackupDocument(backup); } catch (_) { missingRedemption = true; }
        expect(missingRedemption).assertTrue();
        await gateway.close();
        gateway = await RdbPersistenceGateway.open(context, 'engagement_isolated_test.db');
        service = new EngagementServiceImpl(gateway, services);
        expect(await service.getBalance()).assertEqual(0);
        expect((await service.listRedemptions()).length).assertEqual(1);
        expect((await service.listForDate('2026-10-28'))[0].claimed).assertTrue();
      } finally {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(empty()); });
        await gateway.close();
      }
    });

    it('rollsBackClaimIfOperationWriteFails', 0, async () => {
      if (context === undefined) { throw new Error('test context missing'); }
      const gateway = await RdbPersistenceGateway.open(context, 'engagement_isolated_test.db');
      const services = createAppServices(); services.clock = new TestClock(); services.ids = new TestIds();
      try {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(empty()); });
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.records.insert(sample('rollback', Category.FOOD)); });
        const service = new EngagementServiceImpl(new InjectedFailureGateway(gateway), services);
        let failed = false;
        try { await service.claim('daily_record_once', '2026-10-28', 'claim-fail'); } catch (_) { failed = true; }
        expect(failed).assertTrue();
        expect(await gateway.read.points.getBalance()).assertEqual(0);
        expect(await gateway.read.taskStates.get('daily_record_once', '2026-10-28')).assertEqual(null);
        expect(await gateway.read.operations.getByRequestId('claim-fail')).assertEqual(null);
      } finally {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(empty()); });
        await gateway.close();
      }
    });

    it('serializesConcurrentClaimsAndRedemptions', 0, async () => {
      if (context === undefined) { throw new Error('test context missing'); }
      const gateway = await RdbPersistenceGateway.open(context, 'engagement_isolated_test.db');
      const services = createAppServices(); services.clock = new TestClock(); services.ids = new TestIds();
      try {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(empty()); });
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.records.insert(sample('race', Category.FOOD)); });
        const service = new EngagementServiceImpl(gateway, services);
        const claims: boolean[] = await Promise.all([
          service.claim('daily_record_once', '2026-10-28', 'race-claim-a').then((): boolean => true, (): boolean => false),
          service.claim('daily_record_once', '2026-10-28', 'race-claim-b').then((): boolean => true, (): boolean => false)
        ]);
        expect(claims.filter((value: boolean) => value).length).assertEqual(1);
        expect(await service.getBalance()).assertEqual(10);
        const redemptions: boolean[] = await Promise.all([
          service.redeem('badge_first_step', 'race-redeem-a').then((): boolean => true, (): boolean => false),
          service.redeem('badge_first_step', 'race-redeem-b').then((): boolean => true, (): boolean => false)
        ]);
        expect(redemptions.filter((value: boolean) => value).length).assertEqual(1);
        expect(await service.getBalance()).assertEqual(0);
        expect((await service.listRedemptions()).length).assertEqual(1);
        let past: string = '';
        try { await service.claim('daily_record_once', '2026-10-27', 'past-claim'); } catch (error) { past = (error as AppError).code; }
        expect(past).assertEqual(ErrorCode.INVALID_TASK_PERIOD);
      } finally {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(empty()); });
        await gateway.close();
      }
    });

    it('reconcilesAwardsWhenRecordsChangeAndRollsBackFailedUpdates', 0, async () => {
      if (context === undefined) { throw new Error('test context missing'); }
      const gateway = await RdbPersistenceGateway.open(context, 'engagement_isolated_test.db');
      const services = createAppServices(); services.clock = new TestClock(); services.ids = new TestIds();
      services.calculation = new TestCalculation();
      try {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(empty()); });
        const records = new RecordServiceImpl(gateway, services);
        const engagement = new EngagementServiceImpl(gateway, services);
        const energy = await records.create(input('energy'), 'create-energy');
        await engagement.claim('daily_record_once', '2026-10-28', 'claim-one');
        const travel = await records.create(input('travel'), 'create-travel');
        await engagement.claim('daily_two_categories', '2026-10-28', 'claim-two');
        expect(await engagement.getBalance()).assertEqual(30);
        await records.voidRecord(travel.id, 'void-travel');
        await records.voidRecord(travel.id, 'void-travel');
        expect(await engagement.getBalance()).assertEqual(10);
        await records.create(input('travel'), 'create-travel-again');
        expect(await engagement.getBalance()).assertEqual(30);
        const failing = new RecordServiceImpl(new InjectedFailureGateway(gateway), services);
        let failed = false;
        try { await failing.update(energy.id, input('travel'), 'update-fail'); } catch (_) { failed = true; }
        expect(failed).assertTrue();
        expect((await records.getById(energy.id)).category).assertEqual(Category.ENERGY_WATER);
        expect(await engagement.getBalance()).assertEqual(30);
        await records.update(energy.id, input('travel'), 'update-away');
        expect(await engagement.getBalance()).assertEqual(10);
        await records.update(energy.id, input('energy'), 'update-back');
        expect(await engagement.getBalance()).assertEqual(30);
      } finally {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(empty()); });
        await gateway.close();
      }
    });

    it('keepsNegativeBalanceAndReconcilesAChangedBusinessDate', 0, async () => {
      if (context === undefined) { throw new Error('test context missing'); }
      const gateway = await RdbPersistenceGateway.open(context, 'engagement_isolated_test.db');
      const services = createAppServices(); services.clock = new TestClock(); services.ids = new TestIds();
      services.calculation = new TestCalculation();
      try {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(empty()); });
        const records = new RecordServiceImpl(gateway, services);
        const engagement = new EngagementServiceImpl(gateway, services);
        const first = await records.create(input('energy'), 'create-date');
        await engagement.claim('daily_record_once', '2026-10-28', 'claim-date');
        await engagement.redeem('badge_first_step', 'redeem-date');
        expect(await engagement.getBalance()).assertEqual(0);
        const previous = input('energy'); previous.businessDate = '2026-10-27';
        await records.update(first.id, previous, 'update-date-back');
        expect(await engagement.getBalance()).assertEqual(-10);
        expect((await engagement.listRedemptions()).length).assertEqual(1);
        let code: string = '';
        try { await engagement.redeem('certificate_virtual_tree', 'redeem-negative'); } catch (error) { code = (error as AppError).code; }
        expect(code).assertEqual(ErrorCode.INSUFFICIENT_POINTS);
        await records.update(first.id, input('energy'), 'update-date-forward');
        expect(await engagement.getBalance()).assertEqual(0);
        await records.voidRecord(first.id, 'void-redeemed');
        expect(await engagement.getBalance()).assertEqual(-10);
        expect((await engagement.listRedemptions()).length).assertEqual(1);
        const negativeSnapshot = await gateway.read.getFullSnapshot();
        const negativeBackup: BackupDocument = { schemaVersion: negativeSnapshot.schemaVersion, appVersion: '0.1.0', exportedAt: 1000,
          records: negativeSnapshot.records, ledgerEntries: negativeSnapshot.ledgerEntries, taskRewardStates: negativeSnapshot.taskRewardStates,
          redemptions: negativeSnapshot.redemptions, operations: negativeSnapshot.operations, settings: negativeSnapshot.settings, feedback: negativeSnapshot.feedback };
        validateBackupDocument(negativeBackup);
        const voidOperation = negativeBackup.operations.find((op: IdempotencyOperation): boolean => op.operationType === 'void_record');
        if (voidOperation === undefined) { throw new Error('void operation missing'); }
        const oldFingerprint = voidOperation.inputFingerprint;
        voidOperation.inputFingerprint = '["missing"]';
        let badVoid = false;
        try { validateBackupDocument(negativeBackup); } catch (_) { badVoid = true; }
        expect(badVoid).assertTrue();
        voidOperation.inputFingerprint = oldFingerprint;
        const oldCategory = negativeBackup.records[0].category;
        negativeBackup.records[0].category = Category.FOOD;
        let badCategory = false;
        try { validateBackupDocument(negativeBackup); } catch (_) { badCategory = true; }
        expect(badCategory).assertTrue();
        negativeBackup.records[0].category = oldCategory;
        const recordOperation = negativeBackup.operations.find((op: IdempotencyOperation): boolean => op.result.record !== null);
        if (recordOperation === undefined || recordOperation.result.record === null) { throw new Error('record operation missing'); }
        const oldOperationCategory = recordOperation.result.record.category;
        recordOperation.result.record.category = Category.FOOD;
        let badHistory = false;
        try { validateBackupDocument(negativeBackup); } catch (_) { badHistory = true; }
        expect(badHistory).assertTrue();
        recordOperation.result.record.category = oldOperationCategory;
        recordOperation.result.record.id = 'missing-record';
        let missingRecord = false;
        try { validateBackupDocument(negativeBackup); } catch (_) { missingRecord = true; }
        expect(missingRecord).assertTrue();
      } finally {
        await gateway.runInTransaction(async (tx): Promise<void> => { await tx.replaceAll(empty()); });
        await gateway.close();
      }
    });
  });
}
