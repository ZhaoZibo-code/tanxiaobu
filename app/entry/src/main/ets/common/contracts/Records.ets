import { Category, Id, LocalDate, QuantityUnit, RequestId, TimestampMs } from './Common';
import { FactorSnapshot } from './Calculation';

export enum RecordStatus {
  ACTIVE = 'active',
  VOIDED = 'voided'
}

export interface BehaviorRecord {
  id: Id;
  createdByRequestId: RequestId;
  businessDate: LocalDate;
  category: Category;
  ruleId: Id;
  ruleVersion: string;
  quantity: number;
  unit: QuantityUnit;
  note: string;
  baselineConfirmed: boolean;
  reductionGrams: number;
  formulaText: string;
  factorSnapshot: FactorSnapshot;
  createdAt: TimestampMs;
  updatedAt: TimestampMs;
  status: RecordStatus;
}

export interface RecordFilter {
  startDateInclusive: LocalDate | null;
  endDateExclusive: LocalDate | null;
  category: Category | null;
  keyword: string | null;
}

export interface RecordQuery extends RecordFilter {
  offset: number;
  limit: number;
}

export interface RecordPage {
  items: BehaviorRecord[];
  total: number;
  offset: number;
  limit: number;
}
