import localUnitTest from './LocalUnit.test';
import toolsTest from './m01/Tools.test';
import compositionTest from './m01/Composition.test';
import calculationTest from './m02/Calculation.test';
import catalogTest from './m02/Catalog.test';
import persistenceValidationTest from './m03/Validation.test';
import statisticsTest from './m06/Statistics.test';
import backupValidationTest from './m08/BackupValidation.test';

export default function testsuite() {
  localUnitTest();
  toolsTest();
  compositionTest();
  calculationTest();
  catalogTest();
  persistenceValidationTest();
  statisticsTest();
  backupValidationTest();
}
