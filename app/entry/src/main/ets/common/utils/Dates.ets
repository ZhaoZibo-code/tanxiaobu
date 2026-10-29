import { DateRange, LocalDate, StatisticsPeriod } from '../contracts/Common';
import { AppError, ErrorCode } from '../errors/AppError';

function isLeapYear(year: number): boolean {
  return year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
}

function monthDays(year: number, month: number): number {
  if (month === 2) {
    return isLeapYear(year) ? 29 : 28;
  }
  return [4, 6, 9, 11].indexOf(month) >= 0 ? 30 : 31;
}

export function isValidLocalDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }
  const year = Number(value.substring(0, 4));
  const month = Number(value.substring(5, 7));
  const day = Number(value.substring(8, 10));
  return year >= 1 && year <= 9999 && month >= 1 && month <= 12 &&
    day >= 1 && day <= monthDays(year, month);
}

export function requireLocalDate(value: string): LocalDate {
  if (!isValidLocalDate(value)) {
    throw new AppError(ErrorCode.INVALID_INPUT, '日期须为有效的 YYYY-MM-DD。');
  }
  return value;
}

function pad(value: number, length: number): string {
  return value.toString().padStart(length, '0');
}

function formatParts(year: number, month: number, day: number): LocalDate {
  return requireLocalDate(`${pad(year, 4)}-${pad(month, 2)}-${pad(day, 2)}`);
}

export function localDateFromDate(date: Date): LocalDate {
  if (!Number.isFinite(date.getTime())) {
    throw new AppError(ErrorCode.INVALID_INPUT, '无效的时间。');
  }
  return formatParts(date.getFullYear(), date.getMonth() + 1, date.getDate());
}

function calendarDate(value: LocalDate): Date {
  requireLocalDate(value);
  // UTC is only an internal calendar carrier, never a conversion from business-local time.
  const date = new Date(0);
  date.setUTCFullYear(Number(value.substring(0, 4)), Number(value.substring(5, 7)) - 1,
    Number(value.substring(8, 10)));
  return date;
}

export function addDays(value: LocalDate, days: number): LocalDate {
  if (!Number.isSafeInteger(days)) {
    throw new AppError(ErrorCode.INVALID_INPUT, '日期偏移必须是安全整数。');
  }
  const date = calendarDate(value);
  date.setUTCDate(date.getUTCDate() + days);
  if (!Number.isFinite(date.getTime())) {
    throw new AppError(ErrorCode.INVALID_INPUT, '日期偏移超出支持范围。');
  }
  return formatParts(date.getUTCFullYear(), date.getUTCMonth() + 1, date.getUTCDate());
}

export function startOfWeek(value: LocalDate): LocalDate {
  const weekday = calendarDate(value).getUTCDay();
  return addDays(value, -(weekday === 0 ? 6 : weekday - 1));
}

export function dateRange(period: StatisticsPeriod, anchor: LocalDate): DateRange {
  requireLocalDate(anchor);
  const year = Number(anchor.substring(0, 4));
  const month = Number(anchor.substring(5, 7));
  switch (period) {
    case StatisticsPeriod.DAY:
      return { startDateInclusive: anchor, endDateExclusive: addDays(anchor, 1) };
    case StatisticsPeriod.WEEK:
      const monday = startOfWeek(anchor);
      return { startDateInclusive: monday, endDateExclusive: addDays(monday, 7) };
    case StatisticsPeriod.MONTH:
      return {
        startDateInclusive: formatParts(year, month, 1),
        endDateExclusive: formatParts(month === 12 ? year + 1 : year, month === 12 ? 1 : month + 1, 1)
      };
    case StatisticsPeriod.YEAR:
      return { startDateInclusive: formatParts(year, 1, 1), endDateExclusive: formatParts(year + 1, 1, 1) };
    default:
      throw new AppError(ErrorCode.INVALID_INPUT, '不支持的统计周期。');
  }
}

export function requireDateRange(range: DateRange): DateRange {
  requireLocalDate(range.startDateInclusive);
  requireLocalDate(range.endDateExclusive);
  if (range.startDateInclusive >= range.endDateExclusive) {
    throw new AppError(ErrorCode.INVALID_INPUT, '结束日期必须晚于开始日期。');
  }
  return range;
}

export function isInDateRange(value: LocalDate, range: DateRange): boolean {
  requireLocalDate(value);
  requireDateRange(range);
  return value >= range.startDateInclusive && value < range.endDateExclusive;
}
