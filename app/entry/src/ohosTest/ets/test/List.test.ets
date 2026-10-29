import abilityTest from './Ability.test';
import resourceCalculationTest from './m02/ResourceCalculation.test';
import calculationCompositionTest from './CalculationComposition.test';
import rdbPersistenceTest from './m03/RdbPersistence.test';
import engagementTest from './m04/Engagement.test';

export default function testsuite() {
  abilityTest();
  resourceCalculationTest();
  calculationCompositionTest();
  rdbPersistenceTest();
  engagementTest();
}
