export type Id = string;
export type RequestId = string;
export type LocalDate = string;
export type TimestampMs = number;

export enum Category {
  TRAVEL = 'travel',
  ENERGY_WATER = 'energy_water',
  RECYCLING = 'recycling',
  FOOD = 'food'
}

export enum QuantityUnit {
  KM = 'km',
  KWH = 'kWh',
  LITRE = 'L',
  KG = 'kg',
  PORTION = 'portion'
}

export enum StatisticsPeriod {
  DAY = 'day',
  WEEK = 'week',
  MONTH = 'month',
  YEAR = 'year'
}

export interface DateRange {
  startDateInclusive: LocalDate;
  endDateExclusive: LocalDate;
}

export interface Clock {
  nowMs(): TimestampMs;
  today(): LocalDate;
}

export interface IdGenerator {
  newId(): Id;
}

export type ChangeListener = () => void;
export type Unsubscribe = () => void;

export interface ChangeNotifier {
  subscribe(listener: ChangeListener): Unsubscribe;
  notifyDataChanged(): void;
}
