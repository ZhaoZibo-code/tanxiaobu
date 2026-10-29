import { Category, Id, LocalDate, QuantityUnit } from './Common';

export enum EvidenceStatus {
  DOCUMENTED = 'documented',
  DEVELOPMENT_FIXTURE = 'development_fixture'
}

export enum CalculationMode {
  DIRECT_REDUCTION = 'direct_reduction',
  BASELINE_DIFFERENCE = 'baseline_difference'
}

export interface FactorSource {
  title: string;
  url: string;
  publisher: string;
  publishedDate: LocalDate | null;
  retrievedDate: LocalDate;
  region: string;
  boundary: string;
  notes: string;
}

export interface FactorDefinition {
  id: Id;
  version: string;
  name: string;
  unit: QuantityUnit;
  gramsCo2ePerUnit: number;
  originalValue: number;
  originalUnit: string;
  source: FactorSource;
  assumptions: string[];
  evidenceStatus: EvidenceStatus;
}

export interface CalculationRule {
  id: Id;
  version: string;
  category: Category;
  name: string;
  inputUnit: QuantityUnit;
  minQuantity: number;
  maxQuantity: number;
  mode: CalculationMode;
  reductionFactorId: Id | null;
  baselineFactorId: Id | null;
  actualFactorId: Id | null;
  baselineLabel: string;
  actualLabel: string;
  assumptions: string[];
  confirmationText: string;
}

export interface CalculationInput {
  ruleId: Id;
  quantity: number;
  unit: QuantityUnit;
  businessDate: LocalDate;
  note: string;
  baselineConfirmed: boolean;
}

export interface FactorSnapshot {
  rule: CalculationRule;
  factors: FactorDefinition[];
}

export interface CalculationPreview {
  input: CalculationInput;
  category: Category;
  ruleName: string;
  reductionGrams: number;
  formulaText: string;
  steps: string[];
  assumptions: string[];
  warnings: string[];
  factorSnapshot: FactorSnapshot;
  eligibleForPositiveTasks: boolean;
}
