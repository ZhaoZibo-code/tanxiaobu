import { describe, it, expect } from '@ohos/hypium';
import { QuantityUnit } from '../../main/ets/common/contracts/Common';
import { CalculationInput } from '../../main/ets/common/contracts/Calculation';
import { AppError, ErrorCode } from '../../main/ets/common/errors/AppError';
import { CalculationCatalog, cloneCatalog, normalizeFactorGrams,
  parseDocumentedCatalog, validateCatalog } from '../../main/ets/domain/calculation/Catalog';
import { CalculationEngine } from '../../main/ets/domain/calculation/CalculationEngine';
import { DocumentedCalculationService } from '../../main/ets/domain/calculation/DocumentedCalculationService';
import { fixtureCatalog, fixtureFactor, fixtureInput } from './Fixtures';

function expectCode(work: () => void, expected: ErrorCode = ErrorCode.FACTOR_UNAVAILABLE): void {
  let code: string = '';
  try {
    work();
  } catch (error) {
    code = (error as AppError).code;
  }
  expect(code).assertEqual(expected);
}

function rejectCatalog(catalog: CalculationCatalog): void {
  expectCode(() => { new CalculationEngine(catalog); });
}

export default function catalogTest(): void {
  describe('M02Catalog', () => {
    it('convertsOriginalKilogramsToGramsWithoutRounding', 0, () => {
      expect(Math.abs(normalizeFactorGrams(0.5306, 'kgCO2/kWh', QuantityUnit.KWH) - 530.6) < 1e-10).assertTrue();
      expect(normalizeFactorGrams(0.098, 'kgCO2/PKM', QuantityUnit.KM)).assertEqual(98);
      expect(normalizeFactorGrams(0.0005, 'kgCO2e/kg', QuantityUnit.KG)).assertEqual(0.5);
      expect(normalizeFactorGrams(-0.0005, 'kgCO2e/kg', QuantityUnit.KG)).assertEqual(-0.5);
      expect(normalizeFactorGrams(1.25, 'gCO2e/L', QuantityUnit.LITRE)).assertEqual(1.25);
      expectCode(() => { normalizeFactorGrams(1, 'tCO2e/t', QuantityUnit.KG); });
      expectCode(() => { normalizeFactorGrams(1, 'kgCO2/kWh', QuantityUnit.KM); });
      expectCode(() => { normalizeFactorGrams(Number.NaN, 'kgCO2/kg', QuantityUnit.KG); });
      expectCode(() => { normalizeFactorGrams(Number.POSITIVE_INFINITY, 'kgCO2/kg', QuantityUnit.KG); });
    });

    it('rejectsDevelopmentFixturesFromFormalServiceAndParser', 0, () => {
      expectCode(() => { new DocumentedCalculationService(fixtureCatalog()); });
      expectCode(() => { parseDocumentedCatalog(JSON.stringify(fixtureCatalog())); });
      validateCatalog(fixtureCatalog(), false);
    });

    it('rejectsInvalidSchemaCatalogAndFactorVersions', 0, () => {
      const schema = fixtureCatalog();
      schema.schemaVersion = 2;
      rejectCatalog(schema);
      const catalog = fixtureCatalog();
      catalog.version = 'latest';
      rejectCatalog(catalog);
      catalog.version = '01.0.0';
      rejectCatalog(catalog);
      const factor = fixtureCatalog();
      factor.factors[0].version = '';
      rejectCatalog(factor);
      const rule = fixtureCatalog();
      rule.rules[0].version = 'v1';
      rejectCatalog(rule);
    });

    it('rejectsDuplicateFactorAndRuleIdentifiers', 0, () => {
      const factors = fixtureCatalog();
      factors.factors.push(fixtureFactor('test-net', 1, QuantityUnit.KG));
      rejectCatalog(factors);
      const rules = fixtureCatalog();
      rules.rules.push(rules.rules[0]);
      rejectCatalog(rules);
    });

    it('rejectsMissingReferencesAndMixedModeSlots', 0, () => {
      const missing = fixtureCatalog();
      missing.rules[0].reductionFactorId = 'missing';
      rejectCatalog(missing);
      const mixed = fixtureCatalog();
      mixed.rules[0].baselineFactorId = 'test-base';
      rejectCatalog(mixed);
      const absent = fixtureCatalog();
      absent.rules[1].actualFactorId = null;
      rejectCatalog(absent);
    });

    it('rejectsIncompatibleUnitsRegionsBoundariesAndGasCoverage', 0, () => {
      const units = fixtureCatalog();
      units.factors[1] = fixtureFactor('test-base', 200, QuantityUnit.KWH);
      rejectCatalog(units);
      const regions = fixtureCatalog();
      regions.factors[2].source.region = '另一地区';
      rejectCatalog(regions);
      const boundaries = fixtureCatalog();
      boundaries.factors[2].source.boundary = '另一系统边界';
      rejectCatalog(boundaries);
      const gas = fixtureCatalog();
      gas.factors[2].originalUnit = 'kgCO2/km';
      rejectCatalog(gas);
    });

    it('rejectsInconsistentNormalizedNumbersAndNegativeEmissionFactors', 0, () => {
      const wrong = fixtureCatalog();
      wrong.factors[0].gramsCo2ePerUnit = 251;
      rejectCatalog(wrong);
      const negative = fixtureCatalog();
      negative.factors[1] = fixtureFactor('test-base', -1, QuantityUnit.KM);
      rejectCatalog(negative);
      const infinite = fixtureCatalog();
      infinite.factors[0].gramsCo2ePerUnit = Number.POSITIVE_INFINITY;
      rejectCatalog(infinite);
    });

    it('requiresExplicitBaselineAndValidQuantityRange', 0, () => {
      const confirmation = fixtureCatalog();
      confirmation.rules[1].confirmationText = ' ';
      rejectCatalog(confirmation);
      const labels = fixtureCatalog();
      labels.rules[0].baselineLabel = '';
      rejectCatalog(labels);
      const bounds = fixtureCatalog();
      bounds.rules[0].maxQuantity = bounds.rules[0].minQuantity - 0.001;
      rejectCatalog(bounds);
      const infinite = fixtureCatalog();
      infinite.rules[0].maxQuantity = Number.POSITIVE_INFINITY;
      rejectCatalog(infinite);
      const nan = fixtureCatalog();
      nan.rules[0].minQuantity = Number.NaN;
      rejectCatalog(nan);
      const negative = fixtureCatalog();
      negative.rules[0].minQuantity = -1;
      rejectCatalog(negative);
    });

    it('acceptsFixedQuantityWithoutGloballyRestrictingPortionsToIntegers', 0, () => {
      const catalog = fixtureCatalog();
      catalog.factors[0] = fixtureFactor('test-net', 25000, QuantityUnit.PORTION);
      catalog.factors[0].originalUnit = 'kg碳减排量/portion';
      catalog.rules[0].inputUnit = QuantityUnit.PORTION;
      catalog.rules[0].minQuantity = 1;
      catalog.rules[0].maxQuantity = 1;
      const engine = new CalculationEngine(catalog);
      const input = fixtureInput();
      input.unit = QuantityUnit.PORTION;
      input.quantity = 1;
      const preview = engine.preview(input);
      expect(preview.reductionGrams).assertEqual(25000);
      expect(preview.formulaText.includes('g参考碳减排量')).assertTrue();
      expect(preview.formulaText.includes('CO₂')).assertFalse();
      [0.5, 1.1, 2].forEach((quantity: number): void => {
        input.quantity = quantity;
        expectCode(() => { engine.preview(input); }, ErrorCode.INVALID_INPUT);
      });
      catalog.rules[0].minQuantity = 0.5;
      catalog.rules[0].maxQuantity = 2;
      input.quantity = 0.5;
      expect(new CalculationEngine(catalog).preview(input).reductionGrams).assertEqual(12500);
      expect(normalizeFactorGrams(25, 'kg碳减排量/portion', QuantityUnit.PORTION)).assertEqual(25000);
      expectCode(() => { normalizeFactorGrams(25, 'kg碳减排量/portion', QuantityUnit.KG); });
      catalog.rules[0].maxQuantity = 0.4;
      rejectCatalog(catalog);
    });

    it('doesNotMixUnspecifiedCarbonScopeWithCO2InDifferenceRules', 0, () => {
      const catalog = fixtureCatalog();
      catalog.rules[1].inputUnit = QuantityUnit.PORTION;
      catalog.factors[1] = fixtureFactor('test-base', 200, QuantityUnit.PORTION);
      catalog.factors[1].originalUnit = 'kg碳减排量/portion';
      catalog.factors[2] = fixtureFactor('test-actual', 80, QuantityUnit.PORTION);
      catalog.factors[2].originalUnit = 'kgCO2/portion';
      rejectCatalog(catalog);
    });

    it('requiresTraceableSourceDatesAndMetadata', 0, () => {
      const url = fixtureCatalog();
      url.factors[0].source.url = 'not-a-url';
      rejectCatalog(url);
      const date = fixtureCatalog();
      date.factors[0].source.retrievedDate = '2026-02-30';
      rejectCatalog(date);
      const future = fixtureCatalog();
      future.factors[0].source.publishedDate = '2027-01-01';
      rejectCatalog(future);
      const publisher = fixtureCatalog();
      publisher.factors[0].source.publisher = '';
      rejectCatalog(publisher);
    });

    it('mapsBrokenJsonAndNullShapesToFactorUnavailable', 0, () => {
      ['{', 'null', '[]', '{}', '{"schemaVersion":1,"version":"1.0.0","factors":[null],"rules":[null]}']
        .forEach((text: string): void => {
          expectCode(() => { parseDocumentedCatalog(text); });
        });
      const valid = JSON.stringify(fixtureCatalog());
      ['"evidenceStatus":"unrecognized"', '"unit":"tonne"', '"category":"other"', '"mode":"other"']
        .forEach((field: string): void => {
          let broken: string = valid;
          if (field.startsWith('"evidenceStatus"')) {
            broken = valid.replace('"evidenceStatus":"development_fixture"', field);
          } else if (field.startsWith('"unit"')) {
            broken = valid.replace('"unit":"kg"', field);
          } else if (field.startsWith('"category"')) {
            broken = valid.replace('"category":"recycling"', field);
          } else {
            broken = valid.replace('"mode":"direct_reduction"', field);
          }
          expectCode(() => { new CalculationEngine(JSON.parse(broken) as CalculationCatalog); });
        });
    });

    it('rejectsRuntimeInputTypesRatherThanCoercingThem', 0, () => {
      const engine = new CalculationEngine(fixtureCatalog());
      const text = JSON.stringify(fixtureInput());
      const malformed: string[] = [text.replace('"quantity":2.5', '"quantity":"2.5"'),
        text.replace('"baselineConfirmed":true', '"baselineConfirmed":"true"'),
        text.replace('"note":"  仅测试  "', '"note":null'), 'null', '[]'];
      malformed.forEach((value: string): void => {
        expectCode(() => { engine.preview(JSON.parse(value) as CalculationInput); }, ErrorCode.INVALID_INPUT);
      });
    });

    it('clonesAllCatalogMetadataWithoutSharingNestedArrays', 0, () => {
      const catalog = fixtureCatalog();
      const clone = cloneCatalog(catalog);
      expect(clone).assertDeepEquals(catalog);
      clone.factors[0].source.title = 'new';
      clone.factors[0].assumptions[0] = 'new';
      clone.rules[0].assumptions[0] = 'new';
      expect(catalog.factors[0].source.title).assertEqual('M02数学测试夹具（非科学来源）');
      expect(catalog.factors[0].assumptions[0]).assertEqual('测试假设');
      expect(catalog.rules[0].assumptions[0]).assertEqual('规则测试假设');
    });
  });
}
