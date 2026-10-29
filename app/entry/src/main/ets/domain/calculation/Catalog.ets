import { Category, QuantityUnit } from '../../common/contracts/Common';
import { CalculationMode, CalculationRule, EvidenceStatus, FactorDefinition,
  FactorSource } from '../../common/contracts/Calculation';
import { AppError, ErrorCode } from '../../common/errors/AppError';
import { isValidLocalDate } from '../../common/utils/Dates';

export interface CalculationCatalog {
  schemaVersion: number;
  version: string;
  factors: FactorDefinition[];
  rules: CalculationRule[];
}

function requireCatalog(condition: boolean): void {
  if (!condition) {
    throw new AppError(ErrorCode.FACTOR_UNAVAILABLE, '核算规则资料无效或版本不受支持。');
  }
}

function nonempty(value: string): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

function validVersion(value: string): boolean {
  return typeof value === 'string' && /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(value);
}

function validStrings(values: string[]): boolean {
  return Array.isArray(values) && values.every((value: string): boolean => nonempty(value));
}

function validUnit(unit: QuantityUnit): boolean {
  return unit === QuantityUnit.KM || unit === QuantityUnit.KWH || unit === QuantityUnit.KG ||
    unit === QuantityUnit.LITRE || unit === QuantityUnit.PORTION;
}

function validCategory(category: Category): boolean {
  return category === Category.TRAVEL || category === Category.ENERGY_WATER ||
    category === Category.RECYCLING || category === Category.FOOD;
}

export function normalizeFactorGrams(value: number, originalUnit: string, unit: QuantityUnit): number {
  requireCatalog(typeof value === 'number' && Number.isFinite(value) && validUnit(unit));
  let multiplier: number = 0;
  if (originalUnit === `gCO2e/${unit}` || originalUnit === `gCO2/${unit}`) {
    multiplier = 1;
  } else if (originalUnit === `kgCO2e/${unit}` || originalUnit === `kgCO2/${unit}` ||
    (unit === QuantityUnit.KM && (originalUnit === 'kgCO2/PKM' || originalUnit === 'kgCO2e/PKM')) ||
    (unit === QuantityUnit.PORTION && originalUnit === 'kg碳减排量/portion')) {
    multiplier = 1000;
  }
  requireCatalog(multiplier > 0);
  const grams = value * multiplier;
  requireCatalog(Number.isFinite(grams) && Math.abs(grams) <= Number.MAX_SAFE_INTEGER);
  return grams === 0 ? 0 : grams;
}

function validateSource(source: FactorSource): void {
  requireCatalog(source !== null && typeof source === 'object' && !Array.isArray(source));
  requireCatalog(nonempty(source.title) && nonempty(source.publisher) && nonempty(source.region) &&
    nonempty(source.boundary) && nonempty(source.notes));
  requireCatalog(typeof source.url === 'string' && /^https:\/\/[^\s/]+\/.+/.test(source.url));
  requireCatalog(typeof source.retrievedDate === 'string' && isValidLocalDate(source.retrievedDate));
  requireCatalog(source.publishedDate === null ||
    (typeof source.publishedDate === 'string' && isValidLocalDate(source.publishedDate)));
  if (source.publishedDate !== null) {
    requireCatalog(source.publishedDate <= source.retrievedDate);
  }
}

function validateFactor(factor: FactorDefinition, documentedOnly: boolean): void {
  requireCatalog(factor !== null && typeof factor === 'object' && !Array.isArray(factor));
  requireCatalog(nonempty(factor.id) && validVersion(factor.version) && nonempty(factor.name));
  requireCatalog(validStrings(factor.assumptions));
  validateSource(factor.source);
  requireCatalog(factor.evidenceStatus === EvidenceStatus.DOCUMENTED ||
    factor.evidenceStatus === EvidenceStatus.DEVELOPMENT_FIXTURE);
  requireCatalog(!documentedOnly || factor.evidenceStatus === EvidenceStatus.DOCUMENTED);
  requireCatalog(typeof factor.gramsCo2ePerUnit === 'number' && Number.isFinite(factor.gramsCo2ePerUnit));
  const normalized = normalizeFactorGrams(factor.originalValue, factor.originalUnit, factor.unit);
  const conversionTolerance = Number.EPSILON * Math.max(Math.abs(normalized), Math.abs(factor.gramsCo2ePerUnit));
  requireCatalog(Math.abs(normalized - factor.gramsCo2ePerUnit) <= conversionTolerance);
}

export function referencedFactors(catalog: CalculationCatalog, rule: CalculationRule): FactorDefinition[] {
  const ids: string[] = [];
  if (rule.mode === CalculationMode.DIRECT_REDUCTION) {
    requireCatalog(typeof rule.reductionFactorId === 'string' && nonempty(rule.reductionFactorId) &&
      rule.baselineFactorId === null && rule.actualFactorId === null);
    ids.push(rule.reductionFactorId as string);
  } else {
    requireCatalog(rule.mode === CalculationMode.BASELINE_DIFFERENCE && rule.reductionFactorId === null &&
      typeof rule.baselineFactorId === 'string' && nonempty(rule.baselineFactorId) &&
      typeof rule.actualFactorId === 'string' && nonempty(rule.actualFactorId));
    ids.push(rule.baselineFactorId as string, rule.actualFactorId as string);
  }
  const factors: FactorDefinition[] = [];
  ids.forEach((id: string): void => {
    const factor = catalog.factors.find((item: FactorDefinition): boolean => item.id === id);
    requireCatalog(factor !== undefined);
    factors.push(factor as FactorDefinition);
  });
  return factors;
}

export function validateCatalog(catalog: CalculationCatalog, documentedOnly: boolean): void {
  requireCatalog(catalog !== null && typeof catalog === 'object' && !Array.isArray(catalog));
  requireCatalog(catalog.schemaVersion === 1 && validVersion(catalog.version));
  requireCatalog(Array.isArray(catalog.factors) && catalog.factors.length > 0 &&
    Array.isArray(catalog.rules) && catalog.rules.length > 0);
  const factorIds: string[] = [];
  catalog.factors.forEach((factor: FactorDefinition): void => {
    validateFactor(factor, documentedOnly);
    requireCatalog(!factorIds.includes(factor.id));
    factorIds.push(factor.id);
  });
  const ruleIds: string[] = [];
  catalog.rules.forEach((rule: CalculationRule): void => {
    requireCatalog(rule !== null && typeof rule === 'object' && !Array.isArray(rule));
    requireCatalog(nonempty(rule.id) && validVersion(rule.version) && nonempty(rule.name) &&
      validCategory(rule.category) && validUnit(rule.inputUnit));
    requireCatalog(typeof rule.minQuantity === 'number' && Number.isFinite(rule.minQuantity) &&
      typeof rule.maxQuantity === 'number' && Number.isFinite(rule.maxQuantity) &&
      rule.minQuantity >= 0 && rule.maxQuantity >= rule.minQuantity);
    requireCatalog(nonempty(rule.baselineLabel) && nonempty(rule.actualLabel) &&
      typeof rule.confirmationText === 'string' && validStrings(rule.assumptions));
    requireCatalog(!ruleIds.includes(rule.id));
    ruleIds.push(rule.id);
    const factors = referencedFactors(catalog, rule);
    factors.forEach((factor: FactorDefinition): void => {
      requireCatalog(factor.unit === rule.inputUnit);
    });
    if (rule.mode === CalculationMode.BASELINE_DIFFERENCE) {
      requireCatalog(nonempty(rule.confirmationText));
      requireCatalog(factors[0].source.region === factors[1].source.region &&
        factors[0].source.boundary === factors[1].source.boundary);
      requireCatalog(factors[0].originalUnit.includes('CO2e/') === factors[1].originalUnit.includes('CO2e/') &&
        factors[0].originalUnit.includes('CO2/') === factors[1].originalUnit.includes('CO2/'));
      requireCatalog(factors[0].gramsCo2ePerUnit >= 0 && factors[1].gramsCo2ePerUnit >= 0);
    }
  });
}

export function cloneRule(rule: CalculationRule): CalculationRule {
  return {
    id: rule.id, version: rule.version, category: rule.category, name: rule.name,
    inputUnit: rule.inputUnit, minQuantity: rule.minQuantity, maxQuantity: rule.maxQuantity,
    mode: rule.mode, reductionFactorId: rule.reductionFactorId,
    baselineFactorId: rule.baselineFactorId, actualFactorId: rule.actualFactorId,
    baselineLabel: rule.baselineLabel, actualLabel: rule.actualLabel,
    assumptions: rule.assumptions.slice(), confirmationText: rule.confirmationText
  };
}

export function cloneFactor(factor: FactorDefinition): FactorDefinition {
  return {
    id: factor.id, version: factor.version, name: factor.name, unit: factor.unit,
    gramsCo2ePerUnit: factor.gramsCo2ePerUnit, originalValue: factor.originalValue,
    originalUnit: factor.originalUnit, evidenceStatus: factor.evidenceStatus,
    assumptions: factor.assumptions.slice(),
    source: {
      title: factor.source.title, url: factor.source.url, publisher: factor.source.publisher,
      publishedDate: factor.source.publishedDate, retrievedDate: factor.source.retrievedDate,
      region: factor.source.region, boundary: factor.source.boundary, notes: factor.source.notes
    }
  };
}

export function cloneCatalog(catalog: CalculationCatalog): CalculationCatalog {
  return {
    schemaVersion: catalog.schemaVersion, version: catalog.version,
    factors: catalog.factors.map((factor: FactorDefinition): FactorDefinition => cloneFactor(factor)),
    rules: catalog.rules.map((rule: CalculationRule): CalculationRule => cloneRule(rule))
  };
}

export function parseDocumentedCatalog(text: string): CalculationCatalog {
  try {
    const catalog = JSON.parse(text) as CalculationCatalog;
    validateCatalog(catalog, true);
    return cloneCatalog(catalog);
  } catch (error) {
    throw new AppError(ErrorCode.FACTOR_UNAVAILABLE, '核算规则资料无效或版本不受支持。');
  }
}
