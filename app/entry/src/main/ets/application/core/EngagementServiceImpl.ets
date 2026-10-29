import { Category, LocalDate, QuantityUnit } from '../../common/contracts/Common';
import { BehaviorRecord, RecordStatus } from '../../common/contracts/Records';
import { IdempotencyOperation, OperationStatus, OperationType, PersistenceGateway } from '../../common/contracts/Persistence';
import { PointLedgerEntry, PointReason, Redemption, RewardDefinition, RewardType, TaskDefinition, TaskPeriodType,
  TaskProgress, TaskRewardState, TaskRuleType } from '../../common/contracts/Engagement';
import { AppServices, PointsService, RewardService, TaskService } from '../../common/contracts/Services';
import { AppError, ErrorCode } from '../../common/errors/AppError';
import { addDays, requireLocalDate } from '../../common/utils/Dates';

const TASKS: TaskDefinition[] = [
  { id: 'daily_record_once', version: '2', title: '记录 1 次低碳行为', description: '任意录入一条低碳行为即可完成',
    periodType: TaskPeriodType.DAILY, ruleType: TaskRuleType.POSITIVE_RECORD_COUNT, target: 1, points: 10, enabled: true },
  { id: 'daily_two_categories', version: '2', title: '探索两种低碳方式', description: '在两个不同分类各记录一条',
    periodType: TaskPeriodType.DAILY, ruleType: TaskRuleType.POSITIVE_CATEGORY_COUNT, target: 2, points: 20, enabled: true },
  { id: 'daily_green_travel_3km', version: '1', title: '绿色出行 3 公里', description: '步行 / 骑行 / 公交累计满 3 公里',
    periodType: TaskPeriodType.DAILY, ruleType: TaskRuleType.TRAVEL_KM_SUM, target: 3, points: 15, enabled: true },
  { id: 'daily_food_once', version: '1', title: '今天光盘了吗', description: '记录 1 次光盘行动',
    periodType: TaskPeriodType.DAILY, ruleType: TaskRuleType.FOOD_RECORD_COUNT, target: 1, points: 10, enabled: true },
  { id: 'daily_reduction_1kg', version: '1', title: '今日减排 1 千克', description: '当天累计减排量达到 1 kg CO₂e',
    periodType: TaskPeriodType.DAILY, ruleType: TaskRuleType.TOTAL_REDUCTION_GRAMS, target: 1000, points: 25, enabled: true }
];
const REWARDS: RewardDefinition[] = [
  { id: 'badge_first_step', version: '1', type: RewardType.BADGE, title: '绿色第一步',
    description: '应用内虚拟徽章，纪念一次绿色选择。', costPoints: 10 },
  { id: 'certificate_virtual_tree', version: '1', type: RewardType.VIRTUAL_CERTIFICATE, title: '绿色心愿证书',
    description: '应用内虚拟植树证书，不代表实际植树。', costPoints: 30 }
];

function copy<T>(value: T): T { return JSON.parse(JSON.stringify(value)) as T; }

function requireRequest(requestId: string): void {
  if (typeof requestId !== 'string' || requestId.length === 0) {
    throw new AppError(ErrorCode.INVALID_INPUT, '请求标识不能为空。');
  }
}

function taskDefinition(id: string): TaskDefinition {
  const definition = TASKS.find((task: TaskDefinition) => task.id === id);
  if (definition === undefined) { throw new AppError(ErrorCode.INVALID_INPUT, '没有找到该任务。'); }
  return definition;
}

function rewardDefinition(id: string): RewardDefinition {
  const reward = REWARDS.find((item: RewardDefinition) => item.id === id);
  if (reward === undefined) { throw new AppError(ErrorCode.INVALID_INPUT, '没有找到该奖励。'); }
  return reward;
}

function taskProgress(definition: TaskDefinition, date: LocalDate, records: BehaviorRecord[],
  state: TaskRewardState | null): TaskProgress {
  const categories: Category[] = [];
  let count = 0;
  let travelKm = 0;
  let foodCount = 0;
  let positiveGrams = 0;
  records.forEach((record: BehaviorRecord) => {
    if (record.status === RecordStatus.ACTIVE && record.businessDate === date && record.reductionGrams > 0) {
      count += 1;
      positiveGrams += record.reductionGrams;
      if (categories.indexOf(record.category) < 0) { categories.push(record.category); }
      if (record.category === Category.TRAVEL && record.unit === QuantityUnit.KM) { travelKm += record.quantity; }
      if (record.category === Category.FOOD) { foodCount += 1; }
    }
  });
  const effective = state === null ? definition : state.definitionSnapshot;
  let current = count;
  if (effective.ruleType === TaskRuleType.POSITIVE_CATEGORY_COUNT) {
    current = categories.length;
  } else if (effective.ruleType === TaskRuleType.TRAVEL_KM_SUM) {
    current = Math.round(travelKm * 10) / 10;
  } else if (effective.ruleType === TaskRuleType.FOOD_RECORD_COUNT) {
    current = foodCount;
  } else if (effective.ruleType === TaskRuleType.TOTAL_REDUCTION_GRAMS) {
    current = positiveGrams;
  }
  return { definition: copy(effective), periodKey: date, current: current, target: effective.target,
    eligible: current >= effective.target, claimed: state !== null && state.everClaimed,
    earnedPoints: state === null ? 0 : state.netGrantedPoints };
}

function priorTask(operation: IdempotencyOperation, fingerprint: string): TaskProgress {
  if (operation.operationType !== OperationType.CLAIM_TASK || operation.inputFingerprint !== fingerprint ||
    operation.result.taskProgress === null) {
    throw new AppError(ErrorCode.IDEMPOTENCY_CONFLICT, '请求标识已用于其他操作。');
  }
  return operation.result.taskProgress;
}

function priorRedemption(operation: IdempotencyOperation, fingerprint: string): Redemption {
  if (operation.operationType !== OperationType.REDEEM_REWARD || operation.inputFingerprint !== fingerprint ||
    operation.result.redemption === null) {
    throw new AppError(ErrorCode.IDEMPOTENCY_CONFLICT, '请求标识已用于其他操作。');
  }
  return operation.result.redemption;
}

export class EngagementServiceImpl implements TaskService, PointsService, RewardService {
  private readonly gateway: PersistenceGateway;
  private readonly services: AppServices;
  constructor(gateway: PersistenceGateway, services: AppServices) { this.gateway = gateway; this.services = services; }

  async listForDate(date: LocalDate): Promise<TaskProgress[]> {
    requireLocalDate(date);
    const snapshot = await this.gateway.read.getFullSnapshot();
    return TASKS.map((definition: TaskDefinition): TaskProgress => {
      const state = snapshot.taskRewardStates.find((item: TaskRewardState) => item.taskId === definition.id && item.periodKey === date);
      return taskProgress(definition, date, snapshot.records, state === undefined ? null : state);
    });
  }

  async claim(taskId: string, date: LocalDate, requestId: string): Promise<TaskProgress> {
    requireRequest(requestId);
    const fingerprint = JSON.stringify([taskId, date]);
    const existing = await this.gateway.read.operations.getByRequestId(requestId);
    if (existing !== null) { return priorTask(existing, fingerprint); }
    requireLocalDate(date);
    if (date !== this.services.clock.today()) {
      throw new AppError(ErrorCode.INVALID_TASK_PERIOD, '只能领取今天完成的任务。');
    }
    const definition = taskDefinition(taskId);
    const now = this.services.clock.nowMs();
    let inserted = false;
    const result = await this.gateway.runInTransaction(async (tx): Promise<TaskProgress> => {
      const prior = await tx.operations.getByRequestId(requestId);
      if (prior !== null) { return priorTask(prior, fingerprint); }
      const state = await tx.taskStates.get(taskId, date);
      const records = await tx.records.getActiveSnapshot({ startDateInclusive: date,
        endDateExclusive: addDays(date, 1), category: null, keyword: null });
      const progress = taskProgress(definition, date, records, state);
      if (state !== null && state.everClaimed) {
        throw new AppError(ErrorCode.TASK_NOT_ELIGIBLE, '今天已领取过这项任务。');
      }
      if (!progress.eligible) { throw new AppError(ErrorCode.TASK_NOT_ELIGIBLE, '完成任务后即可领取。'); }
      const newState: TaskRewardState = { taskId: taskId, periodKey: date, definitionSnapshot: copy(definition),
        everClaimed: true, netGrantedPoints: definition.points, transitionSequence: 1 };
      const entry: PointLedgerEntry = { id: this.services.ids.newId(), delta: definition.points, reason: PointReason.TASK_REWARD,
        sourceKey: `task:${taskId}:${date}:1`, relatedRecordId: null, relatedTaskId: taskId, periodKey: date, createdAt: now };
      const claimed = taskProgress(definition, date, records, newState);
      await tx.taskStates.insert(newState);
      await tx.points.insert(entry);
      await tx.operations.insert({ requestId: requestId, operationType: OperationType.CLAIM_TASK, inputFingerprint: fingerprint,
        status: OperationStatus.COMMITTED, result: { record: null, taskProgress: claimed, redemption: null, restoreSummary: null }, committedAt: now });
      inserted = true;
      return claimed;
    });
    if (inserted) { this.services.changes.notifyDataChanged(); }
    return result;
  }

  async getBalance(): Promise<number> { return await this.gateway.read.points.getBalance(); }
  async listLedger(offset: number, limit: number): Promise<PointLedgerEntry[]> {
    return await this.gateway.read.points.listLedger(offset, limit);
  }
  async listRewards(): Promise<RewardDefinition[]> { return copy(REWARDS); }
  async listRedemptions(): Promise<Redemption[]> { return await this.gateway.read.redemptions.list(); }

  async redeem(rewardId: string, requestId: string): Promise<Redemption> {
    requireRequest(requestId);
    const fingerprint = JSON.stringify([rewardId]);
    const existing = await this.gateway.read.operations.getByRequestId(requestId);
    if (existing !== null) { return priorRedemption(existing, fingerprint); }
    const reward = rewardDefinition(rewardId);
    const now = this.services.clock.nowMs();
    let inserted = false;
    const result = await this.gateway.runInTransaction(async (tx): Promise<Redemption> => {
      const prior = await tx.operations.getByRequestId(requestId);
      if (prior !== null) { return priorRedemption(prior, fingerprint); }
      if (await tx.redemptions.getByRewardId(rewardId) !== null) {
        throw new AppError(ErrorCode.ALREADY_REDEEMED, '该奖励已经兑换。');
      }
      const balance = await tx.points.getBalance();
      if (balance < reward.costPoints) { throw new AppError(ErrorCode.INSUFFICIENT_POINTS, '积分不足，继续完成任务吧。'); }
      const redemption: Redemption = { id: this.services.ids.newId(), rewardId: rewardId, rewardSnapshot: copy(reward),
        costPoints: reward.costPoints, createdAt: now, requestId: requestId };
      const entry: PointLedgerEntry = { id: this.services.ids.newId(), delta: -reward.costPoints,
        reason: PointReason.REDEMPTION, sourceKey: `redeem:${rewardId}`, relatedRecordId: null, relatedTaskId: null,
        periodKey: null, createdAt: now };
      await tx.redemptions.insert(redemption);
      await tx.points.insert(entry);
      await tx.operations.insert({ requestId: requestId, operationType: OperationType.REDEEM_REWARD,
        inputFingerprint: fingerprint, status: OperationStatus.COMMITTED,
        result: { record: null, taskProgress: null, redemption: redemption, restoreSummary: null }, committedAt: now });
      inserted = true;
      return redemption;
    });
    if (inserted) { this.services.changes.notifyDataChanged(); }
    return result;
  }
}
