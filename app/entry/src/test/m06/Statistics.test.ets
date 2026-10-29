import { describe, it, expect } from '@ohos/hypium';
import { aggregateStatistics } from '../../main/ets/application/core/StatisticsServiceImpl';
import { Category, QuantityUnit, StatisticsPeriod } from '../../main/ets/common/contracts/Common';
import { CalculationMode, CalculationRule } from '../../main/ets/common/contracts/Calculation';
import { BehaviorRecord, RecordStatus } from '../../main/ets/common/contracts/Records';
import { StatisticsQuery, StatisticsReport } from '../../main/ets/common/contracts/Statistics';
import { reportToCsv } from '../../main/ets/features/dataTransfer/CsvReport';

function record(id: string, date: string, category: Category, grams: number, status: RecordStatus): BehaviorRecord {
  const rule: CalculationRule = { id: 'test', version: '1', category: category, name: 'test', inputUnit: QuantityUnit.KWH,
    minQuantity: 0, maxQuantity: 100, mode: CalculationMode.DIRECT_REDUCTION, reductionFactorId: 'test',
    baselineFactorId: null, actualFactorId: null, baselineLabel: '', actualLabel: '', assumptions: [], confirmationText: '' };
  return { id: id, createdByRequestId: id, businessDate: date, category: category, ruleId: 'test', ruleVersion: '1',
    quantity: 1, unit: QuantityUnit.KWH, note: '', baselineConfirmed: true, reductionGrams: grams,
    formulaText: 'test', factorSnapshot: { rule: rule, factors: [] }, createdAt: 0, updatedAt: 0, status: status };
}

export default function statisticsTest(): void {
  describe('StatisticsAggregation', () => {
    it('usesCalendarWeekAndSeparatesPositiveFromNet', 0, () => {
      const records: BehaviorRecord[] = [
        record('a', '2024-02-26', Category.ENERGY_WATER, 500, RecordStatus.ACTIVE),
        record('b', '2024-02-29', Category.ENERGY_WATER, -100, RecordStatus.ACTIVE),
        record('c', '2024-03-03', Category.FOOD, 50, RecordStatus.ACTIVE),
        record('d', '2024-03-04', Category.FOOD, 999, RecordStatus.ACTIVE),
        record('e', '2024-02-28', Category.FOOD, 999, RecordStatus.VOIDED)
      ];
      const result = aggregateStatistics({ period: StatisticsPeriod.WEEK, anchorDate: '2024-02-29', category: null }, records);
      expect(result.startDateInclusive).assertEqual('2024-02-26');
      expect(result.endDateExclusive).assertEqual('2024-03-04');
      expect(result.recordCount).assertEqual(3);
      expect(result.totalReductionGrams).assertEqual(450);
      expect(result.buckets.length).assertEqual(7);
      expect(result.buckets[3].reductionGrams).assertEqual(-100);
      expect(result.categories[0].positiveReductionGrams).assertEqual(500);
      expect(result.categories[0].reductionGrams).assertEqual(400);
      const filtered = aggregateStatistics({ period: StatisticsPeriod.WEEK, anchorDate: '2024-02-29', category: Category.FOOD }, records);
      expect(filtered.totalReductionGrams).assertEqual(50);
      expect(filtered.recordCount).assertEqual(1);
    });
    it('padsLeapMonthAndYearBuckets', 0, () => {
      const records: BehaviorRecord[] = [record('a', '2024-02-29', Category.FOOD, 10, RecordStatus.ACTIVE)];
      const month = aggregateStatistics({ period: StatisticsPeriod.MONTH, anchorDate: '2024-02-02', category: null }, records);
      expect(month.buckets.length).assertEqual(29);
      expect(month.buckets[28].reductionGrams).assertEqual(10);
      const year = aggregateStatistics({ period: StatisticsPeriod.YEAR, anchorDate: '2024-02-29', category: null }, records);
      expect(year.buckets.length).assertEqual(12);
      expect(year.buckets[1].reductionGrams).assertEqual(10);
      expect(year.buckets[0].reductionGrams).assertEqual(0);
    });
    it('exportsEscapedCsvFromTheSameSnapshot', 0, () => {
      const item = record('csv', '2024-02-29', Category.FOOD, -10, RecordStatus.ACTIVE);
      item.note = '=1+1, "测试"\n下一行';
      const records: BehaviorRecord[] = [item];
      const query: StatisticsQuery = { period: StatisticsPeriod.MONTH, anchorDate: '2024-02-29', category: null };
      const report: StatisticsReport = { query: query, records: records,
        statistics: aggregateStatistics(query, records), snapshotAt: 0 };
      const csv = reportToCsv(report);
      expect(csv.startsWith('\uFEFF')).assertTrue();
      expect(csv.indexOf('"\'=1+1, ""测试""\n下一行"') >= 0).assertTrue();
      expect(csv.indexOf('"净减排合计(克)",-10') >= 0).assertTrue();
      expect(csv.indexOf('"2024-03-01（不含结束日）"') >= 0).assertTrue();
    });
  });
}
