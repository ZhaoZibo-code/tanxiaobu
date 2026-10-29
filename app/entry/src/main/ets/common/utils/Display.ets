import { Category, QuantityUnit } from '../contracts/Common';
import { AppError, ErrorCode } from '../errors/AppError';

export function requireInteger(value: number): number {
  if (!Number.isSafeInteger(value)) {
    throw new AppError(ErrorCode.INVALID_INPUT, '数值必须为安全整数。');
  }
  return value === 0 ? 0 : value;
}

export function roundReductionGrams(value: number): number {
  if (!Number.isFinite(value)) {
    throw new AppError(ErrorCode.INVALID_INPUT, '减排估算必须为有限数值。');
  }
  // Apply the same tie rule to both signs; do not turn a negative result into positive savings.
  const rounded = value < 0 ? -Math.round(-value) : Math.round(value);
  return requireInteger(rounded);
}

export function formatReduction(grams: number): string {
  requireInteger(grams);
  if (Math.abs(grams) < 1000) {
    return `${grams === 0 ? 0 : grams} g CO₂e`;
  }
  return `${(grams / 1000).toFixed(2)} kg CO₂e`;
}

export function unitLabel(unit: QuantityUnit): string {
  switch (unit) {
    case QuantityUnit.KM: return '公里';
    case QuantityUnit.KWH: return '千瓦时';
    case QuantityUnit.LITRE: return '升';
    case QuantityUnit.KG: return '千克';
    case QuantityUnit.PORTION: return '份';
    default: throw new AppError(ErrorCode.INVALID_INPUT, '不支持的数量单位。');
  }
}

export function formatQuantity(quantity: number, unit: QuantityUnit): string {
  if (!Number.isFinite(quantity)) {
    throw new AppError(ErrorCode.INVALID_INPUT, '数量必须为有限数值。');
  }
  const text = quantity.toFixed(3).replace(/\.?0+$/, '');
  return `${text === '-0' ? '0' : text} ${unitLabel(unit)}`;
}

export function categoryLabel(category: Category): string {
  switch (category) {
    case Category.TRAVEL: return '出行';
    case Category.ENERGY_WATER: return '节水节电';
    case Category.RECYCLING: return '回收';
    case Category.FOOD: return '光盘行动';
    default: throw new AppError(ErrorCode.INVALID_INPUT, '不支持的行为分类。');
  }
}
