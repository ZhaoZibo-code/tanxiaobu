import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { AppComposition } from '../../../main/ets/common/composition/AppComposition';
import { configureCalculation } from '../../../main/ets/common/composition/ResourceCalculationAdapter';
import { Category, QuantityUnit } from '../../../main/ets/common/contracts/Common';
import { CalculationInput, CalculationRule } from '../../../main/ets/common/contracts/Calculation';
import { AppError, ErrorCode } from '../../../main/ets/common/errors/AppError';

export default function calculationCompositionTest(): void {
  describe('M10CalculationComposition', () => {
    it('connectsNativeResourcesToTheExistingContainerUsingProductionInitializer', 0, async () => {
      const services = AppComposition.getServices();
      const changes = services.changes;
      configureCalculation(abilityDelegatorRegistry.getAbilityDelegator().getAppContext().resourceManager);
      expect(AppComposition.getServices() === services).assertTrue();
      expect(services.changes === changes).assertTrue();
      let notifications = 0;
      const unsubscribe = changes.subscribe(() => { notifications += 1; });
      try {
        const rules = await services.calculation.listRules();
        expect(rules.length).assertEqual(4);
        const categories: Category[] = [Category.ENERGY_WATER, Category.TRAVEL, Category.FOOD, Category.RECYCLING];
        const requests: CalculationInput[] = [
          { ruleId: 'saved-electricity-cn-2023', quantity: 1.25, unit: QuantityUnit.KWH,
            businessDate: '2026-10-28', note: '', baselineConfirmed: true },
          { ruleId: 'green-travel-avoided-km-2010', quantity: 200, unit: QuantityUnit.KM,
            businessDate: '2026-10-28', note: '', baselineConfirmed: true },
          { ruleId: 'avoided-pork-waste-handbook-2010', quantity: 0.5, unit: QuantityUnit.KG,
            businessDate: '2026-10-28', note: '', baselineConfirmed: true },
          { ruleId: 'completed-phone-reuse-ndrc-2022', quantity: 1, unit: QuantityUnit.PORTION,
            businessDate: '2026-10-28', note: '', baselineConfirmed: true }
        ];
        const expectedGrams: number[] = [663, 36800, 700, 25000];
        for (let index = 0; index < requests.length; index += 1) {
          expect(rules.filter((rule: CalculationRule): boolean => rule.category === categories[index]).length)
            .assertEqual(1);
          const preview = await services.calculation.preview(requests[index]);
          expect(preview.category).assertEqual(categories[index]);
          expect(preview.reductionGrams).assertEqual(expectedGrams[index]);
          expect(preview.factorSnapshot.rule.id).assertEqual(requests[index].ruleId);
          expect(preview.formulaText.includes(index === 3 ? 'g参考碳减排量' : 'gCO₂')).assertTrue();
          expect(preview.formulaText.includes('gCO₂e')).assertFalse();
        }
        expect(AppComposition.getServices() === services).assertTrue();
        expect(services.changes === changes).assertTrue();
        expect(notifications).assertEqual(0);
      } finally {
        unsubscribe();
      }
    });

    it('doesNotMarkUnimplementedBusinessServicesReady', 0, async () => {
      let code: string = '';
      try {
        await AppComposition.getServices().records.list({
          startDateInclusive: null, endDateExclusive: null, category: null,
          keyword: null, offset: 0, limit: 20
        });
      } catch (error) {
        code = (error as AppError).code;
      }
      expect(code).assertEqual(ErrorCode.MODULE_NOT_READY);
    });
  });
}
