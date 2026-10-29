import { describe, it, expect } from '@ohos/hypium';
import { QuantityUnit, StatisticsPeriod } from '../../main/ets/common/contracts/Common';
import { addDays, dateRange, isInDateRange, isValidLocalDate, localDateFromDate,
  requireDateRange, requireLocalDate, startOfWeek } from '../../main/ets/common/utils/Dates';
import { formatQuantity, formatReduction, requireInteger, roundReductionGrams,
  unitLabel } from '../../main/ets/common/utils/Display';
import { AppError, ErrorCode, toAppError } from '../../main/ets/common/errors/AppError';

function expectInvalid(work: () => void): void {
  let code: string = '';
  try {
    work();
  } catch (error) {
    code = (error as AppError).code;
  }
  expect(code).assertEqual(ErrorCode.INVALID_INPUT);
}

export default function toolsTest(): void {
  describe('M01Tools', () => {
    it('validatesGregorianLeapDates', 0, () => {
      expect(isValidLocalDate('2000-02-29')).assertTrue();
      expect(isValidLocalDate('2024-02-29')).assertTrue();
      expect(isValidLocalDate('1900-02-29')).assertFalse();
      expect(isValidLocalDate('2023-02-29')).assertFalse();
      expect(isValidLocalDate('0001-01-01')).assertTrue();
      expect(isValidLocalDate('0000-01-01')).assertFalse();
      expect(isValidLocalDate('2026-04-31')).assertFalse();
      expect(isValidLocalDate('2026-13-01')).assertFalse();
      expect(isValidLocalDate('2026-01-00')).assertFalse();
      expect(isValidLocalDate('2026-1-01')).assertFalse();
      expect(isValidLocalDate(' 2026-01-01')).assertFalse();
      expect(isValidLocalDate('2026-01-01T00:00:00Z')).assertFalse();
      expectInvalid(() => { requireLocalDate('not-a-date'); });
    });

    it('addsCalendarDaysAcrossYearAndLeapDay', 0, () => {
      expect(addDays('2023-12-31', 1)).assertEqual('2024-01-01');
      expect(addDays('2024-03-01', -1)).assertEqual('2024-02-29');
      expect(addDays('1900-02-28', 1)).assertEqual('1900-03-01');
      expect(addDays('0099-12-31', 1)).assertEqual('0100-01-01');
      expect(addDays('2026-10-27', 0)).assertEqual('2026-10-27');
      expectInvalid(() => { addDays('2026-01-01', 1.5); });
      expectInvalid(() => { addDays('9999-12-31', 1); });
      expectInvalid(() => { addDays('0001-01-01', -1); });
    });

    it('startsWeeksOnMondayIncludingSundayAndCrossYear', 0, () => {
      expect(startOfWeek('2026-10-26')).assertEqual('2026-10-26');
      expect(startOfWeek('2026-11-01')).assertEqual('2026-10-26');
      expect(startOfWeek('2021-01-01')).assertEqual('2020-12-28');
      const range = dateRange(StatisticsPeriod.WEEK, '2021-01-01');
      expect(range.startDateInclusive).assertEqual('2020-12-28');
      expect(range.endDateExclusive).assertEqual('2021-01-04');
    });

    it('returnsHalfOpenDayMonthYearRanges', 0, () => {
      const day = dateRange(StatisticsPeriod.DAY, '2024-02-29');
      expect(day.startDateInclusive).assertEqual('2024-02-29');
      expect(day.endDateExclusive).assertEqual('2024-03-01');
      const month = dateRange(StatisticsPeriod.MONTH, '2024-02-18');
      expect(month.startDateInclusive).assertEqual('2024-02-01');
      expect(month.endDateExclusive).assertEqual('2024-03-01');
      const december = dateRange(StatisticsPeriod.MONTH, '2026-12-31');
      expect(december.endDateExclusive).assertEqual('2027-01-01');
      const year = dateRange(StatisticsPeriod.YEAR, '2024-08-01');
      expect(year.startDateInclusive).assertEqual('2024-01-01');
      expect(year.endDateExclusive).assertEqual('2025-01-01');
      expect(isInDateRange('2024-02-01', month)).assertTrue();
      expect(isInDateRange('2024-02-29', month)).assertTrue();
      expect(isInDateRange('2024-03-01', month)).assertFalse();
      expectInvalid(() => { requireDateRange({ startDateInclusive: '2026-01-01', endDateExclusive: '2026-01-01' }); });
      expectInvalid(() => { requireDateRange({ startDateInclusive: '2026-02-01', endDateExclusive: '2026-01-01' }); });
    });

    it('derivesBusinessDayFromLocalCalendarFields', 0, () => {
      const date = new Date(2026, 9, 27, 0, 5);
      expect(localDateFromDate(date)).assertEqual('2026-10-27');
      expectInvalid(() => { localDateFromDate(new Date(Number.NaN)); });
    });

    it('roundsOnlyTheFinalSignedGramResult', 0, () => {
      expect(roundReductionGrams(0.49)).assertEqual(0);
      expect(roundReductionGrams(0.5)).assertEqual(1);
      expect(roundReductionGrams(-0.5)).assertEqual(-1);
      expect(roundReductionGrams(-12.6)).assertEqual(-13);
      expect(roundReductionGrams(1.2 + 1.2)).assertEqual(2);
      expectInvalid(() => { roundReductionGrams(Number.POSITIVE_INFINITY); });
      expectInvalid(() => { roundReductionGrams(Number.NaN); });
      expectInvalid(() => { requireInteger(9007199254740992); });
      expectInvalid(() => { requireInteger(1.2); });
    });

    it('formatsSignedGramsAndKilogramsWithoutChangingStorage', 0, () => {
      expect(formatReduction(0)).assertEqual('0 g CO₂e');
      expect(formatReduction(-0)).assertEqual('0 g CO₂e');
      expect(formatReduction(999)).assertEqual('999 g CO₂e');
      expect(formatReduction(-999)).assertEqual('-999 g CO₂e');
      expect(formatReduction(1000)).assertEqual('1.00 kg CO₂e');
      expect(formatReduction(-1250)).assertEqual('-1.25 kg CO₂e');
      expect(formatReduction(123456)).assertEqual('123.46 kg CO₂e');
      expectInvalid(() => { formatReduction(0.5); });
    });

    it('formatsQuantityAndExplicitUnits', 0, () => {
      expect(formatQuantity(100, QuantityUnit.KM)).assertEqual('100 公里');
      expect(formatQuantity(1.23456, QuantityUnit.KWH)).assertEqual('1.235 千瓦时');
      expect(formatQuantity(0, QuantityUnit.LITRE)).assertEqual('0 升');
      expect(formatQuantity(-0.0001, QuantityUnit.KG)).assertEqual('0 千克');
      expect(unitLabel(QuantityUnit.PORTION)).assertEqual('份');
      expectInvalid(() => { formatQuantity(Number.NaN, QuantityUnit.KM); });
    });

    it('preservesPublicErrorsAndSanitizesUnexpectedErrors', 0, () => {
      const expected = new AppError(ErrorCode.BACKUP_CHANGED, '请重新预览。');
      expect(toAppError(expected).code).assertEqual(ErrorCode.BACKUP_CHANGED);
      expect(toAppError(expected).message).assertEqual('请重新预览。');
      const mapped = toAppError(new Error('technical file path'));
      expect(mapped.code).assertEqual(ErrorCode.STORAGE_FAILED);
      expect(mapped.retryable).assertTrue();
      expect(mapped.message).assertEqual('操作未完成，请稍后重试。');
    });
  });
}
