import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import util from '@ohos.util';
import { Category, QuantityUnit } from '../../../../main/ets/common/contracts/Common';
import { CalculationInput, CalculationRule, EvidenceStatus, FactorDefinition } from '../../../../main/ets/common/contracts/Calculation';
import { CalculationService } from '../../../../main/ets/common/contracts/Services';
import { AppError, ErrorCode } from '../../../../main/ets/common/errors/AppError';
import { CalculationCatalog, parseDocumentedCatalog } from '../../../../main/ets/domain/calculation/Catalog';
import { DocumentedCalculationService } from '../../../../main/ets/domain/calculation/DocumentedCalculationService';
import { CALCULATION_CATALOG_PATH, loadCalculationService } from '../../../../main/ets/domain/calculation/ResourceCalculationService';

async function service(): Promise<CalculationService> {
  return loadCalculationService(abilityDelegatorRegistry.getAbilityDelegator().getAppContext().resourceManager);
}

async function catalogAt(path: string): Promise<CalculationCatalog> {
  const manager = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().resourceManager;
  const bytes = await manager.getRawFileContent(path);
  return parseDocumentedCatalog(util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(bytes));
}

function input(ruleId: string, quantity: number, unit: QuantityUnit): CalculationInput {
  return {
    ruleId: ruleId, quantity: quantity, unit: unit,
    businessDate: '2026-10-28', note: '  资源测试  ', baselineConfirmed: true
  };
}

function requests(): CalculationInput[] {
  return [input('saved-electricity-cn-2023', 1.25, QuantityUnit.KWH),
    input('green-travel-avoided-km-2010', 200, QuantityUnit.KM),
    input('avoided-pork-waste-handbook-2010', 0.5, QuantityUnit.KG),
    input('completed-phone-reuse-ndrc-2022', 1, QuantityUnit.PORTION)];
}

async function expectCode(calculation: CalculationService, request: CalculationInput, expected: ErrorCode): Promise<void> {
  let code: string = '';
  try {
    await calculation.preview(request);
  } catch (error) {
    code = (error as AppError).code;
  }
  expect(code).assertEqual(expected);
}

export default function resourceCalculationTest(): void {
  describe('M02PackagedResources', () => {
    it('readsNewPackagedCatalogWithFourDocumentedScenes', 0, async () => {
      expect(CALCULATION_CATALOG_PATH).assertEqual('factors/catalog-v1.2.json');
      const catalog = await catalogAt(CALCULATION_CATALOG_PATH);
      expect(catalog.version).assertEqual('1.2.0');
      expect(catalog.factors.length).assertEqual(4);
      expect(catalog.rules.length).assertEqual(4);
      catalog.factors.forEach((factor: FactorDefinition): void => {
        expect(factor.evidenceStatus).assertEqual(EvidenceStatus.DOCUMENTED);
        expect(factor.source.url.startsWith('https://')).assertTrue();
        expect(factor.source.boundary.length > 0).assertTrue();
        expect(factor.source.region.length > 0).assertTrue();
        expect(factor.version).assertEqual('1.0.0');
      });
      [Category.TRAVEL, Category.ENERGY_WATER, Category.FOOD, Category.RECYCLING]
        .forEach((category: Category): void => {
          expect(catalog.rules.filter((rule: CalculationRule): boolean => rule.category === category).length).assertEqual(1);
        });
      expect(catalog.rules.some((rule: CalculationRule): boolean => rule.id === 'shared-bicycle-sh-2024')).assertFalse();
      expect(catalog.factors.some((factor: FactorDefinition): boolean => factor.id.startsWith('sh-'))).assertFalse();
      const rules = await (await service()).listRules();
      expect(rules).assertDeepEquals(catalog.rules);
    });

    it('keepsSavedElectricityAndCO2OnlyScope', 0, async () => {
      const preview = await (await service()).preview(requests()[0]);
      expect(preview.category).assertEqual(Category.ENERGY_WATER);
      expect(preview.reductionGrams).assertEqual(663);
      expect(preview.input.quantity).assertEqual(1.25);
      expect(preview.input.note).assertEqual('资源测试');
      expect(preview.factorSnapshot.factors[0].originalValue).assertEqual(0.5306);
      expect(preview.factorSnapshot.factors[0].gramsCo2ePerUnit).assertEqual(530.6);
      expect(preview.warnings.some((value: string): boolean => value.includes('只含CO₂'))).assertTrue();
      expect(preview.formulaText.includes('gCO₂e')).assertFalse();
      expect(preview.eligibleForPositiveTasks).assertTrue();
    });

    it('calculatesGreenTravelFromSameExamplePerKilometre', 0, async () => {
      const calculation = await service();
      const request = requests()[1];
      const preview = await calculation.preview(request);
      expect(preview.category).assertEqual(Category.TRAVEL);
      expect(preview.reductionGrams).assertEqual(36800);
      expect(preview.factorSnapshot.factors.length).assertEqual(1);
      const factor = preview.factorSnapshot.factors[0];
      expect(factor.originalValue).assertEqual(0.184);
      expect(factor.gramsCo2ePerUnit).assertEqual(184);
      expect(factor.originalUnit).assertEqual('kgCO2/km');
      expect(factor.source.notes.includes('汽油消耗16.7升')).assertTrue();
      expect(factor.source.notes.includes('二氧化碳36.8千克')).assertTrue();
      expect(factor.source.publishedDate).assertEqual('2010-05-11');
      expect(factor.source.notes.includes('36.8÷200')).assertTrue();
      expect(preview.assumptions.some((value: string): boolean => value.includes('不区分各自占比'))).assertTrue();
      request.quantity = 1;
      expect((await calculation.preview(request)).reductionGrams).assertEqual(184);
    });

    it('calculatesOnlyExplicitAvoidedPorkWasteNotMealsOrRice', 0, async () => {
      const calculation = await service();
      const request = requests()[2];
      const preview = await calculation.preview(request);
      expect(preview.category).assertEqual(Category.FOOD);
      expect(preview.reductionGrams).assertEqual(700);
      const factor = preview.factorSnapshot.factors[0];
      expect(factor.originalValue).assertEqual(0.7 / 0.5);
      expect(factor.gramsCo2ePerUnit).assertEqual(1400);
      expect(factor.source.notes.includes('每人每年少浪费0.5千克猪肉')).assertTrue();
      expect(factor.source.boundary.includes('未区分猪肉生熟')).assertTrue();
      expect(preview.factorSnapshot.rule.confirmationText.includes('不是总吃肉量')).assertTrue();
      expect(preview.assumptions.some((value: string): boolean => value.includes('不鼓励超量进食'))).assertTrue();
      request.quantity = 0.25;
      expect((await calculation.preview(request)).reductionGrams).assertEqual(350);
    });

    it('calculatesOneCompletedPhoneTransactionWithoutInventingGasScope', 0, async () => {
      const preview = await (await service()).preview(requests()[3]);
      expect(preview.category).assertEqual(Category.RECYCLING);
      expect(preview.reductionGrams).assertEqual(25000);
      expect(preview.factorSnapshot.rule.minQuantity).assertEqual(1);
      expect(preview.factorSnapshot.rule.maxQuantity).assertEqual(1);
      expect(preview.factorSnapshot.factors[0].originalUnit).assertEqual('kg碳减排量/portion');
      const source = preview.factorSnapshot.factors[0].source;
      expect(source.url.includes('ndrc.gov.cn')).assertTrue();
      expect(source.publishedDate).assertEqual('2022-01-25');
      expect(source.notes.includes('每一单闲置手机的二手交易')).assertTrue();
      expect(source.notes.includes('约25公斤')).assertTrue();
      expect(source.boundary.includes('未披露气体覆盖')).assertTrue();
      expect(preview.formulaText.includes('g参考碳减排量')).assertTrue();
      expect(preview.formulaText.includes('CO₂')).assertFalse();
      expect(preview.steps.some((value: string): boolean => value.includes('gCO₂e'))).assertFalse();
      expect(preview.factorSnapshot.rule.confirmationText.includes('不是挂单未售、拆解回收或其他旧物')).assertTrue();
      expect(preview.eligibleForPositiveTasks).assertTrue();
    });

    it('requiresActiveConfirmationForAllFourScenes', 0, async () => {
      const calculation = await service();
      for (const request of requests()) {
        request.baselineConfirmed = false;
        await expectCode(calculation, request, ErrorCode.BASELINE_REQUIRED);
      }
    });

    it('rejectsWrongUnitsNonFiniteAndOutOfRangeInputsForRealRules', 0, async () => {
      const calculation = await service();
      const rules = await calculation.listRules();
      for (const request of requests()) {
        const correctUnit = request.unit;
        request.unit = QuantityUnit.KM;
        await expectCode(calculation, request, ErrorCode.INVALID_INPUT);
        request.unit = correctUnit;
        for (const quantity of [0, -1, Number.NaN, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY]) {
          request.quantity = quantity;
          await expectCode(calculation, request, ErrorCode.INVALID_INPUT);
        }
        const found = rules.find((rule: CalculationRule): boolean => rule.id === request.ruleId) as CalculationRule;
        request.quantity = found.minQuantity - 0.0001;
        await expectCode(calculation, request, ErrorCode.INVALID_INPUT);
        request.quantity = found.maxQuantity + 0.0001;
        await expectCode(calculation, request, ErrorCode.INVALID_INPUT);
        request.quantity = found.minQuantity;
        expect((await calculation.preview(request)).input.quantity).assertEqual(found.minQuantity);
        request.quantity = found.maxQuantity;
        expect((await calculation.preview(request)).input.quantity).assertEqual(found.maxQuantity);
      }
    });

    it('acceptsExactlyOnePhoneTransactionAndRejectsFractionalOrBatchCounts', 0, async () => {
      const calculation = await service();
      const request = requests()[3];
      for (const quantity of [0.5, 1.1, 2]) {
        request.quantity = quantity;
        await expectCode(calculation, request, ErrorCode.INVALID_INPUT);
      }
      request.quantity = 1;
      expect((await calculation.preview(request)).reductionGrams).assertEqual(25000);
      request.ruleId = 'shared-bicycle-sh-2024';
      await expectCode(calculation, request, ErrorCode.RULE_NOT_FOUND);
      request.ruleId = 'unknown';
      await expectCode(calculation, request, ErrorCode.RULE_NOT_FOUND);
    });

    it('preservesOldCatalogAndShanghaiIdentifierMeaningWithoutActivatingIt', 0, async () => {
      const oldCatalog = await catalogAt('factors/catalog-v1.json');
      expect(oldCatalog.version).assertEqual('1.0.0');
      expect(oldCatalog.rules.length).assertEqual(2);
      expect(oldCatalog.factors.length).assertEqual(3);
      const oldService = new DocumentedCalculationService(oldCatalog);
      const old = await oldService.preview(input('shared-bicycle-sh-2024', 2.5, QuantityUnit.KM));
      expect(old.reductionGrams).assertEqual(245);
      expect(old.factorSnapshot.rule.baselineLabel.includes('不是小汽车')).assertTrue();
      expect(old.factorSnapshot.factors[0].source.region.includes('上海')).assertTrue();
      expect(old.assumptions.some((value: string): boolean => value.includes('缺省路径系数1'))).assertTrue();
      expect(old.warnings.some((value: string): boolean => value.includes('不构成核证减排'))).assertTrue();
      const currentCatalog = await catalogAt(CALCULATION_CATALOG_PATH);
      expect(currentCatalog.factors[0]).assertDeepEquals(oldCatalog.factors[0]);
      expect(currentCatalog.rules[0]).assertDeepEquals(oldCatalog.rules[0]);
      const saved = JSON.stringify(old);
      await (await service()).preview(requests()[1]);
      expect(JSON.stringify(old)).assertEqual(saved);
      await expectCode(oldService, requests()[1], ErrorCode.RULE_NOT_FOUND);
    });

    it('keepsAllFourFormalSnapshotsDeeplyIndependentAndRepeatable', 0, async () => {
      const calculation = await service();
      for (const request of requests()) {
        const first = await calculation.preview(request);
        const serialized = JSON.stringify(first);
        const sibling = await calculation.preview(request);
        expect(JSON.stringify(sibling)).assertEqual(serialized);
        sibling.factorSnapshot.factors[0].source.publisher = '修改';
        sibling.factorSnapshot.factors[0].assumptions[0] = '修改';
        sibling.factorSnapshot.rule.assumptions[0] = '修改';
        sibling.warnings[0] = '修改';
        sibling.input.note = '修改';
        const rules = await calculation.listRules();
        rules.forEach((rule: CalculationRule): void => {
          rule.confirmationText = '';
          rule.assumptions[0] = '修改';
        });
        const catalog = await catalogAt(CALCULATION_CATALOG_PATH);
        const replacement = new DocumentedCalculationService(catalog);
        catalog.factors.forEach((factor: FactorDefinition): void => {
          factor.source.notes = '修改';
          factor.assumptions[0] = '修改';
        });
        catalog.rules.forEach((rule: CalculationRule): void => {
          rule.assumptions[0] = '修改';
        });
        expect(JSON.stringify(first)).assertEqual(serialized);
        expect(JSON.stringify(await calculation.preview(request))).assertEqual(serialized);
        expect(JSON.stringify(await replacement.preview(request))).assertEqual(serialized);
        expect(JSON.stringify(await (await service()).preview(request))).assertEqual(serialized);
      }
    });
  });
}
