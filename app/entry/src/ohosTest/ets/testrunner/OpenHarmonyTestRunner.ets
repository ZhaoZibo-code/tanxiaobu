// Adapted from the official OpenHarmony AppStartup sample test runner.
import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit';
import { Want } from '@kit.AbilityKit';

export default class OpenHarmonyTestRunner implements TestRunner {
  onPrepare(): void {}

  async onRun(): Promise<void> {
    const args = abilityDelegatorRegistry.getArguments();
    const want: Want = {
      bundleName: args.bundleName,
      abilityName: 'TestAbility',
      moduleName: 'entry_test'
    };
    await abilityDelegatorRegistry.getAbilityDelegator().startAbility(want);
  }
}
