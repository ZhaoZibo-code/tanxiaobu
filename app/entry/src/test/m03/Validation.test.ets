import { describe, it, expect } from '@ohos/hypium';
import { AppError, ErrorCode } from '../../main/ets/common/errors/AppError';
import { Category, QuantityUnit } from '../../main/ets/common/contracts/Common';
import { CalculationMode, CalculationRule, EvidenceStatus, FactorDefinition } from '../../main/ets/common/contracts/Calculation';
import { BehaviorRecord, RecordStatus } from '../../main/ets/common/contracts/Records';
import { validateRecord } from '../../main/ets/data/persistence/Validation';
import { validateLedger, validateOperation, validateSetting, validateFeedback } from '../../main/ets/data/persistence/Validation';
import { PointReason } from '../../main/ets/common/contracts/Engagement';
import { OperationStatus, OperationType } from '../../main/ets/common/contracts/Persistence';
import { SuggestionFeedback } from '../../main/ets/common/contracts/Content';

function recordWithRule(mode: CalculationMode, includeAll: boolean): BehaviorRecord {
  const direct = mode === CalculationMode.DIRECT_REDUCTION;
  const rule: CalculationRule = { id: 'rule', version: '1', category: Category.TRAVEL, name: 'rule', inputUnit: QuantityUnit.KM,
    minQuantity: 0.1, maxQuantity: 10, mode: mode,
    reductionFactorId: direct ? 'factor-a' : null, baselineFactorId: direct ? null : 'factor-a',
    actualFactorId: direct ? null : 'factor-b', baselineLabel: '', actualLabel: '', assumptions: [], confirmationText: '' };
  const factors: FactorDefinition[] = [{ id: 'factor-a', version: '1', name: 'factor-a', unit: QuantityUnit.KM,
    gramsCo2ePerUnit: 10, originalValue: 10, originalUnit: 'g/km',
    source: { title: 'source', url: 'https://example.invalid', publisher: 'source', publishedDate: null,
      retrievedDate: '2026-10-28', region: 'global', boundary: 'test', notes: '' },
    assumptions: [], evidenceStatus: EvidenceStatus.DEVELOPMENT_FIXTURE }];
  if (includeAll && !direct) {
    factors.push({ id: 'factor-b', version: '1', name: 'factor-b', unit: QuantityUnit.KM,
      gramsCo2ePerUnit: 5, originalValue: 5, originalUnit: 'g/km',
      source: { title: 'source', url: 'https://example.invalid', publisher: 'source', publishedDate: null,
        retrievedDate: '2026-10-28', region: 'global', boundary: 'test', notes: '' },
      assumptions: [], evidenceStatus: EvidenceStatus.DEVELOPMENT_FIXTURE });
  }
  return { id: 'record', createdByRequestId: 'request', businessDate: '2026-10-28', category: Category.TRAVEL,
    ruleId: rule.id, ruleVersion: rule.version, quantity: 1, unit: QuantityUnit.KM, note: '', baselineConfirmed: true,
    reductionGrams: 1, formulaText: '', factorSnapshot: { rule: rule, factors: factors }, createdAt: 1, updatedAt: 1,
    status: RecordStatus.ACTIVE };
}

function expectInvalid(work: () => void): void {
  let code: string = '';
  try {
    work();
  } catch (error) {
    code = (error as AppError).code;
  }
  expect(code).assertEqual(ErrorCode.INVALID_INPUT);
}

export default function persistenceValidationTest(): void {
  describe('M03PersistenceValidation', () => {
    it('requiresEveryHistoricalRuleFactorAndRejectsMalformedEntries', 0, () => {
      validateRecord(recordWithRule(CalculationMode.DIRECT_REDUCTION, false));
      validateRecord(recordWithRule(CalculationMode.BASELINE_DIFFERENCE, true));
      expectInvalid(() => validateRecord(recordWithRule(CalculationMode.BASELINE_DIFFERENCE, false)));
      const duplicate = recordWithRule(CalculationMode.DIRECT_REDUCTION, false);
      duplicate.factorSnapshot.factors.push(duplicate.factorSnapshot.factors[0]);
      expectInvalid(() => validateRecord(duplicate));
      const malformed = recordWithRule(CalculationMode.DIRECT_REDUCTION, false);
      malformed.factorSnapshot.factors[0].source.boundary = '';
      expectInvalid(() => validateRecord(malformed));
    });

    it('acceptsSignedSafeIntegerLedgerWithoutInventingPointRules', 0, () => {
      validateLedger({ id: 'point', delta: -10, reason: PointReason.REVOCATION_ADJUSTMENT,
        sourceKey: 'source', relatedRecordId: null, relatedTaskId: null, periodKey: '2024-02-29', createdAt: 0 });
      expectInvalid(() => validateLedger({ id: 'point', delta: 0.5, reason: PointReason.TASK_REWARD,
        sourceKey: 'source', relatedRecordId: null, relatedTaskId: null, periodKey: null, createdAt: 0 }));
      expectInvalid(() => validateLedger({ id: 'point', delta: Number.NaN, reason: PointReason.TASK_REWARD,
        sourceKey: 'source', relatedRecordId: null, relatedTaskId: null, periodKey: null, createdAt: 0 }));
      expectInvalid(() => validateLedger({ id: 'point', delta: 1, reason: PointReason.TASK_REWARD,
        sourceKey: '', relatedRecordId: null, relatedTaskId: null, periodKey: '2023-02-29', createdAt: 0 }));
    });

    it('validatesBusinessJsonAndFeedbackMetadata', 0, () => {
      validateSetting({ key: 'setting', valueJson: '{"nested":[1,false,null]}', updatedAt: 1 });
      validateSetting({ key: 'scalar', valueJson: 'null', updatedAt: 1 });
      validateFeedback({ suggestionId: 'suggestion', feedback: SuggestionFeedback.DISMISSED, updatedAt: 1 });
      expectInvalid(() => validateSetting({ key: 'setting', valueJson: '{', updatedAt: 1 }));
      expectInvalid(() => validateSetting({ key: '', valueJson: '{}', updatedAt: 1 }));
      expectInvalid(() => validateFeedback({ suggestionId: 'suggestion', feedback: SuggestionFeedback.ACCEPTED, updatedAt: -1 }));
    });

    it('requiresExactlyTheCommittedResultSlotForTheOperationType', 0, () => {
      validateOperation({ requestId: 'void', operationType: OperationType.VOID_RECORD, inputFingerprint: 'raw-input',
        status: OperationStatus.COMMITTED, committedAt: 0,
        result: { record: null, taskProgress: null, redemption: null, restoreSummary: null } });
      expectInvalid(() => validateOperation({ requestId: 'create', operationType: OperationType.CREATE_RECORD,
        inputFingerprint: 'raw-input', status: OperationStatus.COMMITTED, committedAt: 0,
        result: { record: null, taskProgress: null, redemption: null, restoreSummary: null } }));
      expectInvalid(() => validateOperation({ requestId: 'restore', operationType: OperationType.RESTORE_BACKUP,
        inputFingerprint: 'digest', status: OperationStatus.COMMITTED, committedAt: 0,
        result: { record: null, taskProgress: null, redemption: null, restoreSummary: {
          recordCount: -1, ledgerEntryCount: 0, taskStateCount: 0, redemptionCount: 0, settingCount: 0,
          feedbackCount: 0, operationCount: 0, finalPointsBalance: 0 } } }));
    });
  });
}
