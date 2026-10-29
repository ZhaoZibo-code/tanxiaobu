import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit';
import { UuidGenerator } from '../../../main/ets/common/utils/Runtime';

async function assertTitle(driver: Driver, title: string): Promise<void> {
  await driver.waitForComponent(ON.text(title).id('shell-page-title'), 5000);
  expect(await (await driver.findComponent(ON.id('shell-page-title'))).getText()).assertEqual(title);
  await driver.waitForComponent(ON.text('功能尚未就绪').id('shell-status-title'), 5000);
}

export default function abilityTest(): void {
  describe('M01NativeShell', () => {
    it('rendersIsolatedLoadingEmptyAndRetryStates', 0, async () => {
      const driver = Driver.create();
      await driver.waitForComponent(ON.id('test-state-loading'), 5000);
      await (await driver.findComponent(ON.id('test-state-loading'))).click();
      await driver.waitForComponent(ON.text('正在读取').id('shell-status-title'), 3000);
      await (await driver.findComponent(ON.id('test-state-empty'))).click();
      await driver.waitForComponent(ON.text('暂无记录').id('shell-status-title'), 3000);
      await (await driver.findComponent(ON.id('test-state-error'))).click();
      await driver.waitForComponent(ON.text('测试读取失败').id('shell-status-title'), 3000);
      await (await driver.findComponent(ON.id('shell-retry'))).click();
      await driver.waitForComponent(ON.text('暂无记录').id('shell-status-title'), 3000);
      expect(await (await driver.findComponent(ON.id('test-retry-count'))).getText()).assertEqual('重试次数：1');
    });

    it('navigatesFiveTabsAndUnreadySubpages', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({
        bundleName: 'com.carbonfootprint.app', abilityName: 'EntryAbility', moduleName: 'entry'
      });
      const driver = Driver.create();
      await assertTitle(driver, '总览');
      await (await driver.findComponent(ON.id('shell-link-knowledge'))).click();
      await assertTitle(driver, '低碳科普');
      await (await driver.findComponent(ON.id('shell-back'))).click();
      await assertTitle(driver, '总览');
      await (await driver.findComponent(ON.id('shell-tab-records'))).click();
      await assertTitle(driver, '记录');
      await (await driver.findComponent(ON.id('shell-tab-statistics'))).click();
      await assertTitle(driver, '统计');
      await (await driver.findComponent(ON.id('shell-tab-tasks'))).click();
      await assertTitle(driver, '任务');
      await (await driver.findComponent(ON.id('shell-link-rewards'))).click();
      await assertTitle(driver, '虚拟奖励');
      await driver.pressBack();
      await assertTitle(driver, '任务');
      await (await driver.findComponent(ON.id('shell-tab-profile'))).click();
      await assertTitle(driver, '我的');
      await (await driver.findComponent(ON.id('shell-link-data_management'))).click();
      await assertTitle(driver, '数据管理');
      await (await driver.findComponent(ON.id('shell-tab-overview'))).click();
      await assertTitle(driver, '总览');
      await (await driver.findComponent(ON.id('shell-link-advice'))).click();
      await assertTitle(driver, '低碳建议');
      await driver.pressBack();
      await assertTitle(driver, '总览');
    });

    it('generatesNativeUuidIdentifiers', 0, () => {
      const ids = new UuidGenerator();
      const first = ids.newId();
      const second = ids.newId();
      expect(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(first)).assertTrue();
      expect(first === second).assertFalse();
    });
  });
}
