import { Id, TimestampMs, RequestId } from './Common';

export enum PointReason {
  TASK_REWARD = 'task_reward',
  REVOCATION_ADJUSTMENT = 'revocation_adjustment',
  REDEMPTION = 'redemption'
}

export interface PointLedgerEntry {
  id: Id;
  delta: number;
  reason: PointReason;
  sourceKey: string;
  relatedRecordId: Id | null;
  relatedTaskId: Id | null;
  periodKey: string | null;
  createdAt: TimestampMs;
}

export enum TaskPeriodType {
  DAILY = 'daily'
}

export enum TaskRuleType {
  POSITIVE_RECORD_COUNT = 'positive_record_count',
  POSITIVE_CATEGORY_COUNT = 'positive_category_count',
  TRAVEL_KM_SUM = 'travel_km_sum',
  FOOD_RECORD_COUNT = 'food_record_count',
  TOTAL_REDUCTION_GRAMS = 'total_reduction_grams'
}

export interface TaskDefinition {
  id: Id;
  version: string;
  title: string;
  description: string;
  periodType: TaskPeriodType;
  ruleType: TaskRuleType;
  target: number;
  points: number;
  enabled: boolean;
}

export interface TaskProgress {
  definition: TaskDefinition;
  periodKey: string;
  current: number;
  target: number;
  eligible: boolean;
  claimed: boolean;
  earnedPoints: number;
}

export interface TaskRewardState {
  taskId: Id;
  periodKey: string;
  definitionSnapshot: TaskDefinition;
  everClaimed: boolean;
  netGrantedPoints: number;
  transitionSequence: number;
}

export enum RewardType {
  BADGE = 'badge',
  VIRTUAL_CERTIFICATE = 'virtual_certificate'
}

export interface RewardDefinition {
  id: Id;
  version: string;
  type: RewardType;
  title: string;
  description: string;
  costPoints: number;
}

export interface Redemption {
  id: Id;
  rewardId: Id;
  rewardSnapshot: RewardDefinition;
  costPoints: number;
  createdAt: TimestampMs;
  requestId: RequestId;
}
