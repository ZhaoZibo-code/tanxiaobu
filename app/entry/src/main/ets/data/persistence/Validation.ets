import { QuantityUnit } from '../../common/contracts/Common';
import { CalculationMode, FactorDefinition, FactorSnapshot } from '../../common/contracts/Calculation';
import { BehaviorRecord, RecordStatus } from '../../common/contracts/Records';
import { PointLedgerEntry, Redemption, TaskRewardState, TaskPeriodType } from '../../common/contracts/Engagement';
import { IdempotencyOperation, OperationStatus, OperationType } from '../../common/contracts/Persistence';
import { BusinessSetting, SuggestionFeedback, SuggestionFeedbackEntry } from '../../common/contracts/Content';
import { AppError, ErrorCode } from '../../common/errors/AppError';
import { isValidLocalDate } from '../../common/utils/Dates';

const CATEGORY_VALUES: string[] = ['travel', 'energy_water', 'recycling', 'food'];
const UNIT_VALUES: string[] = ['km', 'kWh', 'L', 'kg', 'portion'];

export function requireValid(condition: boolean): void {
  if (!condition) {
    throw new AppError(ErrorCode.INVALID_INPUT, '持久化数据格式无效。');
  }
}

function contains(values: string[], candidate: string): boolean {
  for (let i: number = 0; i < values.length; i++) {
    if (values[i] === candidate) {
      return true;
    }
  }
  return false;
}

export function validKey(value: string): boolean {
  return typeof value === 'string' && value.length > 0;
}

export function validTime(value: number): boolean {
  return Number.isSafeInteger(value) && value >= 0;
}

function validateFactor(factor: FactorDefinition): void {
  requireValid(factor !== null && factor !== undefined);
  requireValid(validKey(factor.id) && validKey(factor.version) && validKey(factor.name));
  requireValid(contains(UNIT_VALUES, factor.unit) && Number.isFinite(factor.gramsCo2ePerUnit) &&
    Number.isFinite(factor.originalValue) && validKey(factor.originalUnit));
  requireValid(factor.source !== null && factor.source !== undefined);
  requireValid(validKey(factor.source.title) && validKey(factor.source.url) && validKey(factor.source.publisher) &&
    (factor.source.publishedDate === null || isValidLocalDate(factor.source.publishedDate)) &&
    isValidLocalDate(factor.source.retrievedDate) && validKey(factor.source.region) &&
    validKey(factor.source.boundary) && typeof factor.source.notes === 'string');
  requireValid(Array.isArray(factor.assumptions) && factor.assumptions.every((item: string): boolean => typeof item === 'string'));
  requireValid(factor.evidenceStatus === 'documented' || factor.evidenceStatus === 'development_fixture');
}

function validateFactorSnapshot(snapshot: FactorSnapshot): void {
  const rule = snapshot.rule;
  requireValid(validKey(rule.id) && validKey(rule.version) && validKey(rule.name));
  requireValid(contains(CATEGORY_VALUES, rule.category) && contains(['km', 'kWh', 'L', 'kg', 'portion'], rule.inputUnit));
  requireValid(Number.isFinite(rule.minQuantity) && Number.isFinite(rule.maxQuantity) && rule.minQuantity > 0 &&
    rule.maxQuantity >= rule.minQuantity);
  requireValid(rule.mode === CalculationMode.DIRECT_REDUCTION || rule.mode === CalculationMode.BASELINE_DIFFERENCE);
  requireValid(Array.isArray(rule.assumptions) && rule.assumptions.every((item: string): boolean => typeof item === 'string'));
  requireValid(typeof rule.baselineLabel === 'string' && typeof rule.actualLabel === 'string' && typeof rule.confirmationText === 'string');

  const referencedIds: string[] = [];
  if (rule.mode === CalculationMode.DIRECT_REDUCTION) {
    requireValid(validKey(rule.reductionFactorId as string) && rule.baselineFactorId === null && rule.actualFactorId === null);
    referencedIds.push(rule.reductionFactorId as string);
  } else {
    requireValid(rule.reductionFactorId === null && validKey(rule.baselineFactorId as string) && validKey(rule.actualFactorId as string));
    referencedIds.push(rule.baselineFactorId as string);
    referencedIds.push(rule.actualFactorId as string);
  }
  requireValid(Array.isArray(snapshot.factors));
  const factorIds: string[] = [];
  const factorUnits: QuantityUnit[] = [];
  for (let i: number = 0; i < snapshot.factors.length; i++) {
    const factor: FactorDefinition = snapshot.factors[i];
    validateFactor(factor);
    requireValid(factorIds.indexOf(factor.id) < 0);
    factorIds.push(factor.id);
    factorUnits.push(factor.unit);
  }
  requireValid(factorIds.length === referencedIds.length);
  for (let i: number = 0; i < referencedIds.length; i++) {
    const factorIndex: number = factorIds.indexOf(referencedIds[i]);
    requireValid(factorIndex >= 0);
    if (factorIndex >= 0) {
      requireValid(factorUnits[factorIndex] === rule.inputUnit);
    }
  }
}

function expectUnitType(unit: string): void {
  requireValid(contains(UNIT_VALUES, unit));
}

export function validateRecord(record: BehaviorRecord): void {
  requireValid(record !== null && record !== undefined);
  requireValid(validKey(record.id) && validKey(record.createdByRequestId) && isValidLocalDate(record.businessDate));
  requireValid(contains(CATEGORY_VALUES, record.category) && contains(UNIT_VALUES, record.unit));
  expectUnitType(record.unit);
  requireValid(validKey(record.ruleId) && validKey(record.ruleVersion) && Number.isFinite(record.quantity) && record.quantity > 0);
  requireValid(typeof record.note === 'string' && typeof record.formulaText === 'string' && typeof record.baselineConfirmed === 'boolean');
  requireValid(Number.isSafeInteger(record.reductionGrams) && validTime(record.createdAt) && validTime(record.updatedAt));
  requireValid(record.status === RecordStatus.ACTIVE || record.status === RecordStatus.VOIDED);
  requireValid(record.factorSnapshot !== null && record.factorSnapshot !== undefined);
  requireValid(record.factorSnapshot.rule !== null && record.factorSnapshot.rule !== undefined && Array.isArray(record.factorSnapshot.factors));
  requireValid(record.factorSnapshot.rule.id === record.ruleId && record.factorSnapshot.rule.version === record.ruleVersion &&
    typeof record.factorSnapshot.rule.name === 'string');
  validateFactorSnapshot(record.factorSnapshot);
}

export function validateLedger(entry: PointLedgerEntry): void {
  requireValid(entry !== null && entry !== undefined);
  requireValid(validKey(entry.id) && validKey(entry.sourceKey) && Number.isSafeInteger(entry.delta) && validTime(entry.createdAt));
  requireValid(entry.reason === 'task_reward' || entry.reason === 'revocation_adjustment' || entry.reason === 'redemption');
  requireValid(entry.relatedRecordId === null || validKey(entry.relatedRecordId));
  requireValid(entry.relatedTaskId === null || validKey(entry.relatedTaskId));
  requireValid(entry.periodKey === null || isValidLocalDate(entry.periodKey));
}

export function validateTaskState(state: TaskRewardState): void {
  requireValid(state !== null && state !== undefined);
  requireValid(validKey(state.taskId) && isValidLocalDate(state.periodKey) && typeof state.everClaimed === 'boolean');
  requireValid(Number.isSafeInteger(state.netGrantedPoints) && Number.isSafeInteger(state.transitionSequence) && state.transitionSequence >= 0);
  const definition = state.definitionSnapshot;
  requireValid(definition !== null && definition !== undefined);
  requireValid(definition.id === state.taskId && validKey(definition.version) && typeof definition.title === 'string' &&
    typeof definition.description === 'string' && typeof definition.enabled === 'boolean');
  requireValid(definition.periodType === TaskPeriodType.DAILY &&
    (definition.ruleType === 'positive_record_count' || definition.ruleType === 'positive_category_count' ||
      definition.ruleType === 'travel_km_sum' || definition.ruleType === 'food_record_count' ||
      definition.ruleType === 'total_reduction_grams'));
  requireValid(Number.isSafeInteger(definition.points) && definition.points >= 0 && Number.isFinite(definition.target) && definition.target > 0);
}

export function validateRedemption(redemption: Redemption): void {
  requireValid(redemption !== null && redemption !== undefined);
  requireValid(validKey(redemption.id) && validKey(redemption.rewardId) && validKey(redemption.requestId));
  requireValid(Number.isSafeInteger(redemption.costPoints) && redemption.costPoints >= 0 && validTime(redemption.createdAt));
  const reward = redemption.rewardSnapshot;
  requireValid(reward !== null && reward !== undefined);
  requireValid(reward.id === redemption.rewardId && validKey(reward.version) &&
    (reward.type === 'badge' || reward.type === 'virtual_certificate'));
  requireValid(typeof reward.title === 'string' && typeof reward.description === 'string' && reward.costPoints === redemption.costPoints);
}

export function validateOperation(operation: IdempotencyOperation): void {
  requireValid(operation !== null && operation !== undefined);
  requireValid(validKey(operation.requestId) && validKey(operation.inputFingerprint) && validTime(operation.committedAt));
  requireValid(operation.status === OperationStatus.COMMITTED);
  const result = operation.result;
  requireValid(result !== null && result !== undefined);
  const type: OperationType = operation.operationType;
  requireValid(type === OperationType.CREATE_RECORD || type === OperationType.UPDATE_RECORD ||
    type === OperationType.VOID_RECORD || type === OperationType.CLAIM_TASK ||
    type === OperationType.REDEEM_REWARD || type === OperationType.RESTORE_BACKUP);
  const recordResult: boolean = type === OperationType.CREATE_RECORD || type === OperationType.UPDATE_RECORD;
  requireValid(recordResult ? result.record !== null && result.record !== undefined : result.record === null);
  requireValid(type === OperationType.CLAIM_TASK ? result.taskProgress !== null && result.taskProgress !== undefined : result.taskProgress === null);
  requireValid(type === OperationType.REDEEM_REWARD ? result.redemption !== null && result.redemption !== undefined : result.redemption === null);
  requireValid(type === OperationType.RESTORE_BACKUP ? result.restoreSummary !== null && result.restoreSummary !== undefined : result.restoreSummary === null);
  if (result.record !== null) {
    validateRecord(result.record);
  }
  if (result.redemption !== null) {
    validateRedemption(result.redemption);
  }
  if (result.restoreSummary !== null) {
    const summary = result.restoreSummary;
    const counts: number[] = [summary.recordCount, summary.ledgerEntryCount, summary.taskStateCount, summary.redemptionCount,
      summary.settingCount, summary.feedbackCount, summary.operationCount];
    requireValid(counts.every((value: number): boolean => Number.isSafeInteger(value) && value >= 0));
    requireValid(Number.isSafeInteger(summary.finalPointsBalance));
  }
  if (result.taskProgress !== null) {
    const progress = result.taskProgress;
    requireValid(isValidLocalDate(progress.periodKey) && Number.isFinite(progress.current) && Number.isFinite(progress.target) &&
      typeof progress.eligible === 'boolean' && typeof progress.claimed === 'boolean' && Number.isSafeInteger(progress.earnedPoints));
  }
}

export function validateSetting(setting: BusinessSetting): void {
  requireValid(setting !== null && setting !== undefined);
  requireValid(validKey(setting.key) && typeof setting.valueJson === 'string' && validTime(setting.updatedAt));
  try {
    JSON.parse(setting.valueJson);
  } catch (_) {
    throw new AppError(ErrorCode.INVALID_INPUT, '业务设置必须是合法JSON。');
  }
}

export function validateFeedback(feedback: SuggestionFeedbackEntry): void {
  requireValid(feedback !== null && feedback !== undefined);
  requireValid(validKey(feedback.suggestionId) && validTime(feedback.updatedAt) &&
    (feedback.feedback === 'accepted' || feedback.feedback === 'dismissed'));
}
