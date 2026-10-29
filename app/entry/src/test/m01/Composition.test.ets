import { describe, it, expect } from '@ohos/hypium';
import { AppComposition, createAppServices } from '../../main/ets/common/composition/AppComposition';
import { ChangeBus } from '../../main/ets/common/composition/ChangeBus';
import { Category, QuantityUnit, StatisticsPeriod } from '../../main/ets/common/contracts/Common';
import { CalculationInput } from '../../main/ets/common/contracts/Calculation';
import { SuggestionFeedback } from '../../main/ets/common/contracts/Content';
import { StatisticsQuery } from '../../main/ets/common/contracts/Statistics';
import { AppError, ErrorCode } from '../../main/ets/common/errors/AppError';

async function expectNotReady(work: () => Promise<void>): Promise<void> {
  let code: string = '';
  try {
    await work();
  } catch (error) {
    code = (error as AppError).code;
  }
  expect(code).assertEqual(ErrorCode.MODULE_NOT_READY);
}

export default function compositionTest(): void {
  describe('M01Composition', () => {
    it('keepsOneCompositionAndBroadcastsOnlyExplicitNotifications', 0, () => {
      expect(AppComposition.getServices() === AppComposition.getServices()).assertTrue();
      const bus = new ChangeBus();
      let first = 0;
      let second = 0;
      const unsubscribe = bus.subscribe(() => { first += 1; });
      bus.subscribe(() => { second += 1; });
      expect(first).assertEqual(0);
      bus.notifyDataChanged();
      expect(first).assertEqual(1);
      expect(second).assertEqual(1);
      unsubscribe();
      unsubscribe();
      bus.notifyDataChanged();
      expect(first).assertEqual(1);
      expect(second).assertEqual(2);
    });

    it('isolatesListenerFailureFromCommittedWriteNotifications', 0, () => {
      const bus = new ChangeBus();
      let received = 0;
      bus.subscribe(() => { throw new Error('test-only listener failure'); });
      bus.subscribe(() => { received += 1; });
      bus.notifyDataChanged();
      expect(received).assertEqual(1);
    });

    it('rejectsEveryUnavailableServiceMethodWithoutSuccessData', 0, async () => {
      const services = createAppServices();
      const input: CalculationInput = {
        ruleId: 'unavailable-test-only', quantity: 1, unit: QuantityUnit.KM,
        businessDate: '2026-10-27', note: '', baselineConfirmed: false
      };
      const query: StatisticsQuery = {
        period: StatisticsPeriod.DAY, anchorDate: '2026-10-27', category: Category.TRAVEL
      };
      await expectNotReady(async () => { await services.calculation.listRules(); });
      await expectNotReady(async () => { await services.calculation.preview(input); });
      await expectNotReady(async () => { await services.records.create(input, 'test-request'); });
      await expectNotReady(async () => { await services.records.update('test-record', input, 'test-request'); });
      await expectNotReady(async () => { await services.records.voidRecord('test-record', 'test-request'); });
      await expectNotReady(async () => { await services.records.getById('test-record'); });
      await expectNotReady(async () => {
        await services.records.list({
          startDateInclusive: null, endDateExclusive: null, category: null, keyword: null, offset: 0, limit: 20
        });
      });
      await expectNotReady(async () => { await services.tasks.listForDate('2026-10-27'); });
      await expectNotReady(async () => { await services.tasks.claim('test-task', '2026-10-27', 'test-request'); });
      await expectNotReady(async () => { await services.points.getBalance(); });
      await expectNotReady(async () => { await services.points.listLedger(0, 20); });
      await expectNotReady(async () => { await services.rewards.listRewards(); });
      await expectNotReady(async () => { await services.rewards.listRedemptions(); });
      await expectNotReady(async () => { await services.rewards.redeem('test-reward', 'test-request'); });
      await expectNotReady(async () => { await services.statistics.query(query); });
      await expectNotReady(async () => { await services.statistics.createReport(query); });
      await expectNotReady(async () => { await services.backup.exportBackup(); });
      await expectNotReady(async () => { await services.backup.inspectBackup('test-only-uri'); });
      await expectNotReady(async () => { await services.backup.restoreBackup('test-only-uri', 'test-digest', 'test-request'); });
      await expectNotReady(async () => { await services.backup.exportCsv(query); });
      await expectNotReady(async () => { await services.advice.listSuggestions('2026-10-27'); });
      await expectNotReady(async () => { await services.advice.recordFeedback('test-suggestion', SuggestionFeedback.ACCEPTED); });
    });

    it('providesOfflineKnowledgeWithoutSharingMutableArticleData', 0, async () => {
      const services = createAppServices();
      const articles = await services.knowledge.listArticles();
      expect(articles.length).assertEqual(3);
      const article = await services.knowledge.getArticle(articles[0].id);
      expect(article.sections.length > 0).assertTrue();
      expect(article.sources.length > 0).assertTrue();
      article.sections[0].body = 'changed by caller';
      const again = await services.knowledge.getArticle(articles[0].id);
      expect(again.sections[0].body === 'changed by caller').assertFalse();
    });
  });
}
