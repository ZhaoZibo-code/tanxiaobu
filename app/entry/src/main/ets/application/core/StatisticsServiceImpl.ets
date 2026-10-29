import { Category, DateRange, StatisticsPeriod } from '../../common/contracts/Common';
import { BehaviorRecord, RecordStatus } from '../../common/contracts/Records';
import { PersistenceGateway } from '../../common/contracts/Persistence';
import { StatisticsService } from '../../common/contracts/Services';
import { StatisticsItem, StatisticsQuery, StatisticsReport, StatisticsResult } from '../../common/contracts/Statistics';
import { addDays, dateRange } from '../../common/utils/Dates';
import { categoryLabel, requireInteger } from '../../common/utils/Display';

function emptyItem(key: string, label: string): StatisticsItem {
  return { key: key, label: label, reductionGrams: 0, positiveReductionGrams: 0, recordCount: 0 };
}

function addRecord(item: StatisticsItem, grams: number): void {
  item.reductionGrams = requireInteger(item.reductionGrams + grams);
  if (grams > 0) {
    item.positiveReductionGrams = requireInteger(item.positiveReductionGrams + grams);
  }
  item.recordCount += 1;
}

export function aggregateStatistics(query: StatisticsQuery, records: BehaviorRecord[]): StatisticsResult {
  const range: DateRange = dateRange(query.period, query.anchorDate);
  const buckets: StatisticsItem[] = [];
  if (query.period === StatisticsPeriod.YEAR) {
    for (let month = 1; month <= 12; month++) {
      const key = `${range.startDateInclusive.substring(0, 4)}-${month.toString().padStart(2, '0')}`;
      buckets.push(emptyItem(key, `${month}月`));
    }
  } else {
    let date = range.startDateInclusive;
    while (date < range.endDateExclusive) {
      buckets.push(emptyItem(date, `${Number(date.substring(5, 7))}/${Number(date.substring(8, 10))}`));
      date = addDays(date, 1);
    }
  }
  const allCategories: Category[] = [Category.ENERGY_WATER, Category.TRAVEL, Category.FOOD, Category.RECYCLING];
  const categories: StatisticsItem[] = allCategories.map((category: Category): StatisticsItem =>
    emptyItem(category, categoryLabel(category)));
  let total = 0;
  let count = 0;
  for (const record of records) {
    if (record.status !== RecordStatus.ACTIVE || record.businessDate < range.startDateInclusive ||
      record.businessDate >= range.endDateExclusive || (query.category !== null && record.category !== query.category)) {
      continue;
    }
    const grams = requireInteger(record.reductionGrams);
    total = requireInteger(total + grams);
    count += 1;
    const bucketKey = query.period === StatisticsPeriod.YEAR ? record.businessDate.substring(0, 7) : record.businessDate;
    const bucket = buckets.find((item: StatisticsItem) => item.key === bucketKey);
    const category = categories.find((item: StatisticsItem) => item.key === record.category);
    if (bucket !== undefined) { addRecord(bucket, grams); }
    if (category !== undefined) { addRecord(category, grams); }
  }
  return { query: query, startDateInclusive: range.startDateInclusive, endDateExclusive: range.endDateExclusive,
    totalReductionGrams: total, recordCount: count, buckets: buckets, categories: categories };
}

export class StatisticsServiceImpl implements StatisticsService {
  private readonly gateway: () => Promise<PersistenceGateway>;
  private readonly now: () => number;

  constructor(gateway: () => Promise<PersistenceGateway>, now: () => number) {
    this.gateway = gateway;
    this.now = now;
  }

  async createReport(query: StatisticsQuery): Promise<StatisticsReport> {
    const range = dateRange(query.period, query.anchorDate);
    const gateway = await this.gateway();
    const records = await gateway.read.records.getActiveSnapshot({ startDateInclusive: range.startDateInclusive,
      endDateExclusive: range.endDateExclusive, category: query.category, keyword: null });
    return { query: query, records: records, statistics: aggregateStatistics(query, records), snapshotAt: this.now() };
  }

  async query(query: StatisticsQuery): Promise<StatisticsResult> {
    return (await this.createReport(query)).statistics;
  }
}
