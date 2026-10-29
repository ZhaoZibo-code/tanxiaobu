import { describe, it, expect } from '@ohos/hypium';
import { QuantityUnit } from '../../main/ets/common/contracts/Common';
import { AppError, ErrorCode } from '../../main/ets/common/errors/AppError';
import { CalculationEngine } from '../../main/ets/domain/calculation/CalculationEngine';
import { fixtureCatalog, fixtureFactor, fixtureInput } from './Fixtures';

function expectCode(work: () => void, expected: ErrorCode): void {
  let code: string = '';
  try {
    work();
  } catch (error) {
    code = (error as AppError).code;
  }
  expect(code).assertEqual(expected);
}

export default function calculationTest(): void {
  describe('M02Calculation', () => {
    it('calculatesDirectNetReductionAndNormalizesInput', 0, () => {
      const input = fixtureInput();
      const preview = new CalculationEngine(fixtureCatalog()).preview(input);
      expect(preview.reductionGrams).assertEqual(625);
      expect(preview.input.note).assertEqual('仅测试');
      expect(input.note).assertEqual('  仅测试  ');
      expect(preview.input.quantity).assertEqual(2.5);
      expect(preview.eligibleForPositiveTasks).assertTrue();
      expect(preview.factorSnapshot.factors.length).assertEqual(1);
      expect(preview.factorSnapshot.factors[0].originalValue).assertEqual(0.25);
      expect(preview.steps.length > 3).assertTrue();
      expect(preview.formulaText.includes('625')).assertTrue();
      expect(preview.warnings.some((value: string): boolean => value.includes('开发测试因子'))).assertTrue();
    });

    it('calculatesBaselineMinusActualWithoutSubtractingAgain', 0, () => {
      const preview = new CalculationEngine(fixtureCatalog()).preview(fixtureInput(true));
      expect(preview.reductionGrams).assertEqual(300);
      expect(preview.factorSnapshot.factors.length).assertEqual(2);
      expect(preview.factorSnapshot.factors[0].id).assertEqual('test-base');
      expect(preview.factorSnapshot.factors[1].id).assertEqual('test-actual');
      expect(preview.formulaText.includes('(200 − 80)')).assertTrue();
    });

    it('roundsOnlyFinalDifferenceNotEachFactor', 0, () => {
      const catalog = fixtureCatalog();
      catalog.factors[1] = fixtureFactor('test-base', 1.2, QuantityUnit.KM);
      catalog.factors[2] = fixtureFactor('test-actual', 0.6, QuantityUnit.KM);
      const input = fixtureInput(true);
      input.quantity = 1;
      expect(new CalculationEngine(catalog).preview(input).reductionGrams).assertEqual(1);
    });

    it('roundsPositiveAndNegativeHalfGramsAwayFromZero', 0, () => {
      const catalog = fixtureCatalog();
      const input = fixtureInput();
      input.quantity = 1;
      catalog.factors[0] = fixtureFactor('test-net', 0.5, QuantityUnit.KG);
      expect(new CalculationEngine(catalog).preview(input).reductionGrams).assertEqual(1);
      catalog.factors[0] = fixtureFactor('test-net', -0.5, QuantityUnit.KG);
      const negative = new CalculationEngine(catalog).preview(input);
      expect(negative.reductionGrams).assertEqual(-1);
      expect(negative.eligibleForPositiveTasks).assertFalse();
    });

    it('retainsNegativeDifferenceAndExplainsIncreasedEmissions', 0, () => {
      const catalog = fixtureCatalog();
      catalog.factors[2] = fixtureFactor('test-actual', 250, QuantityUnit.KM);
      const preview = new CalculationEngine(catalog).preview(fixtureInput(true));
      expect(preview.reductionGrams).assertEqual(-125);
      expect(preview.eligibleForPositiveTasks).assertFalse();
      expect(preview.warnings.some((value: string): boolean => value.includes('排放增加'))).assertTrue();
    });

    it('doesNotQualifyZeroOrRoundedTinyPositiveForTasks', 0, () => {
      const catalog = fixtureCatalog();
      const input = fixtureInput();
      input.quantity = 1;
      catalog.factors[0] = fixtureFactor('test-net', 0, QuantityUnit.KG);
      const zero = new CalculationEngine(catalog).preview(input);
      expect(zero.reductionGrams).assertEqual(0);
      expect(zero.eligibleForPositiveTasks).assertFalse();
      catalog.factors[0] = fixtureFactor('test-net', 0.49, QuantityUnit.KG);
      const tiny = new CalculationEngine(catalog).preview(input);
      expect(tiny.reductionGrams).assertEqual(0);
      expect(tiny.eligibleForPositiveTasks).assertFalse();
      catalog.factors[0] = fixtureFactor('test-net', -0.49, QuantityUnit.KG);
      const negativeZero = new CalculationEngine(catalog).preview(input);
      expect(1 / negativeZero.reductionGrams).assertEqual(Number.POSITIVE_INFINITY);
    });

    it('rejectsUnitMismatchAndUnknownRule', 0, () => {
      const engine = new CalculationEngine(fixtureCatalog());
      const input = fixtureInput();
      input.unit = QuantityUnit.LITRE;
      expectCode(() => { engine.preview(input); }, ErrorCode.INVALID_INPUT);
      input.unit = QuantityUnit.KG;
      input.ruleId = 'missing';
      expectCode(() => { engine.preview(input); }, ErrorCode.RULE_NOT_FOUND);
      input.ruleId = '';
      expectCode(() => { engine.preview(input); }, ErrorCode.INVALID_INPUT);
    });

    it('rejectsNonFiniteNonpositiveAndOutOfRangeQuantities', 0, () => {
      const engine = new CalculationEngine(fixtureCatalog());
      [Number.NaN, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY, -1, 0, -0, 0.0009, 1000001]
        .forEach((quantity: number): void => {
          const input = fixtureInput();
          input.quantity = quantity;
          expectCode(() => { engine.preview(input); }, ErrorCode.INVALID_INPUT);
        });
      const min = fixtureInput();
      min.quantity = 0.001;
      expect(engine.preview(min).input.quantity).assertEqual(0.001);
      min.quantity = 1000000;
      expect(engine.preview(min).reductionGrams).assertEqual(250000000);
    });

    it('validatesRealCalendarDateWithoutChangingBusinessDay', 0, () => {
      const engine = new CalculationEngine(fixtureCatalog());
      ['2023-02-29', '1900-02-29', '2026-04-31', '0000-01-01', '2026-1-01', '2026-01-01T00:00:00Z']
        .forEach((date: string): void => {
          const input = fixtureInput();
          input.businessDate = date;
          expectCode(() => { engine.preview(input); }, ErrorCode.INVALID_INPUT);
        });
      const input = fixtureInput();
      input.businessDate = '0001-01-01';
      expect(engine.preview(input).input.businessDate).assertEqual('0001-01-01');
    });

    it('requiresConfirmationForDifferenceAndConditionalDirectRules', 0, () => {
      const engine = new CalculationEngine(fixtureCatalog());
      [false, true].forEach((difference: boolean): void => {
        const input = fixtureInput(difference);
        input.baselineConfirmed = false;
        expectCode(() => { engine.preview(input); }, ErrorCode.BASELINE_REQUIRED);
      });
    });

    it('rejectsUnsafeFinalGramResult', 0, () => {
      const catalog = fixtureCatalog();
      catalog.factors[0] = fixtureFactor('test-net', 1000000000000, QuantityUnit.KG);
      const input = fixtureInput();
      input.quantity = 1000000;
      expectCode(() => { new CalculationEngine(catalog).preview(input); }, ErrorCode.INVALID_INPUT);
    });

    it('isolatesInputListsCatalogAndNestedHistoricalSnapshots', 0, () => {
      const catalog = fixtureCatalog();
      const engine = new CalculationEngine(catalog);
      const input = fixtureInput(true);
      const original = engine.preview(input);
      const saved = JSON.stringify(original);
      const sibling = engine.preview(input);
      const rules = engine.listRules();
      catalog.version = '2.0.0';
      catalog.rules[1].name = '改规则';
      catalog.rules[1].assumptions[0] = '改假设';
      catalog.factors[1] = fixtureFactor('test-base', 800, QuantityUnit.KM);
      rules[1].assumptions[0] = '列表改假设';
      input.note = '修改输入';
      sibling.input.note = '改预览';
      sibling.factorSnapshot.rule.assumptions[0] = '改快照规则';
      sibling.factorSnapshot.factors[0].source.notes = '改嵌套来源';
      sibling.factorSnapshot.factors[0].assumptions[0] = '改嵌套假设';
      sibling.assumptions[0] = '改汇总假设';
      sibling.steps[0] = '改步骤';
      sibling.warnings[0] = '改警告';
      expect(JSON.stringify(original)).assertEqual(saved);
      expect(engine.preview(fixtureInput(true)).reductionGrams).assertEqual(300);
      expect(engine.listRules()[1].assumptions[0]).assertEqual('规则测试假设');
      const updated = new CalculationEngine(catalog).preview(fixtureInput(true));
      expect(updated.reductionGrams).assertEqual(1800);
      expect(JSON.stringify(original)).assertEqual(saved);
    });

    it('isDeterministicAndKeepsFullPrecisionInput', 0, () => {
      const engine = new CalculationEngine(fixtureCatalog());
      const input = fixtureInput();
      input.quantity = 1.23456789;
      const first = engine.preview(input);
      expect(first.input.quantity).assertEqual(1.23456789);
      expect(first.reductionGrams).assertEqual(309);
      expect(JSON.stringify(engine.preview(input))).assertEqual(JSON.stringify(first));
    });
  });
}
