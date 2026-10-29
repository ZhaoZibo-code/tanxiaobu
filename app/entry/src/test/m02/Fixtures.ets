import { Category, QuantityUnit } from '../../main/ets/common/contracts/Common';
import { CalculationInput, CalculationMode, CalculationRule, EvidenceStatus,
  FactorDefinition } from '../../main/ets/common/contracts/Calculation';
import { CalculationCatalog } from '../../main/ets/domain/calculation/Catalog';

export function fixtureFactor(id: string, grams: number, unit: QuantityUnit): FactorDefinition {
  return {
    id: id, version: '1.0.0', name: `测试因子${id}`, unit: unit,
    gramsCo2ePerUnit: grams, originalValue: grams / 1000, originalUnit: `kgCO2e/${unit}`,
    source: {
      title: 'M02数学测试夹具（非科学来源）', url: 'https://example.invalid/m02-fixture',
      publisher: 'M02测试套件', publishedDate: null, retrievedDate: '2026-10-28',
      region: '测试专用', boundary: '相同测试边界', notes: '人为数值，仅验证计算，不进入正式资源。'
    },
    assumptions: ['测试假设'], evidenceStatus: EvidenceStatus.DEVELOPMENT_FIXTURE
  };
}

export function fixtureRule(difference: boolean): CalculationRule {
  return {
    id: difference ? 'test-difference' : 'test-direct', version: '1.0.0',
    category: difference ? Category.TRAVEL : Category.RECYCLING,
    name: '仅测试数学规则', inputUnit: difference ? QuantityUnit.KM : QuantityUnit.KG,
    minQuantity: 0.001, maxQuantity: 1000000,
    mode: difference ? CalculationMode.BASELINE_DIFFERENCE : CalculationMode.DIRECT_REDUCTION,
    reductionFactorId: difference ? null : 'test-net', baselineFactorId: difference ? 'test-base' : null,
    actualFactorId: difference ? 'test-actual' : null, baselineLabel: '测试基准', actualLabel: '测试实际',
    assumptions: ['规则测试假设'], confirmationText: '请确认这是测试基准。'
  };
}

export function fixtureCatalog(): CalculationCatalog {
  return {
    schemaVersion: 1, version: '1.0.0',
    factors: [fixtureFactor('test-net', 250, QuantityUnit.KG),
      fixtureFactor('test-base', 200, QuantityUnit.KM), fixtureFactor('test-actual', 80, QuantityUnit.KM)],
    rules: [fixtureRule(false), fixtureRule(true)]
  };
}

export function fixtureInput(difference: boolean = false): CalculationInput {
  return {
    ruleId: difference ? 'test-difference' : 'test-direct', quantity: 2.5,
    unit: difference ? QuantityUnit.KM : QuantityUnit.KG, businessDate: '2024-02-29',
    note: '  仅测试  ', baselineConfirmed: true
  };
}
