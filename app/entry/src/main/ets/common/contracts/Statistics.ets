import { Category, LocalDate, StatisticsPeriod, TimestampMs } from './Common';
import { BehaviorRecord } from './Records';

export interface StatisticsQuery {
  period: StatisticsPeriod;
  anchorDate: LocalDate;
  category: Category | null;
}

export interface StatisticsItem {
  key: string;
  label: string;
  reductionGrams: number;
  positiveReductionGrams: number;
  recordCount: number;
}

export interface StatisticsResult {
  query: StatisticsQuery;
  startDateInclusive: LocalDate;
  endDateExclusive: LocalDate;
  totalReductionGrams: number;
  recordCount: number;
  buckets: StatisticsItem[];
  categories: StatisticsItem[];
}

export interface StatisticsReport {
  query: StatisticsQuery;
  records: BehaviorRecord[];
  statistics: StatisticsResult;
  snapshotAt: TimestampMs;
}
